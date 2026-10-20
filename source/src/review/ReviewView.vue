<script setup lang="ts">
import { reviewImages } from './utils/review.utils'
import './styles/review.scss'
</script>

<template>
    <div class="review-overlay">
        <section
            class="review-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Review business books"
            tabindex="-1"
        >
            <img
                class="review-scene-image"
                :src="reviewImages.scene"
                alt=""
                draggable="false"
            />
        </section>
    </div>
</template>