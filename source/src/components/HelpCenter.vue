<script setup lang="ts">
import { onBeforeUnmount, onMounted } from 'vue'
import {
    ArrowRightLeft,
    BriefcaseBusiness,
    Building2,
    ChevronDown,
    CircleHelp,
    ShieldCheck,
    TriangleAlert,
    X,
} from '@lucide/vue'

const emit = defineEmits<{
    close: []
}>()

function handleEscape(event: KeyboardEvent) {
    if (event.key !== 'Escape') return

    event.preventDefault()
    event.stopImmediatePropagation()
    emit('close')
}

onMounted(() => {
    window.addEventListener('keydown', handleEscape, true)
})

onBeforeUnmount(() => {
    window.removeEventListener('keydown', handleEscape, true)
})
</script>

<template>
    <div class="help-center-backdrop" @click.self="emit('close')">
        <section class="help-center-modal" role="dialog" aria-modal="true" aria-labelledby="help-center-title">
            <header class="help-center-header">
                <div>
                    <span class="eyebrow">PLATFORM GUIDANCE</span>
                    <h2 id="help-center-title">Help Center</h2>
                    <p>
                        Learn how listings, eligibility and portfolio ownership work.
                    </p>
                </div>

                <button type="button" class="modal-close" aria-label="Close Help Center" @click="emit('close')">
                    <X :size="16" />
                </button>
            </header>

            <div class="help-topic-list">
                <details class="help-topic" open>
                    <summary>
                        <span class="help-topic-icon">
                            <ShieldCheck :size="17" />
                        </span>

                        <span>
                            <strong>Investor Score</strong>
                            <small>Your standing within Ledger Capital</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Investor Score represents your account standing with the
                            brokerage. Increasing your score grants access to additional
                            business categories and higher-tier opportunities.
                        </p>

                        <p>
                            Your current membership status and progress toward the next
                            level are displayed under Your Account.
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <CircleHelp :size="17" />
                        </span>

                        <span>
                            <strong>Listing eligibility</strong>
                            <small>How business categories become available</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Each business category has an Investor Score requirement.
                            Eligible categories can be opened and browsed through the
                            Marketplace.
                        </p>

                        <p>
                            Restricted categories show the score required for access.
                            Their locations remain unavailable until the requirement has
                            been reached.
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <BriefcaseBusiness :size="17" />
                        </span>

                        <span>
                            <strong>Portfolio weight</strong>
                            <small>Understanding your ownership capacity</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Every registered business uses part of your portfolio capacity.
                            Higher-tier businesses may carry a greater portfolio weight.
                        </p>

                        <p>
                            A new acquisition cannot be completed if its weight would
                            exceed your available portfolio capacity.
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <Building2 :size="17" />
                        </span>

                        <span>
                            <strong>Acquiring a business</strong>
                            <small>Reviewing and confirming a listing</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Select an available listing from the Marketplace or its map
                            marker to review the location, acquisition price, tier and
                            portfolio weight.
                        </p>

                        <p>
                            Each location can have only one registered owner. Your account
                            may hold only one business from each category.
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <ArrowRightLeft :size="17" />
                        </span>

                        <span>
                            <strong>Transferring ownership</strong>
                            <small>Assigning a business to another player</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Ownership can be transferred to an eligible nearby player from
                            My Portfolio. The transfer takes effect immediately after
                            confirmation.
                        </p>

                        <p>
                            The recipient must have sufficient portfolio capacity and
                            cannot already own the same business type.
                        </p>
                    </div>
                </details>

                <details class="help-topic danger">
                    <summary>
                        <span class="help-topic-icon">
                            <TriangleAlert :size="17" />
                        </span>

                        <span>
                            <strong>Relinquishing a business</strong>
                            <small>Permanently releasing a registered holding</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            Relinquishing ownership permanently removes the business from
                            your portfolio and returns its location to the Marketplace.
                        </p>

                        <p>
                            No acquisition refund is provided, and everything associated
                            with the business is lost. This action cannot be reversed.
                        </p>
                    </div>
                </details>
            </div>

            <footer class="help-center-footer">
                <CircleHelp :size="15" />

                <span>
                    Operational business management is handled through the assigned
                    representative at the business location.
                </span>
            </footer>
        </section>
    </div>
</template>