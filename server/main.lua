local ESX = nil
local QBCore = nil
local ESXVer = Config.ESXVer
local FrameWork = nil

-- Inicializar Framework
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

-- Crear tablas en la base de datos al iniciar
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
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (`account_id`) REFERENCES `bank_accounts`(`id`) ON DELETE CASCADE,
                INDEX(`account_id`)
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
                `owner` VARCHAR(50) NOT NULL,
                `bank_name` VARCHAR(100) NOT NULL,
                `commission_rate` DECIMAL(5,4) DEFAULT 0.0100,
                `total_earned` DECIMAL(20,2) DEFAULT 0.00,
                `purchased_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX(`owner`)
            )
        ]]
    }

    for _, query in ipairs(queries) do
        MySQL.query.await(query)
    end
    
    print('^2[Bank System] Database initialized successfully^7')
end)

-- Helper: Obtener identificador del jugador
function GetIdentifier(source)
    if FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.identifier or nil
    elseif FrameWork == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.citizenid or nil
    end
end

-- Helper: Obtener dinero del jugador
function GetPlayerMoney(source)
    if FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and xPlayer.getMoney() or 0
    elseif FrameWork == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        return Player and Player.PlayerData.money.cash or 0
    end
end

-- Helper: Añadir dinero al jugador
function AddPlayerMoney(source, amount)
    if FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(amount)
            return true
        end
    elseif FrameWork == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney('cash', amount)
            return true
        end
    end
    return false
end

-- Helper: Remover dinero del jugador
function RemovePlayerMoney(source, amount)
    if FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            if xPlayer.getMoney() >= amount then
                xPlayer.removeMoney(amount)
                return true
            end
        end
    elseif FrameWork == "qb" then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            if Player.PlayerData.money.cash >= amount then
                Player.Functions.RemoveMoney('cash', amount)
                return true
            end
        end
    end
    return false
end

-- Helper: Notificar al jugador
function Notify(source, type, message)
    TriggerClientEvent('muhaddil_bank:notify', source, type, message)
end

-- Callback: Obtener todos los datos del jugador
lib.callback.register('muhaddil_bank:getData', function(source)
    local identifier = GetIdentifier(source)
    if not identifier then return nil end
    
    -- Obtener cuentas propias
    local ownedAccounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE owner = ?', {identifier})
    
    -- Obtener cuentas compartidas
    local sharedAccounts = MySQL.query.await([[
        SELECT ba.* FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], {identifier})
    
    -- Combinar todas las cuentas
    local allAccounts = {}
    for _, acc in ipairs(ownedAccounts or {}) do
        acc.isOwner = true
        table.insert(allAccounts, acc)
    end
    for _, acc in ipairs(sharedAccounts or {}) do
        acc.isOwner = false
        table.insert(allAccounts, acc)
    end
    
    -- Obtener transacciones de todas las cuentas del jugador
    local transactions = {}
    for _, acc in ipairs(allAccounts) do
        local accTransactions = MySQL.query.await([[
            SELECT * FROM bank_transactions 
            WHERE account_id = ? 
            ORDER BY created_at DESC 
            LIMIT 50
        ]], {acc.id})
        
        for _, trans in ipairs(accTransactions or {}) do
            trans.account_name = acc.account_name
            table.insert(transactions, trans)
        end
    end
    
    -- Ordenar transacciones por fecha (más recientes primero)
    table.sort(transactions, function(a, b)
        return a.created_at > b.created_at
    end)
    
    -- Obtener préstamos
    local loans = MySQL.query.await([[
        SELECT * FROM bank_loans 
        WHERE user_identifier = ? AND status = 'active'
    ]], {identifier})
    
    -- Obtener bancos que posee
    local ownedBanks = MySQL.query.await([[
        SELECT * FROM bank_ownership 
        WHERE owner = ?
    ]], {identifier})
    
    -- Obtener dinero en efectivo
    local cash = GetPlayerMoney(source)
    
    return {
        accounts = allAccounts,
        transactions = transactions,
        loans = loans or {},
        ownedBanks = ownedBanks or {},
        cash = cash,
        playerIdentifier = identifier
    }
end)

-- Crear cuenta
RegisterNetEvent('muhaddil_bank:createAccount', function(data)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    local accountName = data.accountName or data.name
    if not accountName or accountName == "" then
        return Notify(src, 'error', 'Nombre de cuenta inválido')
    end
    
    -- Verificar límite de cuentas
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', {identifier})
    if count >= Config.Accounts.MaxPerPlayer then
        return Notify(src, 'error', 'Has alcanzado el límite de cuentas (' .. Config.Accounts.MaxPerPlayer .. ')')
    end
    
    -- Crear cuenta
    MySQL.insert.await('INSERT INTO bank_accounts (owner, account_name, balance) VALUES (?, ?, ?)', {
        identifier, accountName, Config.Accounts.InitialBalance
    })
    
    Notify(src, 'success', 'Cuenta creada: ' .. accountName)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

-- Añadir usuario compartido
RegisterNetEvent('muhaddil_bank:addSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    -- Verificar que el jugador es el dueño
    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', {accountId})
    if owner ~= identifier then
        return Notify(src, 'error', 'Solo el dueño puede añadir usuarios compartidos')
    end
    
    -- Verificar que el target existe (convertir ID del jugador a identifier)
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', 'Jugador no encontrado')
    end
    
    -- Verificar que no sea el mismo dueño
    if targetIdentifier == identifier then
        return Notify(src, 'error', 'No puedes añadirte a ti mismo')
    end
    
    -- Verificar límite de usuarios compartidos
    local sharedCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ?', {accountId})
    if sharedCount >= Config.Accounts.MaxSharedUsers then
        return Notify(src, 'error', 'Límite de usuarios compartidos alcanzado')
    end
    
    -- Verificar si ya está añadido
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
        accountId, targetIdentifier
    })
    if exists > 0 then
        return Notify(src, 'error', 'El usuario ya tiene acceso a esta cuenta')
    end
    
    -- Añadir usuario compartido
    MySQL.insert.await('INSERT INTO bank_shared_access (account_id, user_identifier) VALUES (?, ?)', {
        accountId, targetIdentifier
    })
    
    Notify(src, 'success', 'Usuario añadido a la cuenta')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
    
    -- Notificar al usuario añadido si está conectado
    if GetPlayerName(targetId) then
        Notify(targetId, 'info', 'Has sido añadido a una cuenta compartida')
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

-- Remover usuario compartido
RegisterNetEvent('muhaddil_bank:removeSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end
    
    -- Verificar que el jugador es el dueño
    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', {accountId})
    if owner ~= identifier then
        return Notify(src, 'error', 'Solo el dueño puede remover usuarios compartidos')
    end
    
    -- Obtener identifier del target
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', 'Jugador no encontrado')
    end
    
    -- Remover usuario compartido
    MySQL.query.await('DELETE FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
        accountId, targetIdentifier
    })
    
    Notify(src, 'success', 'Usuario removido de la cuenta')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
    
    -- Notificar al usuario removido si está conectado
    if GetPlayerName(targetId) then
        Notify(targetId, 'warning', 'Has sido removido de una cuenta compartida')
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

-- Eliminar cuenta
RegisterNetEvent('muhaddil_bank:deleteAccount', function(accountId)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', {accountId})
    if owner ~= identifier then
        return Notify(src, 'error', 'No tienes permisos para eliminar esta cuenta')
    end

    MySQL.query.await('DELETE FROM bank_accounts WHERE id = ?', {accountId})
    Notify(src, 'success', 'Cuenta eliminada')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

-- Transferir dinero
RegisterNetEvent('muhaddil_bank:transfer', function(data)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local fromAccountId = tonumber(data.fromAccountId)
    local toAccountId   = tonumber(data.toAccountId)
    local amount        = tonumber(data.amount)

    if not fromAccountId or not toAccountId then
        return Notify(src, 'error', 'Cuenta inválida')
    end

    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa 
            ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, fromAccountId, identifier, identifier })

    if not account then
        return Notify(src, 'error', 'No tienes permisos en la cuenta origen')
    end

    account.balance = tonumber(account.balance)
    if not account.balance or account.balance < amount then
        return Notify(src, 'error', 'Saldo insuficiente')
    end

    -- Transacción oxmysql correcta
    local success = MySQL.transaction.await({
        {
            query = 'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
            values = { amount, fromAccountId }
        },
        {
            query = 'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            values = { amount, toAccountId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { fromAccountId, 'transfer_out', -amount, 'Transferencia a cuenta #' .. toAccountId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { toAccountId, 'transfer_in', amount, 'Transferencia desde cuenta #' .. fromAccountId }
        }
    })

    if not success then
        return Notify(src, 'error', 'Error al procesar la transferencia')
    end

    Notify(src, 'success', 'Transferencia realizada')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

-- Depositar
RegisterNetEvent('muhaddil_bank:deposit', function(accountId, amount)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if amount <= 0 then return Notify(src, 'error', 'Cantidad inválida') end

    if RemovePlayerMoney(src, amount) then
        MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', {amount, accountId})
        MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
            accountId, 'deposit', amount, 'Depósito en efectivo'
        })
        
        Notify(src, 'success', 'Depósito realizado')
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', 'No tienes suficiente dinero en efectivo')
    end
end)

-- Retirar
RegisterNetEvent('muhaddil_bank:withdraw', function(accountId, amount)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local balance = MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?',
        { accountId }
    )

    balance = tonumber(balance)
    if not balance then
        return Notify(src, 'error', 'Cuenta no encontrada')
    end

    if balance < amount then
        return Notify(src, 'error', 'Saldo insuficiente')
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { amount, accountId }
    )

    AddPlayerMoney(src, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'withdrawal', -amount, 'Retiro en efectivo' }
    )

    Notify(src, 'success', 'Retiro realizado')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

-- Solicitar préstamo
RegisterNetEvent('muhaddil_bank:requestLoan', function(data)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local amount = tonumber(data.amount)
    local installments = tonumber(data.installments)

    if amount < Config.Loans.MinAmount or amount > Config.Loans.MaxAmount then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local activeLoans = MySQL.scalar.await('SELECT COUNT(*) FROM bank_loans WHERE user_identifier = ? AND status = "active"', {identifier})
    if activeLoans > 0 then
        return Notify(src, 'error', 'Ya tienes un préstamo activo')
    end

    local totalWithInterest = amount * (1 + Config.Loans.InterestRate)

    MySQL.insert.await('INSERT INTO bank_loans (user_identifier, amount, remaining, interest_rate, installments) VALUES (?, ?, ?, ?, ?)', {
        identifier, amount, totalWithInterest, Config.Loans.InterestRate * 100, installments
    })

    AddPlayerMoney(src, amount)
    Notify(src, 'success', 'Préstamo aprobado')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

-- Pagar préstamo
RegisterNetEvent('muhaddil_bank:payLoan', function(loanId, amount)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local remaining = MySQL.scalar.await(
        'SELECT remaining FROM bank_loans WHERE id = ? AND user_identifier = ?',
        { loanId, identifier }
    )

    remaining = tonumber(remaining)
    if not remaining then
        return Notify(src, 'error', 'Préstamo no encontrado')
    end

    if amount > remaining then
        amount = remaining
    end

    if RemovePlayerMoney(src, amount) then
        local newRemaining = remaining - amount
        local status = (newRemaining <= 0) and 'paid' or 'active'

        MySQL.query.await(
            'UPDATE bank_loans SET remaining = ?, status = ? WHERE id = ?',
            { newRemaining, status, loanId }
        )

        Notify(src, 'success', 'Pago realizado. Restante: $' .. newRemaining)
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', 'No tienes suficiente dinero')
    end
end)

-- Comprar banco
RegisterNetEvent('muhaddil_bank:purchaseBank', function(bankName)
    local src = source
    local identifier = GetIdentifier(src)
    if not identifier then return end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_ownership WHERE owner = ?', {identifier})
    if count >= Config.BankOwnership.MaxBanksPerPlayer then
        return Notify(src, 'error', 'Has alcanzado el límite de bancos')
    end

    if RemovePlayerMoney(src, Config.BankOwnership.PurchasePrice) then
        MySQL.insert.await('INSERT INTO bank_ownership (owner, bank_name, commission_rate) VALUES (?, ?, ?)', {
            identifier, bankName, Config.BankOwnership.CommissionRate
        })
        Notify(src, 'success', 'Banco comprado exitosamente')
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', 'No tienes suficiente dinero')
    end
end)

-- Comando para abrir el banco
RegisterCommand(Config.OpenCommand, function(source, args, rawCommand)
    TriggerClientEvent('muhaddil_bank:openBank', source)
end, false)

print('^2[Bank System] Server initialized successfully^7')