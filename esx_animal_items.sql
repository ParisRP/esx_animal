CREATE TABLE IF NOT EXISTS `owned_animals` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(50) NOT NULL,
    `animals` longtext NOT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `items` (`name`, `label`, `weight`, `rare`, `can_remove`) VALUES
        ('pet_food', 'Pet Food', 1, 0, 1),
        ('pet_water', 'Pet Water', 1, 0, 1);

