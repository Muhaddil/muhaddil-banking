fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Muhaddil'
description 'Banking System'
version 'v0.2.1-beta'

ui_page 'web/build/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/*'
}

client_script 'client/*'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/security.lua',
    'server/functions.lua',
    'server/main.lua',
    'server/admin.lua',
    'server/atm.lua',
    'server/bankmanagement.lua',
    'server/cards.lua',
    'server/checks.lua',
    'server/contacts.lua',
    'server/directdebits.lua',
    'server/phoneApp.lua',
    'server/savings.lua',
    'server/scheduledtransfers.lua',
    'server/sync.lua',
    'server/transferrequests.lua',
    'server/updatechecker.lua',
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
