<template>
    <div class="app-surface">
        <slot />
    </div>
</template>

<style scoped lang="scss">
.app-surface {
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-lg);
    background: var(--color-surface);
}
</style>