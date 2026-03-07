lib.callback.register('muhaddil_bank:getSavings', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local savings = MySQL.query.await([[
        SELECT bsa.*, ba.account_name
        FROM bank_savings_accounts bsa
        INNER JOIN bank_accounts ba ON bsa.account_id = ba.id
        WHERE bsa.owner = ?
        ORDER BY bsa.created_at DESC
    ]], { identifier })

    return savings or {}
end)

RegisterNetEvent('muhaddil_bank:createSavings', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.Savings.Enabled then
        return Notify(src, 'error', Locale('server.savings_disabled'))
    end

    local accountId = tonumber(data.accountId)
    local goalName = data.goalName
    local goalAmount = tonumber(data.goalAmount)

    if not accountId or not goalName or goalName == '' then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    if not goalAmount or goalAmount <= 0 or goalAmount > Config.Savings.MaxGoalAmount then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.no_permission_origin'))
    end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_savings_accounts WHERE account_id = ? AND owner = ?',
        { accountId, identifier }
    )
    if count >= Config.Savings.MaxPerAccount then
        return Notify(src, 'error', Locale('server.max_savings_reached'))
    end

    MySQL.insert.await([[
        INSERT INTO bank_savings_accounts (account_id, owner, goal_name, goal_amount, interest_rate)
        VALUES (?, ?, ?, ?, ?)
    ]], { accountId, identifier, goalName, goalAmount, Config.Savings.InterestRate })

    Notify(src, 'success', Locale('server.savings_created'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:depositSavings', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local savingsId = tonumber(data.savingsId)
    local amount = tonumber(data.amount)

    if not savingsId or not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    if amount < Config.Savings.MinDeposit then
        return Notify(src, 'error', Locale('server.savings_min_deposit', Config.Savings.MinDeposit))
    end

    local savings = MySQL.single.await(
        'SELECT * FROM bank_savings_accounts WHERE id = ? AND owner = ?',
        { savingsId, identifier }
    )
    if not savings then
        return Notify(src, 'error', Locale('server.savings_not_found'))
    end

    local balance = tonumber(MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ?', { savings.account_id }
    ))

    if not balance or balance < amount then
        return Notify(src, 'error', Locale('server.insufficient_balance'))
    end

    MySQL.transaction.await({
        {
            query = 'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
            values = { amount, savings.account_id }
        },
        {
            query = 'UPDATE bank_savings_accounts SET current_amount = current_amount + ? WHERE id = ?',
            values = { amount, savingsId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { savings.account_id, 'savings_deposit', -amount, 'Depósito en ahorro: ' .. savings.goal_name }
        }
    })

    Notify(src, 'success', Locale('server.savings_deposit_completed'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:withdrawSavings', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local savingsId = tonumber(data.savingsId)
    local amount = tonumber(data.amount)

    if not savingsId or not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    local savings = MySQL.single.await(
        'SELECT * FROM bank_savings_accounts WHERE id = ? AND owner = ?',
        { savingsId, identifier }
    )
    if not savings then
        return Notify(src, 'error', Locale('server.savings_not_found'))
    end

    local currentAmount = tonumber(savings.current_amount)
    if currentAmount < amount then
        amount = currentAmount
    end

    MySQL.transaction.await({
        {
            query = 'UPDATE bank_savings_accounts SET current_amount = current_amount - ? WHERE id = ?',
            values = { amount, savingsId }
        },
        {
            query = 'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            values = { amount, savings.account_id }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { savings.account_id, 'savings_withdraw', amount, 'Retiro de ahorro: ' .. savings.goal_name }
        }
    })

    Notify(src, 'success', Locale('server.savings_withdraw_completed'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:deleteSavings', function(savingsId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    savingsId = tonumber(savingsId)
    if not savingsId then return end

    local savings = MySQL.single.await(
        'SELECT * FROM bank_savings_accounts WHERE id = ? AND owner = ?',
        { savingsId, identifier }
    )
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
        ]], { savings.account_id, currentAmount, 'Cierre de ahorro: ' .. savings.goal_name })
    end

    MySQL.query.await('DELETE FROM bank_savings_accounts WHERE id = ?', { savingsId })

    Notify(src, 'success', Locale('server.savings_deleted'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

if Config.Savings.Enabled then
    Wait(12000)
    local cronExpr = buildCronExpression(Config.Savings.InterestIntervalHours)

    lib.cron.new(cronExpr, function()
        print('^3[Bank System] Processing savings interest...^7')

        local savings = MySQL.query.await([[
            SELECT * FROM bank_savings_accounts WHERE current_amount > 0
        ]])

        if not savings or #savings == 0 then
            print('^3[Bank System] No savings to process.^7')
            return
        end

        local processed = 0
        for _, s in ipairs(savings) do
            local interest = math.floor((tonumber(s.current_amount) * (tonumber(s.interest_rate) / 100)) + 0.5)
            if interest > 0 then
                MySQL.query.await(
                    'UPDATE bank_savings_accounts SET current_amount = current_amount + ?, last_interest_date = NOW() WHERE id = ?',
                    { interest, s.id }
                )
                MySQL.insert.await([[
                    INSERT INTO bank_transactions (account_id, type, amount, description)
                    VALUES (?, 'savings_interest', ?, ?)
                ]], { s.account_id, interest, 'Interés de ahorro: ' .. s.goal_name })

                processed = processed + 1
            end
        end

        print(string.format('^2[Bank System] Savings interest processed: %d goals^7', processed))
    end, { debug = false })
end

print('^2[Bank System] Savings system loaded^7')
