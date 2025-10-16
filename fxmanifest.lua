fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'prison_taxi'
author 'Kakarot (for Bert)'
description 'Free taxi from Bolingbroke with destination picker & auto-despawn'
version '1.0.0'

shared_scripts {
  'config.lua'
}

client_scripts {
  '@es_extended/imports.lua',
  'client.lua'
}

server_scripts {
  '@mysql-async/lib/MySQL.lua',
  '@es_extended/imports.lua',
  'server.lua'
}

dependencies {
  'es_extended'
}
