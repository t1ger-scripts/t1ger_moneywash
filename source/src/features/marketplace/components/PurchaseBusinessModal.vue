<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Building2, ShoppingCart } from '@lucide/vue'
import { useI18n } from 'vue-i18n'

import { usePortalActions } from '@/composables/usePortalActions'
import AppButton from '@/design-system/components/AppButton.vue'
import AppModal from '@/design-system/components/AppModal.vue'
import { useMarketplaceStore } from '@/stores/marketplace.store'
import { formatCurrency } from '@/utils/formatters'

const marketplaceStore = useMarketplaceStore()
const { requestBusinessPurchase } = usePortalActions()
const { locale, t } = useI18n()

const errorMessage = ref('')

const location = computed(
    () => marketplaceStore.purchaseDialogLocation,
)

const formattedPrice = computed(() => {
    if (!location.value) return ''

    return formatCurrency(
        location.value.price,
        marketplaceStore.currencySymbol,
        locale.value,
    )
})

const modalTitle = computed(() =>
    t('portal.purchaseDialog.title', {
        business: location.value?.displayName ?? '',
    }),
)

watch(
    () => marketplaceStore.purchaseDialogLocationId,
    () => {
        errorMessage.value = ''
    },
)

function closeDialog(): void {
    marketplaceStore.closePurchaseDialog()
}

async function confirmPurchase(): Promise<void> {
    const selectedLocation = location.value
    if (!selectedLocation) return

    if (!marketplaceStore.beginPurchase(selectedLocation.id)) {
        return
    }

    errorMessage.value = ''
    let purchaseSucceeded = false

    try {
        const response = await requestBusinessPurchase(
            selectedLocation,
        )

        purchaseSucceeded = response.success

        if (!response.success) {
            errorMessage.value = t(
                'portal.purchaseDialog.failed',
            )
        }
    } finally {
        marketplaceStore.finishPurchase()
    }

    if (purchaseSucceeded) {
        marketplaceStore.closePurchaseDialog()
    }
}
</script>

<template>
    <AppModal :open="marketplaceStore.isPurchaseDialogOpen" :title="modalTitle"
        :eyebrow="t('portal.purchaseDialog.eyebrow')" :close-label="t('common.close')" @close="closeDialog">
        <div v-if="location" class="purchase-dialog">
            <div class="purchase-dialog__icon">
                <Building2 :size="30" aria-hidden="true" />
            </div>

            <p>
                {{
                    t('portal.purchaseDialog.confirmation', {
                        business: location.displayName,
                    })
                }}
            </p>

            <div class="purchase-dialog__summary">
                <span>{{ t('portal.purchaseDialog.price') }}</span>
                <strong>{{ formattedPrice }}</strong>
            </div>

            <p class="purchase-dialog__notice">
                {{ t('portal.purchaseDialog.notice') }}
            </p>

            <p v-if="errorMessage" class="purchase-dialog__error" role="alert">
                {{ errorMessage }}
            </p>
        </div>

        <template #footer>
            <AppButton variant="secondary" :disabled="marketplaceStore.isPurchasePending" @click="closeDialog">
                {{ t('common.cancel') }}
            </AppButton>

            <AppButton :loading="marketplaceStore.isPurchasePending" @click="confirmPurchase">
                <ShoppingCart :size="18" aria-hidden="true" />
                {{ t('portal.purchaseDialog.confirm') }}
            </AppButton>
        </template>
    </AppModal>
</template>

<style scoped lang="scss">
.purchase-dialog {
    display: grid;
    justify-items: center;
    gap: var(--space-4);
    text-align: center;

    &__icon {
        display: grid;
        width: 4rem;
        height: 4rem;
        place-items: center;
        border-radius: 50%;
        color: var(--color-primary);
        background: var(--color-primary-subtle);
    }

    p {
        color: var(--color-text-secondary);
        font-size: var(--font-size-sm);
        line-height: var(--line-height-normal);
    }

    &__summary {
        display: flex;
        width: 100%;
        align-items: center;
        justify-content: space-between;
        gap: var(--space-4);
        padding: var(--space-4);
        border: var(--border-width) solid var(--color-border-strong);
        border-radius: var(--radius-md);
        background: var(--color-surface-raised);

        span {
            color: var(--color-text-secondary);
        }

        strong {
            color: var(--color-primary-hover);
            font-size: var(--font-size-xl);
        }
    }

    &__notice {
        font-size: var(--font-size-xs) !important;
    }

    &__error {
        color: var(--color-danger) !important;
    }
}
</style>