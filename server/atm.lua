lib.callback.register('muhaddil_bank:getATMData', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local ownedAccounts = MySQL.query.await('SELECT id, account_name, balance FROM bank_accounts WHERE owner = ?',
        { identifier })

    local sharedAccounts = MySQL.query.await([[
        SELECT ba.id, ba.account_name, ba.balance FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], { identifier })

    local allAccounts = {}
    for _, acc in ipairs(ownedAccounts or {}) do
        table.insert(allAccounts, acc)
    end
    for _, acc in ipairs(sharedAccounts or {}) do
        table.insert(allAccounts, acc)
    end

    local cash = GetPlayerMoney(source)

    return {
        accounts = allAccounts,
        cash = cash
    }
end)

-- RegisterNetEvent('muhaddil_bank:atmDeposit', function(accountId, amount)
--     local src = source
--     local identifier = GetPlayerIdentifier(src)
--     if not identifier then return end

--     amount = tonumber(amount)
--     if not amount or amount <= 0 then
--         return Notify(src, 'error', 'Cantidad inválida')
--     end

--     if amount > Config.ATMs.DepositLimit then
--         return Notify(src, 'error', 'Límite de depósito: $' .. Config.ATMs.DepositLimit)
--     end

--     local fee = Config.ATMs.Fee or 0
--     local totalNeeded = amount + fee

--     if RemovePlayerMoney(src, totalNeeded) then
--         MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })
--         MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
--             accountId, 'atm_deposit', amount, 'Depósito por cajero ATM'
--         })

--         if fee > 0 then
--             Notify(src, 'success', 'Depósito realizado. Comisión ATM: $' .. fee)
--         else
--             Notify(src, 'success', 'Depósito realizado')
--         end
--         TriggerClientEvent('muhaddil_bank:refreshATMData', src)
--     else
--         Notify(src, 'error', 'No tienes suficiente dinero en efectivo')
--     end
-- end)

RegisterNetEvent('muhaddil_bank:atmDeposit', function(accountId, amount)              -- Simpler version
    local src = source
    local ok, result = exports['muhaddil-banking']:ATMDeposit(src, accountId, amount) -- If changed resource name, this won't work if not modified

    if not ok then
        return Notify(src, 'error', result)
    end

    if tonumber(result) and result > 0 then
        Notify(src, 'success', 'Depósito realizado. Comisión: $' .. result)
    else
        Notify(src, 'success', 'Depósito realizado')
    end

    TriggerClientEvent('muhaddil_bank:refreshATMData', src)
end)

RegisterNetEvent('muhaddil_bank:atmWithdraw', function(accountId, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', 'Cantidad inválida')
    end

    if amount > Config.ATMs.WithdrawLimit then
        return Notify(src, 'error', 'Límite de retiro: $' .. Config.ATMs.WithdrawLimit)
    end

    local fee = Config.ATMs.Fee or 0
    local totalNeeded = amount + fee

    local balance = MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?',
        { accountId }
    )

    balance = tonumber(balance)
    if not balance then
        return Notify(src, 'error', 'Cuenta no encontrada')
    end

    if balance < totalNeeded then
        return Notify(src, 'error', 'Saldo insuficiente (incluye comisión de $' .. fee .. ')')
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { totalNeeded, accountId }
    )

    AddPlayerMoney(src, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'atm_withdrawal', -amount, 'Retiro por cajero ATM' }
    )

    if fee > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'atm_fee', -fee, 'Comisión cajero ATM' }
        )
        Notify(src, 'success', 'Retiro realizado. Comisión ATM: $' .. fee)
    else
        Notify(src, 'success', 'Retiro realizado')
    end
    TriggerClientEvent('muhaddil_bank:refreshATMData', src)
end)

RegisterNetEvent('muhaddil_bank:atmTransfer', function(fromAccountId, toAccountId, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    fromAccountId = tonumber(fromAccountId)
    toAccountId = tonumber(toAccountId)
    amount = tonumber(amount)

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

    local targetExists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE id = ?', { toAccountId })
    if not targetExists or targetExists == 0 then
        return Notify(src, 'error', 'Cuenta destino no existe')
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
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { fromAccountId, 'atm_transfer_out', -amount, 'Transferencia ATM a cuenta #' .. toAccountId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { toAccountId, 'atm_transfer_in', amount, 'Transferencia ATM desde cuenta #' .. fromAccountId }
        }
    })

    if not success then
        return Notify(src, 'error', 'Error al procesar la transferencia')
    end

    Notify(src, 'success', 'Transferencia realizada')
    TriggerClientEvent('muhaddil_bank:refreshATMData', src)
end)

print('^2[Bank System] ATM server events loaded^7')

exports('GetATMData', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local ownedAccounts = MySQL.query.await(
        'SELECT id, account_name, balance FROM bank_accounts WHERE owner = ?',
        { identifier }
    )

    local sharedAccounts = MySQL.query.await([[
        SELECT ba.id, ba.account_name, ba.balance
        FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], { identifier })

    local accounts = {}

    for _, acc in ipairs(ownedAccounts or {}) do
        accounts[#accounts + 1] = acc
    end

    for _, acc in ipairs(sharedAccounts or {}) do
        accounts[#accounts + 1] = acc
    end

    return {
        accounts = accounts,
        cash = GetPlayerMoney(source)
    }
end)

exports('ATMDeposit', function(source, accountId, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'Cantidad inválida' end

    if amount > Config.ATMs.DepositLimit then
        return false, 'Límite de depósito: $' .. Config.ATMs.DepositLimit
    end

    local fee = Config.ATMs.Fee or 0
    local total = amount + fee

    if not RemovePlayerMoney(source, total) then
        return false, 'No tienes suficiente efectivo'
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
        { amount, accountId }
    )

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'atm_deposit', amount, 'Depósito por cajero ATM' }
    )

    return true, fee
end)

exports('ATMWithdraw', function(source, accountId, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, 'Cantidad inválida' end

    if amount > Config.ATMs.WithdrawLimit then
        return false, 'Límite de retiro: $' .. Config.ATMs.WithdrawLimit
    end

    local fee = Config.ATMs.Fee or 0
    local total = amount + fee

    local balance = tonumber(MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?',
        { accountId }
    ))

    if not balance then
        return false, 'Cuenta no encontrada'
    end

    if balance < total then
        return false, 'Saldo insuficiente'
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { total, accountId }
    )

    AddPlayerMoney(source, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'atm_withdrawal', -amount, 'Retiro por cajero ATM' }
    )

    if fee > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'atm_fee', -fee, 'Comisión cajero ATM' }
        )
    end

    return true, fee
end)

exports('ATMTransfer', function(source, fromAccountId, toAccountId, amount)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    fromAccountId = tonumber(fromAccountId)
    toAccountId = tonumber(toAccountId)
    amount = tonumber(amount)

    if not fromAccountId or not toAccountId or not amount or amount <= 0 then
        return false, 'Datos inválidos'
    end

    local account = MySQL.single.await([[
        SELECT ba.balance
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa
            ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, fromAccountId, identifier, identifier })

    if not account or tonumber(account.balance) < amount then
        return false, 'Saldo insuficiente o sin permisos'
    end

    local targetExists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_accounts WHERE id = ?',
        { toAccountId }
    )

    if targetExists == 0 then
        return false, 'Cuenta destino no existe'
    end

    local ok = MySQL.transaction.await({
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
            values = { fromAccountId, 'atm_transfer_out', -amount, 'Transferencia ATM' }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { toAccountId, 'atm_transfer_in', amount, 'Transferencia ATM' }
        }
    })

    if not ok then
        return false, 'Error al procesar la transferencia'
    end

    return true
end)
