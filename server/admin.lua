RegisterCommand('bankadmin', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts ORDER BY balance DESC LIMIT 50', {})

    print("^2========== " .. Locale('admin.top50_header') .. " ==========^7")
    for i, acc in ipairs(accounts) do
        print(string.format("^3#%d^7 | %s: ^2%s^7 | %s: ^5%s^7 | %s: ^1$%.2f^7",
            i, Locale('admin.owner'), acc.owner, Locale('admin.name'), acc.account_name, Locale('admin.balance'), acc.balance))
    end
    print("^2=====================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', Locale('server.check_console'))
end, false)

RegisterCommand('bankaddmoney', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local accountId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not accountId or not amount then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('admin.usage_addmoney'))
        return
    end

    local result = MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', {
        amount, accountId
    })

    local affectedRows = type(result) == 'table' and result.affectedRows or result
    if affectedRows and affectedRows > 0 then
        MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
            accountId, 'admin_deposit', amount, Locale('admin.admin_deposit_desc')
        })

        TriggerClientEvent('muhaddil_bank:notify', source, 'success',
            Locale('admin.added_money', amount, accountId))
        print(string.format("^2[ADMIN] %s añadió $%.2f a la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.account_not_found'))
    end
end, false)

RegisterCommand('bankremovemoney', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local accountId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not accountId or not amount then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('admin.usage_removemoney'))
        return
    end

    local affectedRows = MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', {
        amount, accountId
    })

    if affectedRows > 0 then
        MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
            accountId, 'admin_withdrawal', -amount, Locale('admin.admin_withdrawal_desc')
        })

        TriggerClientEvent('muhaddil_bank:notify', source, 'success',
            Locale('admin.removed_money', amount, accountId))
        print(string.format("^2[ADMIN] %s removió $%.2f de la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.account_not_found'))
    end
end, false)

RegisterCommand('bankloans', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local loans = MySQL.query.await('SELECT * FROM bank_loans WHERE status = "active" ORDER BY remaining DESC', {})

    print("^2========== " .. Locale('admin.active_loans_header') .. " ==========^7")
    for i, loan in ipairs(loans) do
        print(string.format("^3#%d^7 | %s: ^2%s^7 | %s: ^1$%.2f^7 | %s: ^1$%.2f^7",
            loan.id, Locale('admin.user'), loan.user_identifier, Locale('admin.amount'), loan.amount, Locale('admin.remaining'), loan.remaining))
    end
    print("^2========================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', Locale('server.check_console'))
end, false)

RegisterCommand('bankcancelloan', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local loanId = tonumber(args[1])

    if not loanId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('admin.usage_cancelloan'))
        return
    end

    local affectedRows = MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE id = ?', {
        loanId
    })

    if affectedRows > 0 then
        TriggerClientEvent('muhaddil_bank:notify', source, 'success', Locale('admin.loan_cancelled_id', loanId))
        print(string.format("^2[ADMIN] %s canceló el préstamo #%d^7", GetPlayerName(source), loanId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.loan_not_found'))
    end
end, false)

RegisterCommand('bankinfo', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local accountId = tonumber(args[1])

    if not accountId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('admin.usage_bankinfo'))
        return
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE id = ?', { accountId })

    if #accounts == 0 then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.account_not_found'))
        return
    end

    local account = accounts[1]

    local shared = MySQL.query.await('SELECT user_identifier FROM bank_shared_access WHERE account_id = ?', { accountId })

    print("^2========== " .. Locale('admin.account_info_header', accountId) .. " ==========^7")
    print("^3" .. Locale('admin.name') .. ":^7 " .. account.account_name)
    print("^3" .. Locale('admin.owner') .. ":^7 " .. account.owner)
    print("^3" .. Locale('admin.balance') .. ":^7 $" .. string.format("%.2f", account.balance))
    print("^3" .. Locale('admin.created_at') .. ":^7 " .. account.created_at)

    if #shared > 0 then
        print("^3" .. Locale('admin.shared_users') .. "^7")
        for _, user in ipairs(shared) do
            print("  - " .. user.user_identifier)
        end
    else
        print("^3" .. Locale('admin.shared_users') .. "^7 " .. Locale('admin.none'))
    end

    print("^2=============================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', Locale('server.check_console'))
end, false)

RegisterCommand('bankreset', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local targetId = tonumber(args[1])

    if not targetId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('admin.usage_bankreset'))
        return
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.player_not_found'))
        return
    end

    MySQL.query.await('DELETE FROM bank_accounts WHERE owner = ?', { targetIdentifier })

    MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE user_identifier = ?',
        { targetIdentifier })

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', Locale('admin.bank_reset_success'))
    TriggerClientEvent('muhaddil_bank:notify', targetId, 'error', Locale('admin.bank_reset_target'))
    print(string.format("^2[ADMIN] %s reseteó el banco de %s^7", GetPlayerName(source), GetPlayerName(targetId)))
end, false)

lib.callback.register('muhaddil_bank:getAdminData', function(source)
    if not hasPermission(source) then return nil end

    local totalAccounts = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts') or 0
    local totalBalance = MySQL.scalar.await('SELECT COALESCE(SUM(balance), 0) FROM bank_accounts') or 0
    local activeLoans = MySQL.scalar.await("SELECT COUNT(*) FROM bank_loans WHERE status = 'active'") or 0
    local totalLoanAmount = MySQL.scalar.await(
        "SELECT COALESCE(SUM(remaining), 0) FROM bank_loans WHERE status = 'active'") or 0
    local totalTransactions = MySQL.scalar.await('SELECT COUNT(*) FROM bank_transactions') or 0
    local totalTransactionVolume = MySQL.scalar.await('SELECT COALESCE(SUM(ABS(amount)), 0) FROM bank_transactions') or 0
    local totalSavings = MySQL.scalar.await('SELECT COALESCE(SUM(current_amount), 0) FROM bank_savings_accounts') or 0
    local totalScheduled = MySQL.scalar.await("SELECT COUNT(*) FROM bank_scheduled_transfers WHERE enabled = 1") or 0
    local pendingRequests = MySQL.scalar.await("SELECT COUNT(*) FROM bank_transfer_requests WHERE status = 'pending'") or
        0

    local recentTransactions = MySQL.query.await([[
        SELECT bt.*, ba.account_name, ba.owner
        FROM bank_transactions bt
        LEFT JOIN bank_accounts ba ON bt.account_id = ba.id
        ORDER BY bt.created_at DESC
        LIMIT 100
    ]])

    local topAccounts = MySQL.query.await([[
        SELECT * FROM bank_accounts ORDER BY balance DESC LIMIT 50
    ]])

    local allLoans = MySQL.query.await([[
        SELECT * FROM bank_loans WHERE status = 'active' ORDER BY remaining DESC
    ]])

    local bankOwnerships = MySQL.query.await('SELECT * FROM bank_ownership')

    local allScheduled = MySQL.query.await([[
        SELECT bst.*,
            ba_from.account_name as from_account_name,
            ba_to.account_name as to_account_name
        FROM bank_scheduled_transfers bst
        LEFT JOIN bank_accounts ba_from ON bst.from_account_id = ba_from.id
        LEFT JOIN bank_accounts ba_to ON bst.to_account_id = ba_to.id
        ORDER BY bst.created_at DESC
        LIMIT 100
    ]])

    local allPendingRequests = MySQL.query.await([[
        SELECT btr.*, ba.account_name as requester_account_name
        FROM bank_transfer_requests btr
        LEFT JOIN bank_accounts ba ON btr.requester_account_id = ba.id
        WHERE btr.status = 'pending'
        ORDER BY btr.created_at DESC
    ]])

    return {
        stats = {
            totalAccounts = totalAccounts,
            totalBalance = totalBalance,
            activeLoans = activeLoans,
            totalLoanAmount = totalLoanAmount,
            totalTransactions = totalTransactions,
            totalTransactionVolume = totalTransactionVolume,
            totalSavings = totalSavings,
            totalScheduled = totalScheduled,
            pendingRequests = pendingRequests,
        },
        recentTransactions = recentTransactions or {},
        topAccounts = topAccounts or {},
        allLoans = allLoans or {},
        bankOwnerships = bankOwnerships or {},
        allScheduled = allScheduled or {},
        allPendingRequests = allPendingRequests or {},
    }
end)

lib.callback.register('muhaddil_bank:adminSearchUser', function(source, searchQuery)
    if not hasPermission(source) then return nil end

    if not searchQuery or searchQuery == '' then return nil end

    local targetId = tonumber(searchQuery)
    local targetIdentifier = nil

    if targetId then
        targetIdentifier = GetPlayerIdentifier(targetId)
    else
        targetIdentifier = searchQuery
    end

    if not targetIdentifier then
        return { error = Locale('server.player_not_found') }
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE owner = ?', { targetIdentifier })
    local loans = MySQL.query.await('SELECT * FROM bank_loans WHERE user_identifier = ? ORDER BY created_at DESC',
        { targetIdentifier })
    local savings = MySQL.query.await([[
        SELECT bsa.*, ba.account_name
        FROM bank_savings_accounts bsa
        INNER JOIN bank_accounts ba ON bsa.account_id = ba.id
        WHERE bsa.owner = ?
    ]], { targetIdentifier })
    local contacts = MySQL.query.await('SELECT * FROM bank_contacts WHERE owner = ?', { targetIdentifier })
    local scheduled = MySQL.query.await('SELECT * FROM bank_scheduled_transfers WHERE owner = ?', { targetIdentifier })
    local creditScore = GetPlayerCreditScore(targetIdentifier)

    local transactions = {}
    for _, acc in ipairs(accounts or {}) do
        local accTx = MySQL.query.await([[
            SELECT * FROM bank_transactions
            WHERE account_id = ?
            ORDER BY created_at DESC
            LIMIT 50
        ]], { acc.id })
        for _, tx in ipairs(accTx or {}) do
            tx.account_name = acc.account_name
            table.insert(transactions, tx)
        end
    end

    return {
        identifier = targetIdentifier,
        accounts = accounts or {},
        loans = loans or {},
        savings = savings or {},
        contacts = contacts or {},
        scheduled = scheduled or {},
        transactions = transactions,
        creditScore = creditScore,
    }
end)

RegisterNetEvent('muhaddil_bank:adminAddMoney', function(accountId, amount)
    local src = source
    if not hasPermission(src) then return end

    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount or amount <= 0 then return end

    local account = MySQL.single.await('SELECT id FROM bank_accounts WHERE id = ?', { accountId })
    if not account then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })
    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'admin_deposit', amount, Locale('admin.admin_deposit_desc') }
    )

    Notify(src, 'success', Locale('admin.added_money', amount, accountId))
    print(string.format("^2[ADMIN] %s añadió $%.2f a cuenta #%d^7", GetPlayerName(src), amount, accountId))
end)

RegisterNetEvent('muhaddil_bank:adminRemoveMoney', function(accountId, amount)
    local src = source
    if not hasPermission(src) then return end

    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount or amount <= 0 then return end

    local account = MySQL.single.await('SELECT id FROM bank_accounts WHERE id = ?', { accountId })
    if not account then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', { amount, accountId })
    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
        { accountId, 'admin_withdrawal', -amount, Locale('admin.admin_withdrawal_desc') }
    )

    Notify(src, 'success', Locale('admin.removed_money', amount, accountId))
    print(string.format("^2[ADMIN] %s removió $%.2f de cuenta #%d^7", GetPlayerName(src), amount, accountId))
end)

RegisterNetEvent('muhaddil_bank:adminCancelLoan', function(loanId)
    local src = source
    if not hasPermission(src) then return end

    loanId = tonumber(loanId)
    if not loanId then return end

    MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE id = ?', { loanId })

    Notify(src, 'success', Locale('admin.loan_cancelled_id', loanId))
    print(string.format("^2[ADMIN] %s canceló préstamo #%d^7", GetPlayerName(src), loanId))
end)

RegisterNetEvent('muhaddil_bank:adminFreezeAccount', function(accountId)
    local src = source
    if not hasPermission(src) then return end

    accountId = tonumber(accountId)
    if not accountId then return end

    local balance = MySQL.scalar.await('SELECT balance FROM bank_accounts WHERE id = ?', { accountId })
    if balance then
        MySQL.query.await('UPDATE bank_accounts SET balance = 0 WHERE id = ?', { accountId })
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'admin_freeze', -tonumber(balance), Locale('admin.admin_freeze_desc') }
        )
        Notify(src, 'success', Locale('admin.account_frozen_id', accountId))
        print(string.format("^2[ADMIN] %s congeló cuenta #%d^7", GetPlayerName(src), accountId))
    end
end)

RegisterNetEvent('muhaddil_bank:adminDeleteScheduled', function(transferId)
    local src = source
    if not hasPermission(src) then return end

    transferId = tonumber(transferId)
    if not transferId then return end

    MySQL.query.await('DELETE FROM bank_scheduled_transfers WHERE id = ?', { transferId })
    Notify(src, 'success', Locale('admin.scheduled_deleted_id', transferId))
end)

RegisterNetEvent('muhaddil_bank:adminCancelRequest', function(requestId)
    local src = source
    if not hasPermission(src) then return end

    requestId = tonumber(requestId)
    if not requestId then return end

    MySQL.query.await(
        "UPDATE bank_transfer_requests SET status = 'cancelled', resolved_at = NOW() WHERE id = ?",
        { requestId }
    )
    Notify(src, 'success', Locale('admin.request_cancelled_id', requestId))
end)

if Config.AdminPanel and Config.AdminPanel.Enabled then
    RegisterCommand(Config.AdminPanel.Command, function(source, args, rawCommand)
        if source == 0 then return end
        if not hasPermission(source) then
            TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
            return
        end
        TriggerClientEvent('muhaddil_bank:openAdminPanel', source)
    end, false)
end

exports('GetTopAccounts', function(limit)
    limit = tonumber(limit) or 50
    return MySQL.query.await(
        'SELECT * FROM bank_accounts ORDER BY balance DESC LIMIT ?',
        { limit }
    )
end)

exports('AddMoneyToAccount', function(accountId, amount, reason)
    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount then return false end

    local affectedRows = MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
        { amount, accountId }
    )

    if affectedRows > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'admin_deposit', amount, reason or Locale('admin.admin_deposit_desc') }
        )
        return true
    end

    return false
end)

exports('RemoveMoneyFromAccount', function(accountId, amount, reason)
    accountId = tonumber(accountId)
    amount = tonumber(amount)
    if not accountId or not amount then return false end

    local affectedRows = MySQL.query.await(
        'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
        { amount, accountId }
    )

    if affectedRows > 0 then
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            { accountId, 'admin_withdrawal', -amount, reason or Locale('admin.admin_withdrawal_desc') }
        )
        return true
    end

    return false
end)

exports('GetActiveLoans', function()
    return MySQL.query.await(
        'SELECT * FROM bank_loans WHERE status = "active" ORDER BY remaining DESC',
        {}
    )
end)

exports('CancelLoan', function(loanId)
    loanId = tonumber(loanId)
    if not loanId then return false end

    local affectedRows = MySQL.query.await(
        'UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE id = ?',
        { loanId }
    )

    return affectedRows > 0
end)

exports('GetAccountInfo', function(accountId)
    accountId = tonumber(accountId)
    if not accountId then return nil end

    local accounts = MySQL.query.await(
        'SELECT * FROM bank_accounts WHERE id = ?',
        { accountId }
    )

    if #accounts == 0 then return nil end

    local shared = MySQL.query.await(
        'SELECT user_identifier FROM bank_shared_access WHERE account_id = ?',
        { accountId }
    )

    return {
        account = accounts[1],
        sharedUsers = shared
    }
end)

exports('ResetPlayerBank', function(identifier)
    if not identifier then return false end

    MySQL.query.await(
        'DELETE FROM bank_accounts WHERE owner = ?',
        { identifier }
    )

    MySQL.query.await(
        'UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE user_identifier = ?',
        { identifier }
    )

    return true
end)

print('^2[Bank System] Admin system loaded^7')
