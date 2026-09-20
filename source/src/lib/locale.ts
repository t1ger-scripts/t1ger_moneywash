import { shallowRef } from 'vue'

export type LocaleDictionary = Record<string, unknown>

type LocaleVariable = string | number
type LocaleVariables = Record<string, LocaleVariable>

const englishFallback: LocaleDictionary = {
    browser: {
        brand: {
            name: 'Ledger Capital',
            subtitle: 'Business Brokerage',
        },

        chrome: {
            close: 'Close browser',
            tab_suffix: 'Ledger Capital',
            protocol: 'https://',
            domain: 'ledgercapital.com',
            secure_session: 'Secure Session',
            path_marketplace: 'marketplace',
            path_portfolio: 'portfolio',
        },

        navigation: {
            primary_label: 'Primary navigation',
            marketplace: 'Marketplace',
            portfolio: 'My Portfolio',
            help_center: 'Help Center',
        },

        account: {
            heading: 'Your Account',
            membership_status: 'Membership Status',
            investor_score: 'Investor Score',
            progress_to: 'Progress to {level}',
            maximum_status: 'Maximum status achieved',
            portfolio_usage: 'Portfolio Usage',
        },

        marketplace: {
            eyebrow: 'Verified Listings',
            title: 'Marketplace',
            description: 'Browse available business acquisitions and expand your portfolio.',
        },

        tiers: {
            available: '{count} available',
            access_restricted: 'Access restricted',
            eligible: 'ELIGIBLE',
        },

        listings: {
            heading: 'Available Listings',
            count_one: '{available} of {total} listing available',
            count_many: '{available} of {total} listings available',

            search_label: 'Search business listings',
            search_placeholder: 'Search brand, street or zone',

            none_configured_title: 'No listings configured',
            none_configured_description:
                'There are currently no registered locations for this business category.',

            no_matches_title: 'No matching listings',
            no_matches_description: 'No businesses match “{query}”.',
            clear_search: 'Clear search',

            fully_allocated_title: 'Category fully allocated',
            fully_allocated_description:
                'All registered locations have currently been acquired.',

            status_active: 'ACTIVE',
            status_acquired: 'ACQUIRED',
            status_in_portfolio: 'IN PORTFOLIO',
            weight: 'Weight: {weight}',
        },
        
        map: {
            loading_title: 'Loading location map',
            loading_description: 'Retrieving satellite imagery',
            unavailable_title: 'Map imagery unavailable',
            unavailable_description:
                'Listings are still available in the location panel.',
            retry: 'Retry',
            label: 'LOCATION MAP',
            zoom_in: 'Zoom in',
            zoom_out: 'Zoom out',
            show_all: 'Show all',
            legend_available: 'Available',
            legend_selected: 'Selected',
            legend_score_required: 'Score Required',
        },

        listing_detail: {
            close_label: 'Close listing details',
            kicker: 'LISTING {id} · TIER {tier}',
            acquisition_price: 'Acquisition price',
            expected_revenue: 'Expected revenue',
            per_cycle: '{amount} / cycle',
            service_fee: 'Service fee',
            portfolio_weight: 'Portfolio weight',

            unavailable_title: 'LISTING UNAVAILABLE',
            unavailable_description:
                'This location has already been acquired.',

            score_required_title: 'INVESTOR SCORE REQUIRED',
            points_needed: '{points} more points needed',

            type_active_title: 'TYPE ALREADY ACTIVE',
            type_active_description:
                'You may only register one {type}.',

            insufficient_funds_title: 'INSUFFICIENT FUNDS',
            insufficient_funds_description:
                'Additional funds are required for this acquisition.',

            portfolio_limit_title: 'PORTFOLIO LIMIT',
            portfolio_limit_description:
                'Free up capacity before acquiring this listing.',

            eligible: 'Eligible to acquire',

            button_unavailable: 'Listing unavailable',
            button_score_required: 'Score requirement not met',
            button_type_active: 'Type already registered',
            button_insufficient_funds: 'Insufficient funds',
            button_portfolio_limit: 'Portfolio limit exceeded',
            button_review: 'Review acquisition',

            review_note:
                'Review all acquisition details before confirming.',
        },

        purchase: {
            dialog_label: 'Confirm business acquisition',
            close_label: 'Close',
            final_review: 'FINAL REVIEW',
            confirm_title: 'Confirm acquisition',
            tier: 'Tier {tier}',

            acquisition_price: 'ACQUISITION PRICE',
            business_type: 'BUSINESS TYPE',
            portfolio_weight: 'PORTFOLIO WEIGHT',
            current_usage: 'CURRENT USAGE',
            resulting_usage: 'RESULTING USAGE',

            restriction_unavailable:
                'This listing is no longer available.',
            restriction_score:
                'Your Investor Score does not meet this tier requirement.',
            restriction_type:
                'You already have an active {type}.',
            restriction_funds:
                'You do not have enough funds to complete this acquisition.',
            restriction_portfolio:
                'This acquisition would exceed your portfolio limit.',

            confirmation_note:
                'The acquisition price will be charged immediately after confirmation.',

            cancel: 'Cancel',
            processing: 'Processing…',
            confirm: 'Confirm Acquisition',
        },
    },
}

const activeLocales =
    shallowRef<LocaleDictionary>({})

function resolveLocaleValue(
    dictionary: LocaleDictionary,
    path: string,
): unknown {
    return path.split('.').reduce<unknown>(
        (current, segment) => {
            if (
                !current ||
                typeof current !== 'object' ||
                Array.isArray(current)
            ) {
                return undefined
            }

            return (
                current as Record<string, unknown>
            )[segment]
        },
        dictionary,
    )
}

function replaceVariables(
    value: string,
    variables: LocaleVariables,
): string {
    return value.replace(
        /\{([a-zA-Z0-9_]+)\}/g,
        (match, variable: string) => {
            const replacement = variables[variable]

            return replacement === undefined
                ? match
                : String(replacement)
        },
    )
}

export function setLocales(
    locales?: LocaleDictionary,
) {
    activeLocales.value =
        locales && typeof locales === 'object'
            ? locales
            : {}
}

export function t(
    key: string,
    variables: LocaleVariables = {},
): string {
    const runtimeValue = resolveLocaleValue(
        activeLocales.value,
        key,
    )

    const fallbackValue = resolveLocaleValue(
        englishFallback,
        key,
    )

    const value =
        typeof runtimeValue === 'string'
            ? runtimeValue
            : typeof fallbackValue === 'string'
                ? fallbackValue
                : key

    return replaceVariables(value, variables)
}