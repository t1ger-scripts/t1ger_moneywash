DROP TABLE IF EXISTS `t1ger_moneywash`;
CREATE TABLE `t1ger_moneywash` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`identifier` VARCHAR(100) NOT NULL, -- Player Identifier
	`points` INT(11) NOT NULL DEFAULT 0, -- Reputation Experience
	`contracts` INT(11) NOT NULL DEFAULT 0, -- Number of street contracts completed
	`total_washed` BIGINT(20) NOT NULL DEFAULT 0, -- Lifetime amount of dirty money laundered
	PRIMARY KEY (`id`)
);