<template>
    <div class="bootstrap-layout" aria-label="Loading brokerage data">
        <aside class="bootstrap-sidebar">
            <div class="bootstrap-brand">
                <span class="skeleton skeleton-logo" />
                <div>
                    <span class="skeleton skeleton-line brand-long" />
                    <span class="skeleton skeleton-line brand-short" />
                </div>
            </div>

            <div class="bootstrap-navigation">
                <span class="skeleton skeleton-nav" />
                <span class="skeleton skeleton-nav" />
            </div>

            <div class="bootstrap-account">
                <span class="skeleton skeleton-label" />
                <span class="skeleton skeleton-line account-name" />
                <span class="skeleton skeleton-line account-status" />

                <span class="skeleton skeleton-metric" />
                <span class="skeleton skeleton-progress" />

                <span class="skeleton skeleton-metric" />
                <div class="bootstrap-weight">
                    <span v-for="index in 6" :key="index" class="skeleton" />
                </div>
            </div>
        </aside>

        <main class="bootstrap-main">
            <header class="bootstrap-header">
                <div>
                    <span class="skeleton skeleton-label" />
                    <span class="skeleton skeleton-heading" />
                    <span class="skeleton skeleton-description" />
                </div>
            </header>

            <div class="bootstrap-tiers">
                <span v-for="index in 9" :key="index" class="skeleton skeleton-tier" />
            </div>

            <div class="bootstrap-workspace">
                <section class="bootstrap-list">
                    <div class="bootstrap-list-header">
                        <div>
                            <span class="skeleton skeleton-label" />
                            <span class="skeleton skeleton-count" />
                        </div>

                        <span class="skeleton skeleton-search" />
                    </div>

                    <div class="bootstrap-cards">
                        <div v-for="index in 6" :key="index" class="skeleton-listing">
                            <span class="skeleton skeleton-listing-icon" />

                            <div class="bootstrap-listing-copy">
                                <span class="skeleton skeleton-listing-title" />
                                <span class="skeleton skeleton-listing-location" />
                            </div>

                            <div class="bootstrap-listing-price">
                                <span class="skeleton skeleton-price" />
                                <span class="skeleton skeleton-weight" />
                            </div>
                        </div>
                    </div>
                </section>

                <section class="bootstrap-map">
                    <div class="bootstrap-map-status">
                        <span class="loading-pulse" />
                        <span>LOADING BROKERAGE DATA</span>
                    </div>

                    <div class="bootstrap-map-center">
                        <span class="bootstrap-spinner" />
                        <strong>Retrieving current listings</strong>
                        <small>Verifying availability and account access</small>
                    </div>
                </section>
            </div>
        </main>
    </div>
</template>