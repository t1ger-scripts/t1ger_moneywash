fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 't1ger_moneywash'
author 'T1GER Scripts'
discord 'https://discord.gg/RdwXAK3Vnw'
description 'T1GER Money Wash'
version '1.0.0'

ui_page 'web/index.html'

dependencies {
    '/server:7290',
    '/gameBuild:3258',
}

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/config.lua',
    'bridge/init.lua',
    'shared/config.lua',
    'shared/ui_text.lua',
}

client_scripts {
    'bridge/framework/client.lua',
    'bridge/target/client.lua',
    'bridge/inventory/client.lua',
    'bridge/notification/client.lua',

    'client/functions.lua',
    'client/reputation.lua',
    'client/customize.lua',
    'client/ui.lua',
    'client/cash_counter.lua',
    'client/portal.lua',
    'client/business/bank_deposit.lua',
    'client/business/raid.lua',
    'client/business/menu.lua',
    'client/business/stock.lua',
    'client/business/review.lua',
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',

    'bridge/framework/server.lua',
    'bridge/inventory/server.lua',
    'bridge/jobaccount/server.lua',
    'bridge/notification/server.lua',

    'server/reputation.lua',
    'server/functions.lua',
    'server/customize.lua',
    'server/hooks.lua',
    'server/portal.lua',

    'server/business/store.lua',
    'server/business/suspicion.lua',
    'server/business/ownership.lua',
    'server/business/bank_deposit.lua',
    'server/business/raid.lua',
    'server/business/review.lua',
    'server/business/stock.lua',
    'server/business/commands.lua',
    'server/business/cash_operation.lua',
    
    'server/main.lua',
}

files {
    'locales/*.json',
    'web/index.html',
    'web/assets/**/*',
    'web/images/**/*',

    'web/mapStyles/styleSatelite/0/**/*',
    'web/mapStyles/styleSatelite/1/**/*',
    'web/mapStyles/styleSatelite/2/**/*',
    'web/mapStyles/styleSatelite/3/**/*',
    'web/mapStyles/styleSatelite/4/**/*',
    'web/mapStyles/styleSatelite/5/**/*',

    'shared/locations.lua',
    'shared/delivery.lua',
}

ox_libs {
    'locale',
    'math',
}

escrow_ignore {
    'shared/*.lua',
    'bridge/**/*.lua',
    'client/**/*.lua',
    'server/**/*.lua',
}