-- client/cutting_board.lua
-- ================================================================
-- TÁBUA DE CORTE FÍSICA 3D COM FACA DE CHEF (INTERACTIVE SLICING)
-- Câmera em ângulo fechado sobre a tábua de corte.
-- Faca móvel orientada pelo mouse e descida rítmica de fatiamento.
-- Fatias 3D desacopladas fisicamente a cada golpe, com som de madeira e áudio NUI.
-- Integração server-authoritative e anti-exploit com ox_inventory.
-- ================================================================

local isCuttingActive       = false
local cuttingCam            = nil
local boardCenterCoords     = nil
local boardProp             = nil
local knifeProp             = nil
local currentRawProp        = nil
local currentSlicesProps    = {}
local activeRecipe          = nil
local currentCuts           = 0
local totalRequiredCuts     = 4
local sessionToken          = nil
local isChopping            = false

-- Receitas de Corte Disponíveis na Tábua
local CUTTING_RECIPES = {
    potato = {
        label        = "Batata Inteira",
        inputItem    = "raw_potato",
        outputItem   = "raw_fries",
        outputCount  = 2,
        rawModel     = "prop_veg_crop_01",
        sliceModel   = "mxc_kitchen_prop_kebab_wrap_fries",
        rawScale     = 0.8,
        sliceScale   = 0.9,
        cutsRequired = 4,
        icon         = "🥔"
    },
    tomato = {
        label        = "Tomate Fresco",
        inputItem    = "raw_tomato",
        outputItem   = "tomato",
        outputCount  = 3,
        rawModel     = "prop_cs_burger_01",
        sliceModel   = "mxc_kitchen_prop_burger_tomatoes",
        rawScale     = 0.6,
        sliceScale   = 1.0,
        cutsRequired = 4,
        icon         = "🍅"
    },
    cheese = {
        label        = "Bloco de Queijo",
        inputItem    = "raw_cheese",
        outputItem   = "cheese",
        outputCount  = 3,
        rawModel     = "prop_cs_cheese",
        sliceModel   = "mxc_kitchen_prop_burger_cheddar",
        rawScale     = 0.7,
        sliceScale   = 1.0,
        cutsRequired = 4,
        icon         = "🧀"
    },
    onion = {
        label        = "Cebola Inteira",
        inputItem    = "raw_onion",
        outputItem   = "sliced_onion",
        outputCount  = 2,
        rawModel     = "mxc_kitchen_prop_burger_onion",
        sliceModel   = "mxc_kitchen_prop_burger_onion",
        rawScale     = 1.0,
        sliceScale   = 0.9,
        cutsRequired = 4,
        icon         = "🧅"
    },
    meat = {
        label        = "Peça de Carne",
        inputItem    = "raw_meat",
        outputItem   = "raw_meat",
        outputCount  = 2,
        rawModel     = "prop_cs_steak",
        sliceModel   = "mxc_kitchen_prop_burger_meat_1",
        rawScale     = 0.9,
        sliceScale   = 0.9,
        cutsRequired = 4,
        icon         = "🥩"
    }
}

-- ── Carregar Modelo de forma segura com fallback ────────────────
local function LoadModelSafely(primary, fallback)
    local hash = GetHashKey(primary)
    if IsModelInCdimage(hash) and IsModelValid(hash) then
        RequestModel(hash)
        local t = 0
        while not HasModelLoaded(hash) and t < 80 do
            Wait(10); t = t + 1
        end
        if HasModelLoaded(hash) then return hash end
    end
    if fallback then
        local fbHash = GetHashKey(fallback)
        RequestModel(fbHash)
        local t = 0
        while not HasModelLoaded(fbHash) and t < 80 do
            Wait(10); t = t + 1
        end
        if HasModelLoaded(fbHash) then return fbHash end
    end
    return nil
end

-- ── Limpar Props e Entidades da Sessão ───────────────────────────
local function CleanupCuttingEntities()
    if knifeProp and DoesEntityExist(knifeProp) then
        DeleteEntity(knifeProp)
        knifeProp = nil
    end
    if currentRawProp and DoesEntityExist(currentRawProp) then
        DeleteEntity(currentRawProp)
        currentRawProp = nil
    end
    for _, slProp in ipairs(currentSlicesProps) do
        if slProp and DoesEntityExist(slProp) then
            DeleteEntity(slProp)
        end
    end
    currentSlicesProps = {}
    if boardProp and DoesEntityExist(boardProp) then
        DeleteEntity(boardProp)
        boardProp = nil
    end
end

-- ── Encerrar a Câmera de Corte ──────────────────────────────────
function StopCuttingCamera()
    if not isCuttingActive then return end
    isCuttingActive = false

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    CleanupCuttingEntities()

    if cuttingCam and DoesCamExist(cuttingCam) then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(cuttingCam, false)
        cuttingCam = nil
    end

    SendNUIMessage({ action = 'closeCuttingWorld' })
    SetNuiFocus(false, false)
end

-- ── Spawnar Fatia 3D com deslocamento físico lateral ────────────
local function SpawnSliceProp(recipe, cutIndex)
    if not boardCenterCoords then return end
    local sliceHash = LoadModelSafely(recipe.sliceModel, "prop_cs_steak")
    if not sliceHash then return end

    -- As fatias vão sendo empilhadas / deslocadas para a direita da tábua
    local offsetX = 0.08 + (cutIndex * 0.035)
    local offsetY = (cutIndex % 2 == 0) and 0.02 or -0.02
    local sliceZ  = boardCenterCoords.z + 0.035

    local sliceObj = CreateObject(sliceHash, boardCenterCoords.x + offsetX, boardCenterCoords.y + offsetY, sliceZ, false, false, false)
    if DoesEntityExist(sliceObj) then
        SetEntityCollision(sliceObj, false, false)
        -- Leve inclinação para dar realismo orgânico
        SetEntityRotation(sliceObj, math.random(-8, 8) + 0.0, math.random(-8, 8) + 0.0, math.random(10, 80) + 0.0, 2, true)
        FreezeEntityPosition(sliceObj, true)
        table.insert(currentSlicesProps, sliceObj)
    end
end

-- ── Executar Golpe da Faca ──────────────────────────────────────
local function PerformKnifeChop()
    if isChopping or not isCuttingActive or not activeRecipe then return end
    isChopping = true

    -- Som de corte via Web Audio NUI
    SendNUIMessage({ action = 'PLAY_CHOP_SOUND' })

    -- Animação rápida de descida da faca (interpolação rápida)
    if knifeProp and DoesEntityExist(knifeProp) then
        local currentCoords = GetEntityCoords(knifeProp)
        local baseZ = boardCenterCoords.z + 0.035
        local upZ   = boardCenterCoords.z + 0.12

        -- Golpe de corte: desce com força
        SetEntityCoords(knifeProp, currentCoords.x, currentCoords.y, baseZ, false, false, false, false)
        SetEntityRotation(knifeProp, 18.0, 0.0, -90.0, 2, true)
        Wait(60)

        -- Retorna para a posição de suspensão
        SetEntityCoords(knifeProp, currentCoords.x, currentCoords.y, upZ, false, false, false, false)
        SetEntityRotation(knifeProp, 0.0, 0.0, -90.0, 2, true)
    end

    currentCuts = currentCuts + 1
    SpawnSliceProp(activeRecipe, currentCuts)

    -- Atualiza NUI
    SendNUIMessage({
        action    = 'UPDATE_CUTTING_PROGRESS',
        cuts      = currentCuts,
        totalCuts = totalRequiredCuts,
        title     = activeRecipe.label,
        hint      = (currentCuts >= totalRequiredCuts) and "Concluído! Recolhendo fatias..." or "Continue fatiando no ritmo!"
    })

    -- Se completou todas as fatias necessárias
    if currentCuts >= totalRequiredCuts then
        Wait(250)
        SendNUIMessage({ action = 'PLAY_DING_SOUND' })
        
        -- Solicita conclusão segura ao servidor
        TriggerServerEvent('granolla_restaurants:server:CompleteCutting', sessionToken, activeRecipe.inputItem, activeRecipe.outputItem, activeRecipe.outputCount)
        Wait(600)
        StopCuttingCamera()
        return
    end

    Wait(150)
    isChopping = false
end

-- ── Iniciar o Corte de um Ingrediente Específico ─────────────────
local function SetupIngredientForCutting(recipeKey)
    local recipe = CUTTING_RECIPES[recipeKey]
    if not recipe then return end

    -- Solicita início de sessão ao servidor para validação de posse do item
    lib.callback('granolla_restaurants:server:StartCuttingSession', false, function(token)
        if not token then
            lib.notify({ title = 'Tábua de Corte', description = 'Você não possui ' .. recipe.label .. ' no inventário!', type = 'error' })
            return
        end

        sessionToken       = token
        activeRecipe       = recipe
        currentCuts        = 0
        totalRequiredCuts  = recipe.cutsRequired
        isChopping         = false

        -- Spawna o prop do ingrediente cru centralizado na tábua
        if currentRawProp and DoesEntityExist(currentRawProp) then DeleteEntity(currentRawProp) end
        local rawHash = LoadModelSafely(recipe.rawModel, "prop_cs_steak")
        if rawHash and boardCenterCoords then
            currentRawProp = CreateObject(rawHash, boardCenterCoords.x - 0.02, boardCenterCoords.y, boardCenterCoords.z + 0.035, false, false, false)
            SetEntityCollision(currentRawProp, false, false)
            FreezeEntityPosition(currentRawProp, true)
        end

        -- Spawna a Faca de Chef suspensa
        if knifeProp and DoesEntityExist(knifeProp) then DeleteEntity(knifeProp) end
        local knifeHash = LoadModelSafely("prop_knife", "mxc_kitchen_prop_tools_kebabknife")
        if knifeHash and boardCenterCoords then
            knifeProp = CreateObject(knifeHash, boardCenterCoords.x, boardCenterCoords.y, boardCenterCoords.z + 0.12, false, false, false)
            SetEntityCollision(knifeProp, false, false)
            SetEntityRotation(knifeProp, 0.0, 0.0, -90.0, 2, true)
            FreezeEntityPosition(knifeProp, true)
        end

        -- Notifica NUI
        SendNUIMessage({
            action    = 'openCuttingWorld',
            cuts      = 0,
            totalCuts = totalRequiredCuts,
            title     = recipe.label,
            hint      = "Pressione [ESPAÇO] ou [CLIQUE] para descer a lâmina"
        })

        -- Thread de controle e movimentação da faca durante o corte
        CreateThread(function()
            local knifeOffsetLimit = 0.12
            while isCuttingActive and activeRecipe do
                Wait(0)
                DisableControlAction(0, 24, true)  -- Attack / LMB
                DisableControlAction(0, 25, true)  -- Aim / RMB
                DisableControlAction(0, 22, true)  -- Jump / Spacebar
                DisableControlAction(0, 177, true) -- Backspace
                DisableControlAction(0, 200, true) -- ESC

                -- Sair ao pressionar Backspace ou ESC
                if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                    StopCuttingCamera()
                    break
                end

                -- Fatiar ao pressionar LMB ou Barra de Espaço
                if (IsDisabledControlJustPressed(0, 24) or IsDisabledControlJustPressed(0, 22)) and not isChopping then
                    PerformKnifeChop()
                end

                -- Suave acompanhamento horizontal da faca se não estiver golpeando
                if not isChopping and knifeProp and DoesEntityExist(knifeProp) and boardCenterCoords then
                    local targetX = boardCenterCoords.x - 0.04 + (currentCuts * 0.025)
                    local currentCoords = GetEntityCoords(knifeProp)
                    local newX = currentCoords.x + (targetX - currentCoords.x) * 0.2
                    SetEntityCoords(knifeProp, newX, boardCenterCoords.y, boardCenterCoords.z + 0.12, false, false, false, false)
                end
            end
        end)

    end, recipe.inputItem)
end

-- ── Menu de Seleção de Ingrediente da Tábua ─────────────────────
local function OpenCuttingBoardMenu()
    local options = {}
    for key, recipe in pairs(CUTTING_RECIPES) do
        table.insert(options, {
            title       = recipe.icon .. " " .. recipe.label,
            description = "Fatiar para gerar porções culinárias",
            icon        = "scissors",
            onSelect    = function()
                SetupIngredientForCutting(key)
            end
        })
    end

    table.insert(options, {
        title    = "❌ Fechar e Sair",
        icon     = "circle-xmark",
        onSelect = function()
            StopCuttingCamera()
        end
    })

    lib.registerContext({
        id      = 'cutting_board_selection_menu',
        title   = '🔪 Tábua de Corte de Chef',
        options = options
    })
    lib.showContext('cutting_board_selection_menu')
end

-- ════════════════════════════════════════════════════════════════
-- StartCuttingCamera — Entra no Modo Tábua de Corte 3D
-- ════════════════════════════════════════════════════════════════
function StartCuttingCamera(workstationCoords, stationId)
    local ped = PlayerPedId()
    if isCuttingActive then return end

    if not workstationCoords then
        workstationCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.75, 0.0)
    end
    boardCenterCoords = vector3(workstationCoords.x, workstationCoords.y, workstationCoords.z)

    isCuttingActive = true
    FreezeEntityPosition(ped, true)

    TaskTurnPedToFaceCoord(ped, boardCenterCoords.x, boardCenterCoords.y, boardCenterCoords.z, 300)
    Wait(150)

    -- Postura de trabalho
    lib.requestAnimDict('anim@amb@business@weed@weed_inspecting_high_dry@')
    TaskPlayAnim(ped, 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Câmera focalizada na tábua de madeira em ângulo top-down de 50 graus
    local camX = boardCenterCoords.x
    local camY = boardCenterCoords.y - 0.42
    local camZ = boardCenterCoords.z + 0.48

    cuttingCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cuttingCam, camX, camY, camZ)
    PointCamAtCoord(cuttingCam, boardCenterCoords.x, boardCenterCoords.y, boardCenterCoords.z + 0.02)
    SetCamFov(cuttingCam, 38.0)
    RenderScriptCams(true, true, 600, true, true)

    -- Spawna a tábua de corte de madeira
    local boardHash = LoadModelSafely("v_res_tre_kitchenboard", "prop_food_bs_burger")
    if boardHash then
        boardProp = CreateObject(boardHash, boardCenterCoords.x, boardCenterCoords.y, boardCenterCoords.z + 0.02, false, false, false)
        SetEntityCollision(boardProp, false, false)
        FreezeEntityPosition(boardProp, true)
    end

    Wait(400)
    OpenCuttingBoardMenu()
end

-- Export público e comando de teste
exports('StartCuttingCamera', StartCuttingCamera)

RegisterCommand('testcut', function()
    StartCuttingCamera()
end, false)
