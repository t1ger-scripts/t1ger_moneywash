export const stackThresholds = [
    25_000,
    100_000,
    250_000,
    500_000,
    1_000_000,
    2_000_000,
    3_000_000,
    4_000_000,
    5_000_000,
    6_500_000,
    8_000_000,
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
export function counterDuration(amount: number): number {
    return Math.round(
        3000 +
            3000 *
                Math.max(
                    0,
                    Math.min(
                        1,
                        Math.log10(amount / 15000) /
                            Math.log10(1000000 / 15000),
                    ),
                ),
    )
}
