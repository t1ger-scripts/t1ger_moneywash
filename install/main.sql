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
CREATE TABLE IF NOT EXISTS `moneywash_businesses` (
    `id`                INT(11)      NOT NULL AUTO_INCREMENT,
    `identifier`        VARCHAR(100) NOT NULL,               -- owner player identifier
    `business_type`     VARCHAR(50)  NOT NULL,               -- matches type key in business_locations.lua
    `location_id`       INT(11)      NOT NULL,               -- matches id key in business_locations.lua
    `location_x`        DECIMAL(12,6) NOT NULL,              -- immutable purchased-location snapshot
    `location_y`        DECIMAL(12,6) NOT NULL,
    `location_z`        DECIMAL(12,6) NOT NULL,
    `stock`             INT(11)      NOT NULL DEFAULT 0,      -- current stock units held
    `safe_covered`      BIGINT(20)   NOT NULL DEFAULT 0,      -- clean covered funds in Safe
    `safe_exposed`      BIGINT(20)   NOT NULL DEFAULT 0,      -- clean exposed funds in Safe
    `suspicion`         FLOAT        NOT NULL DEFAULT 0,      -- current suspicion value (0-100)
    `total_laundered`   BIGINT(20)   NOT NULL DEFAULT 0,      -- gross amount ever laundered
    `purchased_at`      BIGINT(20)   NOT NULL DEFAULT 0,      -- unix timestamp of purchase
    PRIMARY KEY (`id`),
    UNIQUE KEY `owner` (`identifier`),                          -- one business per player
    UNIQUE KEY `business_location` (`business_type`, `location_id`) -- one owner per location
);

-- Stock purchase receipts
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