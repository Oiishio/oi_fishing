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
    'shared/constants.lua',
    'shared/utils.lua',
    'config/config.lua'
}

client_scripts {
    'framework/**/client.lua',
    'config/cl_edit.lua',
    'client/environment.lua',
    'client/ui.lua',
    'client/main.lua',
    'client/*.lua'
}
server_scripts {
    'framework/**/server.lua',
    '@oxmysql/lib/MySQL.lua',
    'utils/sv_main.lua',
    'config/sv_config.lua',
    'locales/*.lua',
    'server/*.lua'
}