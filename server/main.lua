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

lib.callback.register('muhaddil_bank:getAvailableBanks', function(source)
    local available = {}

    for _, bankLocation in ipairs(Config.BankLocations) do
        if bankLocation.purchasable then
            local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankLocation.id })

            table.insert(available, {
                id = bankLocation.id,
                name = bankLocation.name,
                coords = bankLocation.coords,
                isOwned = owner ~= nil,
                owner = owner,
                price = Config.BankOwnership.PurchasePrice
            })
        end
    end

    return available
end)

lib.callback.register('muhaddil_bank:getData', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local currentBankInfo = nil
    if bankId and type(bankId) == 'string' then
        local bankLocation = nil
        for _, bank in ipairs(Config.BankLocations) do
            if bank.id == bankId then
                bankLocation = bank
                break
            end
        end

        if bankLocation then
            local ownedBank = MySQL.single.await('SELECT commission_rate FROM bank_ownership WHERE bank_id = ?',
                { bankId })
            local commissionRate = 0
            if Config.BankOwnership.Enabled and ownedBank and ownedBank.commission_rate then
                commissionRate = tonumber(ownedBank.commission_rate) or 0
            end

            local isOwned = ownedBank ~= nil
            local bankType = bankLocation.bankType or (isOwned and 'private' or 'state')
            currentBankInfo = {
                id = bankLocation.id,
                name = bankLocation.name,
                bankType = bankType,
                commissionRate = commissionRate,
                isOwned = isOwned
            }
        end
    end

    local ownedAccounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE owner = ?', { identifier })

    local sharedAccounts = MySQL.query.await([[
        SELECT ba.* FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], { identifier })

    local allAccounts = {}
    for _, acc in ipairs(ownedAccounts or {}) do
        acc.isOwner = true
        table.insert(allAccounts, acc)
    end
    for _, acc in ipairs(sharedAccounts or {}) do
        acc.isOwner = false
        table.insert(allAccounts, acc)
    end

    local transactions = {}
    for _, acc in ipairs(allAccounts) do
        local accTransactions = MySQL.query.await([[
            SELECT * FROM bank_transactions
            WHERE account_id = ?
            ORDER BY created_at DESC
            LIMIT 50
        ]], { acc.id })

        for _, trans in ipairs(accTransactions or {}) do
            trans.account_name = acc.account_name
            table.insert(transactions, trans)
        end
    end

    table.sort(transactions, function(a, b)
        return a.created_at > b.created_at
    end)

    local loans = MySQL.query.await([[
        SELECT * FROM bank_loans
        WHERE user_identifier = ? AND status = 'active'
    ]], { identifier })

    local ownedBanks = MySQL.query.await([[
        SELECT * FROM bank_ownership
        WHERE owner = ?
    ]], { identifier })

    local availableBanks = {}
    for _, bankLocation in ipairs(Config.BankLocations) do
        if bankLocation.purchasable then
            local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankLocation.id })

            if not owner then
                table.insert(availableBanks, {
                    id = bankLocation.id,
                    name = bankLocation.name,
                    price = Config.BankOwnership.PurchasePrice
                })
            end
        end
    end

    local cash = GetPlayerMoney(source)

    return {
        accounts = allAccounts,
        maxAccounts = Config.Accounts.MaxPerPlayer,
        transactions = transactions,
        loans = loans or {},
        ownedBanks = ownedBanks or {},
        availableBanks = availableBanks,
        cash = cash,
        playerIdentifier = identifier,
        currentBankInfo = currentBankInfo
    }
end)

RegisterNetEvent('muhaddil_bank:createAccount', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local accountName = data.accountName or data.name
    if not accountName or accountName == "" then
        return Notify(src, 'error', 'Nombre de cuenta inválido')
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })
    if count >= Config.Accounts.MaxPerPlayer then
        return Notify(src, 'error', 'Has alcanzado el límite de cuentas (' .. Config.Accounts.MaxPerPlayer .. ')')
    end

    local isFirstAccount = (count == 0)
    local initialBalance = Config.Accounts.InitialBalance

    if isFirstAccount then
        local frameworkMoney = GetPlayerBankMoney(src)
        if frameworkMoney > 0 then
            initialBalance = frameworkMoney
        end
    end

    local accountId = MySQL.insert.await('INSERT INTO bank_accounts (owner, account_name, balance) VALUES (?, ?, ?)', {
        identifier, accountName, initialBalance
    })

    if isFirstAccount and initialBalance > Config.Accounts.InitialBalance then
        MySQL.insert.await([[
            INSERT INTO bank_transactions (account_id, type, amount, description)
            VALUES (?, ?, ?, ?)
        ]], { accountId, 'import', initialBalance, 'Importación inicial' })
    end

    Notify(src, 'success', 'Cuenta creada: ' .. accountName)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:addSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', 'Solo el dueño puede añadir usuarios compartidos')
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', 'Jugador no encontrado')
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', 'No puedes añadirte a ti mismo')
    end

    local sharedCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ?', { accountId })
    if sharedCount >= Config.Accounts.MaxSharedUsers then
        return Notify(src, 'error', 'Límite de usuarios compartidos alcanzado')
    end

    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
            accountId, targetIdentifier
        })
    if exists > 0 then
        return Notify(src, 'error', 'El usuario ya tiene acceso a esta cuenta')
    end

    MySQL.insert.await('INSERT INTO bank_shared_access (account_id, user_identifier) VALUES (?, ?)', {
        accountId, targetIdentifier
    })

    Notify(src, 'success', 'Usuario añadido a la cuenta')
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    if GetPlayerName(targetId) then
        Notify(targetId, 'info', 'Has sido añadido a una cuenta compartida')
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

RegisterNetEvent('muhaddil_bank:removeSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', 'Solo el dueño puede remover usuarios compartidos')
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', 'Jugador no encontrado')
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', 'No puedes quitarte a ti mismo')
    end

    MySQL.query.await('DELETE FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
        accountId, targetIdentifier
    })

    Notify(src, 'success', 'Usuario removido de la cuenta')
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    if GetPlayerName(targetId) then
        Notify(targetId, 'warning', 'Has sido removido de una cuenta compartida')
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

RegisterNetEvent('muhaddil_bank:deleteAccount', function(accountId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', 'No tienes permisos para eliminar esta cuenta')
    end

    MySQL.query.await('DELETE FROM bank_accounts WHERE id = ?', { accountId })
    Notify(src, 'success', 'Cuenta eliminada')
    TriggerEvent('muhaddil_bank:afterDeleteAccount', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:transfer', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local fromAccountId = tonumber(data.fromAccountId)
    local toAccountId   = tonumber(data.toAccountId)
    local amount        = tonumber(data.amount)
    local bankLocation  = data.bankLocation

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
            query =
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            values = { fromAccountId, 'transfer_out', -amount, 'Transferencia a cuenta #' .. toAccountId, bankLocation }
        },
        {
            query =
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            values = { toAccountId, 'transfer_in', amount, 'Transferencia desde cuenta #' .. fromAccountId, bankLocation }
        }
    })

    if not success then
        return Notify(src, 'error', 'Error al procesar la transferencia')
    end

    if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnTransfer and bankLocation then
        ApplyBankCommission(bankLocation, amount)
    end

    Notify(src, 'success', 'Transferencia realizada')
    TriggerEvent('muhaddil_bank:afterTransfer', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:deposit', function(accountId, amount, bankLocation)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if amount <= 0 then return Notify(src, 'error', 'Cantidad inválida') end

    if RemovePlayerMoney(src, amount) then
        MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            {
                accountId, 'deposit', amount, 'Depósito en efectivo', bankLocation
            })

        if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnDeposit and bankLocation then
            ApplyBankCommission(bankLocation, amount)
        end

        Notify(src, 'success', 'Depósito realizado')
        TriggerEvent('muhaddil_bank:afterDeposit', src)
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', 'No tienes suficiente dinero en efectivo')
    end
end)

RegisterNetEvent('muhaddil_bank:withdraw', function(accountId, amount, bankLocation)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local balance = MySQL.scalar.await('SELECT balance FROM bank_accounts WHERE id = ?', { accountId })
    balance = tonumber(balance)

    if not balance then
        return Notify(src, 'error', 'Cuenta no encontrada')
    end

    if balance < amount then
        return Notify(src, 'error', 'Saldo insuficiente')
    end

    MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', { amount, accountId })
    AddPlayerMoney(src, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)', {
            accountId, 'withdrawal', -amount, 'Retiro en efectivo', bankLocation
        })

    if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnWithdraw and bankLocation then
        ApplyBankCommission(bankLocation, amount)
    end

    Notify(src, 'success', 'Retiro realizado')
    TriggerEvent('muhaddil_bank:afterWithdraw', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:requestLoan', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local amount = tonumber(data.amount)
    local installments = tonumber(data.installments)

    if amount < Config.Loans.MinAmount or amount > Config.Loans.MaxAmount then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local activeLoans = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_loans WHERE user_identifier = ? AND status = "active"', { identifier })
    if activeLoans > 0 then
        return Notify(src, 'error', 'Ya tienes un préstamo activo')
    end

    local totalWithInterest = amount * (1 + Config.Loans.InterestRate)

    MySQL.insert.await(
        'INSERT INTO bank_loans (user_identifier, amount, remaining, interest_rate, installments) VALUES (?, ?, ?, ?, ?)',
        {
            identifier, amount, totalWithInterest, Config.Loans.InterestRate * 100, installments
        })

    AddPlayerMoney(src, amount)
    Notify(src, 'success', 'Préstamo aprobado')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:payLoan', function(loanId, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    local remaining = MySQL.scalar.await('SELECT remaining FROM bank_loans WHERE id = ? AND user_identifier = ?',
        { loanId, identifier })
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

        MySQL.query.await('UPDATE bank_loans SET remaining = ?, status = ? WHERE id = ?',
            { newRemaining, status, loanId })

        Notify(src, 'success', 'Pago realizado. Restante: $' .. newRemaining)
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', 'No tienes suficiente dinero')
    end
end)

RegisterNetEvent('muhaddil_bank:purchaseBank', function(bankId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', 'La compra de bancos está deshabilitada')
    end

    local bankExists = false
    local bankName = nil
    for _, bank in ipairs(Config.BankLocations) do
        if bank.id == bankId and bank.purchasable then
            bankExists = true
            bankName = bank.name
            break
        end
    end

    if not bankExists then
        return Notify(src, 'error', 'Este banco no está disponible para compra')
    end

    local currentOwner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankId })
    if currentOwner then
        return Notify(src, 'error', 'Este banco ya tiene dueño')
    end

    local playerBankCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_ownership WHERE owner = ?', { identifier })
    if playerBankCount >= Config.BankOwnership.MaxBanksPerPlayer then
        return Notify(src, 'error',
            'Has alcanzado el límite de bancos (' .. Config.BankOwnership.MaxBanksPerPlayer .. ')')
    end

    if not RemovePlayerMoney(src, Config.BankOwnership.PurchasePrice) then
        return Notify(src, 'error', 'No tienes suficiente dinero ($' .. Config.BankOwnership.PurchasePrice .. ')')
    end

    MySQL.insert.await('INSERT INTO bank_ownership (bank_id, owner, bank_name, commission_rate) VALUES (?, ?, ?, ?)', {
        bankId, identifier, bankName, Config.BankOwnership.DefaultCommissionRate
    })

    Notify(src, 'success', 'Has comprado ' .. bankName)
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    print(string.format("^2[Bank System] %s compró el banco %s (%s)^7", GetPlayerName(src), bankName, bankId))
end)

RegisterCommand(Config.OpenCommand, function(source, args, rawCommand)
    TriggerClientEvent('muhaddil_bank:openBank', source)
end, false)

print('^2[Bank System] Server initialized successfully^7')
