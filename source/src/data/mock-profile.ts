export const mockProfile = {
  characterName: 'Michael Anderson',
  reputation: 6000,
  portfolioWeight: 2,
  portfolioLimit: 6,
  balance: 286400,
  ownedLocationIds: ['coffee_shop:12', 'gas_station:21'],
}

// Mirrors Config.Reputation.Levels for local UI development.
export const mockReputationLevels = [
  { points: 0, label: 'Unverified' },
  { points: 250, label: 'Registered' },
  { points: 500, label: 'Active Operator' },
  { points: 1000, label: 'Established Operator' },
  { points: 1750, label: 'Verified Investor' },
  { points: 2750, label: 'Accredited Investor' },
  { points: 4000, label: 'Senior Operator' },
  { points: 5500, label: 'Portfolio Manager' },
  { points: 7500, label: 'Commercial Investor' },
  { points: 10000, label: 'Institutional Buyer' },
  { points: 15000, label: 'Premium Member' },
]
