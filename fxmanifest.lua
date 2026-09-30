fx_version 'cerulean'
game 'gta5'

description 'Granolla Restaurants - Sistema Avançado de Gastronomia'
author 'Granolla / Antigravity'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/kitchens.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
    'client/props.lua',
    'client/assembly.lua',
    'client/fryer.lua',
    'client/cutting_board.lua',
    'client/drinks.lua',
    'client/counter.lua',
    'client/kitchens.lua',
    'client/placement.lua',
    'client/recipes.lua',
    'client/minigames.lua',
    'client/delivery.lua',
    'client/npcs.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/main.lua',
    'server/recipes.lua',
    'server/cooking.lua',
    'server/economy.lua',
    'server/npcs.lua',
    'server/props.lua'
}

lua54 'yes'
