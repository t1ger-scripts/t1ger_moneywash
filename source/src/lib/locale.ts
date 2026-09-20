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
            membership_status: 'Membership Status:',
            investor_score: 'Investor Score',
            progress_to: 'Progress to {level}',
            maximum_status: 'Maximum status achieved',
            portfolio_usage: 'Portfolio Usage',
        },

        business_types: {
            coffee_shop: 'Coffee Shop',
            gas_station: 'Gas Station',
            restaurant: 'Restaurant',
            laundromat: 'Laundromat',
            bar: 'Bar',
            nightclub: 'Nightclub',
            stripclub: 'Strip Club',
            carwash: 'Car Wash',
            casino: 'Casino',
        },

        reputation_levels: {
            0: 'Unverified',
            250: 'Registered',
            500: 'Active Operator',
            1000: 'Established Operator',
            1750: 'Verified Investor',
            2750: 'Accredited Investor',
            4000: 'Senior Operator',
            5500: 'Portfolio Manager',
            7500: 'Commercial Investor',
            10000: 'Institutional Buyer',
            15000: 'Premium Member',
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

        portfolio: {
            eyebrow: 'OWNERSHIP LEDGER',
            title: 'My Portfolio',
            description:
                'Manage your registered businesses and ownership actions.',
            usage: 'PORTFOLIO USAGE',

            registered_businesses: 'REGISTERED BUSINESSES',
            business_count_one: '{count} business',
            business_count_many: '{count} businesses',
            actions_description: 'Manage available ownership actions.',

            status_active: 'ACTIVE',
            tier: 'Tier {tier}',
            weight: 'Weight {weight}',
            site: 'Site {id}',

            set_waypoint: 'Set waypoint',
            transfer_action: 'Transfer Ownership',
            relinquish_action: 'Relinquish Holding',

            empty_title: 'No businesses registered',
            empty_description:
                'Purchase your first business through the Marketplace.',
            browse_marketplace: 'Browse Marketplace',

            ownership_action_label: '{business} ownership action',
            close_label: 'Close',

            transfer: {
                kicker: 'TRANSFER OWNERSHIP',
                title: 'Select a nearby player',
                description:
                    'The business will be transferred immediately after confirmation. No payment is included in this transfer.',

                searching_label: 'Searching for nearby players',
                empty_title: 'No nearby players',
                empty_description:
                    'Another player must be nearby before ownership can be transferred.',

                player_details: 'Session ID {id} · {distance}m away',

                cancel: 'Cancel',
                processing: 'Processing…',
                confirm: 'Confirm Transfer',
            },

            relinquish: {
                kicker: 'PERMANENT ACTION',
                title: 'Relinquish {business}?',
                description:
                    'This business will immediately return to the Marketplace. You will receive no refund.',

                warning_title:
                    'Everything associated with this business will be lost:',

                loss_funds:
                    'All funds remaining in the business account',
                loss_inventory:
                    'All remaining inventory and active orders',
                loss_activity:
                    'All pending transactions and business activity',

                cancel: 'Keep Business',
                processing: 'Processing…',
                confirm: 'Relinquish Permanently',
            },
        },

        bootstrap: {
            error_eyebrow: 'CONNECTION ERROR',
            error_title: 'Unable to load brokerage data',
            error_description:
                'Ledger Capital could not retrieve the current listings and account information.',
            retry: 'Retry',
        },

        notifications: {
            title_success: 'Completed',
            title_warning: 'Attention required',
            title_error: 'Action unsuccessful',
            title_info: 'Information',
            dismiss: 'Dismiss notification',
        },

        actions: {
            purchase_stale:
                'This acquisition can no longer be completed.',
            purchase_failed:
                'The acquisition could not be completed.',
            purchase_success:
                '{business} has been added to your portfolio.',

            waypoint_failed:
                'The waypoint could not be set.',
            waypoint_success:
                'Waypoint set for {business}.',

            nearby_players_failed:
                'Nearby players could not be retrieved.',

            ownership_record_unavailable:
                'This business ownership record is unavailable.',

            transfer_failed:
                'The ownership transfer could not be completed.',
            transfer_success:
                '{business} was transferred to {player}.',

            relinquish_failed:
                'The business could not be returned to the Marketplace.',
            relinquish_success:
                '{business} has been returned to the Marketplace.',
        },

        action_reasons: {
            invalid_request:
                'The request was invalid.',
            invalid_player:
                'Your player data is not available.',
            invalid_type:
                'This business category is invalid.',
            invalid_location:
                'This business location does not exist.',

            already_owned:
                'This listing has already been acquired.',
            already_owns_type:
                'You already own a business in this category.',

            insufficient_reputation:
                'Your Investor Score is not high enough.',
            portfolio_full:
                'Your portfolio does not have enough available capacity.',
            insufficient_funds:
                'You do not have enough money in your bank account.',

            database_error:
                'The request could not be saved.',
            purchase_failed:
                'The acquisition could not be completed.',

            not_found:
                'This business could not be found.',
            not_owner:
                'You are no longer the owner of this business.',

            invalid_target:
                'The selected player is invalid.',
            cannot_transfer_self:
                'You cannot transfer a business to yourself.',
            self_transfer:
                'You cannot transfer a business to yourself.',

            target_not_online:
                'The selected player is no longer online.',
            target_too_far:
                'The selected player is no longer nearby.',
            too_far:
                'The selected player is no longer nearby.',

            target_owns_type:
                'The selected player already owns this business type.',
            target_insufficient_reputation:
                'The selected player does not meet the Investor Score requirement.',
            target_portfolio_full:
                'The selected player does not have enough portfolio capacity.',

            active_stock_mission:
                'This business has an active stock delivery.',
            pending_deposit:
                'This business has a pending bank deposit.',
            raid_pending:
                'This business currently has a pending compliance action.',

            browser_closed:
                'The browser is no longer open.',
            nearby_players_unavailable:
                'Nearby players could not be retrieved.',

            ownership_locked:
                'This business is currently being updated. Please try again.',
            transfer_failed:
                'The ownership transfer could not be completed.',
            abandon_failed:
                'The business could not be returned to the Marketplace.',
            unknown:
                'The requested action could not be completed.',
        },

        loading: {
            aria_label: 'Loading brokerage data',
            status: 'LOADING BROKERAGE DATA',
            title: 'Retrieving current listings',
            description: 'Verifying availability and account access',
        },

        help: {
            eyebrow: 'PLATFORM GUIDANCE',
            title: 'Help Center',
            description: 'Learn how listings, eligibility and portfolio ownership work.',
            close_label: 'Close Help Center',

            investor_score: {
                title: 'Investor Score',
                subtitle: 'Your standing within Ledger Capital',
                body_one: 'Investor Score represents your account standing with the brokerage. Increasing your score grants access to additional business categories and higher-tier opportunities.',
                body_two: 'Your current membership status and progress toward the next level are displayed under Your Account.',
            },

            eligibility: {
                title: 'Listing eligibility',
                subtitle: 'How business categories become available',
                body_one: 'Each business category has an Investor Score requirement. Eligible categories can be opened and browsed through the Marketplace.',
                body_two: 'Restricted categories show the score required for access. Their locations remain unavailable until the requirement has been reached.',
            },

            portfolio_weight: {
                title: 'Portfolio weight',
                subtitle: 'Understanding your ownership capacity',
                body_one: 'Every registered business uses part of your portfolio capacity. Higher-tier businesses may carry a greater portfolio weight.',
                body_two: 'A new acquisition cannot be completed if its weight would exceed your available portfolio capacity.',
            },

            acquisition: {
                title: 'Acquiring a business',
                subtitle: 'Reviewing and confirming a listing',
                body_one: 'Select an available listing from the Marketplace or its map marker to review the location, acquisition price, tier and portfolio weight.',
                body_two: 'Each location can have only one registered owner. Your account may hold only one business from each category.',
            },

            transfer: {
                title: 'Transferring ownership',
                subtitle: 'Assigning a business to another player',
                body_one: 'Ownership can be transferred to an eligible nearby player from My Portfolio. The transfer takes effect immediately after confirmation.',
                body_two: 'The recipient must have sufficient portfolio capacity and cannot already own the same business type.',
            },

            relinquish: {
                title: 'Relinquishing a business',
                subtitle: 'Permanently releasing a registered holding',
                body_one: 'Relinquishing ownership permanently removes the business from your portfolio and returns its location to the Marketplace.',
                body_two: 'No acquisition refund is provided, and everything associated with the business is lost. This action cannot be reversed.',
            },

            footer: 'Operational business management is handled through the assigned representative at the business location.',
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

export function tOr(
    key: string,
    fallback: string,
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
                : fallback

    return replaceVariables(value, variables)
}
