import { createI18n } from 'vue-i18n'

import type { LocaleMessages } from './localization.types'

const fallbackMessages: LocaleMessages = {
    common: {
        close: 'Close',
        cancel: 'Cancel',
        loading: 'Loading...',
    },
}

export const i18n = createI18n<
    [LocaleMessages],
    string,
    false
>({
    legacy: false,
    locale: 'en',
    fallbackLocale: 'en',

    messages: {
        en: fallbackMessages,
    },

    missingWarn: import.meta.env.DEV,
    fallbackWarn: import.meta.env.DEV,
})

export function installLocaleMessages(
    locale: string,
    messages: LocaleMessages,
): void {
    i18n.global.setLocaleMessage(locale, messages)
    i18n.global.locale.value = locale
}