import fs from 'node:fs'
import path from 'node:path'

const root = path.resolve(import.meta.dirname, '..')
const businessPath = process.argv[2]
const locationsPath = process.argv[3]

if (!businessPath || !locationsPath) {
  throw new Error('Usage: node scripts/generate-mock-data.mjs <business.lua> <business_locations.lua>')
}

const business = fs.readFileSync(businessPath, 'utf8')
const locations = fs.readFileSync(locationsPath, 'utf8')

const tiers = []
for (const match of business.matchAll(/\[(\d+)\]\s*=\s*\{([\s\S]*?)\n\s*\},/g)) {
  const [, tierText, body] = match
  const readString = (key) => body.match(new RegExp(`${key}\\s*=\\s*"([^"]+)"`))?.[1] ?? ''
  const readNumber = (key) => Number(body.match(new RegExp(`${key}\\s*=\\s*([0-9.]+)`))?.[1] ?? 0)
  if (!readString('type')) continue
  tiers.push({
    tier: Number(tierText), type: readString('type'), label: readString('label'),
    weight: readNumber('weight'), requiredPoints: readNumber('requiredPoints'),
    price: readNumber('price'), npc: readString('npc'),
    expectedRevenue: readNumber('expectedRevenue'), launderFee: readNumber('launderFee'),
  })
}

const businessTypes = [...locations.matchAll(/^\s{4}([a-z_]+)\s*=\s*\{/gm)]
const parsedLocations = []
for (let index = 0; index < businessTypes.length; index += 1) {
  const type = businessTypes[index][1]
  const start = businessTypes[index].index + businessTypes[index][0].length
  const end = businessTypes[index + 1]?.index ?? locations.length
  const block = locations.slice(start, end)
  const pattern = /\[(\d+)\]\s*=\s*\{coords\s*=\s*vector4\(([-\d.]+),\s*([-\d.]+),\s*([-\d.]+),\s*([-\d.]+)\),\s*brand\s*=\s*"([^"]+)"(?:,\s*price\s*=\s*(\d+))?\}/g
  for (const match of block.matchAll(pattern)) {
    const [, id, x, y, z, heading, brand, price] = match
    parsedLocations.push({
      uid: `${type}:${id}`, id: Number(id), type, brand,
      coords: { x: Number(x), y: Number(y), z: Number(z), heading: Number(heading) },
      ...(price ? { price: Number(price) } : {}),
    })
  }
}

const output = `// Generated from the supplied Lua configuration for local UI development.\n` +
  `// Replace this mock source with NUI messages when game integration begins.\n` +
  `import type { BusinessLocation, BusinessTier } from '@/types/business'\n\n` +
  `export const businessTiers: BusinessTier[] = ${JSON.stringify(tiers, null, 2)}\n\n` +
  `export const businessLocations: BusinessLocation[] = ${JSON.stringify(parsedLocations, null, 2)}\n`

fs.mkdirSync(path.join(root, 'src/data'), { recursive: true })
fs.writeFileSync(path.join(root, 'src/data/mock-businesses.ts'), output)
console.log(`Generated ${tiers.length} tiers and ${parsedLocations.length} locations.`)
