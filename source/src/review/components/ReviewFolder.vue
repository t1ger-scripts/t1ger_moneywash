<script setup lang="ts">
import { reviewImages } from '../utils/review.utils'
import { useI18n } from 'vue-i18n'
const { t } = useI18n()
</script>

<template>
    <section
        class="review-folder"
        :aria-label="t('review.folder.label')"
    >
        <img
            class="review-folder-art review-folder-open"
            :src="reviewImages.folderOpen"
            alt=""
            draggable="false"
        />

        <img
            class="review-folder-art review-folder-closed"
            :src="reviewImages.folderClosed"
            alt=""
            draggable="false"
        />
    </section>
</template>