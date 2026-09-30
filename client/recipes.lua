-- client/recipes.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Comando para gerentes abrirem o tablet
RegisterCommand('tablet_restaurante', function()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData.job or not PlayerData.job.isboss then
        lib.notify({title = 'Acesso Negado', description = 'Apenas gerentes possuem acesso ao sistema.', type = 'error'})
        return
    end
    
    local isRestaurantJob = false
    for _, config in pairs(Config.Restaurants) do
        if config.jobRequired == PlayerData.job.name then
            isRestaurantJob = true
            break
        end
    end
    
    if not isRestaurantJob then
        lib.notify({title = 'Acesso Negado', description = 'Seu emprego não possui painel de restaurante.', type = 'error'})
        return
    end

    -- Preparar lista filtrada de ingredientes
    local ingredientsList = {}
    for _, itemName in ipairs(Config.AllowedIngredients) do
        if QBCore.Shared.Items[itemName] then
            table.insert(ingredientsList, { value = itemName, label = QBCore.Shared.Items[itemName].label })
        end
    end
    
    -- Preparar lista filtrada de resultados
    local resultsList = {}
    for _, itemName in ipairs(Config.AllowedResultItems) do
        if QBCore.Shared.Items[itemName] then
            table.insert(resultsList, { value = itemName, label = QBCore.Shared.Items[itemName].label })
        end
    end
    
    table.sort(ingredientsList, function(a, b) return a.label < b.label end)
    table.sort(resultsList, function(a, b) return a.label < b.label end)

    local myRecipes = {}
    for _, r in ipairs(AvailableRecipes) do
        if r.job == PlayerData.job.name then
            table.insert(myRecipes, r)
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openTablet',
        ingredients = ingredientsList,
        resultItems = resultsList,
        myRecipes = myRecipes
    })
end, false)

-- Callback para fechar a UI
RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- Callback ao salvar a receita na UI
RegisterNUICallback('saveRecipe', function(data, cb)
    TriggerServerEvent('granolla_restaurants:server:SaveRecipe', data)
    cb('ok')
end)

-- Callback para deletar receita
RegisterNUICallback('deleteRecipe', function(data, cb)
    TriggerServerEvent('granolla_restaurants:server:DeleteRecipe', data.id)
    cb('ok')
end)

-- Receber cache atualizado de receitas do servidor
AvailableRecipes = {}
RegisterNetEvent('granolla_restaurants:client:SyncRecipes', function(recipesTable)
    AvailableRecipes = recipesTable
end)

-- Função utilitária para pegar as receitas de uma estação específica
function GetRecipesForWorkstation(workstationType, stationJob)
    local filtered = {}
    for _, recipe in pairs(AvailableRecipes) do
        if recipe.workstation == workstationType then
            -- Receitas sao listadas se forem publicas OU se pertencerem ao job da estação
            if recipe.is_public or recipe.job == stationJob then
                table.insert(filtered, recipe)
            end
        end
    end
    return filtered
end
