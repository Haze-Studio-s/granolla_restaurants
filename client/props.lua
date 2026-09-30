-- client/props.lua

local ActiveFoodProps = {} -- Cache de objetos de comida spawnados [slotKey] = { prop = entity, model = modelName, stage = stage }
local ActiveSlotKeysPerStation = {} -- [stationId] = { [slotKey] = true }

-- Busca a grelha/chapa mais próxima de uma coordenada (100% no prop, sem Ped/NPC)
local function FindClosestGrillTarget(searchPos)
    if not searchPos then return nil end

    -- 1. Procura nas cozinhas suportadas (Config.SupportedKitchens)
    if Config.SupportedKitchens then
        for _, kData in pairs(Config.SupportedKitchens) do
            if kData.griddles then
                for _, g in ipairs(kData.griddles) do
                    if #(searchPos - g.pos) < 3.5 then
                        return { coords = g.pos, rot = g.rot, heading = g.rot and g.rot.z or -15.5 }
                    end
                end
            end
        end
    end

    -- 2. Procura nos restaurantes fixos (Config.Restaurants)
    if Config.Restaurants then
        for _, rData in pairs(Config.Restaurants) do
            if rData.fixedWorkstations then
                for _, ws in ipairs(rData.fixedWorkstations) do
                    if ws.workstation == 'grill' and #(searchPos - ws.coords) < 3.5 then
                        return { coords = ws.coords, rot = ws.rot or vector3(0.0, 0.0, ws.heading or -15.5), heading = ws.heading or (ws.rot and ws.rot.z) or -15.5 }
                    end
                end
            end
        end
    end

    -- 3. Procura entidades físicas de props no mundo (raio 2.5m)
    for _, m in ipairs({ `v_serv_ct_grill`, `v_serv_ct_grill2`, -1876087649, `prop_bbq_3`, `prop_bbq_1`, `prop_cooker_03`, `prop_grill_01` }) do
        local obj = GetClosestObjectOfType(searchPos.x, searchPos.y, searchPos.z, 2.5, m, false, false, false)
        if DoesEntityExist(obj) and not IsEntityAPed(obj) then
            return obj
        end
    end

    return nil
end

-- Resolver de Alvo da Estação (Retorna um Handle de Entidade se existir, ou vector3/tabela de Coordenadas)
function ResolveStationTarget(stationId)
    -- 1. Se stationId for um ID numérico de entity handle válido
    local entNum = tonumber(stationId)
    if entNum and DoesEntityExist(entNum) then
        -- Se for um Ped (jogador ou NPC), NUNCA usar como prop de chapa!
        if IsEntityAPed(entNum) then
            return FindClosestGrillTarget(GetEntityCoords(entNum))
        end
        return entNum
    end

    -- 2. Se for um prop colocado sincronizado no cliente (SpawnedWorldProps)
    local dbNum = tonumber(stationId)
    if dbNum and SpawnedWorldProps and SpawnedWorldProps[dbNum] and DoesEntityExist(SpawnedWorldProps[dbNum]) then
        return SpawnedWorldProps[dbNum]
    end

    -- 3. Se for uma estação de SupportedKitchens (ex: granolla_uniqx-burgershot_griddle_1)
    if type(stationId) == 'string' and stationId:sub(1, 9) == 'granolla_' then
        local restKey, wsType, idx = stationId:match("^granolla_(.-)_([^_]+)_(%d+)$")
        if restKey and wsType and idx and Config.SupportedKitchens and Config.SupportedKitchens[restKey] then
            local kData = Config.SupportedKitchens[restKey]
            local list = (wsType == 'griddle' and kData.griddles)
                      or (wsType == 'fryer' and kData.fryers)
                      or (wsType == 'assembly' and kData.assemblyTables)
                      or (wsType == 'cutting' and kData.cuttingBoards)
            local item = list and list[tonumber(idx)]
            if item then
                -- Tenta encontrar o objeto físico real próximo à coordenada
                local obj = nil
                for _, model in ipairs({ `v_serv_ct_grill`, `v_serv_ct_grill2`, -1876087649, `prop_bbq_3`, `prop_bbq_1`, `prop_grill_01` }) do
                    local found = GetClosestObjectOfType(item.pos.x, item.pos.y, item.pos.z, 1.5, model, false, false, false)
                    if DoesEntityExist(found) and not IsEntityAPed(found) then
                        obj = found
                        break
                    end
                end
                if obj then return obj end
                return { coords = item.pos, rot = item.rot, heading = item.rot and item.rot.z or 74.5 }
            end
        end
    end

    -- 4. Se for uma estação de restaurante fixo (Config.Restaurants)
    for restId, restConfig in pairs(Config.Restaurants) do
        if restConfig.fixedWorkstations then
            for i, ws in ipairs(restConfig.fixedWorkstations) do
                local wsId = ws.id or (restId .. '_' .. i)
                if wsId == stationId then
                    local modelHash = type(ws.model) == "number" and ws.model or (ws.model and GetHashKey(ws.model))
                    if modelHash then
                        local closestObj = GetClosestObjectOfType(ws.coords.x, ws.coords.y, ws.coords.z, 1.5, modelHash, false, false, false)
                        if DoesEntityExist(closestObj) and not IsEntityAPed(closestObj) then
                            return closestObj
                        end
                    end
                    return { coords = ws.coords, rot = ws.rot or vector3(0.0, 0.0, ws.heading or 74.5), heading = ws.heading or (ws.rot and ws.rot.z) or 74.5 }
                end
            end
        end
    end

    return nil
end

-- Cálculo Dinâmico de Offsets por Slot para posicionar a carne exatamente SOBRE a chapa de metal
local function GetSlotOffset(slotId, parentTarget)
    slotId = tonumber(slotId) or 1
    local surfaceHeight = 0.31 -- Ponto perfeito: 0.31m eleva a carne para repousar 100% sobre a superfície da chapa sem afundar!
    
    if type(parentTarget) == "number" and DoesEntityExist(parentTarget) then
        local model = GetEntityModel(parentTarget)
        if model == GetHashKey("prop_bbq_3") then
            surfaceHeight = 0.82
        elseif model == GetHashKey("prop_hotdog_stand_01") then
            surfaceHeight = 1.08
        elseif model == GetHashKey("prop_kitch_pot_fry") then
            surfaceHeight = 0.15
        else
            local minDim, maxDim = GetModelDimensions(model)
            surfaceHeight = (maxDim.z > 0.1) and (maxDim.z + 0.02) or 0.31
        end
    end
    
    local offsets = {
        [1] = vector3(0.0, 0.0, surfaceHeight),
        [2] = vector3(0.18, 0.0, surfaceHeight),
        [3] = vector3(-0.18, 0.0, surfaceHeight),
        [4] = vector3(0.0, 0.18, surfaceHeight)
    }
    return offsets[slotId] or vector3(0.0, 0.0, surfaceHeight)
end

function SpawnFoodPropForSlot(slotKey, modelName, parentTarget, slotId)
    local numSlotId = tonumber(slotId) or 1

    -- Se o prop já existe e o modelo é o mesmo, reaproveita
    if ActiveFoodProps[slotKey] and DoesEntityExist(ActiveFoodProps[slotKey].prop) then
        if ActiveFoodProps[slotKey].model == modelName then
            return ActiveFoodProps[slotKey].prop
        else
            DeleteEntity(ActiveFoodProps[slotKey].prop)
            ActiveFoodProps[slotKey] = nil
        end
    end

    local model = GetHashKey(modelName)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do 
        Wait(10) 
        timeout = timeout + 1
    end
    if not HasModelLoaded(model) then return nil end

    local spawnCoords = nil
    local heading = 0.0

    -- 1. Se a câmera de cozimento está ativa e os slots calibrados existem
    if isCookingCamActive and GrillSlotPositions and GrillSlotPositions[numSlotId] and GrillSlotPositions[numSlotId].pos then
        spawnCoords = GrillSlotPositions[numSlotId].pos
        heading = currentGrillHeading or 0.0
    elseif type(parentTarget) == "number" and DoesEntityExist(parentTarget) then
        heading = GetEntityHeading(parentTarget)
        local pCoords = GetEntityCoords(parentTarget)
        local offset = GetSlotOffset(numSlotId, parentTarget)
        local rad = math.rad(heading)
        local rx = offset.x * math.cos(rad) - offset.y * math.sin(rad)
        local ry = offset.x * math.sin(rad) + offset.y * math.cos(rad)
        spawnCoords = vector3(pCoords.x + rx, pCoords.y + ry, pCoords.z + offset.z)
    elseif type(parentTarget) == "vector3" or type(parentTarget) == "table" then
        local offset = GetSlotOffset(numSlotId, parentTarget)
        spawnCoords = vector3(parentTarget.x + offset.x, parentTarget.y + offset.y, parentTarget.z + offset.z)
    end

    if not spawnCoords then return nil end

    local prop = CreateObject(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, false, false, false)
    SetEntityCollision(prop, false, false)
    SetEntityRotation(prop, 0.0, 0.0, heading, 2, true)
    FreezeEntityPosition(prop, true)
    ActiveFoodProps[slotKey] = { prop = prop, model = modelName, stage = 'raw' }
    return prop
end

function RemoveFoodPropSlot(slotKey)
    if ActiveFoodProps[slotKey] then
        if ActiveFoodProps[slotKey].prop and DoesEntityExist(ActiveFoodProps[slotKey].prop) then
            DeleteEntity(ActiveFoodProps[slotKey].prop)
        end
        ActiveFoodProps[slotKey] = nil
    end
end

function UpdateFoodPropStage(slotKey, stage)
    local propData = ActiveFoodProps[slotKey]
    if not propData or not DoesEntityExist(propData.prop) then return end
    local prop = propData.prop

    propData.stage = stage

    if stage == 'side2' or stage == 'cooked' then
        -- Gira o prop 180 graus no eixo Z (Yaw) para girar a carne horizontalmente na chapa sem afundar
        SetEntityRotation(prop, 0.0, 0.0, 180.0, 2, true)
    end

    if stage == 'burnt' then
        SetEntityRenderScorched(prop, true)
        UseParticleFxAssetNextCall("core")
        StartParticleFxLoopedOnEntity("exp_grd_bikeseat_smoke", prop, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.5, false, false, false)
    elseif stage == 'cooked' then
        UseParticleFxAssetNextCall("core")
        StartParticleFxNonLoopedOnEntity("exp_grd_bikeseat_smoke", prop, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0, 0.2, false, false, false)
    end
end

-- Sincronizar todos os slots de uma estação de preparo
function SyncFoodPropsForStation(stationId, stationData)
    local currentSlots = (stationData and stationData.slots) or {}
    local parentTarget = ResolveStationTarget(stationId)
    
    if not ActiveSlotKeysPerStation[stationId] then
        ActiveSlotKeysPerStation[stationId] = {}
    end

    local newSlotKeys = {}

    for slotId, slot in pairs(currentSlots) do
        local slotKey = stationId .. '_' .. slotId
        newSlotKeys[slotKey] = true
        ActiveSlotKeysPerStation[stationId][slotKey] = true

        local meatMeta = Config.MeatModels[slot.ingredientKey] or Config.FriedModels[slot.ingredientKey]
        if meatMeta then
            local modelName = meatMeta.rawModel or "prop_cs_steak"
            if slot.state == 'cooked' and meatMeta.cookedModel then
                modelName = meatMeta.cookedModel
            elseif slot.state == 'burnt' and meatMeta.burntModel then
                modelName = meatMeta.burntModel
            end

            if parentTarget then
                SpawnFoodPropForSlot(slotKey, modelName, parentTarget, slotId)
                UpdateFoodPropStage(slotKey, slot.state)
            end
        end
    end

    -- Remover props de alimentos que foram recolhidos ou descarte
    for slotKey, _ in pairs(ActiveSlotKeysPerStation[stationId]) do
        if not newSlotKeys[slotKey] then
            RemoveFoodPropSlot(slotKey)
            ActiveSlotKeysPerStation[stationId][slotKey] = nil
        end
    end

    -- Atualiza os slots locais com base no estado do servidor
    if isCookingCamActive and stationId == currentStationId then
        for sId, sData in pairs(currentSlots) do
            local sid = tonumber(sId)
            if GrillSlotPositions and GrillSlotPositions[sid] then
                GrillSlotPositions[sid].occupied = true
                GrillSlotPositions[sid].state = sData.state or 'raw'
            end
        end
    end
end

-- ================================================================

-- ================================================================
-- SISTEMA DE COZINHA 3D — ESPÁTULA FÍSICA NO MOUSE
-- A espátula 3D acompanha o cursor do mouse sobre a superfície da chapa.
-- Zero cursor de desenho animado 2D, zero dedo apontando (sem IK).
-- Suporte aos 4 Estados de Interação (Hover, Drag, Target Zone, Espátula).
-- ================================================================

isCookingCamActive  = false
currentStationId    = nil
GrillSlotPositions  = {}   -- [slotId] = { pos, occupied, state, ingredientKey }
ClientStationsState = ClientStationsState or {}

local cookingCam          = nil
local grillWorldPos       = nil
local currentGrillHeading = 0.0
local currentSurfaceZ     = 0.31
local IngredientPileProps = {}  -- [key] = { prop, pos, label, count }
local grabbedIngredient   = nil   -- { key, label } ou nil
local grabbedProp         = nil   -- prop de comida sendo carregado na mao esquerda
local heldSpatulaProp     = nil   -- espatula física dinâmica na chapa
local isMxcSpatula        = false
local currentSpatulaPos   = nil
local frameThrottle       = 0

-- ── Configuração de Calibração Fina da Espátula 3D ───────────────
local SpatulaConfig = {
    mxc = {
        caboLength = 0.26,  -- Distância da base do cabo até a ponta da lâmina
        pitch      = 12.0,  -- Inclinação natural do cabo subindo em direção ao cozinheiro
        pitchClick = 3.0,   -- Inclinação plana ao prensar a carne na chapa (LMB)
        roll       = 0.0,
        yawOffset  = 180.0, -- Lâmina em -Y local vira para a frente da chapa (+fwd)
        zOffset    = 0.015, -- Altura suave sobre a chapa
        zClick     = 0.004,
        rgtOffset  = 0.02,
        bladeX     = 0.0,
        bladeY     = -0.27, -- Posição centralizada no meio da lâmina da espátula
        bladeZ     = 0.022
    },
    native = { -- prop_fish_slice_01 (fallback com 4 ranhuras)
        caboLength = 0.28,
        pitch      = 8.0,   -- Suave para o cabo subir ao invés de fincar na chapa
        pitchClick = 1.0,
        roll       = 0.0,
        yawOffset  = 180.0, -- Alinha a lâmina apontando para a comida na chapa
        zOffset    = 0.015,
        zClick     = 0.005,
        rgtOffset  = 0.02,
        bladeX     = 0.0,
        bladeY     = -0.28, -- Posição perfeita cobrindo as 4 ranhuras da espátula
        bladeZ     = 0.022
    }
}

-- ── Criar e configurar o prop físico da espátula ────────────────
local function CreateCookingSpatula(ped, grillPos)
    local modelName = "mxc_kitchen_prop_tools_spatula"
    local model = GetHashKey(modelName)
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 150 do
        Wait(10)
        t = t + 1
    end

    local isMxc = HasModelLoaded(model)
    if not isMxc then
        modelName = "prop_fish_slice_01"
        model = GetHashKey(modelName)
        RequestModel(model)
        local t2 = 0
        while not HasModelLoaded(model) and t2 < 150 do
            Wait(10)
            t2 = t2 + 1
        end
    end

    if not HasModelLoaded(model) then return nil, false end

    local spatula = CreateObject(model, grillPos.x, grillPos.y, grillPos.z + 0.45, false, false, false)
    SetEntityCollision(spatula, false, false)
    FreezeEntityPosition(spatula, true)
    SetEntityAlpha(spatula, 255, false)

    return spatula, isMxc
end

-- ── Conversão precisa Screen Normal (0-1) para Coordenada 3D na altura worldZ ──
local function ScreenPosToWorldPos(normX, normY, worldZ)
    if not cookingCam then return nil end
    local camPos = GetCamCoord(cookingCam)
    local fov    = GetCamFov(cookingCam)
    local camRot = GetCamRot(cookingCam, 2)

    local rx = math.rad(camRot.x)
    local rz = math.rad(camRot.z)

    -- Vetores direcionais da câmera
    local fwdX = -math.sin(rz) * math.cos(rx)
    local fwdY =  math.cos(rz) * math.cos(rx)
    local fwdZ =  math.sin(rx)

    local rgtX =  math.cos(rz)
    local rgtY =  math.sin(rz)
    local rgtZ =  0.0

    local upX  = -math.sin(rx) * math.sin(rz)
    local upY  =  math.sin(rx) * (-math.cos(rz))
    local upZ  =  math.cos(rx)

    local aspect = GetAspectRatio(false)
    local tanH = math.tan(math.rad(fov * 0.5))
    local cx   = (normX - 0.5) * 2.0 * tanH * aspect
    local cy   = (0.5 - normY) * 2.0 * tanH

    -- Direção normalizada do raio
    local dX = fwdX + rgtX * cx + upX * cy
    local dY = fwdY + rgtY * cx + upY * cy
    local dZ = fwdZ + rgtZ * cx + upZ * cy
    local len = math.sqrt(dX*dX + dY*dY + dZ*dZ)
    if len < 0.0001 then return nil end
    dX = dX / len; dY = dY / len; dZ = dZ / len

    -- Intersecção matemática com o plano horizontal em worldZ
    if math.abs(dZ) < 0.0001 then return nil end
    local t = (worldZ - camPos.z) / dZ
    if t <= 0 then return nil end

    return vector3(camPos.x + dX * t, camPos.y + dY * t, worldZ)
end

-- ── Mapeamento de modelos de ingredientes ───────────────────────
local PROP_MAP = {
    raw_meat    = 'prop_cs_steak',
    raw_sausage = 'prop_cs_hotdog_02',
    raw_fish    = 'prop_defilied_ragdoll_01',
}
local function GetIngredientProp(key)
    if not key then return 'prop_cs_steak' end
    local lower = key:lower()
    for k, v in pairs(PROP_MAP) do
        if lower:find(k, 1, true) then return v end
    end
    if lower:find('fish') or lower:find('peixe') then return 'prop_defilied_ragdoll_01' end
    if lower:find('sausage') or lower:find('salsicha') then return 'prop_cs_hotdog_02' end
    return 'prop_cs_steak'
end

-- ── Coleta ingredientes de cozinha do inventário do jogador ────
local function GetPlayerCookingIngredients()
    local result = {}
    local ok, inv = pcall(function() return exports.ox_inventory:GetPlayerItems() end)
    if not ok or not inv then return result end
    for _, item in pairs(inv) do
        if item and item.name and item.count and item.count > 0 then
            local meta = (Config.MeatModels and Config.MeatModels[item.name])
                      or (Config.FriedModels and Config.FriedModels[item.name])
            if meta then
                table.insert(result, {
                    key    = item.name,
                    label  = meta.label or item.label or item.name,
                    amount = item.count
                })
            end
        end
    end
    return result
end

-- ── Spawna as pilhas físicas de ingredientes ao redor da bancada ──
-- ── Spawna as pilhas físicas de ingredientes nas abas laterais da chapa ──
local function SpawnIngredientPiles(centerPos, grillHeading, ingredients, surfH)
    for _, d in pairs(IngredientPileProps) do
        if d.prop and DoesEntityExist(d.prop) then DeleteEntity(d.prop) end
    end
    IngredientPileProps = {}
    surfH = surfH or 0.04

    local rad = math.rad(grillHeading)
    local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)

    -- Pilhas alinhadas nas laterais imediatas da chapa de metal
    local pileGrid = {
        { col = -0.38, row = -0.06 },
        { col =  0.38, row = -0.06 },
        { col = -0.38, row =  0.10 },
        { col =  0.38, row =  0.10 },
        { col = -0.38, row = -0.20 },
        { col =  0.38, row = -0.20 },
    }

    local i = 1
    for _, ing in ipairs(ingredients) do
        if i > #pileGrid then break end
        local off = pileGrid[i]
        local spawnPos = vector3(
            centerPos.x + rgt.x * off.col + fwd.x * off.row,
            centerPos.y + rgt.y * off.col + fwd.y * off.row,
            centerPos.z + surfH
        )

        local modelName = GetIngredientProp(ing.key)
        local model = GetHashKey(modelName)
        RequestModel(model)
        local t = 0
        while not HasModelLoaded(model) and t < 50 do Wait(10); t = t + 1 end

        local prop = nil
        if HasModelLoaded(model) then
            prop = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z, false, false, false)
            SetEntityCollision(prop, false, false)
            FreezeEntityPosition(prop, true)
            SetEntityVisible(prop, true, false)
            SetEntityRotation(prop, 0.0, 0.0, grillHeading, 2, true)
        end

        IngredientPileProps[ing.key] = {
            prop  = prop,
            pos   = spawnPos,
            label = ing.label,
            count = ing.amount
        }
        i = i + 1
    end
end

-- ── Configura os 6 slots sobre a superfície central da chapa de metal ──
local function SetupGrillSlots(centerPos, grillHeading, surfH)
    GrillSlotPositions = {}
    local rad = math.rad(grillHeading)
    local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)
    surfH = surfH or 0.04

    -- 6 slots distribuídos em 2 colunas e 3 linhas perfeitamente no miolo da chapa
    local slotGrid = {
        [1] = { col = -0.13, row = -0.10 },
        [2] = { col =  0.13, row = -0.10 },
        [3] = { col = -0.13, row =  0.03 },
        [4] = { col =  0.13, row =  0.03 },
        [5] = { col = -0.13, row =  0.16 },
        [6] = { col =  0.13, row =  0.16 },
    }
    for slotId, off in pairs(slotGrid) do
        local pos = vector3(
            centerPos.x + rgt.x * off.col + fwd.x * off.row,
            centerPos.y + rgt.y * off.col + fwd.y * off.row,
            centerPos.z + surfH
        )
        GrillSlotPositions[slotId] = {
            pos      = pos,
            occupied = false,
            state    = 'empty'
        }
    end
end

function UpdateGrillSlotFromServer(slotId, state)
    local sid = tonumber(slotId)
    if not GrillSlotPositions[sid] then return end
    if state == 'empty' or state == nil then
        GrillSlotPositions[sid].occupied = false
        GrillSlotPositions[sid].state    = 'empty'
    else
        GrillSlotPositions[sid].occupied = true
        GrillSlotPositions[sid].state    = state
    end
end

-- Calibração Fina da Câmera 100% Ancorada no Prop (Ajustável ao vivo via /camtune)
local GrillCamConfig = {
    fwdDist   = 0.58,  -- Distância da câmera recuada para a frente da chapa (afastamento perfeito)
    height    = 0.52,  -- Altura da câmera acima do topo da chapa
    fov       = 55.0,  -- FOV mais amplo para enquadrar a chapa e bancada com folga
    fwdLookAt = 0.10,  -- Ponto focal equilibrado no miolo da chapa
    latLookAt = 0.00,  -- Offset lateral do ponto focal
    pedDist   = 0.65,  -- Distância onde o cozinheiro é posicionado de frente para o prop
}

-- ════════════════════════════════════════════════════════════════
-- StartCookingCamera — Inicia o Modo Chapa com Espátula Física
-- ════════════════════════════════════════════════════════════════
function StartCookingCamera(propCoords, stationId, stationRot)
    local ped = PlayerPedId()
    if stationId then currentStationId = stationId end
    if isCookingCamActive then return end

    -- 1. Determina com precisão absoluta as coordenadas e rotação do Prop da Chapa
    local propPos = nil
    local propHeading = nil
    local propEntity = nil

    if currentStationId then
        local target = ResolveStationTarget(currentStationId)
        if type(target) == 'number' and DoesEntityExist(target) and not IsEntityAPed(target) then
            propEntity = target
            propPos = GetEntityCoords(target)
            propHeading = GetEntityHeading(target)
        elseif type(target) == 'table' then
            if target.coords then
                propPos = target.coords
                propHeading = target.heading or (target.rot and target.rot.z)
            elseif target.x then
                propPos = target
                if target.rot then propHeading = target.rot.z end
            end
        end
    end

    -- Se propCoords foi fornecido diretamente e ainda não temos propPos
    if not propPos and propCoords and type(propCoords) == 'vector3' then
        propPos = propCoords
    end

    -- Se temos propPos mas ainda não achamos propEntity, busca objeto físico real no raio de 1.5m
    if not propEntity and propPos then
        for _, m in ipairs({ `v_serv_ct_grill`, `v_serv_ct_grill2`, -1876087649, `prop_bbq_3`, `prop_bbq_1`, `prop_cooker_03`, `prop_grill_01` }) do
            local obj = GetClosestObjectOfType(propPos.x, propPos.y, propPos.z, 1.8, m, false, false, false)
            if DoesEntityExist(obj) and not IsEntityAPed(obj) then
                propEntity = obj
                propPos = GetEntityCoords(obj)
                propHeading = GetEntityHeading(obj)
                break
            end
        end
    end

    -- Se fornecida rotação explícita (ex: do kitchens.lua rot.z = 74.5), prioriza ela
    if stationRot and stationRot.z then
        propHeading = stationRot.z
    end

    -- Se ainda não tiver rotação nem coordenadas, busca a grelha/chapa mais próxima do local
    if not propPos or not propHeading then
        local nearest = FindClosestGrillTarget(propPos or GetEntityCoords(ped))
        if nearest then
            if type(nearest) == 'number' then
                propEntity = nearest
                propPos = GetEntityCoords(nearest)
                propHeading = GetEntityHeading(nearest)
            elseif type(nearest) == 'table' then
                propPos = propPos or nearest.coords
                propHeading = propHeading or nearest.heading or (nearest.rot and nearest.rot.z)
            end
        end
    end

    -- Salvaguarda: se nenhuma grelha ou prop foi encontrado, avisa o jogador e não abre a câmera
    if not propPos then
        lib.notify({ title = 'Chapa', description = 'Nenhum prop de chapa encontrado próximo.', type = 'error' })
        return
    end

    if not propHeading then
        propHeading = -15.5 -- Fallback padrão para a chapa ficar de frente
    end

    currentGrillHeading = propHeading
    grillWorldPos = propPos

    -- Vetores matemáticos exatos derivados exclusivamente da orientação do Prop
    local rad = math.rad(propHeading)
    local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
    local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)

    -- Centro da superfície da chapa ancorado no prop
    local centerPos = propPos
    local surfH = 0.02
    if propEntity and DoesEntityExist(propEntity) then
        local m = GetEntityModel(propEntity)
        if m == GetHashKey("prop_bbq_3") then surfH = 0.82
        elseif m == GetHashKey("prop_hotdog_stand_01") then surfH = 1.08 end
    end
    currentSurfaceZ = surfH

    isCookingCamActive = true
    grabbedIngredient  = nil

    -- 2. CÂMERA 100% BASEADA NO PROP (Zero dependência da posição do ped/NPC)
    local camPos = vector3(
        centerPos.x - fwd.x * GrillCamConfig.fwdDist,
        centerPos.y - fwd.y * GrillCamConfig.fwdDist,
        centerPos.z + surfH + GrillCamConfig.height
    )
    local lookAt = vector3(
        centerPos.x + fwd.x * GrillCamConfig.fwdLookAt + rgt.x * GrillCamConfig.latLookAt,
        centerPos.y + fwd.y * GrillCamConfig.fwdLookAt + rgt.y * GrillCamConfig.latLookAt,
        centerPos.z + surfH + 0.02
    )

    cookingCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cookingCam, camPos.x, camPos.y, camPos.z)
    SetCamFov(cookingCam, GrillCamConfig.fov)
    PointCamAtCoord(cookingCam, lookAt.x, lookAt.y, lookAt.z)
    RenderScriptCams(true, true, 400, true, true)

    -- 3. O PERSONAGEM NÃO É MOVIDO NEM ROTACIONADO (Mantém posição original exata)
    FreezeEntityPosition(ped, true)
    lib.requestAnimDict('amb@prop_human_bbq@male@base')
    TaskPlayAnim(ped, 'amb@prop_human_bbq@male@base', 'base', 8.0, -8.0, -1, 49, 0, false, false, false)

    -- 4. Cria a espátula física sobre a superfície do Prop
    if heldSpatulaProp and DoesEntityExist(heldSpatulaProp) then
        DeleteEntity(heldSpatulaProp)
    end
    heldSpatulaProp, isMxcSpatula = CreateCookingSpatula(ped, centerPos)
    currentSpatulaPos = nil

    -- 5. Configura slots e pilhas a partir do Prop
    SetupGrillSlots(centerPos, propHeading, surfH)

    -- Sincroniza slots já em preparo
    local stationData = ClientStationsState and ClientStationsState[tostring(stationId)] or { slots = {} }
    for slotId, slotInfo in pairs(stationData.slots or {}) do
        local sid = tonumber(slotId)
        if GrillSlotPositions[sid] then
            GrillSlotPositions[sid].occupied = true
            GrillSlotPositions[sid].state    = slotInfo.state or 'raw'
        end
    end

    local ingredients = GetPlayerCookingIngredients()
    SpawnIngredientPiles(centerPos, propHeading, ingredients, surfH)

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'openCookingWorld', stationId = stationId })

    -- ── LOOP PRINCIPAL DA ESPÁTULA E INTERAÇÃO ───────────────────────
    CreateThread(function()
        while isCookingCamActive do
            Wait(0)

            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisablePlayerFiring(ped, true)

            -- BACKSPACE fecha com segurança
            if IsControlJustPressed(0, 177) then
                StopCookingCamera(); return
            end

            local cursorX, cursorY = GetNuiCursorPosition()
            local screenW, screenH = GetActiveScreenResolution()
            if screenW <= 0 or screenH <= 0 then goto continue end

            local normX = cursorX / screenW
            local normY = cursorY / screenH

            -- Calcula a posição física 3D do cursor sobre o plano da chapa
            local planeZ = centerPos.z + currentSurfaceZ
            local targetPos = ScreenPosToWorldPos(normX, normY, planeZ)

            local isClicking = IsDisabledControlPressed(0, 24) or IsControlPressed(0, 24)

            -- ── Atualiza a Espátula Física no Mouse ───────────────────
            if targetPos and DoesEntityExist(heldSpatulaProp) then
                local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
                local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)

                local cfg = isMxcSpatula and SpatulaConfig.mxc or SpatulaConfig.native
                local caboLength = cfg.caboLength
                local tilt = isClicking and cfg.pitchClick or cfg.pitch
                local zOff = isClicking and cfg.zClick or cfg.zOffset

                -- A ponta da lâmina da espátula se posiciona no ponto da mira
                local targetSpatulaPos = vector3(
                    targetPos.x - fwd.x * caboLength + rgt.x * cfg.rgtOffset,
                    targetPos.y - fwd.y * caboLength + rgt.y * cfg.rgtOffset,
                    targetPos.z + zOff
                )

                -- Interpolação suave (Lerp) para fluidez de 60fps+
                if not currentSpatulaPos then
                    currentSpatulaPos = targetSpatulaPos
                else
                    currentSpatulaPos = currentSpatulaPos * 0.58 + targetSpatulaPos * 0.42
                end

                SetEntityCoordsNoOffset(heldSpatulaProp, currentSpatulaPos.x, currentSpatulaPos.y, currentSpatulaPos.z, false, false, false)

                local targetPitch = tilt
                local targetRoll = cfg.roll
                local targetYaw = (propHeading + cfg.yawOffset) % 360.0

                SetEntityRotation(heldSpatulaProp, targetPitch, targetRoll, targetYaw, 2, true)
            end

            -- Atalhos de calibração fina em tempo real (Dev / Live Tuning com Setas)
            local liveCfg = isMxcSpatula and SpatulaConfig.mxc or SpatulaConfig.native
            if IsControlJustPressed(0, 172) then -- Seta CIMA: Inclina o cabo mais para cima
                liveCfg.pitch = liveCfg.pitch + 2.0
                lib.notify({ description = string.format("Pitch: %.1f | Yaw: %.1f", liveCfg.pitch, liveCfg.yawOffset), type = 'inform' })
            elseif IsControlJustPressed(0, 173) then -- Seta BAIXO: Inclina o cabo mais para baixo
                liveCfg.pitch = liveCfg.pitch - 2.0
                lib.notify({ description = string.format("Pitch: %.1f | Yaw: %.1f", liveCfg.pitch, liveCfg.yawOffset), type = 'inform' })
            elseif IsControlJustPressed(0, 174) then -- Seta ESQUERDA: Gira Yaw em -15°
                liveCfg.yawOffset = (liveCfg.yawOffset - 15.0) % 360.0
                lib.notify({ description = string.format("Pitch: %.1f | Yaw: %.1f", liveCfg.pitch, liveCfg.yawOffset), type = 'inform' })
            elseif IsControlJustPressed(0, 175) then -- Seta DIREITA: Gira Yaw em +15°
                liveCfg.yawOffset = (liveCfg.yawOffset + 15.0) % 360.0
                lib.notify({ description = string.format("Pitch: %.1f | Yaw: %.1f", liveCfg.pitch, liveCfg.yawOffset), type = 'inform' })
            elseif IsControlJustPressed(0, 10) then -- Page Up: Sobe Z da espátula
                liveCfg.zOffset = liveCfg.zOffset + 0.005
                lib.notify({ description = string.format("Z-Offset: %.3f", liveCfg.zOffset), type = 'inform' })
            elseif IsControlJustPressed(0, 11) then -- Page Down: Desce Z da espátula
                liveCfg.zOffset = liveCfg.zOffset - 0.005
                lib.notify({ description = string.format("Z-Offset: %.3f", liveCfg.zOffset), type = 'inform' })
            end

            -- ── THROTTLE DE LABELS E ESTADOS DE INTERAÇÃO (30fps) ────
            frameThrottle = frameThrottle + 1
            if frameThrottle < 2 then goto continue end
            frameThrottle = 0

            local labelsData    = {}
            local nearIngKey    = nil
            local nearIngDist   = 0.11   -- Raio de captura na tela

            -- Estado 1: Hover sobre ingrediente da bancada
            for key, data in pairs(IngredientPileProps) do
                local onScreen, sX, sY = GetScreenCoordFromWorldCoord(data.pos.x, data.pos.y, data.pos.z + 0.08)
                if onScreen then
                    local d = math.sqrt((sX - normX)^2 + (sY - normY)^2)
                    local hovered = (not grabbedIngredient) and (d < nearIngDist)
                    if hovered then nearIngKey = key; nearIngDist = d end
                    table.insert(labelsData, {
                        type    = 'ingredient',
                        key     = key,
                        label   = data.label,
                        count   = data.count,
                        x       = sX * 100,
                        y       = sY * 100,
                        hovered = false
                    })
                end
            end
            if nearIngKey then
                for _, lbl in ipairs(labelsData) do
                    if lbl.key == nearIngKey then lbl.hovered = true end
                end
            end

            -- Estado 3 e 4: Slots da grelha (Target Zone e Interação com a Espátula)
            local nearSlotId   = nil
            local nearSlotDist = 0.13

            for slotId, slotData in pairs(GrillSlotPositions) do
                local onScreen, sX, sY = GetScreenCoordFromWorldCoord(slotData.pos.x, slotData.pos.y, slotData.pos.z)
                if onScreen then
                    local d = math.sqrt((sX - normX)^2 + (sY - normY)^2)
                    local isDropTarget   = grabbedIngredient and (d < nearSlotDist) and (not slotData.occupied)
                    local isInteractable = (not grabbedIngredient) and slotData.occupied and (d < nearSlotDist)
                    if isDropTarget or isInteractable then
                        nearSlotId = slotId; nearSlotDist = d
                    end
                    table.insert(labelsData, {
                        type          = 'slot',
                        slotId        = slotId,
                        state         = slotData.state,
                        occupied      = slotData.occupied,
                        x             = sX * 100,
                        y             = sY * 100,
                        isDropTarget  = false,
                        isInteractable= false
                    })
                end
            end
            if nearSlotId then
                for _, lbl in ipairs(labelsData) do
                    if lbl.slotId == nearSlotId then
                        if grabbedIngredient then lbl.isDropTarget   = true
                        else                      lbl.isInteractable = true end
                    end
                end
            end

            -- Envia labels atualizadas para o overlay transparente
            SendNUIMessage({
                action  = 'UPDATE_WORLD_LABELS',
                labels  = labelsData,
                grabbed = grabbedIngredient
            })

            -- ── CLIQUE ESQUERDO (AÇÕES FÍSICAS) ──────────────────────
            if IsDisabledControlJustPressed(0, 24) then
                if grabbedIngredient then
                    -- Estado 3: Soltar ingrediente na grelha
                    if nearSlotId and not GrillSlotPositions[nearSlotId].occupied then
                        local key = grabbedIngredient.key
                        TriggerServerEvent('granolla_restaurants:server:PlaceIngredient',
                            currentStationId, nearSlotId, key)

                        GrillSlotPositions[nearSlotId].occupied = true
                        GrillSlotPositions[nearSlotId].state    = 'raw'

                        if IngredientPileProps[key] then
                            IngredientPileProps[key].count = IngredientPileProps[key].count - 1
                            if IngredientPileProps[key].count <= 0 then
                                if IngredientPileProps[key].prop and DoesEntityExist(IngredientPileProps[key].prop) then
                                    DeleteEntity(IngredientPileProps[key].prop)
                                end
                                IngredientPileProps[key] = nil
                            end
                        end

                        -- Remove o prop temporário que estava na espátula (o servidor cria o prop oficial sincronizado)
                        if grabbedProp and DoesEntityExist(grabbedProp) then
                            DetachEntity(grabbedProp, true, false)
                            DeleteEntity(grabbedProp)
                            grabbedProp = nil
                        end
                        grabbedIngredient = nil

                        -- Som de chapa ao colocar a carne
                        PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                        lib.notify({ title = 'Chapa', description = 'Carne colocada para chiar na grelha!', type = 'success' })
                    else
                        -- Cancelar clique em local vazio: remove o prop da espátula com segurança
                        if grabbedProp and DoesEntityExist(grabbedProp) then
                            DetachEntity(grabbedProp, true, false)
                            DeleteEntity(grabbedProp)
                            grabbedProp = nil
                        end
                        grabbedIngredient = nil
                    end
                else
                    -- Estado 2: Pegar ingrediente da pilha lateral DIRETAMENTE COM A ESPÁTULA
                    if nearIngKey and IngredientPileProps[nearIngKey] then
                        local ingData = IngredientPileProps[nearIngKey]
                        grabbedIngredient = { key = nearIngKey, label = ingData.label }
                        
                        local modelName = GetIngredientProp(nearIngKey)
                        local modelHash = GetHashKey(modelName)
                        RequestModel(modelHash)
                        local tWait = 0
                        while not HasModelLoaded(modelHash) and tWait < 50 do Wait(10); tWait = tWait + 1 end

                        local pCoords = currentSpatulaPos or GetEntityCoords(ped)
                        local foodProp = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z + 0.1, false, false, false)
                        SetEntityCollision(foodProp, false, false)

                        if heldSpatulaProp and DoesEntityExist(heldSpatulaProp) then
                            -- A carne repousa perfeitamente sobre a lâmina de metal da espátula móvel
                            local cfg = isMxcSpatula and SpatulaConfig.mxc or SpatulaConfig.native
                            local bladeX = cfg.bladeX or 0.0
                            local bladeY = cfg.bladeY or -0.28
                            local bladeZ = cfg.bladeZ or 0.022
                            AttachEntityToEntity(foodProp, heldSpatulaProp, 0, bladeX, bladeY, bladeZ, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                        else
                            local boneR = GetPedBoneIndex(ped, 28422)
                            if boneR == -1 then boneR = GetPedBoneIndex(ped, 60309) end
                            AttachEntityToEntity(foodProp, ped, boneR, 0.08, 0.02, -0.02, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
                        end
                        grabbedProp = foodProp
                        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

                    -- Estado 4: Ação da Espátula com carne na chapa
                    elseif nearSlotId and GrillSlotPositions[nearSlotId].occupied then
                        local state = GrillSlotPositions[nearSlotId].state
                        if state == 'needs_flip' then
                            -- Gesto tátil da espátula virando a carne
                            lib.requestAnimDict('amb@prop_human_bbq@male@idle_a')
                            TaskPlayAnim(ped, 'amb@prop_human_bbq@male@idle_a', 'idle_b', 8.0, -8.0, 650, 49, 0, false, false, false)
                            PlaySoundFrontend(-1, "BASE_JUMP_PASSED", "HUD_AWARDS", true)

                            TriggerServerEvent('granolla_restaurants:server:FlipSlot', currentStationId, nearSlotId)
                        elseif state == 'cooked' or state == 'burnt' then
                            -- Gesto da espátula recolhendo a carne
                            lib.requestAnimDict('amb@prop_human_bbq@male@idle_a')
                            TaskPlayAnim(ped, 'amb@prop_human_bbq@male@idle_a', 'idle_a', 8.0, -8.0, 650, 49, 0, false, false, false)
                            PlaySoundFrontend(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

                            TriggerServerEvent('granolla_restaurants:server:PickupSlot', currentStationId, nearSlotId)
                            GrillSlotPositions[nearSlotId].occupied = false
                            GrillSlotPositions[nearSlotId].state    = 'empty'
                        end
                    end
                end
            end

            -- Clique direito cancela ingrediente na espátula
            if IsDisabledControlJustPressed(0, 25) and grabbedIngredient then
                if grabbedProp and DoesEntityExist(grabbedProp) then
                    DetachEntity(grabbedProp, true, false)
                    DeleteEntity(grabbedProp)
                    grabbedProp = nil
                end
                grabbedIngredient = nil
                PlaySoundFrontend(-1, "CANCEL", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            end

            ::continue::
        end
    end)
end

function StopCookingCamera()
    -- Liberação incondicional de segurança do cursor NUI
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeCookingUI' })

    if not isCookingCamActive then return end
    isCookingCamActive = false
    currentStationId   = nil

    local ped = PlayerPedId()

    -- Remove a espátula física do mundo
    if heldSpatulaProp and DoesEntityExist(heldSpatulaProp) then
        DeleteEntity(heldSpatulaProp)
        heldSpatulaProp = nil
    end

    -- Remove comida segurada se houver
    if grabbedProp and DoesEntityExist(grabbedProp) then
        DetachEntity(grabbedProp, true, false)
        DeleteEntity(grabbedProp)
        grabbedProp = nil
    end
    grabbedIngredient  = nil

    for _, data in pairs(IngredientPileProps) do
        if data.prop and DoesEntityExist(data.prop) then DeleteEntity(data.prop) end
    end
    IngredientPileProps   = {}
    GrillSlotPositions    = {}

    if cookingCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cookingCam, false)
        cookingCam = nil
    end

    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    FreezeEntityPosition(ped, false)
end

-- ── Callbacks NUI da cozinha ─────────────────────────────────────

RegisterNUICallback('placeCookingIngredient', function(data, cb)
    if not isCookingCamActive or not currentStationId then cb('ok') return end
    local slotId = tonumber(data.slotId)
    if slotId and data.ingredientKey then
        TriggerServerEvent('granolla_restaurants:server:PlaceIngredient',
            currentStationId, slotId, data.ingredientKey)
    end
    cb('ok')
end)

RegisterNUICallback('flipCookingSlot', function(data, cb)
    if not isCookingCamActive or not currentStationId then cb('ok') return end
    local slotId = tonumber(data.slotId)
    if slotId then
        TriggerServerEvent('granolla_restaurants:server:FlipSlot', currentStationId, slotId)
    end
    cb('ok')
end)

RegisterNUICallback('pickupCookingSlot', function(data, cb)
    if not isCookingCamActive or not currentStationId then cb('ok') return end
    local slotId = tonumber(data.slotId)
    if slotId then
        TriggerServerEvent('granolla_restaurants:server:PickupSlot', currentStationId, slotId)
        if GrillSlotPositions[slotId] then
            GrillSlotPositions[slotId].occupied = false
            GrillSlotPositions[slotId].state    = 'empty'
        end
    end
    cb('ok')
end)

RegisterNUICallback('serveDish', function(data, cb)
    if isCookingCamActive then
        TriggerServerEvent('granolla_restaurants:server:ServeDish', currentStationId)
        StopCookingCamera()
    end
    cb('ok')
end)

RegisterNUICallback('closeCookingUI', function(data, cb)
    StopCookingCamera()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb('ok')
end)

RegisterNUICallback('clickCookingRing', function(data, cb)
    local slotKey = data.slotKey
    if slotKey then
        local stationId, slotId = slotKey:match("^(.-)_(%d+)$")
        if stationId and slotId then
            local propData = ActiveFoodProps[slotKey]
            if propData then
                if propData.prop and DoesEntityExist(propData.prop) then
                    local propCoords = GetEntityCoords(propData.prop)
                    StartCookingCamera(propCoords, stationId)
                end

                if propData.stage == 'needs_flip' then
                    TriggerServerEvent('granolla_restaurants:server:FlipSlot', stationId, tonumber(slotId))
                elseif propData.stage == 'cooked' or propData.stage == 'burnt' then
                    TriggerServerEvent('granolla_restaurants:server:PickupSlot', stationId, tonumber(slotId))
                end
            end
        end
    end
    cb('ok')
end)

-- Thread NUI 3D Nano Rings Projection
CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local ringsToDraw = {}

        for slotKey, propData in pairs(ActiveFoodProps) do
            if propData.prop and DoesEntityExist(propData.prop) then
                local propCoords = GetEntityCoords(propData.prop)
                local dist = #(pCoords - propCoords)

                if dist <= 6.0 then
                    sleep = 0
                    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(propCoords.x, propCoords.y, propCoords.z + 0.15)

                    if onScreen then
                        local stationId, slotId = slotKey:match("^(.-)_(%d+)$")
                        local stationData = (ClientStationsState and ClientStationsState[stationId])
                        local slot = stationData and stationData.slots and stationData.slots[tonumber(slotId)]

                        local progress = 0
                        local timeText = "0:00"
                        local status = propData.stage or "raw"
                        local label = (stationData and stationData.type == "fryer") and "FRITADEIRA" or "GRELHA"

                        if slot then
                            local now = GetCloudTimeAsInt() or os.time()
                            local elapsed = now - (slot.startTime or now)
                            local meatMeta = Config.MeatModels[slot.ingredientKey] or Config.FriedModels[slot.ingredientKey]

                            if meatMeta and meatMeta.requiresFlip then
                                local sideTime = math.max(3, math.floor((meatMeta.cookTime or 10) / 2))
                                local burnSideTime = math.max(6, math.floor((meatMeta.burnTime or 20) / 2))

                                if status == 'raw' then
                                    local rem = math.max(0, sideTime - elapsed)
                                    progress = math.floor((elapsed / sideTime) * 100)
                                    timeText = string.format("0:%02d", rem)
                                    label = "GRELHA"
                                elseif status == 'needs_flip' then
                                    progress = 100
                                    timeText = "VIRAR"
                                    label = "VIRAR"
                                elseif status == 'side2' then
                                    local rem = math.max(0, sideTime - elapsed)
                                    progress = math.floor((elapsed / sideTime) * 100)
                                    timeText = string.format("0:%02d", rem)
                                    label = "GRELHA"
                                elseif status == 'cooked' then
                                    progress = 100
                                    timeText = "PRONTO"
                                    label = "RECOLHER"
                                elseif status == 'burnt' then
                                    progress = 100
                                    timeText = "QUEIMADO"
                                    label = "DESCARTAR"
                                end
                            else
                                local cookTime = (meatMeta and meatMeta.cookTime) or 10
                                if status == 'raw' then
                                    local rem = math.max(0, cookTime - elapsed)
                                    progress = math.floor((elapsed / cookTime) * 100)
                                    timeText = string.format("0:%02d", rem)
                                elseif status == 'cooked' then
                                    progress = 100
                                    timeText = "PRONTO"
                                    label = "RECOLHER"
                                elseif status == 'burnt' then
                                    progress = 100
                                    timeText = "QUEIMADO"
                                    label = "DESCARTAR"
                                end
                            end
                        end

                        table.insert(ringsToDraw, {
                            id = slotKey,
                            x = screenX * 100,
                            y = screenY * 100,
                            progress = math.min(100, math.max(0, progress)),
                            timeText = timeText,
                            label = label,
                            status = status,
                            dist = dist
                        })
                    end

                    if dist <= 1.5 and IsControlJustPressed(0, 38) then
                        local stationId, slotId = slotKey:match("^(.-)_(%d+)$")
                        if stationId and slotId then
                            StartCookingCamera(propCoords, stationId)

                            if propData.stage == 'needs_flip' then
                                TriggerServerEvent('granolla_restaurants:server:FlipSlot', stationId, tonumber(slotId))
                            elseif propData.stage == 'cooked' or propData.stage == 'burnt' then
                                TriggerServerEvent('granolla_restaurants:server:PickupSlot', stationId, tonumber(slotId))
                            end
                        end
                    end
                end
            end
        end

        SendNUIMessage({
            action = "UPDATE_COOKING_RINGS",
            rings = ringsToDraw
        })

        Wait(sleep)
    end
end)

-- Limpeza ao reiniciar ou parar o script
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        StopCookingCamera()
        for slotKey, propData in pairs(ActiveFoodProps) do
            if propData.prop and DoesEntityExist(propData.prop) then
                DeleteEntity(propData.prop)
            end
        end
        ActiveFoodProps = {}
        ActiveSlotKeysPerStation = {}
    end
end)

-- Comando de Sintonia Fina para Desenvolvedores
RegisterCommand('spatulatune', function(_, args)
    local cfg = isMxcSpatula and SpatulaConfig.mxc or SpatulaConfig.native
    if #args >= 2 then
        cfg.pitch = tonumber(args[1]) or cfg.pitch
        cfg.yawOffset = tonumber(args[2]) or cfg.yawOffset
        if args[3] then cfg.caboLength = tonumber(args[3]) or cfg.caboLength end
        if args[4] then cfg.zOffset = tonumber(args[4]) or cfg.zOffset end
        print(string.format("[SpatulaTune] Aplicado: Pitch=%.1f, Yaw=%.1f, Cabo=%.2f, Z=%.3f", cfg.pitch, cfg.yawOffset, cfg.caboLength, cfg.zOffset))
        lib.notify({ title = "Espátula Calibrada", description = string.format("Pitch: %.1f | Yaw: %.1f | Cabo: %.2f | Z: %.3f", cfg.pitch, cfg.yawOffset, cfg.caboLength, cfg.zOffset), type = 'success' })
    else
        print(string.format("[SpatulaTune] Atual (%s): Pitch=%.1f, Yaw=%.1f, Cabo=%.2f, Z=%.3f", isMxcSpatula and "mxc" or "native", cfg.pitch, cfg.yawOffset, cfg.caboLength, cfg.zOffset))
        print("Uso no F8: spatulatune <pitch> <yawOffset> [caboLength] [zOffset]")
        lib.notify({ title = "Espátula 3D", description = string.format("Modelo: %s | Pitch: %.1f | Yaw: %.1f", isMxcSpatula and "MXC Culinária" or "GTA Nativo", cfg.pitch, cfg.yawOffset), type = 'inform' })
    end
end, false)

-- Comando de Recuperação de Emergência da Cozinha (Destrava mouse e câmera se necessário)
RegisterCommand('fixkitchen', function()
    StopCookingCamera()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closeCookingUI' })
    lib.notify({ title = 'Cozinha', description = 'Cursor e interface resetados com sucesso!', type = 'success' })
end, false)

-- Comando de Teste Imediato da Chapa 3D no Prop Mais Próximo
RegisterCommand('testkitchen', function()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local target = FindClosestGrillTarget(pCoords)
    if target then
        if type(target) == 'number' then
            StartCookingCamera(GetEntityCoords(target), tostring(target))
        elseif type(target) == 'table' then
            StartCookingCamera(target.coords, "nearest_grill", target.rot)
        end
    else
        lib.notify({ title = 'Chapa', description = 'Aproxime-se de um prop ou bancada de chapa para cozinhar!', type = 'error' })
    end
end, false)

-- Sintonia Fina da Câmera ao Vivo no F8 (Sem reiniciar o resource)
RegisterCommand('camtune', function(source, args)
    local param = args[1]
    local val = tonumber(args[2])
    if not param or not val then
        lib.notify({
            title = 'Ajuste de Câmera',
            description = 'Uso: /camtune [fwd|height|fov|look] [valor]\nEx: /camtune fwd 0.40 ou /camtune height 0.48',
            type = 'inform'
        })
        return
    end

    if param == 'fwd' then
        GrillCamConfig.fwdDist = val
    elseif param == 'height' then
        GrillCamConfig.height = val
    elseif param == 'fov' then
        GrillCamConfig.fov = val
    elseif param == 'look' then
        GrillCamConfig.fwdLookAt = val
    elseif param == 'ped' then
        GrillCamConfig.pedDist = val
    elseif param == 'blade' or param == 'bladey' then
        local cfg = isMxcSpatula and SpatulaConfig.mxc or SpatulaConfig.native
        cfg.bladeY = val
        if grabbedProp and DoesEntityExist(grabbedProp) and heldSpatulaProp and DoesEntityExist(heldSpatulaProp) then
            AttachEntityToEntity(grabbedProp, heldSpatulaProp, 0, 0.0, cfg.bladeY, cfg.bladeZ or 0.022, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
    elseif param == 'rot' or param == 'heading' or param == 'yaw' then
        currentGrillHeading = val
        if isCookingCamActive and grillWorldPos then
            SetupGrillSlots(grillWorldPos, val, currentSurfaceZ)
            local ingredients = GetPlayerCookingIngredients()
            SpawnIngredientPiles(grillWorldPos, val, ingredients, currentSurfaceZ)
        end
    end

    lib.notify({
        title = 'Câmera Ajustada',
        description = string.format("%s = %.2f", param, val),
        type = 'success'
    })

    if isCookingCamActive and cookingCam and grillWorldPos then
        local rad = math.rad(currentGrillHeading or 0.0)
        local fwd = vector3(-math.sin(rad), math.cos(rad), 0.0)
        local rgt = vector3(math.cos(rad), math.sin(rad), 0.0)
        local centerPos = grillWorldPos

        local camPos = vector3(
            centerPos.x - fwd.x * GrillCamConfig.fwdDist,
            centerPos.y - fwd.y * GrillCamConfig.fwdDist,
            centerPos.z + currentSurfaceZ + GrillCamConfig.height
        )
        local lookAt = vector3(
            centerPos.x + fwd.x * GrillCamConfig.fwdLookAt + rgt.x * GrillCamConfig.latLookAt,
            centerPos.y + fwd.y * GrillCamConfig.fwdLookAt + rgt.y * GrillCamConfig.latLookAt,
            centerPos.z + currentSurfaceZ + 0.02
        )

        SetCamCoord(cookingCam, camPos.x, camPos.y, camPos.z)
        SetCamFov(cookingCam, GrillCamConfig.fov)
        PointCamAtCoord(cookingCam, lookAt.x, lookAt.y, lookAt.z)
    end
end, false)

