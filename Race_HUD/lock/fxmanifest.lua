fx_version 'cerulean'
game 'gta5'

name 'RACE-LOCK'
description 'Simply Lock your own Car'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
