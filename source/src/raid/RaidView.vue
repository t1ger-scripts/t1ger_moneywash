<script setup lang="ts">
import './styles/raid.scss'

const sceneImage =
    `${import.meta.env.BASE_URL}images/raid/raid-scene.webp`
</script>

<template>
    <div class="raid-overlay">
        <section
            class="raid-scene"
            role="dialog"
            aria-modal="true"
            aria-label="Police evidence collection"
        >
            <img
                class="raid-scene-image"
                :src="sceneImage"
                alt="Open business safe and evidence bag"
                draggable="false"
            />
        </section>
    </div>
</template>