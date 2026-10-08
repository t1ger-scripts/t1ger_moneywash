import { createApp } from 'vue'
import { createPinia } from 'pinia'

import '@fontsource-variable/inter'
import 'leaflet/dist/leaflet.css'
import '@/portal/styles/portal.scss'

import App from '@/App.vue'
import { i18n } from '@/integrations/i18n'

const app = createApp(App)

app.use(createPinia())
app.use(i18n)

app.mount('#app')