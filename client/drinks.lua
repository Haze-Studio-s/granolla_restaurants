-- client/drinks.lua
-- ================================================================
-- MÁQUINA DE REFRIGERANTE & BEBIDAS 3D (SODA FOUNTAIN DISPENSER)
-- Câmera em ângulo fechado focalizada no dispensador de bebidas.
-- Copo físico posicionado sob a torneira da máquina.
-- Fluxo de refrigerante com borbulhas, som Web Audio e barra de enchimento.
-- Aplicação de tampa com canudo ("SNAP!") e entrega da bebida no inventário.
-- ================================================================

local isDrinksActive       = false
local drinksCam            = nil
local dispenserBaseCoords  = nil
local cupProp              = nil
local pourParticles        = nil
local selectedFlavor       = 'cola'
local fillProgress         = 0.0
local isDispensing         = false
local sessionToken         = nil

local FLAVOR_CONFIG = {
    cola = {
        label      = "Refrigerante de Cola",
        outputItem = "burger_softdrink",
        color      = { r = 40, g = 20, b = 15 },
        icon       = "🥤"
    },
    orange = {
        label      = "Suco de Laranja",
        outputItem = "juice_orange",
        color      = { r = 255, g = 140, b = 0 },
        icon       = "🍊"
    },
    lemon = {
        label      = "Refrigerante de Limão",
        outputItem = "burger_softdrink",
        color      = { r = 180, g = 255, b = 50 },
        icon       = "🍋"
    },
    grape = {
        label      = "Refrigerante de Uva",
        outputItem = "burger_softdrink",
        color      = { r = 120, g = 40, b = 180 },
        icon       = "🍇"
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

-- ── Limpeza de Entidades da Sessão de Bebidas ────────────────────
local function CleanupDrinksEntities()
    if cupProp and DoesEntityExist(cupProp) then
        DeleteEntity(cupProp)
        cupProp = nil
    end
    if pourParticles then
        StopParticleFxLooped(pourParticles, false)
        pourParticles = nil
    end
end

-- ── Encerrar a Câmera de Bebidas ─────────────────────────────────
function StopDrinksCamera()
    if not isDrinksActive then return end
    isDrinksActive = false
    isDispensing   = false
    fillProgress   = 0.0

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)

    CleanupDrinksEntities()

    if drinksCam and DoesCamExist(drinksCam) then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(drinksCam, false)
        drinksCam = nil
    end

    SendNUIMessage({ action = 'closeDrinksWorld' })
    SendNUIMessage({ action = 'PLAY_POUR_SOUND', active = false })
    SetNuiFocus(false, false)
end

-- ── Trocar para o Copo Fechado com Tampa e Canudo ───────────────
local function SwitchToLiddedCup()
    if not dispenserBaseCoords then return end
    if cupProp and DoesEntityExist(cupProp) then
        DeleteEntity(cupProp)
    end

    -- Prop oficial do copo com canudo e tampa do Burger Shot
    local liddedHash = LoadModelSafely("prop_food_bs_juice01", "prop_plastic_cup_02")
    if liddedHash then
        cupProp = CreateObject(liddedHash, dispenserBaseCoords.x, dispenserBaseCoords.y, dispenserBaseCoords.z + 0.02, false, false, false)
        SetEntityCollision(cupProp, false, false)
        FreezeEntityPosition(cupProp, true)
    end
end

-- ── Concluir o Enchimento e Entregar a Bebida ───────────────────
local function CompleteDrinkDispense()
    isDispensing = false
    SendNUIMessage({ action = 'PLAY_POUR_SOUND', active = false })
    
    -- Áudio de tampa travando ("SNAP!")
    SendNUIMessage({ action = 'PLAY_SNAP_SOUND' })
    SwitchToLiddedCup()

    SendNUIMessage({
        action   = 'UPDATE_DRINKS_PROGRESS',
        progress = 100,
        title    = FLAVOR_CONFIG[selectedFlavor].label,
        hint     = "Copo tampado com canudo! Recolhendo bebida..."
    })

    Wait(400)
    SendNUIMessage({ action = 'PLAY_DING_SOUND' })

    local outItem = FLAVOR_CONFIG[selectedFlavor].outputItem
    TriggerServerEvent('granolla_restaurants:server:CompleteDrinkDispense', sessionToken, outItem, FLAVOR_CONFIG[selectedFlavor].label)

    Wait(800)
    StopDrinksCamera()
end

-- ── Iniciar Enchimento Contínuo do Copo ──────────────────────────
local function StartPouring()
    if isDispensing or fillProgress >= 100 then return end
    isDispensing = true
    SendNUIMessage({ action = 'PLAY_POUR_SOUND', active = true })

    CreateThread(function()
        while isDrinksActive and isDispensing and fillProgress < 100 do
            Wait(80)
            fillProgress = math.min(100.0, fillProgress + 4.0)

            SendNUIMessage({
                action   = 'UPDATE_DRINKS_PROGRESS',
                progress = fillProgress,
                title    = FLAVOR_CONFIG[selectedFlavor].label,
                hint     = "Enchendo copo... solte para pausar ou aguarde até 100%"
            })

            if fillProgress >= 100.0 then
                CompleteDrinkDispense()
                break
            end
        end
    end)
end

local function StopPouring()
    if not isDispensing or fillProgress >= 100 then return end
    isDispensing = false
    SendNUIMessage({ action = 'PLAY_POUR_SOUND', active = false })
    SendNUIMessage({
        action   = 'UPDATE_DRINKS_PROGRESS',
        progress = fillProgress,
        title    = FLAVOR_CONFIG[selectedFlavor].label,
        hint     = "Enchimento pausado. Pressione novamente para continuar"
    })
end

-- ── Callback NUI para Troca de Sabor ────────────────────────────
RegisterNUICallback('selectDrinkFlavor', function(data, cb)
    if data and data.flavor and FLAVOR_CONFIG[data.flavor] then
        selectedFlavor = data.flavor
        SendNUIMessage({
            action   = 'UPDATE_DRINKS_PROGRESS',
            progress = fillProgress,
            title    = FLAVOR_CONFIG[selectedFlavor].label,
            hint     = "Segure [ESPAÇO] ou [CLIQUE] para acionar a torneira"
        })
    end
    cb('ok')
end)

-- ════════════════════════════════════════════════════════════════
-- StartDrinksCamera — Inicia a Estação de Bebidas 3D
-- ════════════════════════════════════════════════════════════════
function StartDrinksCamera(workstationCoords, stationId)
    local ped = PlayerPedId()
    if isDrinksActive then return end

    if not workstationCoords then
        workstationCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.8, 0.0)
    end
    dispenserBaseCoords = vector3(workstationCoords.x, workstationCoords.y, workstationCoords.z)

    -- Solicita início de sessão ao servidor para validação de posse do copo ou permissão
    lib.callback('granolla_restaurants:server:StartDrinksSession', false, function(token)
        if not token then
            lib.notify({ title = 'Dispensador de Bebidas', description = 'Você precisa de um Copo Descartável no inventário!', type = 'error' })
            return
        end

        sessionToken   = token
        isDrinksActive = true
        isDispensing   = false
        fillProgress   = 0.0
        selectedFlavor = 'cola'

        FreezeEntityPosition(ped, true)
        TaskTurnPedToFaceCoord(ped, dispenserBaseCoords.x, dispenserBaseCoords.y, dispenserBaseCoords.z, 300)
        Wait(150)

        -- Postura de trabalho
        lib.requestAnimDict('anim@amb@business@weed@weed_inspecting_high_dry@')
        TaskPlayAnim(ped, 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector', 8.0, -8.0, -1, 49, 0, false, false, false)

        -- Câmera em ângulo fechado focando na base da torneira
        local camX = dispenserBaseCoords.x
        local camY = dispenserBaseCoords.y - 0.40
        local camZ = dispenserBaseCoords.z + 0.35

        drinksCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(drinksCam, camX, camY, camZ)
        PointCamAtCoord(drinksCam, dispenserBaseCoords.x, dispenserBaseCoords.y, dispenserBaseCoords.z + 0.05)
        SetCamFov(drinksCam, 40.0)
        RenderScriptCams(true, true, 600, true, true)

        -- Spawna o copo descartável na base do dispenser
        local cupHash = LoadModelSafely("prop_plastic_cup_02", "prop_food_bs_juice01")
        if cupHash then
            cupProp = CreateObject(cupHash, dispenserBaseCoords.x, dispenserBaseCoords.y, dispenserBaseCoords.z + 0.02, false, false, false)
            SetEntityCollision(cupProp, false, false)
            FreezeEntityPosition(cupProp, true)
        end

        -- Abre NUI com botões de sabor e barra
        SetNuiFocus(true, true)
        SendNUIMessage({
            action   = 'openDrinksWorld',
            progress = 0,
            title    = FLAVOR_CONFIG[selectedFlavor].label,
            hint     = "Escolha o sabor e segure [ESPAÇO] ou [CLIQUE] para acionar a torneira"
        })

        -- Thread de controles durante o enchimento
        CreateThread(function()
            while isDrinksActive do
                Wait(0)
                DisableControlAction(0, 24, true)  -- LMB
                DisableControlAction(0, 22, true)  -- Space
                DisableControlAction(0, 177, true) -- Backspace
                DisableControlAction(0, 200, true) -- ESC

                if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                    StopDrinksCamera()
                    break
                end

                -- Acionamento da torneira
                if (IsDisabledControlPressed(0, 24) or IsDisabledControlPressed(0, 22)) and fillProgress < 100 then
                    if not isDispensing then
                        StartPouring()
                    end
                else
                    if isDispensing then
                        StopPouring()
                    end
                end
            end
        end)

    end)
end

-- Export público e comando de teste
exports('StartDrinksCamera', StartDrinksCamera)

RegisterCommand('testdrinks', function()
    StartDrinksCamera()
end, false)
