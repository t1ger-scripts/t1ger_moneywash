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
import { t } from '@/lib/locale'

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
                    <span class="eyebrow">{{ t('browser.help.eyebrow') }}</span>
                    <h2 id="help-center-title">{{ t('browser.help.title') }}</h2>
                    <p>
                        {{ t('browser.help.description') }}
                    </p>
                </div>

                <button type="button" class="modal-close" :aria-label="t('browser.help.close_label')"
                    @click="emit('close')">
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
                            <strong>{{ t('browser.help.investor_score.title') }}</strong>
                            <small>{{ t('browser.help.investor_score.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.investor_score.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.investor_score.body_two') }}
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <CircleHelp :size="17" />
                        </span>

                        <span>
                            <strong>{{ t('browser.help.eligibility.title') }}</strong>
                            <small>{{ t('browser.help.eligibility.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.eligibility.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.eligibility.body_two') }}
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <BriefcaseBusiness :size="17" />
                        </span>

                        <span>
                            <strong>{{ t('browser.help.portfolio_weight.title') }}</strong>
                            <small>{{ t('browser.help.portfolio_weight.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.portfolio_weight.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.portfolio_weight.body_two') }}
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <Building2 :size="17" />
                        </span>

                        <span>
                            <strong>{{ t('browser.help.acquisition.title') }}</strong>
                            <small>{{ t('browser.help.acquisition.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.acquisition.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.acquisition.body_two') }}
                        </p>
                    </div>
                </details>

                <details class="help-topic">
                    <summary>
                        <span class="help-topic-icon">
                            <ArrowRightLeft :size="17" />
                        </span>

                        <span>
                            <strong>{{ t('browser.help.transfer.title') }}</strong>
                            <small>{{ t('browser.help.transfer.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.transfer.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.transfer.body_two') }}
                        </p>
                    </div>
                </details>

                <details class="help-topic danger">
                    <summary>
                        <span class="help-topic-icon">
                            <TriangleAlert :size="17" />
                        </span>

                        <span>
                            <strong>{{ t('browser.help.relinquish.title') }}</strong>
                            <small>{{ t('browser.help.relinquish.subtitle') }}</small>
                        </span>

                        <ChevronDown :size="15" class="help-topic-chevron" />
                    </summary>

                    <div class="help-topic-content">
                        <p>
                            {{ t('browser.help.relinquish.body_one') }}
                        </p>

                        <p>
                            {{ t('browser.help.relinquish.body_two') }}
                        </p>
                    </div>
                </details>
            </div>

            <footer class="help-center-footer">
                <CircleHelp :size="15" />

                <span>
                    {{ t('browser.help.footer') }}
                </span>
            </footer>
        </section>
    </div>
</template>
