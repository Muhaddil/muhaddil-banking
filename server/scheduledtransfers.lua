lib.callback.register('muhaddil_bank:getScheduledTransfers', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local transfers = MySQL.query.await([[
        SELECT bst.*,
            ba_from.account_name as from_account_name,
            ba_to.account_name as to_account_name
        FROM bank_scheduled_transfers bst
        LEFT JOIN bank_accounts ba_from ON bst.from_account_id = ba_from.id
        LEFT JOIN bank_accounts ba_to ON bst.to_account_id = ba_to.id
        WHERE bst.owner = ?
        ORDER BY bst.created_at DESC
    ]], { identifier })

    return transfers or {}
end)

RegisterNetEvent('muhaddil_bank:createScheduledTransfer', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.ScheduledTransfers.Enabled then
        return Notify(src, 'error', Locale('server.scheduled_disabled'))
    end

    local fromAccountId = tonumber(data.fromAccountId)
    local toAccountId = tonumber(data.toAccountId)
    local amount = tonumber(data.amount)
    local frequency = data.frequency
    local dayOfWeek = tonumber(data.dayOfWeek) or 1
    local hour = tonumber(data.hour) or 12
    local minute = tonumber(data.minute) or 0
    local description = data.description or ''

    if not fromAccountId or not toAccountId or not amount then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    if amount < Config.ScheduledTransfers.MinAmount then
        return Notify(src, 'error', Locale('server.scheduled_min_amount', Config.ScheduledTransfers.MinAmount))
    end

    if fromAccountId == toAccountId then
        return Notify(src, 'error', Locale('server.same_account_error'))
    end

    local validFrequency = false
    for _, f in ipairs(Config.ScheduledTransfers.Frequencies) do
        if f == frequency then
            validFrequency = true
            break
        end
    end
    if not validFrequency then
        return Notify(src, 'error', Locale('server.invalid_frequency'))
    end

    local account = MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE id = ? AND owner = ?',
        { fromAccountId, identifier }
    )
    if not account then
        return Notify(src, 'error', Locale('server.no_permission_origin'))
    end

    local destAccount = MySQL.single.await('SELECT id FROM bank_accounts WHERE id = ?', { toAccountId })
    if not destAccount then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_scheduled_transfers WHERE owner = ?',
        { identifier }
    )
    if count >= Config.ScheduledTransfers.MaxPerPlayer then
        return Notify(src, 'error', Locale('server.max_scheduled_reached'))
    end

    local nextExecution = CalculateNextExecution(frequency, dayOfWeek, hour, minute)

    MySQL.insert.await([[
        INSERT INTO bank_scheduled_transfers
        (owner, from_account_id, to_account_id, amount, frequency, day_of_week, hour, minute, description, next_execution)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]],
        { identifier, fromAccountId, toAccountId, amount, frequency, dayOfWeek, hour, minute, description, nextExecution })

    Notify(src, 'success', Locale('server.scheduled_created'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:toggleScheduledTransfer', function(transferId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    transferId = tonumber(transferId)
    if not transferId then return end

    local transfer = MySQL.single.await(
        'SELECT * FROM bank_scheduled_transfers WHERE id = ? AND owner = ?',
        { transferId, identifier }
    )
    if not transfer then
        return Notify(src, 'error', Locale('server.scheduled_not_found'))
    end

    local newEnabled = (transfer.enabled == 1 or transfer.enabled == true) and 0 or 1
    local nextExecution = nil

    if newEnabled == 1 then
        nextExecution = CalculateNextExecution(transfer.frequency, transfer.day_of_week, transfer.hour, transfer.minute)
        MySQL.query.await(
            'UPDATE bank_scheduled_transfers SET enabled = ?, next_execution = ? WHERE id = ?',
            { newEnabled, nextExecution, transferId }
        )
    else
        MySQL.query.await(
            'UPDATE bank_scheduled_transfers SET enabled = ?, next_execution = NULL WHERE id = ?',
            { newEnabled, transferId }
        )
    end

    local statusKey = newEnabled == 1 and 'server.scheduled_enabled' or 'server.scheduled_disabled'
    Notify(src, 'success', Locale(statusKey))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:updateScheduledTransfer', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local transferId = tonumber(data.transferId)
    local amount = tonumber(data.amount)
    local frequency = data.frequency
    local dayOfWeek = tonumber(data.dayOfWeek) or 1
    local hour = tonumber(data.hour) or 12
    local minute = tonumber(data.minute) or 0
    local description = data.description or ''

    if not transferId or not amount or amount < Config.ScheduledTransfers.MinAmount then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    local transfer = MySQL.single.await(
        'SELECT * FROM bank_scheduled_transfers WHERE id = ? AND owner = ?',
        { transferId, identifier }
    )
    if not transfer then
        return Notify(src, 'error', Locale('server.scheduled_not_found'))
    end

    local nextExecution = CalculateNextExecution(frequency, dayOfWeek, hour, minute)

    MySQL.query.await([[
        UPDATE bank_scheduled_transfers
        SET amount = ?, frequency = ?, day_of_week = ?, hour = ?, minute = ?, description = ?, next_execution = ?
        WHERE id = ?
    ]], { amount, frequency, dayOfWeek, hour, minute, description, nextExecution, transferId })

    Notify(src, 'success', Locale('server.scheduled_updated'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:deleteScheduledTransfer', function(transferId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    transferId = tonumber(transferId)
    if not transferId then return end

    local transfer = MySQL.single.await(
        'SELECT * FROM bank_scheduled_transfers WHERE id = ? AND owner = ?',
        { transferId, identifier }
    )
    if not transfer then
        return Notify(src, 'error', Locale('server.scheduled_not_found'))
    end

    MySQL.query.await('DELETE FROM bank_scheduled_transfers WHERE id = ?', { transferId })

    Notify(src, 'success', Locale('server.scheduled_deleted'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

if Config.ScheduledTransfers.Enabled then
    Wait(15000)
    lib.cron.new('* * * * *', function()
        local now = os.date('%Y-%m-%d %H:%M:%S')

        local dueTransfers = MySQL.query.await([[
            SELECT * FROM bank_scheduled_transfers
            WHERE enabled = 1 AND next_execution IS NOT NULL AND next_execution <= ?
        ]], { now })

        if not dueTransfers or #dueTransfers == 0 then return end

        local executed, failed = 0, 0

        for _, transfer in ipairs(dueTransfers) do
            local amount = tonumber(transfer.amount)

            local balance = tonumber(MySQL.scalar.await(
                'SELECT balance FROM bank_accounts WHERE id = ?',
                { transfer.from_account_id }
            ))

            if balance and balance >= amount then
                local success = MySQL.transaction.await({
                    {
                        query = 'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
                        values = { amount, transfer.from_account_id }
                    },
                    {
                        query = 'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
                        values = { amount, transfer.to_account_id }
                    },
                    {
                        query =
                        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
                        values = { transfer.from_account_id, 'scheduled_out', -amount,
                            'Transferencia programada: ' .. (transfer.description or '#' .. transfer.id) }
                    },
                    {
                        query =
                        'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
                        values = { transfer.to_account_id, 'scheduled_in', amount,
                            'Transferencia programada recibida: ' .. (transfer.description or '#' .. transfer.id) }
                    }
                })

                if success then
                    local nextExec = CalculateNextExecution(
                        transfer.frequency, transfer.day_of_week, transfer.hour, transfer.minute
                    )
                    MySQL.query.await(
                        'UPDATE bank_scheduled_transfers SET last_executed = NOW(), next_execution = ? WHERE id = ?',
                        { nextExec, transfer.id }
                    )
                    executed = executed + 1

                    local playerData = GetPlayerFromIdentifier(transfer.owner)
                    if playerData and playerData.source then
                        Notify(playerData.source, 'info',
                            Locale('server.scheduled_executed', amount))
                        TriggerEvent('muhaddil_bank:afterTransfer', playerData.source)
                        TriggerClientEvent('muhaddil_bank:refreshData', playerData.source)
                        TriggerClientEvent('muhaddil_bank:phone:notify', playerData.source,
                            Locale('server.scheduled_executed_phone', amount), 'info')
                    end

                    local toAccount = MySQL.single.await('SELECT owner FROM bank_accounts WHERE id = ?',
                        { transfer.to_account_id })
                    if toAccount and toAccount.owner then
                        local targetData = GetPlayerFromIdentifier(toAccount.owner)
                        if targetData and targetData.source then
                            TriggerEvent('muhaddil_bank:afterTransfer', targetData.source)
                            TriggerClientEvent('muhaddil_bank:refreshData', targetData.source)
                            TriggerClientEvent('muhaddil_bank:phone:notify', targetData.source,
                                Locale('server.scheduled_received_phone', amount), 'success')
                        end
                    end
                else
                    failed = failed + 1
                end
            else
                failed = failed + 1

                local playerData = GetPlayerFromIdentifier(transfer.owner)
                if playerData and playerData.source then
                    Notify(playerData.source, 'error',
                        Locale('server.scheduled_failed_funds'))
                    TriggerClientEvent('muhaddil_bank:phone:notify', playerData.source,
                        Locale('server.scheduled_failed_funds_phone', amount), 'error')
                end

                local nextExec = CalculateNextExecution(
                    transfer.frequency, transfer.day_of_week, transfer.hour, transfer.minute
                )
                MySQL.query.await(
                    'UPDATE bank_scheduled_transfers SET next_execution = ? WHERE id = ?',
                    { nextExec, transfer.id }
                )
            end
        end

        if executed > 0 or failed > 0 then
            print(string.format(
                '^2[Bank System] Scheduled transfers: %d executed, %d failed^7',
                executed, failed
            ))
        end
    end, { debug = false })
end

print('^2[Bank System] Scheduled transfers system loaded^7')
