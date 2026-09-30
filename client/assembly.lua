-- client/assembly.lua
-- ================================================================
-- MESA DE MONTAGEM FÍSICA 3D DE HAMBÚRGUER (STACKING 3D)
-- Câmera em primeira pessoa focando na bancada com papel manteiga.
-- Empilhamento de camadas físicas: Pão -> Carne -> Queijo -> Salada -> Bacon -> Pão Topo.
-- Embrulho em papel manteiga com sineta e entrega do item pronto.
-- ================================================================

local isAssemblyActive      = false
local assemblyCam           = nil
local tableCenterCoords     = nil
local paperProp             = nil
local bellProp              = nil
local ContainerProps        = {} -- [key] = { prop = ent, coords = vec3, label = str, icon = str }
local CurrentBurgerLayers   = {} -- array de props empilhados: { { prop = ent, key = str, name = str, height = float } }
local cumZOffset            = 0.015

-- Definição dos modelos 3D e espessuras físicas de cada camada
local LAYER_CONFIG = {
    bread_bottom = {
        model   = "mxc_kitchen_prop_burger_bread_bottom",
        fallback= "prop_cs_burger_01",
        label   = "Pão Inferior",
        height  = 0.020,
        icon    = "🍞",
        itemReq = "bread"
    },
    meat = {
        model   = "mxc_kitchen_prop_burger_meat_1",
        fallback= "prop_cs_steak",
        label   = "Carne Grelhada",
        height  = 0.026,
        icon    = "🥩",
        itemReq = "raw_meat" -- pode ser carne crua ou cozida da chapa
    },
    cheese = {
        model   = "mxc_kitchen_prop_burger_cheddar",
        fallback= "prop_food_bs_burger",
        label   = "Queijo Cheddar",
        height  = 0.009,
        icon    = "🧀",
        itemReq = "cheese"
    },
    salad = {
        model   = "mxc_kitchen_prop_burger_salad",
        fallback= "prop_veg_crop_03_cab",
        label   = "Alface Crocante",
        height  = 0.014,
        icon    = "🥬",
        itemReq = "lettuce"
    },
    tomato = {
        model   = "mxc_kitchen_prop_burger_tomatoes",
        fallback= "prop_cs_burger_01",
        label   = "Tomate Fatiado",
        height  = 0.012,
        icon    = "🍅",
        itemReq = "tomato"
    },
    bacon = {
        model   = "mxc_kitchen_prop_burger_bacon",
        fallback= "prop_cs_burger_01",
        label   = "Bacon Crocante",
        height  = 0.011,
        icon    = "🥓",
        itemReq = "bacon"
    },
    bread_top = {
        model   = "mxc_kitchen_prop_burger_bread_top",
        fallback= "prop_cs_burger_01",
        label   = "Pão Superior",
        height  = 0.038,
        icon    = "🍞",
        itemReq = "bread"
    },
}

-- Potes e dispensadores dispostos na bancada de montagem ao redor do papel
local CONTAINER_LAYOUT = {
    { key = "bread_bottom", label = "Pão Base",        icon = "🍞", offset = vector3(-0.42, -0.15, 0.04), model = "mxc_kitchen_prop_tools_breadbase" },
    { key = "meat",         label = "Carne da Chapa",  icon = "🥩", offset = vector3(-0.42,  0.10, 0.04), model = "mxc_kitchen_prop_burger_meat_1" },
    { key = "cheese",       label = "Queijo Cheddar",  icon = "🧀", offset = vector3(-0.25,  0.30, 0.04), model = "mxc_kitchen_prop_burger_littlecontainer_cheddar" },
    { key = "salad",        label = "Alface Fresca",   icon = "🥬", offset = vector3( 0.00,  0.32, 0.04), model = "mxc_kitchen_prop_burger_littlecontainer_salad" },
    { key = "tomato",       label = "Tomate",          icon = "🍅", offset = vector3( 0.25,  0.30, 0.04), model = "mxc_kitchen_prop_burger_littlecontainer_tomatoes" },
    { key = "bacon",        label = "Bacon",           icon = "🥓", offset = vector3( 0.42,  0.10, 0.04), model = "mxc_kitchen_prop_burger_littlecontainer_bacon" },
    { key = "bread_top",    label = "Pão Topo",        icon = "🍞", offset = vector3( 0.42, -0.15, 0.04), model = "mxc_kitchen_prop_tools_breadbase" },
}

-- Converte coordenadas de tela para mundo 3D no plano Z da bancada
local function ScreenToAssemblyPos(normX, normY, targetZ)
    if not assemblyCam then return nil end
    local camPos = GetCamCoord(assemblyCam)
    local fov    = GetCamFov(assemblyCam)
    local camRot = GetCamRot(assemblyCam, 2)

    local rx = math.rad(camRot.x)
    local rz = math.rad(camRot.z)

    local fwd = vector3(-math.sin(rz) * math.cos(rx), math.cos(rz) * math.cos(rx), math.sin(rx))
    local rgt = vector3(math.cos(rz), math.sin(rz), 0.0)
    local up  = vector3(-math.sin(rx) * math.sin(rz), math.sin(rx) * (-math.cos(rz)), math.cos(rx))

    local aspect = GetAspectRatio(false)
    local tanH = math.tan(math.rad(fov * 0.5))
    local cx   = (normX - 0.5) * 2.0 * tanH * aspect
    local cy   = (0.5 - normY) * 2.0 * tanH

    local dir = fwd + (rgt * cx) + (up * cy)
    local len = #dir
    if len < 0.0001 then return nil end
    dir = dir / len

    if math.abs(dir.z) < 0.0001 then return nil end
    local t = (targetZ - camPos.z) / dir.z
    if t <= 0 then return nil end

    return camPos + (dir * t)
end

-- ── Carregar Modelo de Prop com Fallback Seguro ─────────────────
local function LoadModelSafely(modelName, fallbackName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 30 do
        Wait(10)
        t = t + 1
    end
    if HasModelLoaded(hash) then return hash end

    if fallbackName then
        local fbHash = GetHashKey(fallbackName)
        RequestModel(fbHash)
        local t2 = 0
        while not HasModelLoaded(fbHash) and t2 < 30 do
            Wait(10)
            t2 = t2 + 1
        end
        if HasModelLoaded(fbHash) then return fbHash end
    end
    return nil
end

-- ── Adicionar uma nova camada física ao topo do hambúrguer ─────
local function AddBurgerLayer(layerKey)
    local cfg = LAYER_CONFIG[layerKey]
    if not cfg or not tableCenterCoords then return end

    -- Regra de bom senso culinário: o Pão Base deve ser a primeira camada
    if #CurrentBurgerLayers == 0 and layerKey ~= "bread_bottom" then
        lib.notify({ title = 'Bancada', description = 'Comece colocando o Pão Base no papel!', type = 'warning' })
        return
    end

    -- Se já tem Pão Topo, o hambúrguer já está fechado!
    if #CurrentBurgerLayers > 0 and CurrentBurgerLayers[#CurrentBurgerLayers].key == "bread_top" then
        lib.notify({ title = 'Bancada', description = 'O hambúrguer já está com o pão de cima! Agora clique no papel para embrulhar.', type = 'info' })
        return
    end

    local modelHash = LoadModelSafely(cfg.model, cfg.fallback)
    if not modelHash then return end

    local spawnZ = tableCenterCoords.z + 0.035 + cumZOffset
    local layerProp = CreateObject(modelHash, tableCenterCoords.x, tableCenterCoords.y, spawnZ, false, false, false)
    SetEntityCollision(layerProp, false, false)
    FreezeEntityPosition(layerProp, true)

    -- Leve rotação randômica nas saladas/queijo para aspecto artesanal realista
    local randYaw = (layerKey == "salad" or layerKey == "cheese" or layerKey == "bacon") and (math.random(-15, 15) * 1.0) or 0.0
    SetEntityRotation(layerProp, 0.0, 0.0, randYaw, 2, true)

    cumZOffset = cumZOffset + cfg.height

    table.insert(CurrentBurgerLayers, {
        prop   = layerProp,
        key    = layerKey,
        label  = cfg.label,
        icon   = cfg.icon,
        height = cfg.height,
        itemReq= cfg.itemReq
    })

    PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    -- Notifica a NUI para atualizar a lista lateral de ingredientes empilhados
    local layersInfo = {}
    for _, l in ipairs(CurrentBurgerLayers) do
        table.insert(layersInfo, { key = l.key, label = l.label, icon = l.icon })
    end

    SendNUIMessage({
        action = 'UPDATE_ASSEMBLY_STACK',
        layers = layersInfo,
        isComplete = (layerKey == "bread_top")
    })
end

-- ── Desfazer / Remover a última camada do topo do lanche ────────
local function PopBurgerLayer()
    if #CurrentBurgerLayers == 0 then return end
    local lastLayer = table.remove(CurrentBurgerLayers)
    if lastLayer and lastLayer.prop and DoesEntityExist(lastLayer.prop) then
        DeleteEntity(lastLayer.prop)
    end
    cumZOffset = math.max(0.015, cumZOffset - (lastLayer.height or 0.015))
    PlaySoundFrontend(-1, "BACK", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    local layersInfo = {}
    for _, l in ipairs(CurrentBurgerLayers) do
        table.insert(layersInfo, { key = l.key, label = l.label, icon = l.icon })
    end
    SendNUIMessage({
        action = 'UPDATE_ASSEMBLY_STACK',
        layers = layersInfo,
        isComplete = false
    })
end

-- ── Embrulhar o hambúrguer e concluir a montagem ────────────────
local function WrapAndCompleteBurger()
    if #CurrentBurgerLayers < 2 then
        lib.notify({ title = 'Bancada', description = 'Adicione mais ingredientes antes de embrulhar!', type = 'warning' })
        return
    end

    -- Som de sineta da cozinha "Ding!"
    PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)

    -- Remove todas as camadas e o papel aberto
    for _, l in ipairs(CurrentBurgerLayers) do
        if l.prop and DoesEntityExist(l.prop) then DeleteEntity(l.prop) end
    end
    CurrentBurgerLayers = {}

    -- Cria o hambúrguer embrulhado no papel
    local wrapModel = LoadModelSafely("prop_food_bs_burger", "prop_food_burger_01")
    local wrappedProp = nil
    if wrapModel and tableCenterCoords then
        wrappedProp = CreateObject(wrapModel, tableCenterCoords.x, tableCenterCoords.y, tableCenterCoords.z + 0.06, false, false, false)
        SetEntityCollision(wrappedProp, false, false)
        FreezeEntityPosition(wrappedProp, true)
    end

    lib.notify({ title = 'Pedido Concluído!', description = 'Hambúrguer montado e embalado com perfeição!', type = 'success' })
    Wait(800)

    if wrappedProp and DoesEntityExist(wrappedProp) then
        DeleteEntity(wrappedProp)
    end

    -- Entrega o item no inventário com token de segurança
    TriggerServerEvent('granolla_restaurants:server:CompleteBurgerAssembly', currentAssemblyToken, 'burger_bacon')
    StopAssemblyCamera()
end

-- ════════════════════════════════════════════════════════════════
-- StartAssemblyCamera — Abre a Bancada de Montagem Física 3D
-- ════════════════════════════════════════════════════════════════
local currentAssemblyToken = nil

function StartAssemblyCamera(tableCoords)
    local ped = cache.ped or PlayerPedId()
    if isAssemblyActive then return end

    if not tableCoords then
        tableCoords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.85, 0.0)
    end
    tableCenterCoords = vector3(tableCoords.x, tableCoords.y, tableCoords.z)

    isAssemblyActive    = true
    cumZOffset          = 0.015
    CurrentBurgerLayers = {}
    currentAssemblyToken = nil

    -- Requisita token de sessão ao servidor
    lib.callback('granolla_restaurants:server:StartAssemblySession', false, function(token)
        currentAssemblyToken = token
    end)

    FreezeEntityPosition(ped, true)

    TaskTurnPedToFaceCoord(ped, tableCenterCoords.x, tableCenterCoords.y, tableCenterCoords.z, 300)
    Wait(150)

    -- Postura de trabalho na bancada
    lib.requestAnimDict('anim@amb@business@weed@weed_inspecting_high_dry@')
    TaskPlayAnim(ped, 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- 1. Cria o Papel Manteiga Aberto no Centro
    local paperModel = LoadModelSafely("mxc_kitchen_prop_tools_breadpaper", "prop_paper_bag_01")
    if paperModel then
        paperProp = CreateObject(paperModel, tableCenterCoords.x, tableCenterCoords.y, tableCenterCoords.z + 0.035, false, false, false)
        SetEntityCollision(paperProp, false, false)
        FreezeEntityPosition(paperProp, true)
        SetEntityRotation(paperProp, 0.0, 0.0, GetEntityHeading(ped), 2, true)
    end

    -- 2. Cria a Sineta de Pedido Pronto
    local bellModel = LoadModelSafely("mxc_kitchen_prop_tools_bell", "prop_bell_01")
    local heading   = GetEntityHeading(ped)
    local rad       = math.rad(heading)
    if bellModel then
        local bellOff = vector3(-0.45, 0.32, 0.04)
        local bx = tableCenterCoords.x + bellOff.x * math.cos(rad) - bellOff.y * math.sin(rad)
        local by = tableCenterCoords.y + bellOff.x * math.sin(rad) + bellOff.y * math.cos(rad)
        bellProp = CreateObject(bellModel, bx, by, tableCenterCoords.z + bellOff.z, false, false, false)
        SetEntityCollision(bellProp, false, false)
        FreezeEntityPosition(bellProp, true)
    end

    -- 3. Spawna os Potes de Ingredientes ao Redor do Papel
    ContainerProps = {}
    for _, c in ipairs(CONTAINER_LAYOUT) do
        local rx = c.offset.x * math.cos(rad) - c.offset.y * math.sin(rad)
        local ry = c.offset.x * math.sin(rad) + c.offset.y * math.cos(rad)
        local pPos = vector3(tableCenterCoords.x + rx, tableCenterCoords.y + ry, tableCenterCoords.z + c.offset.z)

        local cModel = LoadModelSafely(c.model, "prop_cs_burger_01")
        local cObj = nil
        if cModel then
            cObj = CreateObject(cModel, pPos.x, pPos.y, pPos.z, false, false, false)
            SetEntityCollision(cObj, false, false)
            FreezeEntityPosition(cObj, true)
            SetEntityRotation(cObj, 0.0, 0.0, heading + 10.0, 2, true)
        end

        ContainerProps[c.key] = {
            prop   = cObj,
            coords = pPos,
            label  = c.label,
            icon   = c.icon
        }
    end

    -- 4. Câmera em Primeira Pessoa olhando para o papel e potes
    local camPos = vector3(
        tableCenterCoords.x - math.sin(rad) * 0.46,
        tableCenterCoords.y - math.cos(rad) * 0.46,
        tableCenterCoords.z + 0.65
    )
    local lookAt = vector3(
        tableCenterCoords.x + math.sin(rad) * 0.03,
        tableCenterCoords.y + math.cos(rad) * 0.03,
        tableCenterCoords.z + 0.05
    )

    assemblyCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(assemblyCam, camPos.x, camPos.y, camPos.z)
    SetCamFov(assemblyCam, 48.0)
    PointCamAtCoord(assemblyCam, lookAt.x, lookAt.y, lookAt.z)
    RenderScriptCams(true, true, 500, true, true)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'openAssemblyWorld' })

    -- ── Loop de Interação com o Mouse ─────────────────────────────
    CreateThread(function()
        local throttle = 0
        while isAssemblyActive do
            Wait(0)

            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisablePlayerFiring(ped, true)

            -- BACKSPACE fecha
            if IsControlJustPressed(0, 177) then
                StopAssemblyCamera(); return
            end

            -- Botão Direito do Mouse desfaz a última camada
            if IsDisabledControlJustPressed(0, 25) then
                PopBurgerLayer()
            end

            local cursorX, cursorY = GetNuiCursorPosition()
            local screenW, screenH = GetActiveScreenResolution()
            if screenW <= 0 or screenH <= 0 then goto continue end

            local normX = cursorX / screenW
            local normY = cursorY / screenH

            throttle = throttle + 1
            if throttle < 2 then goto continue end
            throttle = 0

            local hoveredKey   = nil
            local hoveredDist  = 0.12
            local isHoverPaper = false

            -- Detecta hover nos potes de ingredientes
            for key, data in pairs(ContainerProps) do
                local onScreen, sX, sY = GetScreenCoordFromWorldCoord(data.coords.x, data.coords.y, data.coords.z + 0.08)
                if onScreen then
                    local d = math.sqrt((sX - normX)^2 + (sY - normY)^2)
                    if d < hoveredDist then
                        hoveredKey  = key
                        hoveredDist = d
                    end
                end
            end

            -- Detecta hover no papel manteiga central
            if tableCenterCoords then
                local onScreen, pX, pY = GetScreenCoordFromWorldCoord(tableCenterCoords.x, tableCenterCoords.y, tableCenterCoords.z + 0.06)
                if onScreen then
                    local d = math.sqrt((pX - normX)^2 + (pY - normY)^2)
                    if d < 0.14 and not hoveredKey then
                        isHoverPaper = true
                    end
                end
            end

            -- Envia dados de hover para o cursor da NUI
            SendNUIMessage({
                action       = 'UPDATE_ASSEMBLY_HOVER',
                hoveredKey   = hoveredKey,
                hoveredData  = hoveredKey and ContainerProps[hoveredKey] or nil,
                isHoverPaper = isHoverPaper,
                hasLayers    = (#CurrentBurgerLayers > 0),
                isTopReady   = (#CurrentBurgerLayers > 0 and CurrentBurgerLayers[#CurrentBurgerLayers].key == "bread_top")
            })

            -- Clique Esquerdo adiciona camada ou embrulha
            if IsDisabledControlJustPressed(0, 24) then
                if hoveredKey then
                    AddBurgerLayer(hoveredKey)
                elseif isHoverPaper and #CurrentBurgerLayers > 0 and CurrentBurgerLayers[#CurrentBurgerLayers].key == "bread_top" then
                    WrapAndCompleteBurger()
                end
            end

            ::continue::
        end
    end)
end

function StopAssemblyCamera()
    if not isAssemblyActive then return end
    isAssemblyActive = false

    local ped = PlayerPedId()

    -- Remove papel e sineta
    if paperProp and DoesEntityExist(paperProp) then DeleteEntity(paperProp); paperProp = nil end
    if bellProp and DoesEntityExist(bellProp) then DeleteEntity(bellProp); bellProp = nil end

    -- Remove potes
    for _, d in pairs(ContainerProps) do
        if d.prop and DoesEntityExist(d.prop) then DeleteEntity(d.prop) end
    end
    ContainerProps = {}

    -- Remove camadas não finalizadas
    for _, l in ipairs(CurrentBurgerLayers) do
        if l.prop and DoesEntityExist(l.prop) then DeleteEntity(l.prop) end
    end
    CurrentBurgerLayers = {}

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeAssemblyWorld' })

    if assemblyCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(assemblyCam, false)
        assemblyCam = nil
    end

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

-- Callbacks NUI
RegisterNUICallback('addAssemblyLayer', function(data, cb)
    if isAssemblyActive and data.key then
        AddBurgerLayer(data.key)
    end
    cb('ok')
end)

RegisterNUICallback('popAssemblyLayer', function(data, cb)
    if isAssemblyActive then
        PopBurgerLayer()
    end
    cb('ok')
end)

RegisterNUICallback('wrapBurger', function(data, cb)
    if isAssemblyActive then
        WrapAndCompleteBurger()
    end
    cb('ok')
end)

RegisterNUICallback('closeAssemblyUI', function(data, cb)
    StopAssemblyCamera()
    cb('ok')
end)

-- Limpeza ao reiniciar resource
AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then
        StopAssemblyCamera()
    end
end)
