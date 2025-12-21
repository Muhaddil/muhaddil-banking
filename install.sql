-- Muhaddil Bank System - Database Installation
-- Execute this file to manually create all required tables

-- Table: bank_accounts
CREATE TABLE IF NOT EXISTS `bank_accounts` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `owner` VARCHAR(50) NOT NULL,
    `account_name` VARCHAR(100) NOT NULL,
    `balance` DECIMAL(20,2) DEFAULT 0.00,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table: bank_shared_access
CREATE TABLE IF NOT EXISTS `bank_shared_access` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT NOT NULL,
    `user_identifier` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
    INDEX(`account_id`),
    INDEX(`user_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table: bank_transactions
CREATE TABLE IF NOT EXISTS `bank_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `account_id` INT NOT NULL,
    `type` VARCHAR(50) NOT NULL,
    `amount` DECIMAL(20,2) NOT NULL,
    `description` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
    INDEX(`account_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table: bank_loans
CREATE TABLE IF NOT EXISTS `bank_loans` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `user_identifier` VARCHAR(50) NOT NULL,
    `amount` DECIMAL(20,2) NOT NULL,
    `remaining` DECIMAL(20,2) NOT NULL,
    `interest_rate` DECIMAL(5,2) NOT NULL,
    `installments` INT NOT NULL,
    `status` VARCHAR(20) DEFAULT 'active',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(`user_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table: bank_ownership
CREATE TABLE IF NOT EXISTS `bank_ownership` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `owner` VARCHAR(50) NOT NULL,
    `bank_name` VARCHAR(100) NOT NULL,
    `commission_rate` DECIMAL(5,4) DEFAULT 0.0100,
    `total_earned` DECIMAL(20,2) DEFAULT 0.00,
    `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX(`owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;