<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { Building2, ShoppingCart } from '@lucide/vue'
import { useI18n } from 'vue-i18n'
import { failureMessage } from '@/integrations/i18n'
import { usePortalActions } from '@/portal/composables/usePortalActions'
import { usePortalFormat } from '@/portal/composables/usePortalFormat'
import AppButton from '@/portal/components/ui/AppButton.vue'
import AppModal from '@/portal/components/ui/AppModal.vue'
import { usePortalStore } from '@/portal/stores/portal.store'

const portalStore = usePortalStore()
const { requestBusinessPurchase } = usePortalActions()
const { t } = useI18n()
const { formatMoney } = usePortalFormat()

const errorMessage = ref('')

const location = computed(
    () => portalStore.purchaseDialogLocation,
)

const formattedPrice = computed(() => {
    if (!location.value) return ''

    return formatMoney(location.value.price)
})

const modalTitle = computed(() =>
    t('portal.purchaseDialog.title', {
        business: location.value?.displayName ?? '',
    }),
)

watch(
    () => portalStore.purchaseDialogLocationKey,
    () => {
        errorMessage.value = ''
    },
)

function closeDialog(): void {
    portalStore.closePurchaseDialog()
}

async function confirmPurchase(): Promise<void> {
    const selectedLocation = location.value
    if (!selectedLocation) return

    if (!portalStore.beginPurchase(selectedLocation.key)) {
        return
    }

    errorMessage.value = ''

    // requestBusinessPurchase never throws: a failed request comes back as a failed response.
    const response = await requestBusinessPurchase(selectedLocation)

    portalStore.finishPurchase()

    if (response.success) {
        portalStore.closePurchaseDialog()
    } else {
        errorMessage.value = failureMessage(response)
    }
}
</script>

<template>
    <AppModal :open="portalStore.isPurchaseDialogOpen" :title="modalTitle"
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
            <AppButton variant="secondary" :disabled="portalStore.isPurchasePending" @click="closeDialog">
                {{ t('common.cancel') }}
            </AppButton>

            <AppButton :loading="portalStore.isPurchasePending" @click="confirmPurchase">
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