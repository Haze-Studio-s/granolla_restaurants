-- server/economy.lua
-- ================================================================
-- ECONOMIA GASTRONÔMICA: BANDEJAS COMPARTILHADAS & SISTEMA POS (COBRANÇAS)
-- Integração com ox_inventory (RegisterStash) e Renewed-Banking.
-- Validação estrita anti-exploit para pagamentos de Delivery e NPCs.
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local PendingBills = {}
local ActiveDeliveries = {}
local LastNpcPayout = {}

-- ── Registro de Stashes de Bandejas no Balcão ───────────────────
CreateThread(function()
    Wait(1000)
    for restId, restConfig in pairs(Config.Restaurants) do
        if restConfig.trays then
            for _, tray in ipairs(restConfig.trays) do
                exports.ox_inventory:RegisterStash(
                    tray.id,
                    tray.label or "Bandeja de Pedidos",
                    10,      -- slots
                    25000,   -- maxWeight (25kg)
                    nil,     -- owner (pública para atender clientes)
                    nil,     -- groups
                    tray.coords
                )
            end
        end
    end

    -- Registrar Stashes dos MLOs de Cozinhas Suportadas (ex: uniqx_burgershot)
    if Config.SupportedKitchens then
        for kitchenKey, kData in pairs(Config.SupportedKitchens) do
            if kData.serviceCounters then
                for idx, sc in ipairs(kData.serviceCounters) do
                    if sc.tray then
                        local stashId = string.format("granolla_tray_%s_%d", kitchenKey, idx)
                        exports.ox_inventory:RegisterStash(
                            stashId,
                            "Bandeja de Pedidos (" .. (kData.label or kitchenKey) .. ")",
                            10,
                            25000,
                            nil,
                            nil,
                            sc.pos
                        )
                    end
                end
            end
        end
    end

    print('^2[Granolla Restaurants]^0 Bandejas de balcão e MLOs registradas com sucesso no ox_inventory.')
end)

-- Limpeza de contas expiradas (a cada 60 segundos)
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for billId, bill in pairs(PendingBills) do
            if (now - (bill.createdAt or 0)) > 180 then -- 3 minutos para expirar
                PendingBills[billId] = nil
            end
        end
    end
end)

-- ── Envio de Cobrança pelo Atendente ────────────────────────────
RegisterNetEvent('granolla_restaurants:server:SendBill', function(targetId, amount, note, restaurantId)
    local src = source
    local Biller = QBCore.Functions.GetPlayer(src)
    targetId = tonumber(targetId)
    local Target = targetId and QBCore.Functions.GetPlayer(targetId)

    if not Biller or not Target then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Cliente não encontrado.', type = 'error' })
        return
    end

    if src == targetId then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Você não pode cobrar a si mesmo.', type = 'error' })
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 or amount > 50000 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Valor de cobrança inválido.', type = 'error' })
        return
    end

    -- Validação de Proximidade entre Atendente e Cliente
    local billerCoords = GetEntityCoords(GetPlayerPed(src))
    local targetCoords = GetEntityCoords(GetPlayerPed(targetId))
    if #(billerCoords - targetCoords) > 10.0 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'O cliente está muito distante do balcão.', type = 'error' })
        return
    end

    local restConfig = Config.Restaurants[restaurantId]
    local restLabel  = restConfig and restConfig.label or "Restaurante"
    local restJob    = restConfig and restConfig.jobRequired or "hotdog"

    local billId = "bill_" .. src .. "_" .. targetId .. "_" .. os.time()
    PendingBills[billId] = {
        billerSrc     = src,
        billerName    = Biller.PlayerData.charinfo.firstname .. " " .. Biller.PlayerData.charinfo.lastname,
        targetSrc     = targetId,
        amount        = amount,
        note          = tostring(note or "Refeição"),
        restaurantJob = restJob,
        restLabel     = restLabel,
        createdAt     = os.time()
    }

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Cobrança Enviada',
        description = ('Aguardando confirmação de $%s de %s...'):format(amount, Target.PlayerData.charinfo.firstname),
        type = 'info'
    })

    TriggerClientEvent('granolla_restaurants:client:ReceiveBill', targetId, billId, restLabel, PendingBills[billId].billerName, amount, PendingBills[billId].note)
end)

-- ── Pagamento da Cobrança pelo Cliente ──────────────────────────
RegisterNetEvent('granolla_restaurants:server:PayBill', function(billId)
    local src = source
    local bill = PendingBills[billId]

    if not bill or bill.targetSrc ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Conta inválida ou expirada.', type = 'error' })
        return
    end

    local Target = QBCore.Functions.GetPlayer(src)
    local Biller = QBCore.Functions.GetPlayer(bill.billerSrc)

    if not Target then return end

    local cash = Target.Functions.GetMoney('cash')
    local bank = Target.Functions.GetMoney('bank')
    local paidMethod = nil

    if cash >= bill.amount then
        Target.Functions.RemoveMoney('cash', bill.amount, "restaurant-bill")
        paidMethod = 'dinheiro'
    elseif bank >= bill.amount then
        Target.Functions.RemoveMoney('bank', bill.amount, "restaurant-bill")
        paidMethod = 'banco'
    else
        TriggerClientEvent('ox_lib:notify', src, { title = 'Saldo Insuficiente', description = 'Você não possui fundos para pagar esta conta.', type = 'error' })
        if Biller then
            TriggerClientEvent('ox_lib:notify', bill.billerSrc, { title = 'Pagamento Falhou', description = 'O cliente não possui saldo suficiente.', type = 'error' })
        end
        PendingBills[billId] = nil
        return
    end

    -- Credita o valor na conta bancária da sociedade / empresa
    local creditedToSociety = false
    if GetResourceState('Renewed-Banking') == 'started' then
        local success = pcall(function()
            exports['Renewed-Banking']:addAccountMoney(bill.restaurantJob, bill.amount)
        end)
        creditedToSociety = success
    end

    -- Se não conseguiu enviar para a society, credita na conta do atendente ou boss
    if not creditedToSociety and Biller then
        Biller.Functions.AddMoney('bank', bill.amount, "restaurant-sale")
    end

    -- Notificações
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Pagamento Realizado',
        description = ('Você pagou $%s via %s para o %s.'):format(bill.amount, paidMethod, bill.restLabel),
        type = 'success'
    })

    if Biller then
        TriggerClientEvent('ox_lib:notify', bill.billerSrc, {
            title = 'Conta Paga!',
            description = ('%s pagou $%s (%s). Faturamento enviado ao restaurante!'):format(Target.PlayerData.charinfo.firstname, bill.amount, paidMethod),
            type = 'success'
        })
    end

    PendingBills[billId] = nil
end)

-- ── Recusa da Cobrança ──────────────────────────────────────────
RegisterNetEvent('granolla_restaurants:server:RejectBill', function(billId)
    local src = source
    local bill = PendingBills[billId]
    if not bill or bill.targetSrc ~= src then return end

    local Biller = QBCore.Functions.GetPlayer(bill.billerSrc)
    if Biller then
        TriggerClientEvent('ox_lib:notify', bill.billerSrc, {
            title = 'Conta Recusada',
            description = 'O cliente recusou o pagamento da conta.',
            type = 'warning'
        })
    end

    PendingBills[billId] = nil
end)

-- ── Sistema de Entregas (Delivery via GPS com Sessão Server-Side) ─
RegisterNetEvent('granolla_restaurants:server:StartDelivery', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    ActiveDeliveries[src] = {
        startTime = os.time(),
        active = true
    }
end)

RegisterNetEvent('granolla_restaurants:server:CancelDelivery', function()
    local src = source
    ActiveDeliveries[src] = nil
end)

RegisterNetEvent('granolla_restaurants:server:DeliveryPayout', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local delivery = ActiveDeliveries[src]
    if not delivery or not delivery.active then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Nenhuma rota de entrega ativa registrada.', type = 'error' })
        return
    end

    local elapsed = os.time() - delivery.startTime
    -- Validação de tempo mínimo (pelo menos 20 segundos de viagem de moto/carro)
    if elapsed < 20 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aviso', description = 'Entrega concluída rápido demais.', type = 'warning' })
        return
    end

    ActiveDeliveries[src] = nil

    local payout = math.random(150, 300)
    Player.Functions.AddMoney('cash', payout, "delivery-payout")
end)

-- ── Pagamento de NPC no Balcão (Com Cooldown Anti-Exploit) ───────
RegisterNetEvent('granolla_restaurants:server:NPCPayout', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    local lastPayout = LastNpcPayout[src] or 0
    if (now - lastPayout) < 25 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aguarde', description = 'Aguarde o próximo cliente chegar ao balcão.', type = 'warning' })
        return
    end

    LastNpcPayout[src] = now

    local payout = math.random(80, 150)
    Player.Functions.AddMoney('cash', payout, "npc-sale")
end)

-- Limpeza ao desconectar
AddEventHandler('playerDropped', function()
    local src = source
    ActiveDeliveries[src] = nil
    LastNpcPayout[src] = nil
end)
