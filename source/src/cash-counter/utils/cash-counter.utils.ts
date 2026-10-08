export const stackThresholds = [
    3_000, 10_000, 15_000, 25_000, 35_000, 50_000, 65_000, 80_000,
    100_000, 150_000, 250_000, 400_000, 600_000, 1_000_000, 5_000_000,
    Infinity,
]
export function stackCount(amount: number): number {
    return amount <= 0
        ? 0
        : stackThresholds.findIndex((limit) => amount <= limit) + 1
}
export function validAmount(amount: number, available: number): boolean {
    return Number.isSafeInteger(amount) && amount > 0 && amount <= available
}
