USE `essentialmode`;

ALTER TABLE `users`
	ADD COLUMN `current_character_id` int(11) NULL
;

ALTER TABLE `characters` 
	ADD COLUMN `skin` LONGTEXT NULL
);

UPDATE `characters`
   SET `skin` = (SELECT `skin`
                   FROM `users`
                  WHERE `users`.`identifier` = `characters`.`identifier`)
 WHERE `skin` IS NULL;