lib.callback.register('muhaddil_bank:getATMData', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local cash = GetPlayerMoney(source)
    local result = { cash = cash }

    if Config.Cards.Enabled and Config.Cards.RequireCardForATM then
        local cards = MySQL.query.await([[
            SELECT bc.*, ba.account_name, ba.balance
            FROM bank_cards bc
            INNER JOIN bank_accounts ba ON bc.account_id = ba.id
            WHERE bc.owner = ?
            ORDER BY bc.created_at DESC
        ]], { identifier })

        result.cards = cards or {}
    else
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

        local allAccounts = {}
        for _, acc in ipairs(ownedAccounts or {}) do
            table.insert(allAccounts, acc)
        end
        for _, acc in ipairs(sharedAccounts or {}) do
            table.insert(allAccounts, acc)
        end

        result.accounts = allAccounts
    end

    return result
end)

lib.callback.register('muhaddil_bank:getAccountDataById', function(source, accountId)
    local account = MySQL.single.await('SELECT id, account_name, balance FROM bank_accounts WHERE id = ?', { accountId })
    if not account then return nil end

    local cash = GetPlayerMoney(source)
    return {
        account = account,
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
        Notify(src, 'success',
            Locale('server.atm_deposit_completed') .. '. ' .. Locale('server.atm_fee') .. ': $' .. result)
    else
        Notify(src, 'success', Locale('server.atm_deposit_completed'))
    end

    TriggerClientEvent('muhaddil_bank:refreshATMData', src)
end)

RegisterNetEvent('muhaddil_bank:atmWithdraw', function(accountId, amount)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    if amount > Config.ATMs.WithdrawLimit then
        return Notify(src, 'error', Locale('server.withdraw_limit', Config.ATMs.WithdrawLimit))
    end

    local fee = Config.ATMs.Fee or 0
    local totalNeeded = amount + fee

    local balance = MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?',
        { accountId }
    )

    balance = tonumber(balance)
    if not balance then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    if balance < totalNeeded then
        return Notify(src, 'error', Locale('server.insufficient_balance', fee))
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { totalNeeded, accountId }
    )

    AddPlayerMoney(src, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'atm_withdrawal', -amount, Locale('server.atm_withdrawal') }
    )

    if fee > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'atm_fee', -fee, Locale('server.atm_fee') }
        )
        Notify(src, 'success', Locale('server.withdrawal_completed') .. '. ' .. Locale('server.atm_fee') .. ': $' .. fee)
    else
        Notify(src, 'success', Locale('server.withdrawal_completed'))
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
        return Notify(src, 'error', Locale('server.invalid_account'))
    end

    if not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa
            ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, fromAccountId, identifier, identifier })

    if not account then
        return Notify(src, 'error', Locale('server.no_permissions'))
    end

    account.balance = tonumber(account.balance)
    if not account.balance or account.balance < amount then
        return Notify(src, 'error', Locale('server.insufficient_balance'))
    end

    local targetExists = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE id = ?', { toAccountId })
    if not targetExists or targetExists == 0 then
        return Notify(src, 'error', Locale('server.account_not_found'))
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
            values = { fromAccountId, 'atm_transfer_out', -amount, Locale('server.atm_transfer_completed') .. ' #' .. toAccountId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { toAccountId, 'atm_transfer_in', amount, Locale('server.atm_transfer_completed') .. ' #' .. fromAccountId }
        }
    })

    if not success then
        return Notify(src, 'error', Locale('server.transfer_error'))
    end

    Notify(src, 'success', Locale('server.transfer_completed'))
    TriggerClientEvent('muhaddil_bank:refreshATMData', src)
end)

print('^2[Bank System] ATM server events loaded^7')

exports('GetATMData', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local cards = MySQL.query.await([[
        SELECT bc.*, ba.account_name, ba.balance
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.created_at DESC
    ]], { identifier })

    return {
        cards = cards or {},
        cash = GetPlayerMoney(source)
    }
end)

exports('ATMDeposit', function(source, accountId, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false, Locale('server.invalid_amount') end

    if amount > Config.ATMs.DepositLimit then
        return false, Locale('server.deposit_limit', Config.ATMs.DepositLimit)
    end

    local fee = Config.ATMs.Fee or 0
    local total = amount + fee

    if not RemovePlayerMoney(source, total) then
        return false, Locale('server.insufficient_balance')
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
    if not amount or amount <= 0 then return false, Locale('server.invalid_amount') end

    if amount > Config.ATMs.WithdrawLimit then
        return false, Locale('server.withdraw_limit', Config.ATMs.WithdrawLimit)
    end

    local fee = Config.ATMs.Fee or 0
    local total = amount + fee

    local balance = tonumber(MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?',
        { accountId }
    ))

    if not balance then
        return false, Locale('server.account_not_found')
    end

    if balance < total then
        return false, Locale('server.insufficient_balance')
    end

    MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { total, accountId }
    )

    AddPlayerMoney(source, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'atm_withdrawal', -amount, Locale('server.atm_withdrawal') }
    )

    if fee > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'atm_fee', -fee, Locale('server.atm_fee') }
        )
    end

    return true, fee
end)

exports('ATMTransfer', function(source, fromAccountId, toAccountId, amount)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, Locale('server.invalid_identifier') end

    fromAccountId = tonumber(fromAccountId)
    toAccountId = tonumber(toAccountId)
    amount = tonumber(amount)

    if not fromAccountId or not toAccountId or not amount or amount <= 0 then
        return false, Locale('server.invalid_amount')
    end

    local account = MySQL.single.await([[
        SELECT ba.balance
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa
            ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, fromAccountId, identifier, identifier })

    if not account or tonumber(account.balance) < amount then
        return false, Locale('server.insufficient_balance')
    end

    local targetExists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_accounts WHERE id = ?',
        { toAccountId }
    )

    if targetExists == 0 then
        return false, Locale('server.account_not_found')
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
            values = { fromAccountId, 'atm_transfer_out', -amount, Locale('server.atm_transfer_out') }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { toAccountId, 'atm_transfer_in', amount, Locale('server.atm_transfer_in') }
        }
    })

    if not ok then
        return false, Locale('server.transfer_error')
    end

    return true
end)
