import { createPinia } from 'pinia'
import type { App } from 'vue'

import { i18n } from '@/integrations/localization/i18n'

export function installApplication(app: App): void {
    app.use(createPinia())
    app.use(i18n)
}