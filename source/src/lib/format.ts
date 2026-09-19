export const money = new Intl.NumberFormat('en-US', {
  style: 'currency',
  currency: 'USD',
  maximumFractionDigits: 0,
})

export const compactNumber = new Intl.NumberFormat('en-US', {
  notation: 'compact',
  maximumFractionDigits: 1,
})

export function toRoman(value: number): string {
  const numerals = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX']
  return numerals[value] ?? String(value)
}

export function districtFromCoordinates(x: number, y: number): string {
  if (y > 5500) return 'Paleto Bay'
  if (y > 1800) return x > 900 ? 'Sandy Shores' : 'Blaine County'
  if (y < -1600) return x > 700 ? 'Cypress Flats' : 'South Los Santos'
  if (x < -1800) return 'West Coast'
  if (x < -900) return y > 250 ? 'Vinewood West' : 'Vespucci'
  if (x > 1500) return 'East Los Santos'
  if (y > 250) return 'Vinewood'
  if (y < -700) return 'Downtown South'
  return 'Los Santos'
}
