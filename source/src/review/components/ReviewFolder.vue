<script setup lang="ts">
import { reviewImages } from '../utils/review.utils'
</script>

<template>
    <section
        class="review-folder"
        aria-label="Filing and sealing the prepared books"
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