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
        print(Locale('admin.noFramework'))
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
    print(Locale('admin.noFramework'))
end

local function syncPlayerAccount(accountId)
    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner then
        local targetPlayer = GetPlayerFromIdentifier(owner)
        local playerId = nil
        if targetPlayer then
            if FrameWork == 'esx' then
                playerId = targetPlayer.source
            elseif FrameWork == 'qb' then
                playerId = targetPlayer.PlayerData.source
            end
        end

        if playerId then
            exports['muhaddil-banking']:SyncFrameworkBank(playerId)
            TriggerClientEvent('muhaddil_bank:refreshData', playerId)
        end
    end
end

RegisterCommand('bankadmin', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', Locale('server.no_permissions'))
        return
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts ORDER BY balance DESC LIMIT 50', {})

    print("^2========== " .. Locale('admin.top50_header') .. " ==========^7")
    for i, acc in ipairs(accounts) do
        print(string.format("^3#%d^7 | %s: ^2%s^7 | %s: ^5%s^7 | %s: ^1$%.2f^7",
            i, Locale('admin.owner'), acc.owner, Locale('admin.name'), acc.account_name, Locale('admin.balance'),
            acc.balance))
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
        syncPlayerAccount(accountId)
        print(Locale('admin.logAddMoney', GetPlayerName(source), amount, accountId))
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
        syncPlayerAccount(accountId)
        print(Locale('admin.logRemoveMoney', GetPlayerName(source), amount, accountId))
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
            loan.id, Locale('admin.user'), loan.user_identifier, Locale('admin.amount'), loan.amount,
            Locale('admin.remaining'), loan.remaining))
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
        print(Locale('admin.logCancelLoan', GetPlayerName(source), loanId))
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
    print(Locale('admin.logResetBank', GetPlayerName(source), GetPlayerName(targetId)))
end, false)

local AlertThresholds = {
    LargeTransaction = 50000,
    RapidBalanceChangePercent = 80,
    HighFrequencyCount = 10,
    HighFrequencyMinutes = 30,
    RecentHoursWindow = 24,
}

lib.callback.register('muhaddil_bank:getAdminAlerts', function(source)
    if not hasPermission(source) then return nil end

    local alerts = {}

    local largeTx = MySQL.query.await([[
        SELECT bt.*, ba.account_name, ba.owner
        FROM bank_transactions bt
        LEFT JOIN bank_accounts ba ON bt.account_id = ba.id
        WHERE ABS(bt.amount) >= ?
        AND bt.created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        ORDER BY ABS(bt.amount) DESC
        LIMIT 50
    ]], { AlertThresholds.LargeTransaction, AlertThresholds.RecentHoursWindow })

    for _, tx in ipairs(largeTx or {}) do
        table.insert(alerts, {
            type = 'large_transaction',
            severity = math.abs(tonumber(tx.amount) or 0) >= AlertThresholds.LargeTransaction * 2 and 'critical' or
                'warning',
            accountId = tx.account_id,
            accountName = tx.account_name or ('Account #' .. tx.account_id),
            owner = tx.owner,
            amount = tx.amount,
            txType = tx.type,
            description = tx.description,
            date = tx.created_at,
            txId = tx.id,
        })
    end

    local highFreq = MySQL.query.await([[
        SELECT account_id, ba.account_name, ba.owner, COUNT(*) as tx_count,
            MIN(bt.created_at) as first_tx, MAX(bt.created_at) as last_tx
        FROM bank_transactions bt
        LEFT JOIN bank_accounts ba ON bt.account_id = ba.id
        WHERE bt.created_at >= DATE_SUB(NOW(), INTERVAL ? MINUTE)
        GROUP BY account_id
        HAVING tx_count >= ?
        ORDER BY tx_count DESC
        LIMIT 20
    ]], { AlertThresholds.HighFrequencyMinutes, AlertThresholds.HighFrequencyCount })

    for _, freq in ipairs(highFreq or {}) do
        table.insert(alerts, {
            type = 'high_frequency',
            severity = (tonumber(freq.tx_count) or 0) >= AlertThresholds.HighFrequencyCount * 2 and 'critical' or
                'warning',
            accountId = freq.account_id,
            accountName = freq.account_name or ('Account #' .. freq.account_id),
            owner = freq.owner,
            txCount = freq.tx_count,
            firstTx = freq.first_tx,
            lastTx = freq.last_tx,
            date = freq.last_tx,
        })
    end

    local selfTransfers = MySQL.query.await([[
        SELECT bt.id, bt.account_id, bt.amount, bt.description, bt.created_at,
            ba_from.owner as from_owner, ba_from.account_name as from_name,
            bt.description as tx_desc
        FROM bank_transactions bt
        INNER JOIN bank_accounts ba_from ON bt.account_id = ba_from.id
        WHERE bt.type IN ('transfer_out', 'scheduled_out')
        AND bt.created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        AND ABS(bt.amount) >= 1000
        ORDER BY bt.created_at DESC
        LIMIT 30
    ]], { AlertThresholds.RecentHoursWindow })

    for _, st in ipairs(selfTransfers or {}) do
        local targetAccId = st.tx_desc and st.tx_desc:match('#(%d+)')
        if targetAccId then
            local targetOwner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?',
                { tonumber(targetAccId) })
            if targetOwner and targetOwner == st.from_owner then
                table.insert(alerts, {
                    type = 'self_transfer',
                    severity = 'info',
                    accountId = st.account_id,
                    accountName = st.from_name,
                    owner = st.from_owner,
                    amount = st.amount,
                    targetAccountId = tonumber(targetAccId),
                    description = st.tx_desc,
                    date = st.created_at,
                    txId = st.id,
                })
            end
        end
    end

    local drainedAccounts = MySQL.query.await([[
        SELECT ba.id, ba.account_name, ba.owner, ba.balance,
            (SELECT MAX(ABS(bt2.amount)) FROM bank_transactions bt2
             WHERE bt2.account_id = ba.id
             AND bt2.created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)) as max_recent_tx
        FROM bank_accounts ba
        WHERE ba.balance <= 0
        AND EXISTS (
            SELECT 1 FROM bank_transactions bt
            WHERE bt.account_id = ba.id
            AND bt.amount < -1000
            AND bt.created_at >= DATE_SUB(NOW(), INTERVAL ? HOUR)
        )
        LIMIT 20
    ]], { AlertThresholds.RecentHoursWindow, AlertThresholds.RecentHoursWindow })

    for _, acc in ipairs(drainedAccounts or {}) do
        table.insert(alerts, {
            type = 'drained_account',
            severity = 'warning',
            accountId = acc.id,
            accountName = acc.account_name,
            owner = acc.owner,
            balance = acc.balance,
            maxRecentTx = acc.max_recent_tx,
            date = os.date('%Y-%m-%d %H:%M:%S'),
        })
    end

    local severityOrder = { critical = 1, warning = 2, info = 3 }
    table.sort(alerts, function(a, b)
        return (severityOrder[a.severity] or 9) < (severityOrder[b.severity] or 9)
    end)

    return alerts
end)

lib.callback.register('muhaddil_bank:getAdminData', function(source)
    if not hasPermission(source) then return nil end

    local totalAccounts = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts') or 0
    local totalBalance = MySQL.scalar.await('SELECT COALESCE(SUM(balance), 0) FROM bank_accounts') or 0
    local activeLoans = MySQL.scalar.await("SELECT COUNT(*) FROM bank_loans WHERE status = 'active'") or 0
    local totalLoanAmount = MySQL.scalar.await(
        "SELECT COALESCE(SUM(amount), 0) FROM bank_loans") or 0
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
        SELECT * FROM bank_loans ORDER BY remaining DESC
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

    local searchLower = string.lower(searchQuery)
    local targetIdentifier = nil

    local targetId = tonumber(searchQuery)
    if targetId then
        local identifier = GetPlayerIdentifier(targetId)
        if identifier then
            targetIdentifier = identifier
        end
    end

    if not targetIdentifier then
        for _, playerId in ipairs(GetPlayers()) do
            local identifier = GetPlayerIdentifier(playerId)
            if not identifier then goto continue end

            local playerName = GetPlayerName(playerId)
            if playerName and string.lower(playerName):find(searchLower, 1, true) then
                targetIdentifier = identifier
                break
            end

            if FrameWork == 'esx' then
                local xPlayer = ESX.GetPlayerFromId(playerId)
                if xPlayer then
                    local name = (xPlayer.getName and xPlayer.getName()) or xPlayer.name
                    if name and string.lower(name):find(searchLower, 1, true) then
                        targetIdentifier = identifier
                        break
                    end
                end
            end

            if FrameWork == 'qb' then
                local Player = QBCore.Functions.GetPlayer(playerId)
                if Player and Player.PlayerData and Player.PlayerData.charinfo then
                    local ci = Player.PlayerData.charinfo
                    local fullName = string.format('%s %s', ci.firstname or '', ci.lastname or ''):lower()
                    if fullName:find(searchLower, 1, true) then
                        targetIdentifier = identifier
                        break
                    end
                end
            end

            ::continue::
        end
    end

    if not targetIdentifier then
        if FrameWork == 'esx' then
            local result = MySQL.single.await([[
                SELECT identifier FROM users
                WHERE LOWER(CONCAT(firstname, ' ', lastname)) LIKE ?
                LIMIT 1
            ]], { '%' .. searchLower .. '%' })

            if result then
                targetIdentifier = result.identifier
            end
        elseif FrameWork == 'qb' then
            local result = MySQL.single.await([[
                SELECT citizenid FROM players
                WHERE LOWER(CONCAT(
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')),
                    ' ',
                    JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))
                )) LIKE ?
                LIMIT 1
            ]], { '%' .. searchLower .. '%' })

            if result then
                targetIdentifier = result.citizenid
            end
        end
    end

    if not targetIdentifier then
        return { error = Locale('server.player_not_found') }
    end

    local accounts = MySQL.query.await(
        'SELECT * FROM bank_accounts WHERE owner = ?',
        { targetIdentifier }
    )

    local loans = MySQL.query.await(
        'SELECT * FROM bank_loans WHERE user_identifier = ? ORDER BY created_at DESC',
        { targetIdentifier }
    )

    local savings = MySQL.query.await([[
        SELECT bsa.*, ba.account_name
        FROM bank_savings_accounts bsa
        INNER JOIN bank_accounts ba ON bsa.account_id = ba.id
        WHERE bsa.owner = ?
    ]], { targetIdentifier })

    local contacts = MySQL.query.await(
        'SELECT * FROM bank_contacts WHERE owner = ?',
        { targetIdentifier }
    )

    local scheduled = MySQL.query.await(
        'SELECT * FROM bank_scheduled_transfers WHERE owner = ?',
        { targetIdentifier }
    )

    local creditScore = GetPlayerCreditScore(targetIdentifier)

    local transactions = {}

    for _, acc in ipairs(accounts or {}) do
        acc.shared_users = MySQL.query.await(
            'SELECT user_identifier FROM bank_shared_access WHERE account_id = ?',
            { acc.id }
        ) or {}

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
    syncPlayerAccount(accountId)
    print(Locale('admin.logAddMoney', GetPlayerName(src), amount, accountId))
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
    syncPlayerAccount(accountId)
    print(Locale('admin.logRemoveMoney', GetPlayerName(src), amount, accountId))
end)

RegisterNetEvent('muhaddil_bank:adminCancelLoan', function(loanId)
    local src = source
    if not hasPermission(src) then return end

    loanId = tonumber(loanId)
    if not loanId then return end

    MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE id = ?', { loanId })

    Notify(src, 'success', Locale('admin.loan_cancelled_id', loanId))
    local accountId = MySQL.scalar.await('SELECT account_id FROM bank_loan_payments WHERE loan_id = ? LIMIT 1',
        { loanId })
    if not accountId then
        -- Try to find an account for the user
        local owner = MySQL.scalar.await('SELECT user_identifier FROM bank_loans WHERE id = ?', { loanId })
        if owner then
            accountId = MySQL.scalar.await('SELECT id FROM bank_accounts WHERE owner = ? LIMIT 1', { owner })
        end
    end
    if accountId then syncPlayerAccount(accountId) end
    print(Locale('admin.logCancelLoan', GetPlayerName(src), loanId))
end)

RegisterNetEvent('muhaddil_bank:adminFreezeAccount', function(accountId)
    local src = source
    if not hasPermission(src) then return end

    accountId = tonumber(accountId)
    if not accountId then return end

    local account = MySQL.single.await('SELECT * FROM bank_accounts WHERE id = ?', { accountId })
    if account then
        local newFrozenStatus = not (account.frozen or false)
        MySQL.query.await('UPDATE bank_accounts SET frozen = ? WHERE id = ?', { newFrozenStatus and 1 or 0, accountId })
        Notify(src, 'success',
            newFrozenStatus and Locale('admin.account_frozen_id', accountId) or
            Locale('admin.account_unfrozen_id', accountId))
        syncPlayerAccount(accountId)
        print(Locale('admin.logFreezeAccount', GetPlayerName(src),
            newFrozenStatus and Locale('admin.frozenStatus') or Locale('admin.unfrozenStatus'), accountId))
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

RegisterNetEvent('muhaddil_bank:adminDeleteSaving', function(data)
    local src = source
    if not hasPermission(src) then return end

    local savingId = tonumber(data.savingId)
    if not savingId then return end

    local savings = MySQL.single.await('SELECT * FROM bank_savings_accounts WHERE id = ?', { savingId })
    if not savings then
        return Notify(src, 'error', Locale('server.savings_not_found'))
    end

    local currentAmount = tonumber(savings.current_amount) or 0
    if currentAmount > 0 then
        MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            { currentAmount, savings.account_id })
        MySQL.insert.await([[
            INSERT INTO bank_transactions (account_id, type, amount, description)
            VALUES (?, 'savings_close', ?, ?)
        ]], { savings.account_id, currentAmount, Locale('server.savings_close', savings.goal_name, currentAmount) })
    end

    MySQL.query.await('DELETE FROM bank_savings_accounts WHERE id = ?', { savingId })

    Notify(src, 'success', Locale('admin.saving_deleted_id', savingId))
    syncPlayerAccount(savings.account_id)
    print(Locale('admin.logDeleteSaving', GetPlayerName(src), savingId))
end)

RegisterNetEvent('muhaddil_bank:adminDeleteContact', function(data)
    local src = source
    if not hasPermission(src) then return end

    local contactId = tonumber(data.contactId)
    if not contactId then return end

    local affectedRows = MySQL.query.await('DELETE FROM bank_contacts WHERE id = ?', { contactId })

    if affectedRows > 0 then
        Notify(src, 'success', Locale('admin.contact_deleted_id', contactId))
        print(Locale('admin.logDeleteContact', GetPlayerName(src), contactId))
    else
        Notify(src, 'error', Locale('server.contact_not_found'))
    end
end)

RegisterNetEvent('muhaddil_bank:adminDeleteTransaction', function(data)
    local src = source
    if not hasPermission(src) then return end

    local txId = tonumber(data.txId)
    if not txId then return end

    local tx = MySQL.single.await('SELECT account_id FROM bank_transactions WHERE id = ?', { txId })
    if not tx then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    local affectedRows = MySQL.query.await('DELETE FROM bank_transactions WHERE id = ?', { txId })

    if affectedRows > 0 then
        Notify(src, 'success', Locale('admin.tx_deleted_id', txId))
        syncPlayerAccount(tx.account_id)
        print(Locale('admin.logDeleteTransaction', GetPlayerName(src), txId))
    else
        Notify(src, 'error', Locale('server.invalid_data'))
    end
end)

RegisterNetEvent('muhaddil_bank:adminRemoveSharedUser', function(data)
    local src = source
    if not hasPermission(src) then return end

    local accountId = tonumber(data.accountId)
    local identifier = data.identifier
    if not accountId or not identifier then return end

    local affectedRows = MySQL.query.await(
        'DELETE FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?',
        { accountId, identifier }
    )

    if affectedRows > 0 then
        Notify(src, 'success', Locale('admin.shared_user_removed'))
        syncPlayerAccount(accountId)
        print(string.format('^2[ADMIN] %s removió el acceso de %s a la cuenta #%d^7', GetPlayerName(src), identifier,
            accountId))
    else
        Notify(src, 'error', Locale('server.invalid_data'))
    end
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

print(Locale('admin.systemLoaded'))
