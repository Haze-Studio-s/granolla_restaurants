-- client/npcs.lua
local QBCore = exports['qb-core']:GetCoreObject()

local NPCPeds = {
    'a_m_y_business_02',
    'a_f_y_hipster_01',
    'a_m_m_tourist_01',
    'a_f_m_fatcult_01'
}

-- Ponto de venda fictício dinâmico (Foodcarts colocados no chão)
RegisterNetEvent('granolla_restaurants:client:ToggleNPCLoop', function(cartCoords)
    -- Isso continua igual para as barracas dinâmicas na rua, que não dependem do Job
    CreateThread(function()
        while true do
            Wait(math.random(30000, 60000))
            if cartCoords then
                SpawnNPCAndWalkToCart(cartCoords)
            else
                break
            end
        end
    end)
end)

function SpawnNPCAndWalkToCart(cartCoords)
    local model = GetHashKey(NPCPeds[math.random(#NPCPeds)])
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    local spawnCoords = vector3(cartCoords.x + 30.0, cartCoords.y, cartCoords.z)
    local customer = CreatePed(4, model, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, false, true)
    
    SetEntityAsMissionEntity(customer, true, true)
    TaskGoStraightToCoord(customer, cartCoords.x + 1.5, cartCoords.y, cartCoords.z, 1.0, -1, 0.0, 0.0)
    
    Wait(20000) 
    
    TaskTurnPedToFaceCoord(customer, cartCoords.x, cartCoords.y, cartCoords.z, -1)
    lib.requestAnimDict("misscarsteal4@actor")
    TaskPlayAnim(customer, "misscarsteal4@actor", "actor_berating_loop", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    exports.ox_target:addLocalEntity(customer, {
        {
            name = 'serve_customer_cart',
            icon = 'fa-solid fa-burger',
            label = 'Atender Cliente',
            distance = 2.0,
            onSelect = function()
                ServeStoreCustomer(customer, 'foodcart')
            end
        }
    })
    
    SetTimeout(40000, function()
        if DoesEntityExist(customer) then
            exports.ox_target:removeLocalEntity(customer, 'serve_customer_cart')
            TaskWanderStandard(customer, 10.0, 10)
            Wait(10000)
            if DoesEntityExist(customer) then DeleteEntity(customer) end
        end
    end)
end

-- Loja Fixa (Recebe ordem do Servidor quando for a hora exata)
RegisterNetEvent('granolla_restaurants:client:SpawnStoreNPC', function(restId)
    local restConfig = Config.Restaurants[restId]
    
    local model = GetHashKey(NPCPeds[math.random(#NPCPeds)])
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    -- Sorteia um dos 3 pontos de spawn escondidos
    local spawnPoint = restConfig.npcSpawnPoints[math.random(#restConfig.npcSpawnPoints)]
    local customer = CreatePed(4, model, spawnPoint.x, spawnPoint.y, spawnPoint.z, 0.0, false, true)
    
    SetEntityAsMissionEntity(customer, true, true)
    
    -- Caminha até o balcão
    TaskGoStraightToCoord(customer, restConfig.npcCounterPoint.x, restConfig.npcCounterPoint.y, restConfig.npcCounterPoint.z, 1.0, -1, 0.0, 0.0)
    
    Wait(20000)
    
    -- Fica impaciente no balcão
    TaskTurnPedToFaceCoord(customer, restConfig.npcCounterPoint.x, restConfig.npcCounterPoint.y - 1.0, restConfig.npcCounterPoint.z, -1)
    lib.requestAnimDict("misscarsteal4@actor")
    TaskPlayAnim(customer, "misscarsteal4@actor", "actor_berating_loop", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    exports.ox_target:addLocalEntity(customer, {
        {
            name = 'serve_store_customer_' .. restId,
            icon = 'fa-solid fa-burger',
            label = 'Atender Cliente do Balcão',
            groups = restConfig.jobRequired,
            distance = 2.0,
            onSelect = function()
                ServeStoreCustomer(customer, restId)
            end
        }
    })
    
    SetTimeout(120000, function()
        if DoesEntityExist(customer) then
            exports.ox_target:removeLocalEntity(customer, 'serve_store_customer_' .. restId)
            TaskWanderStandard(customer, 10.0, 10)
            TriggerServerEvent('granolla_restaurants:server:NpcServed', restId)
            lib.notify({title = 'Cliente Perdido', description = 'O cliente cansou de esperar e foi embora.', type = 'error'})
            Wait(20000)
            if DoesEntityExist(customer) then DeleteEntity(customer) end
        end
    end)
end)

function ServeStoreCustomer(customerPed, restId)
    local success = lib.progressBar({
        duration = 3000,
        label = 'Entregando o pedido ao cliente...',
        useWhileDead = false,
        canCancel = false,
        disable = { move = true }
    })
    
    if success then
        exports.ox_target:removeLocalEntity(customerPed, 'serve_store_customer_' .. restId)
        if restId == 'foodcart' then
            exports.ox_target:removeLocalEntity(customerPed, 'serve_customer_cart')
        end
        ClearPedTasks(customerPed)
        
        TaskWanderStandard(customerPed, 10.0, 10)
        
        if restId ~= 'foodcart' then
            TriggerServerEvent('granolla_restaurants:server:NpcServed', restId)
        end
        TriggerServerEvent('granolla_restaurants:server:NPCPayout')
        
        lib.notify({title = 'Vendido!', description = 'O cliente pagou e foi embora.', type = 'success'})
        
        Wait(15000)
        if DoesEntityExist(customerPed) then DeleteEntity(customerPed) end
    end
end
