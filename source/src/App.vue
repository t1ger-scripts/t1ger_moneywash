<template>
  <main class="design-system-preview">
    <section class="design-system-preview__card">
      <span class="design-system-preview__badge">
        Design system ready
      </span>

      <h1>Los Santos Business Portal</h1>

      <p>
        Commercial opportunities, verified ownership and secure acquisitions.
      </p>
    </section>
  </main>
</template>

<style scoped lang="scss">
.design-system-preview {
  display: grid;
  width: 100%;
  height: 100%;
  padding: var(--space-6);
  place-items: center;
  background: var(--color-background);

  &__card {
    width: min(42rem, 100%);
    padding: var(--space-8);
    border: var(--border-width) solid var(--color-border);
    border-radius: var(--radius-lg);
    background: var(--color-surface);
    box-shadow: var(--shadow-surface);
    text-align: center;
  }

  &__badge {
    display: inline-flex;
    min-height: 1.75rem;
    align-items: center;
    margin-bottom: var(--space-4);
    padding: 0 var(--space-3);
    border: var(--border-width) solid var(--color-primary);
    border-radius: var(--radius-pill);
    background: var(--color-primary-subtle);
    color: var(--color-primary-hover);
    font-size: var(--font-size-xs);
    font-weight: var(--font-weight-semibold);
  }

  p {
    margin-top: var(--space-3);
    color: var(--color-text-secondary);
  }
}
</style>