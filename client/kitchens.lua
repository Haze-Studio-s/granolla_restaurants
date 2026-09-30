-- ====================================================================
-- client/kitchens.lua — Gerenciador de Compatibilidade de MLOs & Cozinhas
-- Granolla Restaurants (QBox / ox_lib / ox_target / ox_inventory)
-- ====================================================================

local ActiveKitchenZones = {}
local SpawnedKitchenProps = {}
local RegisteredStashes = {}

-- ── Verificar se o restaurante / MLO está ativo no servidor ─────────
local function IsKitchenActive(kitchenKey, kitchenData)
    -- 1. Verificação por nome do resource
    if kitchenData.requiredResource then
        local state = GetResourceState(kitchenData.requiredResource)
        if state == "started" then
            return true
        end
    end

    -- 2. Verificação de proximidade espacial (caso o resource tenha sido renomeado)
    local samplePos = nil
    if kitchenData.griddles and #kitchenData.griddles > 0 then
        samplePos = kitchenData.griddles[1].pos
    elseif kitchenData.assemblyTables and #kitchenData.assemblyTables > 0 then
        samplePos = kitchenData.assemblyTables[1].pos
    end

    if samplePos then
        local pCoords = GetEntityCoords(cache.ped or PlayerPedId())
        local dist = #(pCoords - samplePos)
        if dist < 250.0 then
            return true
        end
    end

    return false
end

-- ── Carregar e registrar todas as estações de uma cozinha ativa ─────
local function SetupKitchenStations(kitchenKey, data)
    print(string.format("^2[Granolla Kitchens] Ativando estacoes para o restaurante: %s^0", data.label or kitchenKey))

    -- 1. CHAPAS & GRELHAS (Griddles) -> Conecta na chapa 3D com espátula física
    if data.griddles then
        for idx, g in ipairs(data.griddles) do
            local zoneName = string.format("granolla_%s_griddle_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = g.pos,
                radius = 0.85,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-fire-burner",
                        label = "🥩 Usar Chapa & Grelha (3D)",
                        distance = 2.0,
                        onSelect = function()
                            if StartCookingCamera then
                                StartCookingCamera(g.pos, zoneName, g.rot)
                            else
                                ExecuteCommand("testkitchen")
                            end
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end

    -- 2. FRITADEIRAS INDUSTRIAIS (Fryers) -> Conecta na fritadeira com cesto móvel
    if data.fryers then
        for idx, f in ipairs(data.fryers) do
            local zoneName = string.format("granolla_%s_fryer_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = f.pos,
                radius = 0.65,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-temperature-arrow-up",
                        label = "🍟 Fritadeira com Cesto (3D)",
                        distance = 1.8,
                        onSelect = function()
                            ExecuteCommand("testfryer")
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end

    -- 3. MESAS DE MONTAGEM DE HAMBÚRGUER (Assembly Tables)
    if data.assemblyTables then
        for idx, a in ipairs(data.assemblyTables) do
            local zoneName = string.format("granolla_%s_assembly_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = a.pos,
                radius = 0.85,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-burger",
                        label = "🍔 Montagem de Hambúrguer (3D)",
                        distance = 1.8,
                        onSelect = function()
                            ExecuteCommand("testassembly")
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end

    -- 4. BANCADAS DE CORTE / CHIPS (Cutting Boards)
    if data.cuttingBoards then
        for idx, c in ipairs(data.cuttingBoards) do
            local zoneName = string.format("granolla_%s_cut_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = c.pos,
                radius = 0.75,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-kitchen-set",
                        label = "🔪 Tábua de Corte de Alimentos (3D)",
                        distance = 1.8,
                        onSelect = function()
                            ExecuteCommand("testcut")
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end

    -- 5. MÁQUINAS DE BEBIDAS & REFRIGERANTE (Drink Machines)
    if data.drinkMachines then
        for idx, d in ipairs(data.drinkMachines) do
            local zoneName = string.format("granolla_%s_drink_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = d.pos,
                radius = 0.85,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-glass-water",
                        label = "🥤 Dispensador de Refrigerante & Sucos (3D)",
                        distance = 2.0,
                        onSelect = function()
                            ExecuteCommand("testdrinks")
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end

    -- 6. BALCÃO DE ATENDIMENTO (Bandejas de Pedidos & Caixa POS)
    if data.serviceCounters then
        for idx, sc in ipairs(data.serviceCounters) do
            local stashId = string.format("granolla_tray_%s_%d", kitchenKey, idx)

            -- Spawnar prop da bandeja prop_tray_01 se configurado
            if sc.tray then
                local model = GetHashKey("prop_tray_01")
                RequestModel(model)
                local timeout = 0
                while not HasModelLoaded(model) and timeout < 50 do
                    Wait(10)
                    timeout = timeout + 1
                end

                if HasModelLoaded(model) then
                    local trayProp = CreateObject(model, sc.pos.x, sc.pos.y, sc.pos.z, false, false, false)
                    SetEntityRotation(trayProp, sc.rot.x, sc.rot.y, sc.rot.z, 2, true)
                    FreezeEntityPosition(trayProp, true)
                    table.insert(SpawnedKitchenProps, trayProp)

                    -- Registrar no ox_target da bandeja
                    exports.ox_target:addLocalEntity(trayProp, {
                        {
                            name = stashId,
                            icon = "fas fa-box-open",
                            label = "🍱 Bandeja de Pedidos",
                            distance = 2.0,
                            onSelect = function()
                                exports.ox_inventory:openInventory('stash', stashId)
                            end
                        }
                    })
                end
            end

            -- Caixa Registradora POS (Renewed-Banking)
            if sc.register then
                local posZone = string.format("granolla_pos_%s_%d", kitchenKey, idx)
                local posCoords = sc.pos + vector3(0.35, 0.0, 0.0)

                exports.ox_target:addSphereZone({
                    name = posZone,
                    coords = posCoords,
                    radius = 0.65,
                    debug = false,
                    options = {
                        {
                            name = posZone,
                            icon = "fas fa-cash-register",
                            label = "💵 Cobrar Cliente no Balcão",
                            distance = 2.0,
                            onSelect = function()
                                TriggerEvent('granolla_restaurants:client:RegisterBill')
                            end
                        }
                    }
                })
                table.insert(ActiveKitchenZones, posZone)
            end
        end
    end

    -- 7. LIXEIRAS DE DESCARTE (Bins)
    if data.bins then
        for idx, b in ipairs(data.bins) do
            local zoneName = string.format("granolla_%s_bin_%d", kitchenKey, idx)
            exports.ox_target:addSphereZone({
                name = zoneName,
                coords = b.pos,
                radius = 0.70,
                debug = false,
                options = {
                    {
                        name = zoneName,
                        icon = "fas fa-trash-can",
                        label = "🗑️ Descartar Restos & Queimados",
                        distance = 1.8,
                        onSelect = function()
                            lib.notify({ title = "Lixeira", description = "Descarte os restos de comida pelo menu do inventário.", type = 'inform' })
                        end
                    }
                }
            })
            table.insert(ActiveKitchenZones, zoneName)
        end
    end
end

-- ── Ciclo de Vida: Inicialização das Cozinhas ────────────────────────
CreateThread(function()
    Wait(1500) -- Aguarda carregamento de MLOs e do mundo
    if not Config or not Config.SupportedKitchens then return end

    for kitchenKey, kitchenData in pairs(Config.SupportedKitchens) do
        if IsKitchenActive(kitchenKey, kitchenData) then
            SetupKitchenStations(kitchenKey, kitchenData)
        end
    end
end)

-- ── Limpeza ao Parar o Recurso ───────────────────────────────────────
AddEventHandler('onResourceStop', function(resName)
    if resName == GetCurrentResourceName() then
        for _, zoneName in ipairs(ActiveKitchenZones) do
            pcall(function()
                exports.ox_target:removeZone(zoneName)
            end)
        end
        for _, prop in ipairs(SpawnedKitchenProps) do
            if DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
        end
        ActiveKitchenZones = {}
        SpawnedKitchenProps = {}
    end
end)
