-- server/npcs.lua
local QBCore = exports['qb-core']:GetCoreObject()
local StoresState = {}
local ActiveStoreTimers = {}

for restId, _ in pairs(Config.Restaurants) do
    StoresState[restId] = {
        DutyStartTime = 0,
        LastSaleTime = 0,
        NpcCount = 0,
        IsCustomerWaiting = false
    }
end

local function StartNPCSpawner(restId)
    if ActiveStoreTimers[restId] then return end
    ActiveStoreTimers[restId] = true
    
    CreateThread(function()
        while ActiveStoreTimers[restId] do
            Wait(Config.NPCLogic.checkIntervalMin * 60 * 1000)
            
            local config = Config.Restaurants[restId]
            local players = QBCore.Functions.GetQBPlayers()
            local onDutyPlayers = {}
            
            for _, p in pairs(players) do
                if p.PlayerData.job.name == config.jobRequired and p.PlayerData.job.onduty then
                    table.insert(onDutyPlayers, p.PlayerData.source)
                end
            end
            
            local state = StoresState[restId]
            
            if #onDutyPlayers > 0 then
                if not state.IsCustomerWaiting then
                    local timeOnDuty = (os.time() - state.DutyStartTime) / 60
                    local timeSinceLastSale = (os.time() - state.LastSaleTime) / 60
                    
                    local shouldSpawn = false
                    
                    if timeOnDuty >= Config.NPCLogic.dutyTimeRequiredMin and state.NpcCount == 0 then
                        shouldSpawn = true
                    elseif timeSinceLastSale > Config.NPCLogic.checkIntervalMin then
                        shouldSpawn = true
                    elseif math.random(1, 100) <= Config.NPCLogic.chanceIfSold then
                        shouldSpawn = true
                    end
                    
                    if shouldSpawn then
                        state.NpcCount = state.NpcCount + 1
                        state.IsCustomerWaiting = true
                        
                        local randomEmp = onDutyPlayers[math.random(#onDutyPlayers)]
                        TriggerClientEvent('granolla_restaurants:client:SpawnStoreNPC', randomEmp, restId)
                    end
                end
            else
                -- If no one is left on duty, stop the timer loop
                ActiveStoreTimers[restId] = false
                state.DutyStartTime = 0
                state.IsCustomerWaiting = false
                state.NpcCount = 0
            end
        end
    end)
end

RegisterNetEvent('QBCore:Server:OnJobUpdate', function(source, job)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    for restId, config in pairs(Config.Restaurants) do
        if config.jobRequired == job.name then
            if job.onduty then
                if StoresState[restId].DutyStartTime == 0 then
                    StoresState[restId].DutyStartTime = os.time()
                end
                StartNPCSpawner(restId)
            else
                -- Verifica se restou mais alguém em serviço
                local stillOnDuty = 0
                for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
                    if p.PlayerData.job.name == config.jobRequired and p.PlayerData.job.onduty then
                        stillOnDuty = stillOnDuty + 1
                    end
                end
                
                if stillOnDuty == 0 then
                    ActiveStoreTimers[restId] = false
                    StoresState[restId].DutyStartTime = 0
                    StoresState[restId].IsCustomerWaiting = false
                    StoresState[restId].NpcCount = 0
                end
            end
        end
    end
end)

-- Capturar também a mudança direta de duty (ToggleDuty)
RegisterNetEvent('QBCore:ToggleDuty', function()
    local src = source
    SetTimeout(500, function() -- Aguarda pra garantir que o state do job salvou
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        
        local job = Player.PlayerData.job
        for restId, config in pairs(Config.Restaurants) do
            if config.jobRequired == job.name then
                if job.onduty then
                    if StoresState[restId].DutyStartTime == 0 then
                        StoresState[restId].DutyStartTime = os.time()
                    end
                    StartNPCSpawner(restId)
                else
                    -- Verifica se restou mais alguém
                    local stillOnDuty = 0
                    for _, p in pairs(QBCore.Functions.GetQBPlayers()) do
                        if p.PlayerData.job.name == config.jobRequired and p.PlayerData.job.onduty then
                            stillOnDuty = stillOnDuty + 1
                        end
                    end
                    
                    if stillOnDuty == 0 then
                        ActiveStoreTimers[restId] = false
                        StoresState[restId].DutyStartTime = 0
                        StoresState[restId].IsCustomerWaiting = false
                        StoresState[restId].NpcCount = 0
                    end
                end
            end
        end
    end)
end)

RegisterNetEvent('granolla_restaurants:server:RegisterRealSale', function(restId)
    if StoresState[restId] then
        StoresState[restId].LastSaleTime = os.time()
    end
end)

RegisterNetEvent('granolla_restaurants:server:NpcServed', function(restId)
    if StoresState[restId] then
        StoresState[restId].IsCustomerWaiting = false
        StoresState[restId].LastSaleTime = os.time()
    end
end)
