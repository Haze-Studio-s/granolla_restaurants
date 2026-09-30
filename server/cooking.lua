-- server/cooking.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Tabela Global de Estado das Estações (Grelhas e Fritadeiras)
local StationStates = {} 
-- Estrutura:
-- StationStates[stationId] = {
--     type = "grill" | "fryer",
--     hasOil = bool,
--     oilUses = number,
--     slots = {
--         [slotId] = {
--             ingredientKey = "raw_meat",
--             startTime = os.time(),
--             cookTime = 10,
--             burnTime = 20,
--             state = 'raw', -- 'raw', 'cooked', 'burnt'
--             owner = src
--         }
--     }
-- }

local function GetOrCreateStation(stationId, stationType)
    if not StationStates[stationId] then
        StationStates[stationId] = {
            type = stationType or "grill",
            hasOil = false,
            oilUses = 0,
            slots = {}
        }
    end
    return StationStates[stationId]
end

-- Callback para verificar se o jogador tem TODOS os ingredientes
lib.callback.register('granolla_restaurants:server:HasIngredients', function(source, ingredientsArray)
    local src = source
    if not ingredientsArray or type(ingredientsArray) ~= 'table' then return false end

    for _, ing in ipairs(ingredientsArray) do
        local count = exports.ox_inventory:GetItemCount(src, ing.item)
        if not count or count < (ing.amount or 1) then
            return false
        end
    end
    return true
end)

-- Callback para verificar estado de óleo de uma fritadeira
lib.callback.register('granolla_restaurants:server:GetStationState', function(source, stationId)
    return StationStates[stationId] or { hasOil = false, oilUses = 0, slots = {} }
end)

-- Evento para Abastecer Fritadeira com Óleo
RegisterNetEvent('granolla_restaurants:server:AddOil', function(stationId)
    local src = source
    local oilItem = Config.OilItem or 'cooking_oil'
    local count = exports.ox_inventory:GetItemCount(src, oilItem)
    if not count or count < 1 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Você precisa de Óleo de Cozinha no inventário!', type = 'error'})
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, oilItem, 1)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Falha ao utilizar o galão de óleo.', type = 'error'})
        return
    end

    local station = GetOrCreateStation(stationId, "fryer")
    station.hasOil = true
    station.oilUses = Config.OilMaxUses or 10

    TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
    TriggerClientEvent('ox_lib:notify', src, {title = 'Sucesso', description = 'Fritadeira abastecida com óleo novo!', type = 'success'})
end)

-- Iniciar Cozimento em Tempo Real de um Slot
RegisterNetEvent('granolla_restaurants:server:StartRealtimeCook', function(stationId, stationType, slotId, ingredientKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local meatMeta = Config.MeatModels[ingredientKey] or Config.FriedModels[ingredientKey]
    if not meatMeta then return end

    local station = GetOrCreateStation(stationId, stationType)

    -- Se for fritadeira, exige óleo ativo
    if stationType == 'fryer' and not station.hasOil then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'A fritadeira precisa de óleo!', type = 'error'})
        return
    end

    slotId = tonumber(slotId) or 1
    -- Verifica se já há item no slot
    if station.slots[slotId] then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Este espaço da grelha/fritadeira já está ocupado!', type = 'error'})
        return
    end

    -- Remove o item bruto do inventário do jogador com ox_inventory
    local count = exports.ox_inventory:GetItemCount(src, ingredientKey)
    if not count or count < 1 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Você não possui ' .. (meatMeta.label or ingredientKey), type = 'error'})
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, ingredientKey, 1)
    if not removed then return end

    -- Registra o slot ativo no servidor
    local now = os.time()
    station.slots[slotId] = {
        ingredientKey = ingredientKey,
        startTime = now,
        cookTime = meatMeta.cookTime or 10,
        burnTime = meatMeta.burnTime or 20,
        state = 'raw',
        owner = Player.PlayerData.citizenid
    }

    TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
    TriggerClientEvent('ox_lib:notify', src, {title = 'Cozinhando', description = (meatMeta.label or ingredientKey) .. ' colocado na estação!', type = 'info'})
end)

-- Recolher Alimento do Slot (No Ponto ou Queimado)
RegisterNetEvent('granolla_restaurants:server:PickupSlot', function(stationId, slotId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local station = StationStates[stationId]
    if not station or not station.slots[slotId] then return end
    
    local slotData = station.slots[slotId]
    local meatMeta = Config.MeatModels[slotData.ingredientKey] or Config.FriedModels[slotData.ingredientKey]
    
    if slotData.state == 'cooked' then
        -- Sucesso: Entrega o item no ponto
        local reward = meatMeta.rewardItem or "burger_bacon"
        exports.ox_inventory:AddItem(src, reward, 1)
        TriggerClientEvent('ox_lib:notify', src, {title = 'No Ponto!', description = 'Você recolheu ' .. (meatMeta.cookedLabel or reward), type = 'success'})
        
        -- Se for fritadeira, consome 1 uso de óleo
        if station.type == 'fryer' then
            station.oilUses = station.oilUses - 1
            if station.oilUses <= 0 then
                station.hasOil = false
                TriggerClientEvent('ox_lib:notify', src, {title = 'Óleo Esgotado', description = 'O óleo da fritadeira queimou e precisa ser trocado!', type = 'warning'})
            end
        end
    elseif slotData.state == 'burnt' then
        -- Queimado: Apenas limpa o slot e avisa o jogador
        TriggerClientEvent('ox_lib:notify', src, {title = 'Queimou!', description = 'Alimento queimado foi descartado.', type = 'error'})
    else
        -- Ainda cru
        TriggerClientEvent('ox_lib:notify', src, {title = 'Aguarde', description = 'O alimento ainda está cru!', type = 'warning'})
        return
    end
    
    -- Esvazia o slot
    station.slots[slotId] = nil
    TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
end)

-- Virar o Alimento na Grelha (Virar o Lado 1 para o Lado 2)
RegisterNetEvent('granolla_restaurants:server:FlipSlot', function(stationId, slotId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    local station = StationStates[stationId]
    if not station or not station.slots[slotId] then return end
    
    local slotData = station.slots[slotId]
    if slotData.state == 'needs_flip' then
        slotData.state = 'side2'
        slotData.startTime = os.time()
        TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
        TriggerClientEvent('ox_lib:notify', src, {title = 'Virei a Carne', description = 'Carne virada! Cozinhando o outro lado...', type = 'success'})
    else
        TriggerClientEvent('ox_lib:notify', src, {title = 'Aviso', description = 'Esta carne não precisa ser virada agora!', type = 'warning'})
    end
end)

-- Loop em Tempo Real do Servidor para atualização dos tempos de cozimento
CreateThread(function()
    while true do
        Wait(1000)
        local now = os.time()
        
        for stationId, station in pairs(StationStates) do
            local updated = false
            for slotId, slot in pairs(station.slots) do
                local elapsed = now - slot.startTime
                local meatMeta = Config.MeatModels[slot.ingredientKey] or Config.FriedModels[slot.ingredientKey]
                
                if meatMeta and meatMeta.requiresFlip then
                    local sideTime = math.max(3, math.floor((meatMeta.cookTime or 10) / 2))
                    local burnSideTime = math.max(6, math.floor((meatMeta.burnTime or 20) / 2))
                    
                    if slot.state == 'raw' and elapsed >= sideTime then
                        slot.state = 'needs_flip'
                        slot.startTime = now
                        updated = true
                    elseif slot.state == 'needs_flip' and elapsed >= burnSideTime then
                        slot.state = 'burnt'
                        updated = true
                    elseif slot.state == 'side2' and elapsed >= sideTime then
                        slot.state = 'cooked'
                        slot.startTime = now
                        updated = true
                    elseif slot.state == 'cooked' and elapsed >= burnSideTime then
                        slot.state = 'burnt'
                        updated = true
                    end
                else
                    local cookTime = (meatMeta and meatMeta.cookTime) or 10
                    local burnTime = (meatMeta and meatMeta.burnTime) or 20
                    
                    if slot.state == 'raw' and elapsed >= cookTime then
                        slot.state = 'cooked'
                        slot.startTime = now
                        updated = true
                    elseif slot.state == 'cooked' and elapsed >= burnTime then
                        slot.state = 'burnt'
                        updated = true
                    end
                end
            end
            
            if updated then
                TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
            end
        end
    end
end)

-- Sincronizar com jogador recém conectado
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    for stationId, station in pairs(StationStates) do
        TriggerClientEvent('granolla_restaurants:client:SyncStationState', src, stationId, station)
    end
end)

-- ================================================================
-- FINALIZAÇÃO DE PREPARO (MANUAL / CARDÁPIO) - ATÔMICO & ANTI-EXPLOIT
-- ================================================================
local LastFinishCook = {}

RegisterNetEvent('granolla_restaurants:server:FinishCooking', function(recipeId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local now = os.time()
    if LastFinishCook[src] and (now - LastFinishCook[src] < 2) then
        return
    end
    LastFinishCook[src] = now

    local function ProcessRecipeFulfillment(recipe)
        if not recipe or not recipe.ingredients or #recipe.ingredients == 0 then
            TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Receita inválida.', type = 'error'})
            return
        end

        -- 1. Verifica se o jogador possui TODOS os ingredientes
        for _, ing in ipairs(recipe.ingredients) do
            local requiredAmount = ing.amount or 1
            local count = exports.ox_inventory:GetItemCount(src, ing.item)
            if not count or count < requiredAmount then
                TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Você não possui todos os ingredientes necessários.', type = 'error'})
                return
            end
        end

        -- 2. Consome os ingredientes atomicamente
        for _, ing in ipairs(recipe.ingredients) do
            local removed = exports.ox_inventory:RemoveItem(src, ing.item, ing.amount or 1)
            if not removed then
                TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Falha ao processar os ingredientes.', type = 'error'})
                return
            end
        end

        -- 3. Entrega o produto final
        local resultItem = recipe.result or recipe.result_item or "burger_bacon"
        local success = exports.ox_inventory:AddItem(src, resultItem, 1, {
            description = 'Prato artesanal preparado no restaurante.',
            cookedAt = os.date('%H:%M')
        })

        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Cozinha',
                description = (recipe.name or 'Prato') .. ' preparado com sucesso!',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Inventário Cheio',
                description = 'Seu inventário está cheio para receber o prato.',
                type = 'error'
            })
        end
    end

    -- Busca nas receitas padrão configuradas
    local found = false
    if Config.DefaultRecipes then
        for _, def in ipairs(Config.DefaultRecipes) do
            if def.id == recipeId then
                found = true
                ProcessRecipeFulfillment(def)
                break
            end
        end
    end

    -- Se não encontrou nas padrões, busca no banco de dados
    if not found then
        MySQL.query('SELECT * FROM granolla_recipes WHERE id = ?', {recipeId}, function(result)
            if result and result[1] then
                local rec = result[1]
                local decoded = {}
                pcall(function() decoded = json.decode(rec.ingredients) end)
                rec.ingredients = decoded
                ProcessRecipeFulfillment(rec)
            else
                TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Receita não encontrada.', type = 'error'})
            end
        end)
    end
end)

-- ============================================================
-- Novo sistema Drag-and-Drop: PlaceIngredient como alias de StartRealtimeCook
-- ============================================================
RegisterNetEvent('granolla_restaurants:server:PlaceIngredient', function(stationId, slotId, ingredientKey)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local meatMeta = Config.MeatModels[ingredientKey] or Config.FriedModels[ingredientKey]
    if not meatMeta then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Ingrediente inválido!', type = 'error'})
        return
    end

    local station = GetOrCreateStation(stationId, 'grill')
    slotId = tonumber(slotId) or 1

    if station.slots[slotId] then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Slot já ocupado!', type = 'error'})
        return
    end

    local count = exports.ox_inventory:GetItemCount(src, ingredientKey)
    if not count or count < 1 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Você não possui ' .. (meatMeta.label or ingredientKey), type = 'error'})
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, ingredientKey, 1)
    if not removed then return end

    station.slots[slotId] = {
        ingredientKey = ingredientKey,
        startTime = os.time(),
        cookTime = meatMeta.cookTime or 10,
        burnTime = meatMeta.burnTime or 20,
        state = 'raw',
        owner = Player.PlayerData.citizenid
    }

    TriggerClientEvent('granolla_restaurants:client:SyncStationState', -1, stationId, station)
    TriggerClientEvent('ox_lib:notify', src, {title = 'Cozinhando', description = (meatMeta.label or ingredientKey) .. ' colocado na grelha!', type = 'info'})
end)

-- ServeDish: finaliza o modo cozinha sem recolher itens individualmente (acao de UI)
RegisterNetEvent('granolla_restaurants:server:ServeDish', function(stationId)
    local src = source
    TriggerClientEvent('ox_lib:notify', src, {title = 'Prato Servido', description = 'Prato finalizado!', type = 'success'})
end)

-- Whitelist de produtos finais de montagem (Anti-Exploit)
local ValidBurgers = {
    ['burger_bacon'] = true,
    ['hotdog'] = true,
    ['fishburger'] = true,
    ['custom_meal_1'] = true,
    ['custom_meal_2'] = true
}

-- Sessões ativas de montagem de hambúrguer
local ActiveAssemblySessions = {}

lib.callback.register('granolla_restaurants:server:StartAssemblySession', function(source)
    local src = source
    local token = "asm_" .. src .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    ActiveAssemblySessions[token] = {
        source    = src,
        startTime = os.time()
    }
    return token
end)

-- Conclusão da Montagem Física 3D do Hambúrguer na Bancada
RegisterNetEvent('granolla_restaurants:server:CompleteBurgerAssembly', function(token, resultItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = ActiveAssemblySessions[token]
    if not session or session.source ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Sessão de montagem inválida ou expirada!', type = 'error' })
        return
    end

    local elapsed = os.time() - session.startTime
    if elapsed < 2 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aviso', description = 'Montagem rápida demais!', type = 'warning' })
        ActiveAssemblySessions[token] = nil
        return
    end

    ActiveAssemblySessions[token] = nil

    -- Validação de Whitelist estrita: impede injeção de itens arbitrários
    if not resultItem or not ValidBurgers[resultItem] then
        resultItem = 'burger_bacon'
    end

    -- Consome os ingredientes básicos da montagem do inventário (se o jogador tiver)
    local baseIngredients = { 'bread', 'cheese' }
    for _, ing in ipairs(baseIngredients) do
        local count = exports.ox_inventory:GetItemCount(src, ing)
        if count and count > 0 then
            exports.ox_inventory:RemoveItem(src, ing, 1)
        end
    end

    -- Entrega o hambúrguer embrulhado
    local success, response = exports.ox_inventory:AddItem(src, resultItem, 1, {
        description = 'Hambúrguer artesanal montado e embalado na bancada.',
        assembledAt = os.date('%H:%M'),
        quality = 100
    })

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Bancada de Montagem',
            description = 'Hambúrguer embrulhado adicionado ao inventário!',
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Inventário Cheio',
            description = 'Seu inventário está cheio para receber o hambúrguer!',
            type = 'error'
        })
    end
end)

-- Whitelist de itens fritos válidos (Anti-Exploit)
local ValidFried = {
    ['frenchfries'] = true,
    ['chicken_nuggets'] = true
}

-- Sessões ativas de fritadeira
local ActiveFryerSessions = {}

lib.callback.register('granolla_restaurants:server:StartFryerSession', function(source)
    local src = source
    local token = "fry_" .. src .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    ActiveFryerSessions[token] = {
        source    = src,
        startTime = os.time()
    }
    return token
end)

-- Conclusão da Fritura Física 3D (Cesto e Pá de Batatas)
RegisterNetEvent('granolla_restaurants:server:CompleteFryerCook', function(token, resultItem)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = ActiveFryerSessions[token]
    if not session or session.source ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Sessão de fritadeira inválida ou expirada!', type = 'error' })
        return
    end

    local elapsed = os.time() - session.startTime
    if elapsed < 2 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aviso', description = 'Fritura rápida demais!', type = 'warning' })
        ActiveFryerSessions[token] = nil
        return
    end

    ActiveFryerSessions[token] = nil

    if not resultItem or not ValidFried[resultItem] then
        resultItem = 'frenchfries'
    end

    -- Consome a porção de batatas cortadas cruas
    local rawCount = exports.ox_inventory:GetItemCount(src, 'raw_fries')
    if rawCount and rawCount > 0 then
        exports.ox_inventory:RemoveItem(src, 'raw_fries', 1)
    end

    -- Adiciona a batata frita crocante pronta
    local success = exports.ox_inventory:AddItem(src, resultItem, 1, {
        description = 'Porção dourada e crocante recém-saída da fritadeira.',
        friedAt = os.date('%H:%M'),
        crispy = true
    })

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fritadeira',
            description = 'Porção pronta entregue na caixinha!',
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Inventário Cheio',
            description = 'Seu inventário está cheio para receber a porção frita!',
            type = 'error'
        })
    end
end)

-- ================================================================
-- TÁBUA DE CORTE: VALIDAÇÃO SERVER-SIDE ANTI-EXPLOIT
-- ================================================================
local ActiveCuttingSessions = {}

-- Tabela oficial de conversão de insumos brutos server-side (Anti-Exploit)
local ValidCuttingRecipes = {
    ['raw_potato'] = { output = 'raw_fries', count = 3 },
    ['raw_tomato'] = { output = 'tomato', count = 3 },
    ['raw_cheese'] = { output = 'cheese', count = 3 },
    ['raw_onion']  = { output = 'sliced_onion', count = 3 },
    ['raw_meat']   = { output = 'raw_meat', count = 1 }
}

lib.callback.register('granolla_restaurants:server:StartCuttingSession', function(source, inputItem)
    local src = source
    if not inputItem or not ValidCuttingRecipes[inputItem] then
        return false
    end

    local count = exports.ox_inventory:GetItemCount(src, inputItem)
    if not count or count < 1 then
        return false
    end

    local token = "cut_" .. src .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    ActiveCuttingSessions[token] = {
        source    = src,
        inputItem = inputItem,
        startTime = os.time()
    }

    return token
end)

RegisterNetEvent('granolla_restaurants:server:CompleteCutting', function(token, clientInputItem)
    local src = source
    local session = ActiveCuttingSessions[token]

    if not session or session.source ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Sessão de corte inválida ou expirada!', type = 'error' })
        return
    end

    local inputItem = session.inputItem
    local recipe = ValidCuttingRecipes[inputItem]
    if not recipe then
        ActiveCuttingSessions[token] = nil
        return
    end

    -- Validação de tempo mínimo (pelo menos 2.0 segundos para os 4 cortes rítmicos)
    local elapsed = os.time() - session.startTime
    if elapsed < 2 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aviso', description = 'Corte rápido demais! Ritmo inadequado.', type = 'warning' })
        ActiveCuttingSessions[token] = nil
        return
    end

    -- Invalida o token imediatamente para evitar repetição (replay attack)
    ActiveCuttingSessions[token] = nil

    -- Consome 1 unidade do ingrediente bruto
    local removed = exports.ox_inventory:RemoveItem(src, inputItem, 1)
    if not removed then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Falha ao processar o ingrediente bruto.', type = 'error' })
        return
    end

    -- O item e quantidade são definidos EXCLUSIVAMENTE pelo servidor
    local outputItem = recipe.output
    local outputCount = recipe.count

    local success = exports.ox_inventory:AddItem(src, outputItem, outputCount, {
        description = 'Fatiado artesanalmente na tábua de corte.',
        slicedAt = os.date('%H:%M')
    })

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Tábua de Corte',
            description = 'Processamento concluído: ' .. outputCount .. 'x porções geradas!',
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Inventário Cheio',
            description = 'Não foi possível entregar todas as fatias cortadas.',
            type = 'error'
        })
    end
end)

-- ================================================================
-- MÁQUINA DE BEBIDAS: VALIDAÇÃO SERVER-SIDE ANTI-EXPLOIT
-- ================================================================
local ActiveDrinksSessions = {}

local ValidDrinks = {
    ['burger_softdrink'] = true,
    ['juice_orange'] = true,
    ['kurkakola'] = true,
    ['water_bottle'] = true
}

lib.callback.register('granolla_restaurants:server:StartDrinksSession', function(source)
    local src = source
    local token = "drink_" .. src .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    ActiveDrinksSessions[token] = {
        source    = src,
        startTime = os.time()
    }
    return token
end)

RegisterNetEvent('granolla_restaurants:server:CompleteDrinkDispense', function(token, outItem, label)
    local src = source
    local session = ActiveDrinksSessions[token]

    if not session or session.source ~= src then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = 'Sessão de bebidas inválida!', type = 'error' })
        return
    end

    -- Validação de tempo mínimo (pelo menos 1.0s de enchimento)
    local elapsed = os.time() - session.startTime
    if elapsed < 1 then
        TriggerClientEvent('ox_lib:notify', src, { title = 'Aviso', description = 'Enchimento rápido demais!', type = 'warning' })
        ActiveDrinksSessions[token] = nil
        return
    end

    ActiveDrinksSessions[token] = nil

    -- Validação estrita de bebida permitida (Anti-Exploit)
    if not outItem or not ValidDrinks[outItem] then
        outItem = 'burger_softdrink'
    end

    -- Se o jogador tiver copo descartável, consome 1 unidade
    local cupCount = exports.ox_inventory:GetItemCount(src, 'empty_cup')
    if cupCount and cupCount > 0 then
        exports.ox_inventory:RemoveItem(src, 'empty_cup', 1)
    end

    local success = exports.ox_inventory:AddItem(src, outItem, 1, {
        description = 'Bebida gelada servida na máquina de refrigerante.',
        dispensedAt = os.date('%H:%M'),
        ice = true
    })

    if success then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Dispensador de Bebidas',
            description = (label or 'Refrigerante') .. ' com tampa e canudo adicionado ao inventário!',
            type = 'success'
        })
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Inventário Cheio',
            description = 'Seu inventário está cheio para receber a bebida!',
            type = 'error'
        })
    end
end)



