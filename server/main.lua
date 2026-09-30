-- server/main.lua
-- ================================================================
-- GRANÔLLA RESTAURANTS - SERVIDOR: NÚCLEO, LOGS & WEBHOOKS
-- ================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Webhooks Base para auditoria e logs administrativos
local Webhooks = {
    economy   = "SUA_URL_AQUI",
    criacao   = "SUA_URL_AQUI",
    admin     = "SUA_URL_AQUI",
    anticheat = "SUA_URL_AQUI"
}

function SendDiscordWebhook(type, message)
    if not Webhooks[type] or Webhooks[type] == "SUA_URL_AQUI" then return end
    PerformHttpRequest(Webhooks[type], function(err, text, headers) end, 'POST', json.encode({
        username = "Granôlla Gastronomia Logs",
        content  = message
    }), { ['Content-Type'] = 'application/json' })
end

-- Export para outros arquivos usarem os webhooks
exports('SendWebhook', SendDiscordWebhook)

print('^2[Granolla Restaurants]^0 Módulo principal do servidor carregado com sucesso.')
