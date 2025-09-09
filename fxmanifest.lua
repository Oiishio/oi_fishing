-- Resource Metadata
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Lunar Scripts - Enhanced Edition'
description 'Advanced Fishing with Weather System, 25+ Fish Species, and Enhanced Features'
version '2.0.0'

files {
    'locales/*.json'
}

shared_scripts {
    '@ox_lib/init.lua',
    'shared/constant.lua',   -- Load constants first
    'shared/utils.lua',      -- Then shared utils
    'config/config.lua'      -- Then config
}

client_scripts {
    'framework/**/client.lua',
    'config/cl_edit.lua',
    'utils/utils.lua',       -- Client-side utils (separate from shared)
    'client/environment.lua',  
    'client/ui.lua',
    'client/level.lua',        
    'client/main.lua',
    'client/*.lua'           -- Load other client files after main ones
}

server_scripts {
    'framework/**/server.lua',
    '@oxmysql/lib/MySQL.lua',
    'config/sv_config.lua',
    'server/*.lua'
}