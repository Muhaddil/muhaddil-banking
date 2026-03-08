local ESX = nil
local QBCore = nil
local ESXVer = Config.ESXVer
local FrameWork = nil
local bankCoordsCache = {}
local cacheDirty = true
local BANK_INTERACTION_RADIUS = Config.BankOwnership.InteractionRadius

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
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_savings_accounts` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `account_id` INT NOT NULL,
                `owner` VARCHAR(50) NOT NULL,
                `goal_name` VARCHAR(100) NOT NULL,
                `goal_amount` DECIMAL(20,2) DEFAULT 0.00,
                `current_amount` DECIMAL(20,2) DEFAULT 0.00,
                `interest_rate` DECIMAL(5,4) DEFAULT 0.0200,
                `last_interest_date` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`owner`),
                INDEX(`account_id`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_contacts` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `owner` VARCHAR(50) NOT NULL,
                `contact_name` VARCHAR(100) NOT NULL,
                `contact_account_id` INT NOT NULL,
                `notes` TEXT DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(`owner`),
                INDEX(`contact_account_id`),
                FOREIGN KEY (`contact_account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_transfer_requests` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `requester_identifier` VARCHAR(50) NOT NULL,
                `target_identifier` VARCHAR(50) NOT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `requester_account_id` INT NOT NULL,
                `target_account_id` INT DEFAULT NULL,
                `status` VARCHAR(20) DEFAULT 'pending',
                `message` TEXT DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                `resolved_at` TIMESTAMP NULL DEFAULT NULL,
                INDEX(`requester_identifier`),
                INDEX(`target_identifier`),
                INDEX(`status`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_loan_payments` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `loan_id` INT NOT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `payment_type` VARCHAR(20) DEFAULT 'manual',
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`loan_id`) REFERENCES `bank_loans`(`id`) ON DELETE CASCADE,
                INDEX(`loan_id`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_scheduled_transfers` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `owner` VARCHAR(50) NOT NULL,
                `from_account_id` INT NOT NULL,
                `to_account_id` INT NOT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `frequency` VARCHAR(20) DEFAULT 'weekly',
                `day_of_week` INT DEFAULT 1,
                `hour` INT DEFAULT 12,
                `minute` INT DEFAULT 0,
                `enabled` TINYINT(1) DEFAULT 1,
                `description` VARCHAR(200) DEFAULT NULL,
                `last_executed` TIMESTAMP NULL DEFAULT NULL,
                `next_execution` TIMESTAMP NULL DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`from_account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`owner`),
                INDEX(`enabled`),
                INDEX(`next_execution`)
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

    local loansHasLoanType = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'bank_loans'
          AND COLUMN_NAME = 'loan_type'
    ]])

    if tonumber(loansHasLoanType) == 0 then
        MySQL.query.await("ALTER TABLE bank_loans ADD COLUMN loan_type VARCHAR(20) DEFAULT 'personal'")
        MySQL.query.await("ALTER TABLE bank_loans ADD COLUMN paid_installments INT DEFAULT 0")
        MySQL.query.await("ALTER TABLE bank_loans ADD COLUMN next_payment_date TIMESTAMP NULL DEFAULT NULL")
        MySQL.query.await("ALTER TABLE bank_loans ADD COLUMN credit_score_snapshot INT DEFAULT 500")
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

function GetPlayerFromIdentifier(identifier)
    if FrameWork == 'esx' then
        return ESX.GetPlayerFromIdentifier(identifier)
    elseif FrameWork == 'qb' then
        return QBCore.Functions.GetPlayer(identifier)
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

function BuildBankCache()
    if not cacheDirty then return end
    bankCoordsCache = {}
    for _, bank in ipairs(Config.BankLocations) do
        if bank.id ~= nil then
            bankCoordsCache[bank.id] = bank.coords
        end
    end
    cacheDirty = false
end

function InvalidateBankCache()
    cacheDirty = true
end

---@param bankId any
---@return vector3|nil, string|nil
function GetBankCoords(bankId)
    if bankId == nil then
        return nil, "bankId es nil"
    end

    BuildBankCache()

    local coords = bankCoordsCache[bankId]
    if not coords then
        return nil, ("bankId '%s' no encontrado"):format(tostring(bankId))
    end

    return coords, nil
end

---@param src number
---@param bankId any
---@return boolean, string|nil
function IsPlayerAtHisBank(src, bankId)
    if type(src) ~= "number" or src <= 0 then
        return false, "src inválido: " .. tostring(src)
    end

    local bankCoords, err = GetBankCoords(bankId)
    if not bankCoords then
        print(("^1[Bank] GetBankCoords falló — %s^7"):format(err))
        return false, err
    end

    if not GetPlayerPing(src) then
        return false, "jugador no conectado"
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false, "ped inválido"
    end

    local playerCoords = GetEntityCoords(ped)

    local dx = playerCoords.x - bankCoords.x
    local dy = playerCoords.y - bankCoords.y
    local dz = playerCoords.z - bankCoords.z
    local distSq = dx*dx + dy*dy + dz*dz

    if distSq <= (BANK_INTERACTION_RADIUS * BANK_INTERACTION_RADIUS) then
        return true, nil
    end

    return false, ("demasiado lejos (%.1f m)"):format(math.sqrt(distSq))
end

function buildCronExpression(intervalHours)
    if intervalHours == 1 then
        return '0 * * * *'
    elseif intervalHours == 24 then
        return '0 0 * * *'
    elseif intervalHours < 24 and (24 % intervalHours == 0) then
        return string.format('0 */%d * * *', intervalHours)
    elseif intervalHours == 48 then
        return '0 0 */2 * *'
    elseif intervalHours == 168 then
        return '0 0 * * 1'
    else
        local hours = intervalHours % 24
        if hours == 0 then
            local days = math.floor(intervalHours / 24)
            return string.format('0 0 */%d * *', days)
        end
        return string.format('0 */%d * * *', intervalHours)
    end
end

function GetPlayerCreditScore(identifier)
    if not Config.Loans.CreditScore or not Config.Loans.CreditScore.Enabled then
        return Config.Loans.CreditScore and Config.Loans.CreditScore.BaseScore or 500
    end

    local baseScore = Config.Loans.CreditScore.BaseScore
    local maxScore = Config.Loans.CreditScore.MaxScore

    local paidLoans = MySQL.scalar.await([[
        SELECT COUNT(*) FROM bank_loans
        WHERE user_identifier = ? AND status = 'paid'
    ]], { identifier }) or 0

    local penalties = MySQL.scalar.await([[
        SELECT COUNT(*) FROM bank_loan_payments
        WHERE loan_id IN (SELECT id FROM bank_loans WHERE user_identifier = ?)
        AND payment_type = 'penalty'
    ]], { identifier }) or 0

    local paidPayments = MySQL.scalar.await([[
        SELECT COUNT(*) FROM bank_loan_payments
        WHERE loan_id IN (SELECT id FROM bank_loans WHERE user_identifier = ?)
        AND payment_type IN ('manual', 'automatic')
    ]], { identifier }) or 0

    local score = baseScore
        + (tonumber(paidPayments) * Config.Loans.CreditScore.PaymentBonus)
        + (tonumber(paidLoans) * 20)
        - (tonumber(penalties) * Config.Loans.CreditScore.MissedPenalty)

    return math.max(300, math.min(maxScore, score))
end

function CalculateNextExecution(frequency, dayOfWeek, hour, minute)
    local now = os.time()
    local nextExec = now

    if frequency == 'daily' then
        local today = os.date('*t', now)
        nextExec = os.time({
            year = today.year,
            month = today.month,
            day = today.day,
            hour = hour,
            min = minute,
            sec = 0
        })
        if nextExec <= now then
            nextExec = nextExec + 86400
        end
    elseif frequency == 'weekly' then
        local today = os.date('*t', now)
        local currentDay = today.wday
        local daysUntil = (dayOfWeek - currentDay + 7) % 7
        if daysUntil == 0 then
            local todayExec = os.time({
                year = today.year,
                month = today.month,
                day = today.day,
                hour = hour,
                min = minute,
                sec = 0
            })
            if todayExec <= now then
                daysUntil = 7
            end
        end
        nextExec = os.time({
            year = today.year,
            month = today.month,
            day = today.day + daysUntil,
            hour = hour,
            min = minute,
            sec = 0
        })
    elseif frequency == 'biweekly' then
        local today = os.date('*t', now)
        local currentDay = today.wday
        local daysUntil = (dayOfWeek - currentDay + 7) % 7
        if daysUntil == 0 then
            local todayExec = os.time({
                year = today.year,
                month = today.month,
                day = today.day,
                hour = hour,
                min = minute,
                sec = 0
            })
            if todayExec <= now then
                daysUntil = 14
            end
        end
        nextExec = os.time({
            year = today.year,
            month = today.month,
            day = today.day + daysUntil,
            hour = hour,
            min = minute,
            sec = 0
        })
    elseif frequency == 'monthly' then
        local today = os.date('*t', now)
        local nextMonth = today.month + 1
        local nextYear = today.year
        if nextMonth > 12 then
            nextMonth = 1
            nextYear = nextYear + 1
        end
        nextExec = os.time({
            year = nextYear,
            month = nextMonth,
            day = math.min(today.day, 28),
            hour = hour,
            min = minute,
            sec = 0
        })
    end

    return os.date('%Y-%m-%d %H:%M:%S', nextExec)
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
exports('GetPlayerCreditScore', GetPlayerCreditScore)
exports('CalculateNextExecution', CalculateNextExecution)
