-- client/delivery.lua
-- ================================================================
-- GRANÔLLA RESTAURANTS: SISTEMA DE DELIVERY VIA GPS
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

local isDelivering = false
local currentDeliveryBlip = nil
local dropOffCoords = nil
local deliveryCustomerPed = nil

-- Destinos de Exemplo para as entregas
local DeliveryLocations = {
    vector3(116.82, -1950.1, 20.74),
    vector3(-144.52, -1451.9, 31.64),
    vector3(336.17, -2001.2, 21.0),
    vector3(14.21, -1533.2, 29.21)
}

local NPCPeds = {
    'a_m_y_business_02',
    'a_f_y_hipster_01',
    'a_m_m_tourist_01',
    'a_f_m_fatcult_01'
}

-- Inicializa os targets nos restaurantes fixos para iniciar a entrega
CreateThread(function()
    for restId, restData in pairs(Config.Restaurants) do
        if restData.deliveryStartPoint then
            exports.ox_target:addSphereZone({
                coords = restData.deliveryStartPoint,
                radius = 1.0,
                debug = false,
                options = {
                    {
                        name = 'start_delivery_' .. restId,
                        icon = 'fa-solid fa-motorcycle',
                        label = 'Pegar Mochila de Entrega',
                        groups = restData.jobRequired,
                        onSelect = function()
                            StartDeliveryRun()
                        end
                    }
                }
            })
        end
    end
end)

function StartDeliveryRun()
    if isDelivering then
        lib.notify({title = 'Aviso', description = 'Você já está realizando uma entrega ativa!', type = 'error'})
        return
    end

    isDelivering = true
    dropOffCoords = DeliveryLocations[math.random(#DeliveryLocations)]

    -- Notifica o servidor para registrar a sessão com timestamp
    TriggerServerEvent('granolla_restaurants:server:StartDelivery')

    -- Criar Blip no GPS
    currentDeliveryBlip = AddBlipForCoord(dropOffCoords.x, dropOffCoords.y, dropOffCoords.z)
    SetBlipSprite(currentDeliveryBlip, 280)
    SetBlipColour(currentDeliveryBlip, 5)
    SetBlipRoute(currentDeliveryBlip, true)
    SetBlipRouteColour(currentDeliveryBlip, 5)

    lib.notify({title = 'Delivery Iniciado', description = 'Vá até o destino marcado no GPS com a refeição.', type = 'success'})

    -- Loop de verificação de chegada
    CreateThread(function()
        while isDelivering do
            Wait(1000)
            local pCoords = GetEntityCoords(cache.ped or PlayerPedId())
            local dist = #(pCoords - dropOffCoords)

            if dist < 50.0 and not deliveryCustomerPed then
                SpawnCustomerAtDoor()
            end
            
            if dist < 15.0 and deliveryCustomerPed then
                exports.ox_target:addLocalEntity(deliveryCustomerPed, {
                    {
                        name = 'deliver_food_npc',
                        icon = 'fa-solid fa-box',
                        label = 'Entregar Pedido',
                        distance = 2.0,
                        onSelect = function()
                            CompleteDelivery()
                        end
                    }
                })
                break
            end
        end
    end)
end

function SpawnCustomerAtDoor()
    local model = GetHashKey(NPCPeds[math.random(#NPCPeds)])
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 50 do 
        Wait(10)
        t = t + 1
    end
    
    deliveryCustomerPed = CreatePed(4, model, dropOffCoords.x, dropOffCoords.y, dropOffCoords.z, 0.0, false, true)
    SetEntityAsMissionEntity(deliveryCustomerPed, true, true)
    FreezeEntityPosition(deliveryCustomerPed, true)
    
    lib.requestAnimDict("timetable@jimmy@doorknock@")
    TaskPlayAnim(deliveryCustomerPed, "timetable@jimmy@doorknock@", "idle_a", 8.0, -8.0, -1, 1, 0, false, false, false)
end

function CompleteDelivery()
    if not isDelivering then return end
    
    local ped = cache.ped or PlayerPedId()
    
    lib.requestAnimDict("mp_safehouselost@")
    TaskPlayAnim(ped, "mp_safehouselost@", "package_dropoff", 8.0, -8.0, -1, 0, 0, false, false, false)
    
    local success = lib.progressBar({
        duration = 3000,
        label = 'Entregando o pedido ao cliente...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true }
    })
    
    ClearPedTasks(ped)
    
    if success then
        isDelivering = false
        if currentDeliveryBlip then
            RemoveBlip(currentDeliveryBlip)
            currentDeliveryBlip = nil
        end
        if deliveryCustomerPed then
            exports.ox_target:removeLocalEntity(deliveryCustomerPed, 'deliver_food_npc')
            FreezeEntityPosition(deliveryCustomerPed, false)
            TaskWanderStandard(deliveryCustomerPed, 10.0, 10)
        end
        
        -- Pagamento seguro validado no servidor
        TriggerServerEvent('granolla_restaurants:server:DeliveryPayout')
        lib.notify({title = 'Sucesso', description = 'Entrega concluída! Você recebeu seu pagamento.', type = 'success'})
        
        local custToDel = deliveryCustomerPed
        deliveryCustomerPed = nil
        SetTimeout(15000, function()
            if DoesEntityExist(custToDel) then DeleteEntity(custToDel) end
        end)
    else
        TriggerServerEvent('granolla_restaurants:server:CancelDelivery')
        lib.notify({title = 'Cancelado', description = 'Você cancelou a entrega.', type = 'error'})
    end
end

-- Limpeza ao reiniciar o resource
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if currentDeliveryBlip then RemoveBlip(currentDeliveryBlip) end
        if deliveryCustomerPed and DoesEntityExist(deliveryCustomerPed) then DeleteEntity(deliveryCustomerPed) end
    end
end)
