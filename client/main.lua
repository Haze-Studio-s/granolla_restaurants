-- client/main.lua
local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    print("Granolla Restaurants Iniciado!")
    -- Futuramente: Inicializar o sistema de Target (ox_target) para as estações de trabalho e NPCs.
end)

-- Evento para receber o update do servidor quando a comida muda de estágio (cru, cozido, queimado)
RegisterNetEvent('granolla_restaurants:client:UpdatePropVisuals', function(grillId, itemSlot, newStage)
    -- Isso chamará uma função de client/props.lua para mudar a cor do prop no mundo 3D
end)
