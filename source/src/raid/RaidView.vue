<script setup lang="ts">
import RaidCashStacks from './components/RaidCashStacks.vue'
import { raidImages } from './utils/raid.utils'
import './styles/raid.scss'
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
                :src="raidImages.scene"
                alt="Open business safe and evidence bag"
                draggable="false"
            />

            <RaidCashStacks :count="10" />
        </section>
    </div>
</template>