SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL';

CREATE SCHEMA IF NOT EXISTS `chisel` DEFAULT CHARACTER SET utf8 ;
USE `chisel` ;

-- -----------------------------------------------------
-- Table `chisel`.`logs`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `chisel`.`logs` (
  `time` DATETIME NOT NULL ,
  `node` INT(11)  NOT NULL ,
  `code` INT(11)  NOT NULL ,
  `script` INT(11)  NOT NULL ,
  `runtime` INT(11)  NOT NULL ,
  `version` INT(11)  NOT NULL DEFAULT 0 ,
  `fail` TINYINT NOT NULL ,
  PRIMARY KEY (`node`, `script`, `fail`) ,
  INDEX `node_time` (`node` ASC, `time` ASC) ,
  INDEX `node_script_time` (`node` ASC, `script` ASC, `time` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `chisel`.`nodes`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `chisel`.`nodes` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT ,
  `node` VARCHAR(140) NOT NULL ,
  `created` DATETIME NULL ,
  `chisel_client` VARCHAR(45) NULL ,
  `chisel_client_sync` VARCHAR(45) NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `node` (`node` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `chisel`.`scripts`
-- -----------------------------------------------------
CREATE  TABLE IF NOT EXISTS `chisel`.`scripts` (
  `id` INT(11)  NOT NULL AUTO_INCREMENT ,
  `script` VARCHAR(80) NOT NULL ,
  PRIMARY KEY (`id`) ,
  UNIQUE INDEX `script` (`script` ASC) )
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Placeholder table for view `chisel`.`logs_3hr`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `chisel`.`logs_3hr` (`node` INT, `script` INT, `time` INT);

-- -----------------------------------------------------
-- Placeholder table for view `chisel`.`fresh_report`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `chisel`.`fresh_report` (`id` INT, `node` INT, `scripts` INT, `scripts_broken` INT, `chisel_client` INT, `chisel_client_sync` INT, `time` INT);

-- -----------------------------------------------------
-- Placeholder table for view `chisel`.`logs_node_max`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `chisel`.`logs_node_max` (`node` INT, `time` INT);

-- -----------------------------------------------------
-- Placeholder table for view `chisel`.`stale_report`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `chisel`.`stale_report` (`id` INT, `node` INT, `time` INT);

-- -----------------------------------------------------
-- View `chisel`.`logs_3hr`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `chisel`.`logs_3hr`;
USE `chisel`;
create or replace view `logs_3hr` as select `logs`.`node` AS `node`,`logs`.`script` AS `script`,max(`logs`.`time`) AS `time` from `logs` where (`logs`.`time` > subtime(now(),'03:00:00')) group by `logs`.`node`,`logs`.`script`;

-- -----------------------------------------------------
-- View `chisel`.`fresh_report`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `chisel`.`fresh_report`;
USE `chisel`;
create or replace view `fresh_report` AS select `n1`.`id` AS `id`,`n1`.`node` AS `node`,count(`l1`.`script`) AS `scripts`,group_concat(if(`l1`.`code`,`s1`.`script`,NULL) separator ',') AS `scripts_broken`,`n1`.`chisel_client` AS `chisel_client`,`n1`.`chisel_client_sync` AS `chisel_client_sync`,max(`l1`.`time`) AS `time` from ((`nodes` `n1` join (`logs` `l1` join `logs_3hr` `tmp` on(((`l1`.`time` = `tmp`.`time`) and (`l1`.`node` = `tmp`.`node`) and (`l1`.`script` = `tmp`.`script`)))) on((`n1`.`id` = `l1`.`node`))) left join `scripts` `s1` on((`s1`.`id` = `l1`.`script`))) group by `n1`.`id` order by `n1`.`node`;

-- -----------------------------------------------------
-- View `chisel`.`logs_node_max`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `chisel`.`logs_node_max`;
USE `chisel`;
create or replace VIEW `logs_node_max` AS select `logs`.`node` AS `node`,max(`logs`.`time`) AS `time` from `logs` group by `logs`.`node` having (not(`logs`.`node` in (select `fresh_report`.`id` AS `id` from `fresh_report`)));

-- -----------------------------------------------------
-- View `chisel`.`stale_report`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `chisel`.`stale_report`;
USE `chisel`;
create or replace view `stale_report` as select `n`.`id` AS `id`,`n`.`node` AS `node`,`tmp`.`time` AS `time` from (`logs_node_max` `tmp` join `nodes` `n` on((`n`.`id` = `tmp`.`node`))) order by `tmp`.`time`
;


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
