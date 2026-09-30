-- client/placement.lua
local isPlacing = false
local ghostProp = nil

-- Função nativa de raycast para encontrar o chão (Padrão semelhante ao ar-bbq)
local function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

local function RaycastCamera(distance)
    local cameraRotation = GetGameplayCamRot()
    local cameraCoord = GetGameplayCamCoord()
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local a, b, c, d, e = GetShapeTestResult(StartExpensiveSynchronousShapeTestLosProbe(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0))
    return b, c, e
end

-- Iniciar o posicionamento do prop
function StartPlacingProp(itemName)
    if isPlacing then return end
    
    local propData = Config.PlaceableProps[itemName]
    if not propData then return end
    
    local model = GetHashKey(propData.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    isPlacing = true
    ghostProp = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    SetEntityCollision(ghostProp, false, false)
    SetEntityAlpha(ghostProp, 150, false) -- Fica meio transparente (fantasma)
    
    lib.notify({title = "Modo Construção", description = "Use [E] para posicionar, [SCROLL] para girar, [BACKSPACE] para cancelar.", type = "info"})
    
    local heading = 0.0
    
    CreateThread(function()
        while isPlacing do
            Wait(0)
            DisableControlAction(0, 24, true) -- Desativa soco/tiro
            
            local hit, coords, entity = RaycastCamera(10.0)
            
            if hit then
                SetEntityCoords(ghostProp, coords.x, coords.y, coords.z)
                SetEntityHeading(ghostProp, heading)
                
                -- Girar com scroll do mouse
                if IsControlPressed(0, 14) then -- Scroll Down
                    heading = heading - 2.0
                elseif IsControlPressed(0, 15) then -- Scroll Up
                    heading = heading + 2.0
                end
                
                -- Confirmar Colocação [E]
                if IsControlJustPressed(0, 38) then
                    isPlacing = false
                    local finalCoords = GetEntityCoords(ghostProp)
                    local finalHeading = GetEntityHeading(ghostProp)
                    
                    DeleteEntity(ghostProp)
                    
                    -- Enviar para o servidor para remover item do inventário e salvar no DB
                    TriggerServerEvent('granolla_restaurants:server:PlaceProp', itemName, finalCoords, finalHeading)
                    
                    -- Se for um balcão ou carrinho de cachorro-quente, liga os NPCs
                    if itemName == 'granolla_foodcart' then
                        -- Aqui, como o prop real será recriado pelo Sync do servidor, 
                        -- usamos um timer para achar ele ou mandamos apenas a coordenada base.
                        -- Para fins práticos, ativamos o loop mandando as coordenadas
                        TriggerEvent('granolla_restaurants:client:ToggleNPCLoop', finalCoords)
                    end
                end
            end
            
            -- Cancelar [BACKSPACE] ou [ESC]
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                isPlacing = false
                DeleteEntity(ghostProp)
                lib.notify({title = "Cancelado", description = "Você cancelou a colocação do item.", type = "error"})
            end
        end
    end)
end

-- Escutar quando o item for usado do inventário
RegisterNetEvent('granolla_restaurants:client:UsePlaceableItem', function(itemName)
    StartPlacingProp(itemName)
end)

-- Sistema de Sincronização dos Props (Quando entra no server ou quando alguém coloca)
local SpawnedWorldProps = {}

RegisterNetEvent('granolla_restaurants:client:SyncProps', function(propsList)
    -- Limpar props antigos se houver
    for _, propEnt in pairs(SpawnedWorldProps) do
        if DoesEntityExist(propEnt) then DeleteEntity(propEnt) end
    end
    SpawnedWorldProps = {}
    
    -- Spawnar a lista nova que veio do servidor
    for dbId, v in pairs(propsList) do
        local model = GetHashKey(v.model)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        
        local obj = CreateObject(model, v.coords.x, v.coords.y, v.coords.z, false, false, false)
        SetEntityHeading(obj, v.rotation)
        FreezeEntityPosition(obj, true)
        
        local propData = Config.PlaceableProps[v.item_name]
        
        -- Adicionamos o ox_target individualmente nesta entidade
        exports.ox_target:addLocalEntity(obj, {
            {
                name = 'granolla_workstation_'..dbId,
                icon = 'fa-solid fa-fire-burner',
                label = 'Usar ' .. (propData and propData.label or 'Estação'),
                distance = 2.0,
                onSelect = function(data)
                    if propData and propData.workstation then
                        -- Envia o job vinculado a esse prop pra checar exclusividade
                        OpenWorkstationMenu(data.entity, propData.workstation, v.job)
                    end
                end
            },
            {
                name = 'granolla_pickup_'..dbId,
                icon = 'fa-solid fa-hand',
                label = 'Recolher',
                distance = 2.0,
                onSelect = function(data)
                    TriggerServerEvent('granolla_restaurants:server:PickupProp', dbId)
                end
            }
        })
        
        SpawnedWorldProps[dbId] = obj

        if SyncFoodPropsForStation and ClientStationsState and ClientStationsState[tostring(dbId)] then
            SyncFoodPropsForStation(tostring(dbId), ClientStationsState[tostring(dbId)])
        end
    end
end)

local FixedWorldProps = {}

-- Spawn ou Target de Workstations fixas dos restaurantes
CreateThread(function()
    for restId, config in pairs(Config.Restaurants) do
        if config.fixedWorkstations then
            for i, ws in ipairs(config.fixedWorkstations) do
                local wsType = ws.workstation or (Config.PlaceableProps[ws.model] and Config.PlaceableProps[ws.model].workstation) or "grill"
                local wsLabel = (Config.Workstations[wsType] and Config.Workstations[wsType].label) or "Estação"
                
                if ws.useExistingModel then
                    -- Usa o prop que JÁ existe no MLO criando uma SphereZone de Target sem criar objetos duplicados
                    exports.ox_target:addSphereZone({
                        coords = ws.coords,
                        radius = ws.radius or 1.2,
                        debug = false,
                        options = {
                            {
                                name = 'granolla_mlo_ws_' .. restId .. '_' .. i,
                                icon = 'fa-solid fa-fire-burner',
                                label = 'Usar ' .. wsLabel,
                                distance = 2.0,
                                onSelect = function(data)
                                    OpenWorkstationMenu(ws.id or (restId .. '_' .. i), wsType, config.jobRequired)
                                end
                            }
                        }
                    })
                else
                    -- Spawna um prop físico caso não exista no MLO
                    local propData = Config.PlaceableProps[ws.model]
                    if propData then
                        local model = GetHashKey(propData.model)
                        RequestModel(model)
                        while not HasModelLoaded(model) do Wait(10) end
                        
                        local obj = CreateObject(model, ws.coords.x, ws.coords.y, ws.coords.z, false, false, false)
                        SetEntityHeading(obj, ws.heading or 0.0)
                        FreezeEntityPosition(obj, true)
                        
                        exports.ox_target:addLocalEntity(obj, {
                            {
                                name = 'granolla_fixed_ws_' .. restId .. '_' .. i,
                                icon = 'fa-solid fa-fire-burner',
                                label = 'Usar ' .. wsLabel,
                                distance = 2.0,
                                onSelect = function(data)
                                    OpenWorkstationMenu(data.entity, wsType, config.jobRequired)
                                end
                            }
                        })
                        table.insert(FixedWorldProps, obj)
                    end
                end
            end
        end
    end
end)

-- Nota: Modelos de MLOs e restaurantes são gerenciados pelas zonas calibradas em client/kitchens.lua
-- evitando conflitos e duplicidades de opções no ox_target.

-- Sistema de Criação de Blips para Restaurantes Fixos
CreateThread(function()
    for restId, config in pairs(Config.Restaurants) do
        if config.blip and config.blip.enabled then
            local blipData = config.blip
            local blip = AddBlipForCoord(blipData.coords.x, blipData.coords.y, blipData.coords.z)
            SetBlipSprite(blip, blipData.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, blipData.scale)
            SetBlipColour(blip, blipData.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(config.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, propEnt in pairs(SpawnedWorldProps) do
            if DoesEntityExist(propEnt) then DeleteEntity(propEnt) end
        end
        for _, propEnt in ipairs(FixedWorldProps) do
            if DoesEntityExist(propEnt) then DeleteEntity(propEnt) end
        end
    end
end)
