-- ============================================================
-- T1GER Money Wash - Installation SQL
-- Run this file once on first installation
-- ============================================================

-- Player reputation
CREATE TABLE IF NOT EXISTS `moneywash_reputation` (
    `id`           INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`   VARCHAR(100) NOT NULL,               -- player identifier (license)
    `points`       INT(11)      NOT NULL DEFAULT 0,      -- total reputation points
    `total_washed` BIGINT(20)   NOT NULL DEFAULT 0,      -- lifetime dirty money laundered
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
);

-- Business ownership and live state
-- Note: cycle tracking (totalLaundered) resets globally on each server cycle tick
-- cycle_started_at is NOT stored here - it lives in server memory only
CREATE TABLE IF NOT EXISTS `moneywash_businesses` (
    `id`                INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`        VARCHAR(100) NOT NULL,               -- owner player identifier
    `business_type`     VARCHAR(50)  NOT NULL,               -- matches type key in business_locations.lua
    `location_id`       INT(11)      NOT NULL,               -- matches id key in business_locations.lua
    `stock`             INT(11)      NOT NULL DEFAULT 0,      -- current stock units held
    `safe_covered`      BIGINT(20)   NOT NULL DEFAULT 0,      -- clean covered funds in Safe
    `safe_exposed`      BIGINT(20)   NOT NULL DEFAULT 0,      -- clean exposed funds in Safe
    `suspicion`         FLOAT        NOT NULL DEFAULT 0,      -- current suspicion value (0-100)
    `total_laundered`   BIGINT(20)   NOT NULL DEFAULT 0,      -- gross amount laundered this cycle (resets each cycle)
    `last_laundered_at` BIGINT(20)   NOT NULL DEFAULT 0,      -- unix timestamp of last launder action (for decay inactivity check)
    `is_closed`         TINYINT(1)   NOT NULL DEFAULT 0,      -- 1 = temporarily closed after raid escalation
    `closed_until`      BIGINT(20)            DEFAULT NULL,   -- unix timestamp closure ends
    `purchased_at`      BIGINT(20)   NOT NULL DEFAULT 0,      -- unix timestamp of purchase
    PRIMARY KEY (`id`),
    UNIQUE KEY `location` (`business_type`, `location_id`)    -- enforces one owner per location
);

-- Stock purchase receipts (deleted when consumed in accountant review)
CREATE TABLE IF NOT EXISTS `moneywash_receipts` (
    `id`           INT(11)    NOT NULL AUTO_INCREMENT,
    `business_id`  INT(11)    NOT NULL,                  -- references moneywash_businesses.id
    `units`        INT(11)    NOT NULL,                  -- units delivered
    `unit_price`   INT(11)    NOT NULL,                  -- price per unit at time of purchase
    `total_amount` INT(11)    NOT NULL,                  -- total clean money paid
    `created_at`   BIGINT(20) NOT NULL,                  -- unix timestamp of delivery completion
    PRIMARY KEY (`id`),
    KEY `business_id` (`business_id`)
);

-- Raid history per location (independent of ownership changes)
CREATE TABLE IF NOT EXISTS `moneywash_raid_history` (
    `id`            INT(11)     NOT NULL AUTO_INCREMENT,
    `business_type` VARCHAR(50) NOT NULL,                -- business type key
    `location_id`   INT(11)     NOT NULL,                -- location id
    `raided_at`     BIGINT(20)  NOT NULL,                -- unix timestamp of raid
    PRIMARY KEY (`id`),
    KEY `location` (`business_type`, `location_id`)
);

-- Pending bank deposits
CREATE TABLE IF NOT EXISTS `moneywash_deposits` (
    `id`             INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`     VARCHAR(100) NOT NULL,              -- player identifier
    `business_id`    INT(11)      NOT NULL,              -- source business
    `total_amount`   BIGINT(20)   NOT NULL,              -- total deposit amount
    `covered_amount` BIGINT(20)   NOT NULL DEFAULT 0,    -- covered portion of this deposit
    `exposed_amount` BIGINT(20)   NOT NULL DEFAULT 0,    -- exposed portion of this deposit
    `flagged`        TINYINT(1)   NOT NULL DEFAULT 0,    -- 1 = flagged for police review
    `initiated_at`   BIGINT(20)   NOT NULL,              -- unix timestamp deposit started
    `clears_at`      BIGINT(20)   NOT NULL,              -- unix timestamp deposit clears
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)               -- one pending deposit per player at a time
);