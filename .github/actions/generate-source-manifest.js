const fs = require('fs');

const manifestPath = 'fxmanifest.lua';
const outputPath   = process.argv[2] || 'fxmanifest.source.lua';

const sourceEscrowBlock = `escrow_ignore { 
	-- Shared files
    'shared/*.lua',

	-- Bridge files
	'bridge/**/*.lua',

	-- Client files (all, fully unlocked)
	'client/**/*.lua',

	-- Server files (all, fully unlocked)
	'server/**/*.lua',
}`;

let content = fs.readFileSync(manifestPath, 'utf8');

// Matches from 'escrow_ignore {' through its closing brace on its own line
const regex = /escrow_ignore\s*\{[\s\S]*?\n\}/;

if (!regex.test(content)) {
    console.error('Could not find escrow_ignore block in fxmanifest.lua');
    process.exit(1);
}

content = content.replace(regex, sourceEscrowBlock);

fs.writeFileSync(outputPath, content);
console.log(`Generated ${outputPath} from ${manifestPath}`);