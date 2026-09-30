-- client/fryer.lua
-- ================================================================
-- ESTAÇÃO DE FRITURA FÍSICA 3D — CESTO MÓVEL E PÁ DE BATATAS
-- Câmera em primeira pessoa na cuba de óleo quente.
-- Cesto de imersão (mxc_kitchen_prop_tools_friesbasket) que desce no óleo,
-- borbulha com efeito de vapor/óleo quente, sobe para escorrer e
-- recolhe as batatas douradas com a pá (mxc_kitchen_prop_tools_fries_shovel).
-- ================================================================

local isFryerActive       = false
local fryerCam            = nil
local fryerCenterCoords   = nil
local currentStationId    = nil

local basketProp          = nil
local friesProp           = nil
local shovelProp          = nil
local rawBatchProp        = nil
local activeOilParticle   = nil

-- Estados da Fritadeira:
-- 'empty' -> 'loaded' -> 'frying' -> 'draining' -> 'ready'
local fryerState          = 'empty'
local fryTimerStart       = 0
local fryDuration         = 8 -- segundos de imersão
local currentBasketZ      = 0.0

local function LoadPropModel(modelName, fallback)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 30 do
        Wait(10)
        t = t + 1
    end
    if HasModelLoaded(hash) then return hash end
    if fallback then
        local fbHash = GetHashKey(fallback)
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

-- Inicia as partículas de borbulha no óleo quente
local function StartOilBubbles(coords)
    if activeOilParticle then return end
    RequestNamedPtfxAsset("core")
    local t = 0
    while not HasNamedPtfxAssetLoaded("core") and t < 20 do
        Wait(10)
        t = t + 1
    end
    UseParticleFxAssetNextCall("core")
    activeOilParticle = StartParticleFxLoopedAtCoord(
        "exp_grd_bikeseat_smoke",
        coords.x, coords.y, coords.z + 0.05,
        0.0, 0.0, 0.0,
        0.4, false, false, false, false
    )
    SetParticleFxLoopedAlpha(activeOilParticle, 0.6)
end

local function StopOilBubbles()
    if activeOilParticle then
        StopParticleFxLooped(activeOilParticle, false)
        activeOilParticle = nil
    end
end

-- ── Transição Suave do Cesto (Subir / Descer no Óleo) ───────────
local function MoveBasketSmooth(targetZOffset, durationMs)
    if not basketProp or not DoesEntityExist(basketProp) or not fryerCenterCoords then return end
    local startZ = currentBasketZ
    local steps = math.max(1, math.floor(durationMs / 16))
    local delta = (targetZOffset - startZ) / steps

    for i = 1, steps do
        currentBasketZ = currentBasketZ + delta
        SetEntityCoords(basketProp, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z + currentBasketZ, false, false, false, false)
        if friesProp and DoesEntityExist(friesProp) then
            SetEntityCoords(friesProp, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z + currentBasketZ + 0.02, false, false, false, false)
        end
        Wait(16)
    end
    currentBasketZ = targetZOffset
end

-- ── Adicionar Batatas Cruas no Cesto ────────────────────────────
local function LoadFriesIntoBasket()
    if fryerState ~= 'empty' then return end

    local count = exports.ox_inventory:GetItemCount('raw_fries')
    if not count or count < 1 then
        lib.notify({ title = 'Fritadeira', description = 'Você não possui porções de batatas cortadas cruas (raw_fries)!', type = 'warning' })
        return
    end

    local friesModel = LoadPropModel("mxc_kitchen_prop_fries_fried_1", "prop_food_bs_chips")
    if friesModel and fryerCenterCoords then
        friesProp = CreateObject(friesModel, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z + currentBasketZ + 0.02, false, false, false)
        SetEntityCollision(friesProp, false, false)
        FreezeEntityPosition(friesProp, true)
    end

    fryerState = 'loaded'
    PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    lib.notify({ title = 'Fritadeira', description = 'Batatas colocadas no cesto! Clique na alça para mergulhar no óleo quente.', type = 'info' })

    SendNUIMessage({
        action = 'UPDATE_FRYER_STATUS',
        state = fryerState,
        title = 'Cesto Carregado',
        hint = 'Clique para mergulhar no óleo quente'
    })
end

-- ── Mergulhar Cesto no Óleo Quente ──────────────────────────────
local function SubmergeBasket()
    if fryerState ~= 'loaded' then return end
    fryerState = 'frying'
    fryTimerStart = GetGameTimer()

    PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    -- Cesto desce no óleo (~12cm para baixo)
    MoveBasketSmooth(-0.11, 400)
    StartOilBubbles(fryerCenterCoords)

    SendNUIMessage({
        action = 'UPDATE_FRYER_STATUS',
        state = fryerState,
        title = 'Fritando no Óleo...',
        hint = 'Aguarde as batatas ficarem douradas e crocantes'
    })

    -- Thread de contagem regressiva da fritura
    CreateThread(function()
        while isFryerActive and fryerState == 'frying' do
            local elapsed = (GetGameTimer() - fryTimerStart) / 1000.0
            local progress = math.min(100, math.floor((elapsed / fryDuration) * 100))
            local rem = math.max(0, math.ceil(fryDuration - elapsed))

            SendNUIMessage({
                action = 'UPDATE_FRYER_PROGRESS',
                progress = progress,
                timeText = string.format("0:%02d", rem)
            })

            if elapsed >= fryDuration then
                break
            end
            Wait(200)
        end

        if isFryerActive and fryerState == 'frying' then
            fryerState = 'draining'
            StopOilBubbles()
            PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)

            -- Cesto sobe automaticamente para escorrer o óleo
            MoveBasketSmooth(0.08, 450)

            -- Troca o modelo para batatas douradas bem crocantes
            if friesProp and DoesEntityExist(friesProp) then
                DeleteEntity(friesProp)
            end
            local cookedModel = LoadPropModel("mxc_kitchen_prop_fries_fried_2", "prop_food_bs_chips")
            if cookedModel and fryerCenterCoords then
                friesProp = CreateObject(cookedModel, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z + currentBasketZ + 0.02, false, false, false)
                SetEntityCollision(friesProp, false, false)
                FreezeEntityPosition(friesProp, true)
            end

            lib.notify({ title = 'Fritura Concluída!', description = 'Batatas douradas e escorridas! Clique com a pá para embalar.', type = 'success' })
            SendNUIMessage({
                action = 'UPDATE_FRYER_STATUS',
                state = fryerState,
                title = 'Pronto para Embalar!',
                hint = 'Clique com a pá de batatas para recolher'
            })
        end
    end)
end

-- ── Recolher Batatas com a Pá e Embalar na Caixinha ────────────
local function CollectFriesWithShovel()
    if fryerState ~= 'draining' then return end

    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    -- Animação rápida de pá recolhendo
    if shovelProp and DoesEntityExist(shovelProp) then
        SetEntityRotation(shovelProp, -25.0, 0.0, GetEntityHeading(PlayerPedId()), 2, true)
        Wait(300)
        SetEntityRotation(shovelProp, 10.0, 0.0, GetEntityHeading(PlayerPedId()), 2, true)
    end

    if friesProp and DoesEntityExist(friesProp) then
        DeleteEntity(friesProp)
        friesProp = nil
    end

    PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)
    lib.notify({ title = 'Batata Frita', description = 'Porção recolhida e embalada na caixinha do Burger Shot!', type = 'success' })

    -- Entrega o item no servidor com validação de token
    TriggerServerEvent('granolla_restaurants:server:CompleteFryerCook', currentFryerToken, 'frenchfries')

    -- Retorna cesto ao repouso inicial
    fryerState = 'empty'
    MoveBasketSmooth(0.0, 200)

    SendNUIMessage({
        action = 'UPDATE_FRYER_STATUS',
        state = fryerState,
        title = 'Cesto Vazio',
        hint = 'Adicione novas batatas cortadas para fritar'
    })
end

-- ════════════════════════════════════════════════════════════════
-- StartFryerCamera — Abre a Fritadeira em Primeira Pessoa 3D
-- ════════════════════════════════════════════════════════════════
local currentFryerToken = nil

function StartFryerCamera(coords, stationId)
    local ped = cache.ped or PlayerPedId()
    if isFryerActive then return end

    if stationId then currentStationId = stationId end
    if not coords then
        coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.85, 0.0)
    end
    fryerCenterCoords = vector3(coords.x, coords.y, coords.z)

    isFryerActive  = true
    fryerState     = 'empty'
    currentBasketZ = 0.0
    currentFryerToken = nil

    -- Requisita token de sessão ao servidor
    lib.callback('granolla_restaurants:server:StartFryerSession', false, function(token)
        currentFryerToken = token
    end)

    FreezeEntityPosition(ped, true)

    TaskTurnPedToFaceCoord(ped, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z, 300)
    Wait(150)

    lib.requestAnimDict('amb@prop_human_bbq@male@base')
    TaskPlayAnim(ped, 'amb@prop_human_bbq@male@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)

    local heading = GetEntityHeading(ped)
    local rad     = math.rad(heading)

    -- 1. Spawna o Cesto Metálico de Fritadeira
    local basketModel = LoadPropModel("mxc_kitchen_prop_tools_friesbasket", "prop_kitch_pot_fry")
    if basketModel then
        basketProp = CreateObject(basketModel, fryerCenterCoords.x, fryerCenterCoords.y, fryerCenterCoords.z + 0.08, false, false, false)
        SetEntityCollision(basketProp, false, false)
        FreezeEntityPosition(basketProp, true)
        SetEntityRotation(basketProp, 0.0, 0.0, heading, 2, true)
    end

    -- 2. Spawna a Pá de Batatas na lateral da bancada
    local shovelModel = LoadPropModel("mxc_kitchen_prop_tools_fries_shovel", "prop_fish_slice_01")
    if shovelModel then
        local sx = fryerCenterCoords.x + 0.38 * math.cos(rad) - 0.15 * math.sin(rad)
        local sy = fryerCenterCoords.y + 0.38 * math.sin(rad) + 0.15 * math.cos(rad)
        shovelProp = CreateObject(shovelModel, sx, sy, fryerCenterCoords.z + 0.08, false, false, false)
        SetEntityCollision(shovelProp, false, false)
        FreezeEntityPosition(shovelProp, true)
        SetEntityRotation(shovelProp, 10.0, 0.0, heading + 80.0, 2, true)
    end

    -- 3. Câmera em Primeira Pessoa olhando para a cuba de óleo
    local camPos = vector3(
        fryerCenterCoords.x - math.sin(rad) * 0.42,
        fryerCenterCoords.y - math.cos(rad) * 0.42,
        fryerCenterCoords.z + 0.60
    )
    local lookAt = vector3(
        fryerCenterCoords.x,
        fryerCenterCoords.y,
        fryerCenterCoords.z + 0.02
    )

    fryerCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(fryerCam, camPos.x, camPos.y, camPos.z)
    SetCamFov(fryerCam, 49.0)
    PointCamAtCoord(fryerCam, lookAt.x, lookAt.y, lookAt.z)
    RenderScriptCams(true, true, 500, true, true)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({
        action = 'openFryerWorld',
        state = fryerState,
        title = 'Cesto Vazio',
        hint = 'Clique para colocar batatas cruas no cesto'
    })

    -- ── Loop de Interação na Fritadeira ───────────────────────────
    CreateThread(function()
        local throttle = 0
        while isFryerActive do
            Wait(0)

            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisablePlayerFiring(ped, true)

            if IsControlJustPressed(0, 177) then
                StopFryerCamera(); return
            end

            local cursorX, cursorY = GetNuiCursorPosition()
            local screenW, screenH = GetActiveScreenResolution()
            if screenW <= 0 or screenH <= 0 then goto continue end

            local normX = cursorX / screenW
            local normY = cursorY / screenH

            throttle = throttle + 1
            if throttle < 2 then goto continue end
            throttle = 0

            -- Detecta mira sobre o cesto ou sobre a pá
            local isHoverBasket = false
            local isHoverShovel = false

            if basketProp and DoesEntityExist(basketProp) then
                local bPos = GetEntityCoords(basketProp)
                local onScreen, bx, by = GetScreenCoordFromWorldCoord(bPos.x, bPos.y, bPos.z + 0.05)
                if onScreen and math.sqrt((bx - normX)^2 + (by - normY)^2) < 0.16 then
                    isHoverBasket = true
                end
            end

            if shovelProp and DoesEntityExist(shovelProp) then
                local sPos = GetEntityCoords(shovelProp)
                local onScreen, sx, sy = GetScreenCoordFromWorldCoord(sPos.x, sPos.y, sPos.z + 0.05)
                if onScreen and math.sqrt((sx - normX)^2 + (sy - normY)^2) < 0.14 then
                    isHoverShovel = true
                end
            end

            SendNUIMessage({
                action = 'UPDATE_FRYER_HOVER',
                isHoverBasket = isHoverBasket,
                isHoverShovel = isHoverShovel,
                fryerState = fryerState
            })

            -- Ações por Clique
            if IsDisabledControlJustPressed(0, 24) then
                if isHoverBasket then
                    if fryerState == 'empty' then
                        LoadFriesIntoBasket()
                    elseif fryerState == 'loaded' then
                        SubmergeBasket()
                    elseif fryerState == 'draining' then
                        CollectFriesWithShovel()
                    end
                elseif isHoverShovel and fryerState == 'draining' then
                    CollectFriesWithShovel()
                end
            end

            ::continue::
        end
    end)
end

function StopFryerCamera()
    if not isFryerActive then return end
    isFryerActive = false

    local ped = PlayerPedId()
    StopOilBubbles()

    if basketProp and DoesEntityExist(basketProp) then DeleteEntity(basketProp); basketProp = nil end
    if friesProp and DoesEntityExist(friesProp) then DeleteEntity(friesProp); friesProp = nil end
    if shovelProp and DoesEntityExist(shovelProp) then DeleteEntity(shovelProp); shovelProp = nil end

    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeFryerWorld' })

    if fryerCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(fryerCam, false)
        fryerCam = nil
    end

    ClearPedTasks(ped)
    FreezeEntityPosition(ped, false)
end

-- Callbacks NUI
RegisterNUICallback('loadFryer', function(data, cb)
    LoadFriesIntoBasket(); cb('ok')
end)

RegisterNUICallback('submergeFryer', function(data, cb)
    SubmergeBasket(); cb('ok')
end)

RegisterNUICallback('collectFryer', function(data, cb)
    CollectFriesWithShovel(); cb('ok')
end)

RegisterNUICallback('closeFryerUI', function(data, cb)
    StopFryerCamera(); cb('ok')
end)

AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then
        StopFryerCamera()
    end
end)
