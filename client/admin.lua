-- client/admin.lua
local QBCore = exports['qb-core']:GetCoreObject()
local isPropModeActive = false
local lastHighlightedEntity = nil

-- Helper para desenhar texto 3D na tela durante o Raycast
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
        local factor = (string.len(text)) / 370
        DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 0, 0, 0, 150)
    end
end

-- Comando para obter coordenadas atuais do jogador
RegisterCommand('getcoords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local x = math.floor(coords.x * 100) / 100
    local y = math.floor(coords.y * 100) / 100
    local z = math.floor(coords.z * 100) / 100
    local h = math.floor(heading * 100) / 100

    local formattedCoords = string.format("vector3(%s, %s, %s)", x, y, z)
    local formattedCoordsH = string.format("vector4(%s, %s, %s, %s)", x, y, z, h)
    
    -- Copiar para área de transferência via NUI
    SendNUIMessage({ action = 'copyToClipboard', text = formattedCoords })
    
    lib.notify({
        title = 'Coordenadas Copiadas! (Ctrl+V)',
        description = formattedCoords,
        type = 'success',
        duration = 5000
    })
    
    print('^2================================================================^0')
    print('^3COORDS PARA O CONFIG.LUA:^0')
    print(formattedCoords)
    print(formattedCoordsH)
    print('^2================================================================^0')
end, false)

-- Função para Alternar o Modo de Inspeção de Prop com Raycast Visual
function TogglePropInspectorMode()
    isPropModeActive = not isPropModeActive
    
    if not isPropModeActive then
        if lastHighlightedEntity and DoesEntityExist(lastHighlightedEntity) then
            pcall(SetEntityDrawOutline, lastHighlightedEntity, false)
            lastHighlightedEntity = nil
        end
        lib.notify({title = 'Modo Inspeção Encerrado', description = 'Raycast visual desativado.', type = 'info'})
        return
    end
    
    lib.notify({
        title = 'Modo Inspeção ATIVO! 🟢',
        description = 'Mire no prop do MLO. Pressione [E] para COPIAR os dados ou [BACKSPACE] para sair.',
        type = 'success',
        duration = 7000
    })
    
    CreateThread(function()
        while isPropModeActive do
            Wait(0)
            DisableControlAction(0, 24, true) -- Desativa soco/tiro
            DisableControlAction(0, 25, true) -- Desativa mira
            
            local cameraRotation = GetGameplayCamRot()
            local cameraCoord = GetGameplayCamCoord()
            local radiansZ = (math.pi / 180) * cameraRotation.z
            local radiansX = (math.pi / 180) * cameraRotation.x
            local direction = {
                x = -math.sin(radiansZ) * math.abs(math.cos(radiansX)),
                y = math.cos(radiansZ) * math.abs(math.cos(radiansX)),
                z = math.sin(radiansX)
            }
            local destination = {
                x = cameraCoord.x + direction.x * 25.0,
                y = cameraCoord.y + direction.y * 25.0,
                z = cameraCoord.z + direction.z * 25.0
            }
            
            -- Flag -1 varre TODAS as geometrias (props do MLO, entidades, mapas)
            local handle = StartExpensiveSynchronousShapeTestLosProbe(cameraCoord.x, cameraCoord.y, cameraCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 4)
            local _, hit, hitCoords, surfaceNormal, entity = GetShapeTestResult(handle)
            
            if hit == 1 then
                -- Desenha a Linha de Laser Visual Verde/Neon do jogador até o ponto de impacto
                DrawLine(cameraCoord.x, cameraCoord.y, cameraCoord.z, hitCoords.x, hitCoords.y, hitCoords.z, 0, 255, 120, 200)
                
                -- Desenha um Marcador de Ponto 3D no local exato do impacto
                DrawMarker(28, hitCoords.x, hitCoords.y, hitCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 0, 255, 120, 200, false, false, 2, false, nil, nil, false)
                
                -- Se atingiu uma entidade física real e existente, destaca o contorno visual com segurança
                if entity ~= 0 and DoesEntityExist(entity) and entity ~= lastHighlightedEntity then
                    if lastHighlightedEntity and DoesEntityExist(lastHighlightedEntity) then
                        pcall(SetEntityDrawOutline, lastHighlightedEntity, false)
                    end
                    lastHighlightedEntity = entity
                    pcall(function()
                        SetEntityDrawOutline(entity, true)
                        SetEntityDrawOutlineColor(0, 255, 120, 255)
                        SetEntityDrawOutlineShader(1)
                    end)
                end
                
                local modelHash = "MapProp"
                if entity ~= 0 and DoesEntityExist(entity) then
                    local status, hash = pcall(GetEntityModel, entity)
                    if status then modelHash = tostring(hash) end
                end
                
                local x = math.floor(hitCoords.x * 100) / 100
                local y = math.floor(hitCoords.y * 100) / 100
                local z = math.floor(hitCoords.z * 100) / 100
                
                -- Exibe Texto Flutuante 3D na Tela
                DrawText3D(hitCoords.x, hitCoords.y, hitCoords.z + 0.2, string.format("~g~[E] COPIAR DADOS~w~\nHash: ~y~%s~w~\nCoords: vector3(%.2f, %.2f, %.2f)", modelHash, x, y, z))
                
                -- Confirmar e Copiar com [E]
                if IsControlJustPressed(0, 38) then
                    local formattedCoords = string.format("vector3(%.2f, %.2f, %.2f)", x, y, z)
                    local configSnippet = string.format('{\n    id = "ws_%s",\n    workstation = "grill",\n    coords = %s,\n    useExistingModel = true\n}', modelHash, formattedCoords)
                    
                    -- Copiar para área de transferência do Windows via NUI JS (método seguro com textarea)
                    SendNUIMessage({ action = 'copyToClipboard', text = formattedCoords })
                    
                    PlaySoundFrontend(-1, "SELECT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    
                    lib.notify({
                        title = 'COPIADO COM SUCESSO! 📋',
                        description = 'Coordenada copiada (Ctrl+V). Dados detalhados impressos no F8.',
                        type = 'success',
                        duration = 8000
                    })
                    
                    print('^2================================================================^0')
                    print('^3DADOS CAPTURADOS DO PROP (COPIADO PARA CTRL+V):^0')
                    print(string.format('Model Hash: %s', modelHash))
                    print(string.format('Coordenada Formatada: %s', formattedCoords))
                    print('Bloco formatado para o Config.lua:')
                    print(configSnippet)
                    print('^2================================================================^0')
                    
                    Wait(500)
                end
            else
                if lastHighlightedEntity and DoesEntityExist(lastHighlightedEntity) then
                    pcall(SetEntityDrawOutline, lastHighlightedEntity, false)
                    lastHighlightedEntity = nil
                end
            end
            
            -- Sair com [BACKSPACE] ou [ESC]
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 200) then
                isPropModeActive = false
                if lastHighlightedEntity and DoesEntityExist(lastHighlightedEntity) then
                    pcall(SetEntityDrawOutline, lastHighlightedEntity, false)
                    lastHighlightedEntity = nil
                end
                lib.notify({title = 'Modo Inspeção Encerrado', description = 'Raycast visual desativado.', type = 'info'})
            end
        end
    end)
end

RegisterCommand('getprop', TogglePropInspectorMode, false)
RegisterCommand('propmode', TogglePropInspectorMode, false)



