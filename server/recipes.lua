-- server/recipes.lua
-- ================================================================
-- GRANÔLLA RESTAURANTS: GERENCIAMENTO DE RECEITAS & CARDÁPIO
-- Proteção contra edição não autorizada e validação estrita de dados.
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local CachedRecipes = {}

local ValidWorkstations = {
    ['chapa']       = true,
    ['fritadeira']  = true,
    ['fogao']       = true,
    ['bebidas']     = true,
    ['tabua']       = true,
    ['montagem']    = true
}

local function LoadCacheFromDB()
    CachedRecipes = {}
    -- 1. Carrega as receitas padrões configuradas
    if Config.DefaultRecipes then
        for _, def in ipairs(Config.DefaultRecipes) do
            table.insert(CachedRecipes, def)
        end
    end
    
    -- 2. Carrega as receitas customizadas salvas no banco
    MySQL.query('SELECT * FROM granolla_recipes', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                local ingDecoded = {}
                pcall(function()
                    ingDecoded = json.decode(row.ingredients)
                end)

                table.insert(CachedRecipes, {
                    id          = row.id,
                    name        = row.recipe_name,
                    result      = row.result_item,
                    workstation = row.workstation,
                    ingredients = ingDecoded or {},
                    job         = row.job,
                    is_public   = (row.is_public == true or row.is_public == 1)
                })
            end
            print('^2[Granolla Restaurants]^0 Carregadas ' .. #results .. ' receitas customizadas do banco de dados.')
        end
        Wait(500)
        TriggerClientEvent('granolla_restaurants:client:SyncRecipes', -1, CachedRecipes)
    end)
end

-- Export para outros scripts do servidor consultarem o cache
exports('GetRecipes', function()
    return CachedRecipes
end)

-- Carrega o cardápio ao iniciar o resource
CreateThread(function()
    LoadCacheFromDB()
end)

-- Sincronizar receitas quando o jogador entra no servidor
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    TriggerClientEvent('granolla_restaurants:client:SyncRecipes', src, CachedRecipes)
end)

-- Helper: Checa se o jogador tem permissão de gerência (Boss ou Admin)
local function HasManagementPermission(src, Player, targetJob)
    if QBCore.Functions.HasPermission(src, 'admin') then
        return true
    end
    local job = Player.PlayerData.job
    if not job then return false end
    if targetJob and job.name ~= targetJob then return false end

    local isBoss = job.isboss == true
    local gradeLevel = job.grade and tonumber(job.grade.level) or 0
    return (isBoss or gradeLevel >= 3)
end

-- Salvar ou Editar Receita no Cardápio
RegisterNetEvent('granolla_restaurants:server:SaveRecipe', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    
    if type(data) ~= 'table' then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Dados de receita inválidos.', type = 'error'})
        return
    end

    local jobOwner = Player.PlayerData.job.name

    -- 1. Verificação de Cargo / Permissão
    if not HasManagementPermission(src, Player, jobOwner) then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Permissão Negada', description = 'Apenas gerentes ou chefes podem criar/editar receitas.', type = 'error'})
        return
    end

    -- 2. Validação dos Campos de Entrada
    local recipeName = tostring(data.recipeName or ''):gsub('^%s*(.-)%s*$', '%1')
    if string.len(recipeName) < 3 or string.len(recipeName) > 50 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'O nome da receita deve ter entre 3 e 50 caracteres.', type = 'error'})
        return
    end

    local resultItem = tostring(data.resultItem or ''):gsub('^%s*(.-)%s*$', '%1')
    if string.len(resultItem) < 2 or string.len(resultItem) > 50 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Item de resultado inválido.', type = 'error'})
        return
    end

    local workstation = tostring(data.workstation or 'chapa')
    if not ValidWorkstations[workstation] then
        workstation = 'chapa'
    end

    if type(data.ingredients) ~= 'table' or #data.ingredients == 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'A receita deve conter ao menos 1 ingrediente.', type = 'error'})
        return
    end

    -- 3. Sanitização da Tabela de Ingredientes
    local cleanIngredients = {}
    for _, ing in ipairs(data.ingredients) do
        if type(ing) == 'table' and ing.item then
            local cleanItem = tostring(ing.item):gsub('^%s*(.-)%s*$', '%1')
            local cleanAmount = math.max(1, math.min(20, tonumber(ing.amount) or 1))
            table.insert(cleanIngredients, {
                item   = cleanItem,
                amount = cleanAmount
            })
        end
    end

    if #cleanIngredients == 0 then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Erro', description = 'Lista de ingredientes inválida.', type = 'error'})
        return
    end

    local isPublicVal = (data.isPublic == true or data.isPublic == 1)
    local ingData = json.encode(cleanIngredients)

    if data.id and type(data.id) == "number" then
        -- Editar receita existente pertencente ao mesmo job
        MySQL.query('UPDATE granolla_recipes SET recipe_name = ?, result_item = ?, workstation = ?, ingredients = ?, is_public = ? WHERE id = ? AND job = ?', {
            recipeName, resultItem, workstation, ingData, isPublicVal, data.id, jobOwner
        }, function()
            LoadCacheFromDB()
            TriggerClientEvent('ox_lib:notify', src, {title = 'Sucesso', description = 'Receita ' .. recipeName .. ' atualizada!', type = 'success'})
        end)
    else
        -- Criar nova receita
        MySQL.insert('INSERT INTO granolla_recipes (recipe_name, result_item, workstation, ingredients, job, is_public) VALUES (?, ?, ?, ?, ?, ?)', {
            recipeName, resultItem, workstation, ingData, jobOwner, isPublicVal
        }, function(id)
            if id then
                LoadCacheFromDB()
                TriggerClientEvent('ox_lib:notify', src, {title = 'Sucesso', description = 'Receita ' .. recipeName .. ' adicionada ao cardápio!', type = 'success'})
            end
        end)
    end
end)

-- Deletar Receita do Cardápio
RegisterNetEvent('granolla_restaurants:server:DeleteRecipe', function(recipeId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(recipeId) == "string" then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Aviso', description = 'Não é possível deletar receitas padrões do sistema.', type = 'error'})
        return
    end

    local jobOwner = Player.PlayerData.job.name
    if not HasManagementPermission(src, Player, jobOwner) then
        TriggerClientEvent('ox_lib:notify', src, {title = 'Permissão Negada', description = 'Apenas gerentes ou chefes podem remover receitas do cardápio.', type = 'error'})
        return
    end

    local query = 'DELETE FROM granolla_recipes WHERE id = ? AND job = ?'
    local params = { recipeId, jobOwner }

    if QBCore.Functions.HasPermission(src, 'admin') then
        query = 'DELETE FROM granolla_recipes WHERE id = ?'
        params = { recipeId }
    end

    MySQL.query(query, params, function()
        LoadCacheFromDB()
        TriggerClientEvent('ox_lib:notify', src, {title = 'Removido', description = 'Receita removida do cardápio.', type = 'info'})
    end)
end)
