fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 't1ger_moneywash'
author 'T1GER Scripts'
discord 'https://discord.gg/RdwXAK3Vnw'
description 'T1GER Money Wash'
version '1.0.0'

dependencies {
    '/server:7290',
    '/gameBuild:3258',
}

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/config.lua',
    'bridge/init.lua',

    -- IMPORTANT: config.lua MUST load first
    -- Do NOT switch back to shared/*.lua wildcard
    'shared/config.lua',
    'shared/business.lua',
    'shared/suspicion.lua',
}

client_scripts {
    'bridge/framework/client.lua',
    'bridge/target/client.lua',
    'bridge/inventory/client.lua',
    'bridge/notification/client.lua',

    'client/functions.lua',
    'client/reputation.lua',
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
    'server/business/store.lua',
    'server/business/manager.lua',
    'server/business/purchase.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
    'shared/business_locations.lua',
    'shared/stocklocations.lua',
    'shared/banklocations.lua',
    'shared/accountantoffices.lua',
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