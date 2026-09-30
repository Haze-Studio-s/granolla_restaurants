-- server/admin.lua
-- ================================================================
-- GRANÔLLA RESTAURANTS - COMANDOS ADMINISTRATIVOS & KITS DE TESTE
-- ================================================================

local CulinaryKits = {
    ['brutos'] = {
        name = "Insumos Brutos de Culinária",
        items = {
            { item = 'kitchen_knife', count = 1 },
            { item = 'raw_potato',    count = 15 },
            { item = 'raw_tomato',    count = 15 },
            { item = 'raw_cheese',    count = 15 },
            { item = 'raw_onion',     count = 15 },
            { item = 'raw_meat',      count = 15 },
            { item = 'raw_sausage',   count = 15 },
            { item = 'raw_fish',      count = 10 },
            { item = 'cooking_oil',   count = 5 },
            { item = 'empty_cup',     count = 15 },
            { item = 'bread',         count = 15 },
            { item = 'bacon',         count = 15 },
            { item = 'lettuce',       count = 15 },
        }
    },
    ['processados'] = {
        name = "Insumos Intermediários & Processados",
        items = {
            { item = 'raw_fries',     count = 15 },
            { item = 'tomato',        count = 15 },
            { item = 'cheese',        count = 15 },
            { item = 'sliced_onion',  count = 15 },
        }
    },
    ['prontos'] = {
        name = "Produtos Prontos / Consumíveis Finais",
        items = {
            { item = 'burger_bacon',     count = 5 },
            { item = 'hotdog',           count = 5 },
            { item = 'fishburger',       count = 5 },
            { item = 'frenchfries',      count = 5 },
            { item = 'chicken_nuggets',  count = 5 },
            { item = 'burger_softdrink', count = 5 },
            { item = 'juice_orange',     count = 5 },
            { item = 'kurkakola',        count = 5 },
            { item = 'water_bottle',     count = 5 },
        }
    },
    ['props'] = {
        name = "Estruturas Móveis (Props Colocáveis)",
        items = {
            { item = 'granolla_grill',        count = 1 },
            { item = 'granolla_fryer',        count = 1 },
            { item = 'granolla_foodcart',     count = 1 },
            { item = 'granolla_table',        count = 2 },
            { item = 'granolla_chair',        count = 4 },
            { item = 'granolla_gazebo',       count = 1 },
            { item = 'granolla_soda_machine', count = 1 },
        }
    }
}

-- Aliases para categorias
local CategoryAliases = {
    ['bruto']       = 'brutos',
    ['brutos']      = 'brutos',
    ['raw']         = 'brutos',
    ['basico']      = 'brutos',
    ['basicos']     = 'brutos',
    ['processado']  = 'processados',
    ['processados'] = 'processados',
    ['proc']        = 'processados',
    ['pronto']      = 'prontos',
    ['prontos']     = 'prontos',
    ['lanche']      = 'prontos',
    ['lanches']     = 'prontos',
    ['comida']      = 'prontos',
    ['bebidas']     = 'prontos',
    ['prop']        = 'props',
    ['props']       = 'props',
    ['moveis']      = 'props',
    ['estruturas']  = 'props',
    ['all']         = 'all',
    ['tudo']        = 'all',
    ['full']        = 'all'
}

--- Entrega os itens ao jogador indicado
--- @param targetSrc number ID do jogador
--- @param kitKey string Nome da categoria ('brutos', 'processados', 'prontos', 'props', 'all')
--- @return boolean success
--- @return number addedCount
--- @return table failedItems
--- @return string kitName
local function GiveKitToPlayer(targetSrc, kitKey)
    local itemsToGive = {}
    local kitTitle = "Todos os Itens (Full)"

    if kitKey == 'all' then
        kitTitle = "Kit Completo de Gastronomia (33 Itens)"
        -- Ordem: brutos -> processados -> prontos -> props
        local order = {'brutos', 'processados', 'prontos', 'props'}
        for _, cat in ipairs(order) do
            if CulinaryKits[cat] then
                for _, itemData in ipairs(CulinaryKits[cat].items) do
                    table.insert(itemsToGive, itemData)
                end
            end
        end
    elseif CulinaryKits[kitKey] then
        kitTitle = CulinaryKits[kitKey].name
        itemsToGive = CulinaryKits[kitKey].items
    else
        return false, 0, {}, "Categoria desconhecida"
    end

    local addedCount = 0
    local failedItems = {}

    for _, entry in ipairs(itemsToGive) do
        local success, response = exports.ox_inventory:AddItem(targetSrc, entry.item, entry.count)
        if success then
            addedCount = addedCount + 1
        else
            table.insert(failedItems, string.format("%s (x%d)", entry.item, entry.count))
        end
    end

    return true, addedCount, failedItems, kitTitle
end

--- Handler principal dos comandos de kit de culinária
local function HandleKitCommand(source, args)
    local src = source
    local targetId = nil
    local category = 'brutos'

    -- Interpretação flexível dos argumentos:
    -- Ex: /kitculinaria
    -- Ex: /kitculinaria all
    -- Ex: /kitculinaria 1
    -- Ex: /kitculinaria 1 all
    -- Ex: /kitculinaria all 1
    if #args == 0 then
        if src == 0 then
            print('^1[Granolla Restaurants]^0 No console informe o ID: kitculinaria [id] [categoria]')
            return
        end
        targetId = src
        category = 'brutos'
    elseif #args == 1 then
        local num = tonumber(args[1])
        if num then
            targetId = num
            category = 'brutos'
        else
            targetId = src ~= 0 and src or nil
            local alias = CategoryAliases[string.lower(args[1])]
            category = alias or args[1]
        end
    else
        -- 2 ou mais argumentos
        local num1 = tonumber(args[1])
        local num2 = tonumber(args[2])
        if num1 then
            targetId = num1
            local alias = CategoryAliases[string.lower(args[2])]
            category = alias or args[2]
        elseif num2 then
            targetId = num2
            local alias = CategoryAliases[string.lower(args[1])]
            category = alias or args[1]
        else
            targetId = src ~= 0 and src or nil
            local alias = CategoryAliases[string.lower(args[1])]
            category = alias or args[1]
        end
    end

    if not targetId or targetId == 0 then
        if src == 0 then
            print('^1[Granolla Restaurants]^0 Jogador de destino inválido.')
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Comando Kit Culinária',
                description = 'Uso: /kitculinaria [categoria] ou /kitculinaria [id] [categoria]\nCategorias: brutos, processados, prontos, props, all',
                type = 'error'
            })
        end
        return
    end

    -- Validar se o jogador alvo está online
    local targetPed = GetPlayerPed(targetId)
    if not targetPed or targetPed == 0 then
        local msg = string.format('Jogador com ID %s não encontrado ou offline.', tostring(targetId))
        if src == 0 then
            print('^1[Granolla Restaurants]^0 ' .. msg)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = msg, type = 'error' })
        end
        return
    end

    category = CategoryAliases[string.lower(category or '')] or category

    if category ~= 'all' and not CulinaryKits[category] then
        local errMsg = 'Categoria inválida! Use: brutos, processados, prontos, props ou all'
        if src == 0 then
            print('^1[Granolla Restaurants]^0 ' .. errMsg)
        else
            TriggerClientEvent('ox_lib:notify', src, { title = 'Categoria Inválida', description = errMsg, type = 'error' })
        end
        return
    end

    local success, added, failed, kitName = GiveKitToPlayer(targetId, category)
    if not success then
        local errMsg = 'Falha ao processar entrega do kit.'
        if src == 0 then print(errMsg) else TriggerClientEvent('ox_lib:notify', src, { title = 'Erro', description = errMsg, type = 'error' }) end
        return
    end

    local resultDesc = string.format('%d tipo(s) de itens entregues no inventário (%s).', added, kitName)
    if #failed > 0 then
        resultDesc = resultDesc .. string.format(' [!] Falha por peso/espaço em %d itens: %s', #failed, table.concat(failed, ', '))
    end

    -- Feedback ao alvo
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Kit Gastronômico Recebido! 🍽️',
        description = resultDesc,
        type = #failed == 0 and 'success' or 'warning',
        duration = 8000
    })

    -- Feedback ao executor se for diferente do alvo
    if src ~= targetId and src ~= 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Kit Enviado!',
            description = string.format('Kit %s entregue ao ID %d (%d itens ok).', kitName, targetId, added),
            type = 'success',
            duration = 6000
        })
    end

    print(string.format('^2[Granolla Restaurants]^0 Admin (src %s) entregou o kit "%s" para o jogador ID %s. Sucesso: %d itens.', tostring(src), kitName, tostring(targetId), added))
end

-- Registro de comandos e aliases
RegisterCommand('kitculinaria', HandleKitCommand, false)
RegisterCommand('givekitchenkit', HandleKitCommand, false)
RegisterCommand('kitcozinha', HandleKitCommand, false)
RegisterCommand('giveculinarykit', HandleKitCommand, false)

print('^2[Granolla Restaurants]^0 Módulo administrativo de kits carregado (/kitculinaria, /givekitchenkit).')
