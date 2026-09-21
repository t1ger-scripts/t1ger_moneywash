import { createApp } from 'vue'

import '@fontsource-variable/inter'
import '@/design-system/styles/main.scss'

import App from '@/App.vue'
import { installApplication } from '@/app/bootstrap'

const app = createApp(App)

installApplication(app)
app.mount('#app')