-- server/props.lua
-- ================================================================
-- GRANÔLLA RESTAURANTS: GERENCIAMENTO DE PROPS SALVOS NO MUNDO
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local SavedProps = {}

-- Carrega todos os props salvos do banco de dados na inicialização
CreateThread(function()
    Wait(2000) -- Aguardar o banco de dados inicializar
    MySQL.query('SELECT * FROM granolla_props_saved', {}, function(results)
        if not results then return end
        for _, row in ipairs(results) do
            local coords = json.decode(row.coords)
            SavedProps[row.id] = {
                id = row.id,
                model = row.prop_model,
                item_name = row.item_name,
                coords = vector3(coords.x, coords.y, coords.z),
                rotation = tonumber(row.rotation) or 0.0,
                owner = row.owner,
                job = row.job
            }
        end
        print('^2[Granolla Restaurants]^0 Carregados ' .. #results .. ' props do mundo.')
        TriggerClientEvent('granolla_restaurants:client:SyncProps', -1, SavedProps)
    end)
end)

-- Registra a usabilidade dos itens no inventário para abrir o modo de colocação
CreateThread(function()
    for itemName, _ in pairs(Config.PlaceableProps) do
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            local src = source
            local count = exports.ox_inventory:GetItemCount(src, itemName)
            if count and count >= 1 then
                TriggerClientEvent('granolla_restaurants:client:UsePlaceableItem', src, itemName)
            end
        end)
    end
end)

-- Posicionar Prop no Mundo (Com validação atômica de inventário e proximidade)
RegisterNetEvent('granolla_restaurants:server:PlaceProp', function(itemName, coords, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local propData = Config.PlaceableProps[itemName]
    if not propData then return end

    if not coords or not coords.x or not coords.y or not coords.z then
        return
    end

    -- 1. Validação de Proximidade (Anti-Teletransporte / Spawn remoto)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local targetCoords = vector3(coords.x, coords.y, coords.z)
    if #(pCoords - targetCoords) > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Posição de colocação muito distante do seu personagem.', type = 'error'})
        return
    end
    
    -- 2. Validação Atômica no ox_inventory
    local count = exports.ox_inventory:GetItemCount(src, itemName)
    if not count or count < 1 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Você não possui este objeto no inventário.', type = 'error'})
        return
    end
    
    local removed = exports.ox_inventory:RemoveItem(src, itemName, 1)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Falha ao utilizar o objeto.', type = 'error'})
        return
    end
    
    -- 3. Salva no Banco de Dados
    MySQL.insert('INSERT INTO granolla_props_saved (owner, prop_model, item_name, coords, rotation, job) VALUES (?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.citizenid,
        propData.model,
        itemName,
        json.encode({x = coords.x, y = coords.y, z = coords.z}),
        heading,
        Player.PlayerData.job.name
    }, function(id)
        if id then
            SavedProps[id] = {
                id = id,
                model = propData.model,
                item_name = itemName,
                coords = targetCoords,
                rotation = heading,
                owner = Player.PlayerData.citizenid,
                job = Player.PlayerData.job.name
            }
            TriggerClientEvent('granolla_restaurants:client:SyncProps', -1, SavedProps)
            TriggerClientEvent('ox_lib:notify', src, {title = 'Sucesso', description = (propData.label or 'Objeto') .. ' posicionado com sucesso!', type = 'success'})
        end
    end)
end)

-- Recolher Prop do Mundo
RegisterNetEvent('granolla_restaurants:server:PickupProp', function(propId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local prop = SavedProps[propId]
    if not prop then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Objeto não encontrado ou já recolhido.', type = 'error'})
        return
    end

    -- 1. Validação de Proximidade (Máx 5.0 metros)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - prop.coords) > 5.0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Aproxime-se do objeto para recolhê-lo.', type = 'error'})
        return
    end
    
    -- 2. Validação de Autorização: Dono, Chefe da Sociedade ou Administrador
    local isOwner = (prop.owner == Player.PlayerData.citizenid)
    local isBoss  = (Player.PlayerData.job.name == prop.job and Player.PlayerData.job.isboss)
    local isAdmin = QBCore.Functions.HasPermission(src, 'admin')

    if not isOwner and not isBoss and not isAdmin then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Permissão Negada', description = 'Apenas quem colocou, gerentes do restaurante ou admins podem recolher este objeto.', type = 'error'})
        return
    end
    
    -- 3. Deleta do Banco e Devolve o Item
    MySQL.query('DELETE FROM granolla_props_saved WHERE id = ?', {propId}, function(res)
        exports.ox_inventory:AddItem(src, prop.item_name, 1)
        SavedProps[propId] = nil
        TriggerClientEvent('granolla_restaurants:client:SyncProps', -1, SavedProps)
        TriggerClientEvent('ox_lib:notify', src, {title = 'Recolhido', description = 'Objeto recolhido e guardado no seu inventário.', type = 'info'})
    end)
end)

-- Sincronização ao carregar o jogador
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('granolla_restaurants:client:SyncProps', src, SavedProps)
end)
