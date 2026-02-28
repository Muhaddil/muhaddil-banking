fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Muhaddil'
description 'Banking System'
version 'v0.0.2-beta'

ui_page 'web/build/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*'
}

client_script 'client/*'

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/*'
}

files {
    'web/build/index.html',
    'web/build/**/*',
    'phone-app-ui/*',
    'phone-app-ui/**/*',
    'locales/*.json'
}

dependencies {
    'ox_lib',
    'oxmysql'
}
