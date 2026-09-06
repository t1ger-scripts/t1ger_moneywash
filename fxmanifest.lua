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
    '/server:7290',     	-- ⚠️PLEASE READ⚠️; Requires at least SERVER build 7290.
    '/gameBuild:3258',  	-- ⚠️PLEASE READ⚠️; Requires at least GAME build 3095.
}

shared_scripts {
    '@ox_lib/init.lua',
	'bridge/config.lua',
	'bridge/init.lua',
	'shared/*.lua',
}

client_scripts {
    'bridge/framework/client.lua', -- Framework
    'bridge/target/client.lua', -- Target
    'bridge/inventory/client.lua', -- Inventory
    'bridge/notification/client.lua', -- Notification

	'client/functions.lua', -- Functions
	'client/reputation.lua', -- Reputation
	'client/runnerexchange.lua', -- Runner Exchange
	'client/menu.lua', -- Menu
	'client/main.lua', -- Main
}

server_scripts {
	'@oxmysql/lib/MySQL.lua', -- oxmysql

    'bridge/framework/server.lua', -- Framework
    'bridge/inventory/server.lua', -- Inventory
    'bridge/jobaccount/server.lua', -- Job Account / Society Account
    'bridge/notification/server.lua', -- Notification

	'server/functions.lua', -- Functions
	'server/reputation.lua', -- Reputation
	'server/runnerexchange.lua', -- Runner Exchange
	'server/main.lua', -- Main
}

files {
    'locales/*.json',
}

ox_libs {
    'locale',
    'math'
}

escrow_ignore { 
	-- Shared files
    'shared/*.lua',

	-- Bridge files
	'bridge/**/*.lua',

	-- Client files (Source-Available)
	'client/**/*.lua',

	-- Server files (Source-Available)
	'server/**/*.lua',
}