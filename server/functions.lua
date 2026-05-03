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
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_checks` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `check_code` VARCHAR(20) NOT NULL UNIQUE,
                `issuer` VARCHAR(50) NOT NULL,
                `from_account_id` INT NOT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `memo` VARCHAR(200) DEFAULT NULL,
                `status` VARCHAR(20) DEFAULT 'active',
                `expires_at` TIMESTAMP NOT NULL,
                `cashed_by` VARCHAR(50) DEFAULT NULL,
                `cashed_account_id` INT DEFAULT NULL,
                `cashed_at` TIMESTAMP NULL DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(`issuer`),
                INDEX(`check_code`),
                INDEX(`status`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_direct_debits` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `owner` VARCHAR(50) NOT NULL,
                `account_id` INT NOT NULL,
                `creditor_name` VARCHAR(100) NOT NULL,
                `description` VARCHAR(200) DEFAULT NULL,
                `amount` DECIMAL(20,2) NOT NULL,
                `frequency` VARCHAR(20) DEFAULT 'monthly',
                `enabled` TINYINT(1) DEFAULT 1,
                `last_executed` TIMESTAMP NULL DEFAULT NULL,
                `next_execution` TIMESTAMP NULL DEFAULT NULL,
                `source_resource` VARCHAR(100) DEFAULT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`owner`),
                INDEX(`enabled`),
                INDEX(`next_execution`)
            )
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `bank_check_forgery_log` (
                `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
                `identifier` VARCHAR(100) NOT NULL,
                `check_code` VARCHAR(50) NOT NULL,
                `amount` DECIMAL(15,2) NOT NULL DEFAULT 0,
                `detected_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                INDEX `idx_identifier` (`identifier`),
                INDEX `idx_check_code` (`check_code`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
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

    local hasIssuerName = MySQL.scalar.await([[
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'bank_checks'
      AND COLUMN_NAME = 'issuer_name'
]])

    if tonumber(hasIssuerName) == 0 then
        MySQL.query.await([[
        ALTER TABLE bank_checks
        ADD COLUMN issuer_name VARCHAR(100) DEFAULT NULL
    ]])
    end

    if Config.IBAN and Config.IBAN.Enabled then
        local hasIban = MySQL.scalar.await([[
            SELECT COUNT(*)
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE()
              AND TABLE_NAME = 'bank_accounts'
              AND COLUMN_NAME = 'iban'
        ]])

        if tonumber(hasIban) == 0 then
            MySQL.query.await('ALTER TABLE bank_accounts ADD COLUMN iban VARCHAR(15) DEFAULT NULL')
            MySQL.query.await('ALTER TABLE bank_accounts ADD UNIQUE KEY iban_unique (iban)')
        end

        local accountsWithoutIban = MySQL.query.await('SELECT id FROM bank_accounts WHERE iban IS NULL')
        if accountsWithoutIban and #accountsWithoutIban > 0 then
            for _, acc in ipairs(accountsWithoutIban) do
                local iban = GenerateIBAN(nil)
                MySQL.query.await('UPDATE bank_accounts SET iban = ? WHERE id = ?', { iban, acc.id })
            end
            print(string.format('^3[Bank System] Generated IBANs for %d existing accounts^7', #accountsWithoutIban))
        end
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
    local distSq = dx * dx + dy * dy + dz * dz

    if distSq <= (BANK_INTERACTION_RADIUS * BANK_INTERACTION_RADIUS) then
        return true, nil
    end

    return false, ("demasiado lejos (%.1f m)"):format(math.sqrt(distSq))
end

function buildCronExpression(intervalHours)
    intervalHours = tonumber(intervalHours)

    if not intervalHours or intervalHours <= 0 then
        intervalHours = 1
    end

    local totalMinutes = math.floor(intervalHours * 60 + 0.5)

    if intervalHours < 1 then
        local minutes = math.max(1, totalMinutes)
        return string.format("*/%d * * * *", minutes)
    end

    if intervalHours == 1 then
        return '0 * * * *'
    elseif intervalHours == 24 then
        return '0 0 * * *'
    elseif intervalHours == 168 then
        return '0 0 * * 1' -- weekly
    elseif intervalHours == 720 then
        return '0 0 1 * *' -- monthly
    elseif intervalHours < 24 and (24 % intervalHours == 0) then
        return string.format('0 */%d * * *', intervalHours)
    elseif intervalHours % 24 == 0 then
        local days = math.floor(intervalHours / 24)
        return string.format('0 0 */%d * *', days)
    else
        return string.format('0 */%d * * *', intervalHours)
    end
end

function GetPlayerCreditScore(identifier)
    if not Config.Loans.CreditScore or not Config.Loans.CreditScore.Enabled then
        return Config.Loans.CreditScore and Config.Loans.CreditScore.BaseScore or 500
    end

    local baseScore = Config.Loans.CreditScore.BaseScore
    local maxScore = Config.Loans.CreditScore.MaxScore
    local minScore = Config.Loans.CreditScore.MinScore or 300
    local paidLoanBonus = Config.Loans.CreditScore.PaidLoanBonus or 20

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
        + (tonumber(paidLoans) * paidLoanBonus)
        - (tonumber(penalties) * Config.Loans.CreditScore.MissedPenalty)

    return math.max(minScore, math.min(maxScore, score))
end

function GetCreditScoreTier(score)
    if not Config.Loans.CreditScore or not Config.Loans.CreditScore.ScoreTiers then
        return { minScore = 0, interestMultiplier = 1.0, label = 'good' }
    end

    for _, tier in ipairs(Config.Loans.CreditScore.ScoreTiers) do
        if score >= tier.minScore then
            return tier
        end
    end

    return Config.Loans.CreditScore.ScoreTiers[#Config.Loans.CreditScore.ScoreTiers]
end

---@param bankId string|nil The bank location ID (e.g., 'bank_legion')
---@return string The generated IBAN (e.g., 'LS-4821-7390')
function GenerateIBAN(bankId)
    local prefix = Config.IBAN.DefaultPrefix
    if bankId and Config.IBAN.ZonePrefixes[bankId] then
        prefix = Config.IBAN.ZonePrefixes[bankId]
    end

    local function genBlock()
        return string.format('%04d', math.random(1000, 9999))
    end

    local iban = prefix .. '-' .. genBlock() .. '-' .. genBlock()

    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE iban = ?', { iban })
    if exists and tonumber(exists) > 0 then
        return GenerateIBAN(bankId)
    end

    return iban
end

---@param input string|number IBAN string or account ID number
---@return number|nil accountId
function ResolveAccountId(input)
    if type(input) == 'number' then
        return input
    end

    local str = tostring(input)
    if tonumber(str) then
        return tonumber(str)
    end

    if Config.IBAN and Config.IBAN.Enabled then
        local accountId = MySQL.scalar.await('SELECT id FROM bank_accounts WHERE iban = ?', { str:upper() })
        if accountId then
            return tonumber(accountId)
        end
    end

    return nil
end

---@return string The check code (e.g., 'CHK-A3F9-B2C1')
function GenerateCheckCode()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local function randBlock(len)
        local block = ''
        for i = 1, len do
            local idx = math.random(1, #chars)
            block = block .. chars:sub(idx, idx)
        end
        return block
    end

    local code = 'CHK-' .. randBlock(4) .. '-' .. randBlock(4)

    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_checks WHERE check_code = ?', { code })
    if exists and tonumber(exists) > 0 then
        return GenerateCheckCode()
    end

    return code
end

function CalculateNextExecution(frequency, dayOfWeek, hour, minute)
    local now = os.time()
    local today = os.date('*t', now)

    local function isoToLuaDay(d)
        return (d % 7) + 1
    end

    if frequency == 'daily' then
        local baseToday = os.time({
            year = today.year, month = today.month, day = today.day,
            hour = 0, min = 0, sec = 0
        })

        local candidate = baseToday + (hour * 3600) + (minute * 60)

        if candidate <= now then
            candidate = candidate + 86400
        end

        return os.date('%Y-%m-%d %H:%M:%S', candidate)

    elseif frequency == 'weekly' or frequency == 'biweekly' then
        local interval = (frequency == 'biweekly') and 14 or 7
        local luaDay = isoToLuaDay(dayOfWeek)
        local currentDay = today.wday
        local daysUntil = (luaDay - currentDay + 7) % 7

        local baseToday = os.time({
            year = today.year, month = today.month, day = today.day,
            hour = 0, min = 0, sec = 0
        })

        if daysUntil == 0 then
            local candidate = baseToday + (hour * 3600) + (minute * 60)
            if candidate <= now then
                daysUntil = interval
            end
        end

        local candidate = baseToday + (daysUntil * 86400) + (hour * 3600) + (minute * 60)
        return os.date('%Y-%m-%d %H:%M:%S', candidate)

    elseif frequency == 'monthly' then
        local nextMonth = today.month + 1
        local nextYear = today.year
        
        if nextMonth > 12 then
            nextMonth = 1
            nextYear = nextYear + 1
        end

        local candidate = os.time({
            year = nextYear, month = nextMonth,
            day = math.min(today.day, 28),
            hour = hour, min = minute, sec = 0
        })

        return os.date('%Y-%m-%d %H:%M:%S', candidate)
    end

    return os.date('%Y-%m-%d %H:%M:%S', now)
end

function BuildCheckMetadata(checkCode, amount, memo, issuerName, fromAccountId, expiresAt, isFake)
    return {
        check_code   = checkCode,
        amount       = amount,
        memo         = memo or '',
        issuer_name  = issuerName or 'Desconocido',
        from_account = fromAccountId,
        expires_at   = expiresAt,
        is_fake      = isFake or false,
        label        = string.format(Locale('server.check_label', checkCode, amount)),
        description  = string.format(
            Locale('server.check_metadata', issuerName or 'Desconocido', amount, memo or 'Sin concepto', expiresAt)
        ),
    }
end

function GetPlayerDisplayName(src)
    if FrameWork == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        return xPlayer and xPlayer.name
    elseif FrameWork == 'qb' and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local ci = Player.PlayerData.charinfo
            return string.format('%s %s', ci.firstname or '', ci.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
        end
    end
    return ((Locale('server.player') or 'Jugador ') .. src)
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
exports('GetCreditScoreTier', GetCreditScoreTier)
exports('CalculateNextExecution', CalculateNextExecution)
exports('GenerateIBAN', GenerateIBAN)
exports('ResolveAccountId', ResolveAccountId)
exports('GenerateCheckCode', GenerateCheckCode)
