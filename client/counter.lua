-- client/counter.lua
-- ================================================================
-- BALCÃO DE ATENDIMENTO: BANDEJAS DE SERVIR (TRAYS) & CAIXA REGISTRADORA (POS)
-- Interação fluida via ox_target e diálogos nativos ox_lib.
-- Bandejas físicas abrem stashes compartilhadas do ox_inventory.
-- Caixa registradora permite cobrança com repasse direto para a sociedade.
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local SpawnedCounterProps = {}

-- ── Encontrar jogador mais próximo para pré-selecionar no POS ────
local function GetClosestPlayerServerId()
    local coords = GetEntityCoords(cache.ped or PlayerPedId())
    local closestPlayer, closestDistance = QBCore.Functions.GetClosestPlayer(coords)
    if closestPlayer ~= -1 and closestDistance and closestDistance < 3.5 then
        return GetPlayerServerId(closestPlayer)
    end
    return nil
end

-- ── Inicializar Zonas de Interação nos Balcões ────────────────────
CreateThread(function()
    Wait(1500)
    for restId, restConfig in pairs(Config.Restaurants) do
        -- Registrar Bandejas de Balcão (Trays)
        if restConfig.trays then
            for _, tray in ipairs(restConfig.trays) do
                -- Spawna o prop visual da bandeja sobre o balcão
                local trayHash = GetHashKey("prop_tray_01")
                RequestModel(trayHash)
                local t = 0
                while not HasModelLoaded(trayHash) and t < 50 do Wait(10); t = t + 1 end

                local trayObj = CreateObject(trayHash, tray.coords.x, tray.coords.y, tray.coords.z - 0.05, false, false, false)
                if DoesEntityExist(trayObj) then
                    SetEntityCollision(trayObj, false, false)
                    FreezeEntityPosition(trayObj, true)
                    table.insert(SpawnedCounterProps, trayObj)
                end

                exports.ox_target:addSphereZone({
                    coords = tray.coords,
                    radius = tray.radius or 0.8,
                    debug = false,
                    options = {
                        {
                            name = 'rest_tray_' .. tray.id,
                            icon = 'fas fa-utensils',
                            label = '🍱 ' .. (tray.label or 'Bandeja de Pedidos'),
                            distance = 1.8,
                            onSelect = function()
                                exports.ox_inventory:openInventory('stash', tray.id)
                            end
                        }
                    }
                })
            end
        end

        -- Registrar Caixas Registradoras (Registers / POS)
        if restConfig.registers then
            for _, reg in ipairs(restConfig.registers) do
                exports.ox_target:addSphereZone({
                    coords = reg.coords,
                    radius = reg.radius or 0.8,
                    debug = false,
                    options = {
                        {
                            name = 'rest_reg_' .. reg.id,
                            icon = 'fas fa-cash-register',
                            label = '💵 Cobrar Cliente no Balcão',
                            distance = 1.8,
                            groups = restConfig.jobRequired,
                            onSelect = function()
                                local closestId = GetClosestPlayerServerId()
                                local input = lib.inputDialog('💵 Caixa Registradora — ' .. restConfig.label, {
                                    {
                                        type = 'number',
                                        label = 'ID do Cliente',
                                        description = 'ID do jogador no balcão',
                                        default = closestId,
                                        required = true,
                                        min = 1
                                    },
                                    {
                                        type = 'number',
                                        label = 'Valor da Cobrança ($)',
                                        description = 'Valor total do pedido',
                                        required = true,
                                        min = 1
                                    },
                                    {
                                        type = 'input',
                                        label = 'Descrição do Pedido',
                                        description = 'Ex: Combo X-Bacon + Fritas',
                                        placeholder = 'Combo Especial',
                                        required = false
                                    }
                                })

                                if not input then return end

                                local targetId = tonumber(input[1])
                                local amount   = tonumber(input[2])
                                local note     = input[3] or 'Refeição'

                                if not targetId or not amount or amount <= 0 then
                                    lib.notify({ title = 'Caixa', description = 'Valores inválidos informados.', type = 'error' })
                                    return
                                end

                                TriggerServerEvent('granolla_restaurants:server:SendBill', targetId, amount, note, restId)
                            end
                        }
                    }
                })
            end
        end
    end
end)

-- ── Recebimento da Cobrança pelo Cliente ─────────────────────────
RegisterNetEvent('granolla_restaurants:client:ReceiveBill', function(billId, restaurantLabel, serverBillerName, amount, note)
    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)

    local alert = lib.alertDialog({
        header = '🧾 Conta: ' .. restaurantLabel,
        content = ('O atendente **%s** enviou a conta do seu pedido:\n\n**Pedido:** %s\n**Total:** $%s\n\nDeseja realizar o pagamento agora?'):format(serverBillerName, note, amount),
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Pagar com Banco / Dinheiro',
            cancel = 'Recusar'
        }
    })

    if alert == 'confirm' then
        TriggerServerEvent('granolla_restaurants:server:PayBill', billId)
    else
        TriggerServerEvent('granolla_restaurants:server:RejectBill', billId)
        lib.notify({ title = 'Conta Recusada', description = 'Você cancelou o pagamento da conta.', type = 'warning' })
    end
end)

-- ── Limpeza de Props ao Reiniciar o Resource ────────────────────
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, prop in ipairs(SpawnedCounterProps) do
        if DoesEntityExist(prop) then DeleteEntity(prop) end
    end
end)
