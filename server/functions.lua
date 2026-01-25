local ESX = nil
local QBCore = nil
local ESXVer = Config.ESXVer
local FrameWork = nil

if Config.FrameWork == "auto" then
    if GetResourceState('es_extended') == 'started' then
        if ESXVer == 'new' then
            ESX = exports['es_extended']:getSharedObject()
            FrameWork = 'esx'
        else
            ESX = nil
            while ESX == nil do
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Citizen.Wait(0)
            end
        end
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        FrameWork = 'qb'
    else
        print('===NO SUPPORTED FRAMEWORK FOUND===')
    end
elseif Config.FrameWork == "esx" and GetResourceState('es_extended') == 'started' then
    if ESXVer == 'new' then
        ESX = exports['es_extended']:getSharedObject()
        FrameWork = 'esx'
    else
        ESX = nil
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Citizen.Wait(0)
        end
    end
elseif Config.FrameWork == "qb" and GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    FrameWork = 'qb'
else
    print('===NO SUPPORTED FRAMEWORK FOUND===')
end

MySQL.ready(function()
    local queries = {
        [[
            CREATE TABLE IF NOT EXISTS `bank_accounts` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `owner` VARCHAR(50) NOT NULL,
                `account_name` VARCHAR(100) NOT NULL,
                `balance` DECIMAL(20,2) DEFAULT 0.00,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(`owner`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_shared_access` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `account_id` INT NOT NULL,
                `user_identifier` VARCHAR(50) NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`account_id`),
                INDEX(`user_identifier`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_transactions` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `account_id` INT NOT NULL,
                `type` VARCHAR(50) NOT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `description` TEXT,
                `bank_location` VARCHAR(50) DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`account_id`),
                INDEX(`bank_location`)
            )
        ]],
        [[
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
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_ownership` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `bank_id` VARCHAR(50) NOT NULL UNIQUE,
                `owner` VARCHAR(50) NOT NULL,
                `bank_name` VARCHAR(100) NOT NULL,
                `commission_rate` DECIMAL(5,4) DEFAULT 0.0100,
                `total_earned` DECIMAL(20,2) DEFAULT 0.00,
                `pending_earnings` DECIMAL(20,2) DEFAULT 0.00,
                `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(`owner`),
                INDEX(`bank_id`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_cards` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `account_id` INT NOT NULL,
                `owner` VARCHAR(50) NOT NULL,
                `card_number` VARCHAR(20) NOT NULL,
                `pin` VARCHAR(4) NOT NULL,
                `is_blocked` TINYINT(1) DEFAULT 0,
                `failed_attempts` INT DEFAULT 0,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`owner`),
                INDEX(`card_number`)
            )
        ]]
    }

    for _, query in ipairs(queries) do
        MySQL.query.await(query)
    end

    local bankOwnershipHasBankId = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'bank_ownership'
          AND COLUMN_NAME = 'bank_id'
    ]])

    if tonumber(bankOwnershipHasBankId) == 0 then
        MySQL.query.await('ALTER TABLE bank_ownership ADD COLUMN bank_id VARCHAR(50) NULL')
        MySQL.query.await('ALTER TABLE bank_ownership ADD UNIQUE KEY bank_id_unique (bank_id)')
        for _, bank in ipairs(Config.BankLocations) do
            MySQL.query.await('UPDATE bank_ownership SET bank_id = ? WHERE bank_id IS NULL AND bank_name = ?',
                { bank.id, bank.name })
        end
    end

    local bankTransactionsHasBankLocation = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'bank_transactions'
          AND COLUMN_NAME = 'bank_location'
    ]])

    if tonumber(bankTransactionsHasBankLocation) == 0 then
        MySQL.query.await('ALTER TABLE bank_transactions ADD COLUMN bank_location VARCHAR(50) DEFAULT NULL')
        MySQL.query.await('CREATE INDEX bank_location_idx ON bank_transactions (bank_location)')
    end

    print('^2[Bank System] Database initialized successfully^7')
end)

function Notify(source, type, message)
    TriggerClientEvent('muhaddil_bank:notify', source, type, message)
end

function GetPlayer(source)
    if FrameWork == 'esx' then
        return ESX.GetPlayerFromId(source)
    elseif FrameWork == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    end
end

function AddPlayerBankMoney(source, amount)
    if FrameWork == 'esx' then
        local xPlayer = GetPlayer(source)
        xPlayer.addAccountMoney('bank', amount)
    elseif FrameWork == 'qb' then
        local xPlayer = GetPlayer(source)
        xPlayer.Functions.AddMoney('bank', amount)
    end
end

function RemovePlayerBankMoney(source, amount)
    if FrameWork == 'esx' then
        local xPlayer = GetPlayer(source)
        xPlayer.removeAccountMoney('bank', amount)
    elseif FrameWork == 'qb' then
        local xPlayer = GetPlayer(source)
        xPlayer.Functions.RemoveMoney('bank', amount)
    end
end

function GetPlayerIdentifier(source)
    if FrameWork == "esx" then
        local xPlayer = GetPlayer(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameWork == "qb" then
        local Player = GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
end

function GetPlayerMoney(source)
    if FrameWork == "esx" then
        local xPlayer = GetPlayer(source)
        return xPlayer and xPlayer.getMoney() or 0
    elseif FrameWork == "qb" then
        local Player = GetPlayer(source)
        return Player and Player.PlayerData.money.cash or 0
    end
end

function GetPlayerBankMoney(source)
    if FrameWork == "esx" then
        local xPlayer = GetPlayer(source)
        return xPlayer and xPlayer.getAccount('bank').money or 0
    elseif FrameWork == "qb" then
        local Player = GetPlayer(source)
        return Player and Player.PlayerData.money.bank or 0
    end
end

function AddPlayerMoney(source, amount)
    if FrameWork == "esx" then
        local xPlayer = GetPlayer(source)
        if xPlayer then
            xPlayer.addMoney(amount)
            return true
        end
    elseif FrameWork == "qb" then
        local Player = GetPlayer(source)
        if Player then
            Player.Functions.AddMoney('cash', amount)
            return true
        end
    end
    return false
end

function RemovePlayerMoney(source, amount)
    if FrameWork == "esx" then
        local xPlayer = GetPlayer(source)
        if xPlayer then
            if xPlayer.getMoney() >= amount then
                xPlayer.removeMoney(amount)
                return true
            end
        end
    elseif FrameWork == "qb" then
        local Player = GetPlayer(source)
        if Player then
            if Player.PlayerData.money.cash >= amount then
                Player.Functions.RemoveMoney('cash', amount)
                return true
            end
        end
    end
    return false
end

function ApplyBankCommission(bankId, transactionAmount)
    if not Config.BankOwnership.Enabled then return end

    local bank = MySQL.single.await('SELECT * FROM bank_ownership WHERE bank_id = ?', { bankId })
    if not bank then return end

    local commission = math.floor(transactionAmount * tonumber(bank.commission_rate))
    if commission > 0 then
        MySQL.query.await([[
            UPDATE bank_ownership
            SET pending_earnings = pending_earnings + ?,
                total_earned = total_earned + ?
            WHERE bank_id = ?
        ]], { commission, commission, bankId })
    end
end

function hasPermission(src)
    if FrameWork == 'qb' then
        for _, group in ipairs(Config.AllowedGroups.qb) do
            if QBCore.Functions.HasPermission(src, group) then
                return true
            end
        end
    end

    if FrameWork == 'esx' then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            for _, group in ipairs(Config.AllowedGroups.esx) do
                if xPlayer.getGroup() == group then
                    return true
                end
            end
        end
    end

    for _, aceGroup in ipairs(Config.AllowedGroups.ace) do
        if IsPlayerAceAllowed(src, aceGroup) then
            return true
        end
    end

    return false
end

function GenerateCardNumber()
    local cardNum = ""
    for i = 1, 16 do
        cardNum = cardNum .. tostring(math.random(0, 9))
    end
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE card_number = ?', { cardNum })
    if exists > 0 then
        return GenerateCardNumber()
    end
    return cardNum
end

function GetBankCoords(bankId)
    for _, bank in ipairs(Config.BankLocations) do
        if bank.id == bankId then
            return bank.coords
        end
    end
    return nil
end

function IsPlayerAtHisBank(src, bankId)
    local bankCoords = GetBankCoords(bankId)
    if not bankCoords then
        print("^1[Bank] bankId inválido:", bankId, "^7")
        return false
    end

    local ped = GetPlayerPed(src)
    if not ped or not DoesEntityExist(ped) then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local distance = #(playerCoords - bankCoords)

    return distance <= 3.5
end

-- exports('GetPlayer', GetPlayer)
-- exports('GetPlayerIdentifier', GetPlayerIdentifier)
-- exports('GetPlayerMoney', GetPlayerMoney)
-- exports('GetPlayerBankMoney', GetPlayerBankMoney)
-- exports('AddPlayerMoney', AddPlayerMoney)
-- exports('RemovePlayerMoney', RemovePlayerMoney)
-- exports('AddPlayerBankMoney', AddPlayerBankMoney)
-- exports('RemovePlayerBankMoney', RemovePlayerBankMoney)
exports('ApplyBankCommission', ApplyBankCommission)
exports('GenerateCardNumber', GenerateCardNumber)
exports('GetBankCoords', GetBankCoords)
exports('IsPlayerAtHisBank', IsPlayerAtHisBank)
