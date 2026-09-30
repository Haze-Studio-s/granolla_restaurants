-- client/minigames.lua
local QBCore = exports['qb-core']:GetCoreObject()

-- Helper para minigame rápido (ox_lib skillCheck) em ações manuais
function PlaySkillCheck(difficulty)
    difficulty = difficulty or {'easy', 'medium'}
    return lib.skillCheck(difficulty, {'e', 'space'})
end

-- Sincronização do Estado em Tempo Real das Estações
ClientStationsState = ClientStationsState or {}

RegisterNetEvent('granolla_restaurants:client:SyncStationState', function(stationId, stationData)
    local oldData = ClientStationsState[stationId] or { slots = {} }
    ClientStationsState[stationId] = stationData

    if SyncFoodPropsForStation then
        SyncFoodPropsForStation(stationId, stationData)
    end

    -- Atualiza os slots 3D da grelha (usados pela camera 3D)
    if stationData and stationData.slots then
        -- Marca slots ativos
        local activeSlots = {}
        for slotId, slotInfo in pairs(stationData.slots) do
            activeSlots[tostring(slotId)] = true
            if UpdateGrillSlotFromServer then
                UpdateGrillSlotFromServer(slotId, slotInfo.state)
            end
        end
        -- Limpa slots que sumiram do servidor (recolhidos/queimados)
        if GrillSlotPositions then
            for slotId, _ in pairs(GrillSlotPositions) do
                if not activeSlots[tostring(slotId)] then
                    if UpdateGrillSlotFromServer then
                        UpdateGrillSlotFromServer(slotId, 'empty')
                    end
                end
            end
        end
    end

    -- Notifica a NUI sobre mudancas de estado de slots (para NUI de cozinha aberta)
    if stationData and stationData.slots then
        for slotId, slotInfo in pairs(stationData.slots) do
            local oldSlot = oldData.slots and oldData.slots[slotId]
            if not oldSlot or oldSlot.state ~= slotInfo.state then
                SendNUIMessage({
                    action       = 'updateCookingSlot',
                    slotId       = slotId,
                    state        = slotInfo.state,
                    ingredientKey= slotInfo.ingredientKey
                })
            end
        end
    end
end)




function PlayFlipAnimation()
    local ped = PlayerPedId()
    lib.requestAnimDict("amb@prop_human_bbq@male@base")
    local model = GetHashKey("prop_fish_slice_01")
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    
    local pCoords = GetEntityCoords(ped)
    local spatula = CreateObject(model, pCoords.x, pCoords.y, pCoords.z, true, true, false)
    AttachEntityToEntity(spatula, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    TaskPlayAnim(ped, "amb@prop_human_bbq@male@base", "base", 8.0, -8.0, 1500, 49, 0, false, false, false)
    Wait(1500)
    
    ClearPedTasks(ped)
    if DoesEntityExist(spatula) then DeleteEntity(spatula) end
end

function OpenWorkstationMenu(entity, workstationType, stationJob)
    if not workstationType then
        lib.notify({title = 'Aviso', description = 'Isso não é uma estação de preparo.', type = 'error'})
        return
    end

    local stationId = tostring(entity)
    local wsConfig = Config.Workstations[workstationType]
    local stationData = ClientStationsState[stationId] or { hasOil = false, slots = {} }

    -- Para a grelha, oferece entrada na Cozinha 3D Interativa ou seleção de receitas
    if workstationType == 'grill' then
        local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
        local options = {
            {
                title = "🍳 Cozinhar na Grelha (Câmera 3D Interativa)",
                description = "Interaja diretamente com os ingredientes físicos e a grelha",
                icon = "fire-burner",
                onSelect = function()
                    if StartCookingCamera then StartCookingCamera(eCoords, stationId) end
                end
            },
            {
                title = "📋 Selecionar Receita do Cardápio",
                description = "Ver lista de receitas cadastradas do restaurante",
                icon = "book-open",
                onSelect = function()
                    OpenRecipeSelection(entity, workstationType, stationJob)
                end
            }
        }
        lib.registerContext({
            id = 'grill_entry_menu',
            title = 'Grelha ' .. (wsConfig and wsConfig.label or ''),
            options = options
        })
        lib.showContext('grill_entry_menu')
        return
    end

    -- Para a bancada de montagem, oferece a Mesa de Montagem Física 3D ou receitas do cardápio
    if workstationType == 'assembly' then
        local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
        local options = {
            {
                title = "🍔 Montar Hambúrguer em Camadas (Mesa 3D)",
                description = "Empilhe pão, carne, queijo e vegetais no papel manteiga",
                icon = "burger",
                onSelect = function()
                    if StartAssemblyCamera then StartAssemblyCamera(eCoords) end
                end
            },
            {
                title = "📋 Selecionar Receita do Cardápio",
                description = "Ver lista de receitas de montagem do restaurante",
                icon = "book-open",
                onSelect = function()
                    OpenRecipeSelection(entity, workstationType, stationJob)
                end
            }
        }
        lib.registerContext({
            id = 'assembly_entry_menu',
            title = 'Bancada de Montagem',
            options = options
        })
        lib.showContext('assembly_entry_menu')
        return
    end

    -- Para a fritadeira, oferece entrada na Estação de Fritura com Cesto Móvel 3D ou receitas
    if workstationType == 'fryer' then
        local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
        local options = {
            {
                title = "🍟 Estação de Fritura com Cesto Móvel (3D)",
                description = "Mergulhe o cesto de batatas no óleo quente e recolha douradas",
                icon = "bowl-food",
                onSelect = function()
                    if StartFryerCamera then StartFryerCamera(eCoords, stationId) end
                end
            },
            {
                title = "📋 Selecionar Receita de Fritura",
                description = "Ver lista de receitas da fritadeira",
                icon = "book-open",
                onSelect = function()
                    OpenRecipeSelection(entity, workstationType, stationJob)
                end
            }
        }
        lib.registerContext({
            id = 'fryer_entry_menu',
            title = 'Fritadeira Industrial',
            options = options
        })
        lib.showContext('fryer_entry_menu')
        return
    end

    -- Para a tábua de corte, oferece entrada no Modo Fatiamento 3D com a Faca de Chef ou receitas
    if workstationType == 'cutting_board' then
        local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
        local options = {
            {
                title = "🔪 Fatiar na Tábua (Câmera 3D Interativa)",
                description = "Corte batatas, tomates, queijo ou carnes usando a faca de chef",
                icon = "scissors",
                onSelect = function()
                    if StartCuttingCamera then StartCuttingCamera(eCoords, stationId) end
                end
            },
            {
                title = "📋 Selecionar Receita de Corte",
                description = "Ver lista de receitas da tábua de corte",
                icon = "book-open",
                onSelect = function()
                    OpenRecipeSelection(entity, workstationType, stationJob)
                end
            }
        }
        lib.registerContext({
            id = 'cutting_entry_menu',
            title = 'Tábua de Corte',
            options = options
        })
        lib.showContext('cutting_entry_menu')
        return
    end

    -- Para a máquina de bebidas, oferece entrada na Estação de Refrigerantes 3D ou receitas
    if workstationType == 'drinks' then
        local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
        local options = {
            {
                title = "🥤 Encher Copo de Bebida / Suco (Câmera 3D)",
                description = "Selecione o sabor e acione a torneira para encher o copo com gás e gelo",
                icon = "faucet",
                onSelect = function()
                    if StartDrinksCamera then StartDrinksCamera(eCoords, stationId) end
                end
            },
            {
                title = "📋 Selecionar Receita de Bebida",
                description = "Ver lista de receitas do dispensador de bebidas",
                icon = "book-open",
                onSelect = function()
                    OpenRecipeSelection(entity, workstationType, stationJob)
                end
            }
        }
        lib.registerContext({
            id = 'drinks_entry_menu',
            title = 'Dispensador de Bebidas',
            options = options
        })
        lib.showContext('drinks_entry_menu')
        return
    end

    -- Se houver slots ocupados nesta estação, abre o menu dos slots primeiro para recolher ou ver status
    if stationData.slots and next(stationData.slots) then
        local slotOptions = {
            {
                title = "📷 Entrar no Modo Cozinha Interativo (Câmera)",
                icon = "eye",
                onSelect = function()
                    local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
                    if StartCookingCamera then StartCookingCamera(eCoords, stationId) end
                end
            }
        }
        for slotId, slot in pairs(stationData.slots) do
            local meatMeta = Config.MeatModels[slot.ingredientKey] or Config.FriedModels[slot.ingredientKey]
            local label = meatMeta and meatMeta.label or slot.ingredientKey
            local statusLabel = "Cru"
            local icon = "hourglass-start"
            local actionCallback = nil
            
            if slot.state == 'needs_flip' then
                statusLabel = "🟢 Lado 1 Pronto! (Clique para Virar a Carne)"
                icon = "arrows-rotate"
                actionCallback = function()
                    PlayFlipAnimation()
                    TriggerServerEvent('granolla_restaurants:server:FlipSlot', stationId, slotId)
                end
            elseif slot.state == 'side2' then
                statusLabel = "🟡 Cozinhando Lado 2..."
                icon = "hourglass-half"
            elseif slot.state == 'cooked' then
                statusLabel = "🟢 No Ponto! (Clique para Recolher)"
                icon = "fire-burner"
                actionCallback = function()
                    TriggerServerEvent('granolla_restaurants:server:PickupSlot', stationId, slotId)
                end
            elseif slot.state == 'burnt' then
                statusLabel = "⬛ Queimado (Clique para Descartar)"
                icon = "dumpster"
                actionCallback = function()
                    TriggerServerEvent('granolla_restaurants:server:PickupSlot', stationId, slotId)
                end
            else
                statusLabel = "🟡 Cozinhando Lado 1..."
            end
            
            table.insert(slotOptions, {
                title = label .. " - " .. statusLabel,
                icon = icon,
                onSelect = actionCallback
            })
        end
        
        table.insert(slotOptions, {
            title = "+ Iniciar Novo Preparo",
            icon = "plus",
            onSelect = function()
                OpenRecipeSelection(entity, workstationType, stationJob)
            end
        })
        
        lib.registerContext({
            id = 'station_active_slots_menu',
            title = (wsConfig and wsConfig.label or 'Estação') .. ' (Em Uso)',
            options = slotOptions
        })
        lib.showContext('station_active_slots_menu')
        return
    end

    OpenRecipeSelection(entity, workstationType, stationJob)
end

function OpenRecipeSelection(entity, workstationType, stationJob)
    local stationId = tostring(entity)
    local wsConfig = Config.Workstations[workstationType]
    local stationData = ClientStationsState[stationId] or { hasOil = false, slots = {} }

    -- Se for fritadeira e estiver sem óleo
    if workstationType == 'fryer' and not stationData.hasOil then
        lib.registerContext({
            id = 'fryer_oil_menu',
            title = 'Fritadeira (Sem Óleo)',
            options = {
                {
                    title = 'Abastecer com Óleo de Cozinha',
                    description = 'Requer 1x Óleo de Cozinha no inventário',
                    icon = 'oil-can',
                    onSelect = function()
                        local ped = PlayerPedId()
                        lib.requestAnimDict("mini@repair")
                        TaskPlayAnim(ped, "mini@repair", "fixing_a_ped", 8.0, -8.0, 3000, 1, 0, false, false, false)
                        local success = lib.progressBar({
                            duration = 3000,
                            label = 'Abastecendo fritadeira com óleo...',
                            useWhileDead = false,
                            canCancel = true,
                            disable = { move = true }
                        })
                        ClearPedTasks(ped)
                        if success then
                            TriggerServerEvent('granolla_restaurants:server:AddOil', stationId)
                        end
                    end
                }
            }
        })
        lib.showContext('fryer_oil_menu')
        return
    end

    local recipes = GetRecipesForWorkstation(workstationType, stationJob)
    if #recipes == 0 then
        lib.notify({title = 'Vazio', description = 'Nenhuma receita cadastrada para esta estação.', type = 'error'})
        return
    end
    
    local options = {}
    for _, recipe in ipairs(recipes) do
        local metaList = {}
        for _, ing in ipairs(recipe.ingredients) do
            local itemData = QBCore.Shared.Items[ing.item]
            local label = itemData and itemData.label or ing.item
            table.insert(metaList, { label = label, value = tostring(ing.amount) .. 'x' })
        end

        local resultLabel = QBCore.Shared.Items[recipe.result] and QBCore.Shared.Items[recipe.result].label or recipe.result

        table.insert(options, {
            title = recipe.name,
            description = 'Produto: ' .. resultLabel,
            metadata = metaList,
            icon = 'utensils',
            onSelect = function()
                StartCookingProcess(entity, recipe, workstationType)
            end
        })
    end
    
    lib.registerContext({
        id = 'workstation_menu',
        title = (wsConfig and wsConfig.label or 'Estação'),
        options = options
    })
    
    lib.showContext('workstation_menu')
end

-- Processo de Cozimento (Realtime para Grelha/Fritadeira e SkillCheck para Manual)
function StartCookingProcess(entity, recipe, workstationType)
    local wsData = Config.Workstations[workstationType]
    local ped = PlayerPedId()
    local stationId = tostring(entity)
    
    lib.callback('granolla_restaurants:server:HasIngredients', false, function(hasItems)
        if not hasItems then
            lib.notify({title = 'Falta de Ingredientes', description = 'Você não possui todos os ingredientes necessários.', type = 'error'})
            return
        end
        
        -- Alinhamento do ped
        TaskTurnPedToFaceEntity(ped, entity, 1000)
        Wait(500)
        
        -- Se for bancada manual (tábua de corte ou montagem) -> Usa ox_lib SkillCheck
        if wsData.type == 'manual' then
            if wsData.animDict and wsData.animClip then
                lib.requestAnimDict(wsData.animDict)
                TaskPlayAnim(ped, wsData.animDict, wsData.animClip, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            
            local success = PlaySkillCheck({'easy', 'medium'})
            ClearPedTasks(ped)
            
            if success then
                TriggerServerEvent('granolla_restaurants:server:FinishCooking', recipe.id)
                lib.notify({title = 'Sucesso', description = 'Preparo concluído com sucesso!', type = 'success'})
            else
                lib.notify({title = 'Erro', description = 'Você errou o corte/preparo!', type = 'error'})
            end
        else
            -- Se for Grelha ou Fritadeira -> Inicia no sistema em tempo real do servidor
            local ingredientKey = recipe.ingredients[1] and recipe.ingredients[1].item or "raw_meat"
            local slotId = 1 -- slot padrão
            TriggerServerEvent('granolla_restaurants:server:StartRealtimeCook', stationId, workstationType, slotId, ingredientKey)
            
            local eCoords = (type(entity) == "number" and DoesEntityExist(entity)) and GetEntityCoords(entity) or nil
            if StartCookingCamera then StartCookingCamera(eCoords, stationId) end
        end
    end, recipe.ingredients)
end


