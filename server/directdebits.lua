if not Config.DirectDebits or not Config.DirectDebits.Enabled then return end

RegisterNetEvent('muhaddil_bank:toggleDirectDebit', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local debitId = tonumber(data.debitId)
    if not debitId then return end

    local debit = MySQL.single.await(
        'SELECT * FROM bank_direct_debits WHERE id = ? AND owner = ?',
        { debitId, identifier }
    )

    if not debit then
        return Notify(src, 'error', Locale('server.debit_not_found') or 'Domiciliación no encontrada')
    end

    local newEnabled = debit.enabled == 1 and 0 or 1
    MySQL.query.await('UPDATE bank_direct_debits SET enabled = ? WHERE id = ?', { newEnabled, debitId })

    local status = newEnabled == 1 and 'activada' or 'desactivada'
    Notify(src, 'success', Locale('server.debit_toggled', status) or '✅ Domiciliación ' .. status)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:cancelDirectDebit', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local debitId = tonumber(data.debitId)
    if not debitId then return end

    local debit = MySQL.single.await(
        'SELECT * FROM bank_direct_debits WHERE id = ? AND owner = ?',
        { debitId, identifier }
    )

    if not debit then
        return Notify(src, 'error', Locale('server.debit_not_found') or 'Domiciliación no encontrada')
    end

    MySQL.query.await('DELETE FROM bank_direct_debits WHERE id = ?', { debitId })
    Notify(src, 'success', Locale('server.debit_cancelled') or '✅ Domiciliación cancelada')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:changeDebitAccount', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local debitId = tonumber(data.debitId)
    local newAccountId = tonumber(data.accountId)
    if not debitId or not newAccountId then return end

    local debit = MySQL.single.await(
        'SELECT * FROM bank_direct_debits WHERE id = ? AND owner = ?',
        { debitId, identifier }
    )

    if not debit then
        return Notify(src, 'error', Locale('server.debit_not_found') or 'Domiciliación no encontrada')
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, newAccountId, identifier, identifier })

    if not account then
        return Notify(src, 'error', Locale('server.no_permission_origin') or 'No tienes permiso sobre esta cuenta')
    end

    MySQL.query.await('UPDATE bank_direct_debits SET account_id = ? WHERE id = ?', { newAccountId, debitId })
    Notify(src, 'success', Locale('server.debit_account_changed') or '✅ Cuenta de domiciliación actualizada')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

---@param identifier string Player identifier
---@param accountId number Bank account ID to charge
---@param creditorName string Name of the creditor (e.g., "Dynasty8 Housing")
---@param amount number Amount to charge
---@param frequency string 'daily', 'weekly', 'biweekly', 'monthly'
---@param description string Description of the charge
---@return number|nil debitId The ID of the created direct debit
exports('RegisterDirectDebit', function(identifier, accountId, creditorName, amount, frequency, description)
    if not identifier or not accountId or not creditorName or not amount then
        return nil
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then return nil end

    frequency = frequency or 'monthly'
    description = description or ''

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_direct_debits WHERE owner = ?',
        { identifier }
    )
    if tonumber(count) >= Config.DirectDebits.MaxPerPlayer then
        return nil
    end

    local nextExec = CalculateNextExecution(frequency, 2, 12, 0)

    local sourceResource = GetInvokingResource() or 'unknown'

    local debitId = MySQL.insert.await([[
        INSERT INTO bank_direct_debits (owner, account_id, creditor_name, description, amount, frequency, next_execution, source_resource)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { identifier, accountId, creditorName, description, amount, frequency, nextExec, sourceResource })

    local playerData = GetPlayerFromIdentifier(identifier)
    if playerData and playerData.source then
        Notify(playerData.source, 'info',
            Locale('server.debit_registered', creditorName, amount) or
            '📋 Nueva domiciliación registrada: ' .. creditorName .. ' - $' .. amount .. '/' .. frequency)
        TriggerClientEvent('muhaddil_bank:refreshData', playerData.source)
    end

    return debitId
end)

---@param debitId number The direct debit ID
---@return boolean success
exports('CancelDirectDebitById', function(debitId)
    if not debitId then return false end

    local debit = MySQL.single.await('SELECT * FROM bank_direct_debits WHERE id = ?', { debitId })
    if not debit then return false end

    MySQL.query.await('DELETE FROM bank_direct_debits WHERE id = ?', { debitId })

    local playerData = GetPlayerFromIdentifier(debit.owner)
    if playerData and playerData.source then
        Notify(playerData.source, 'info',
            Locale('server.debit_cancelled_external', debit.creditor_name) or
            '📋 Domiciliación cancelada: ' .. debit.creditor_name)
        TriggerClientEvent('muhaddil_bank:refreshData', playerData.source)
    end

    return true
end)

---@param identifier string Player identifier
---@param resourceName string The resource that registered the debits
---@return number count Number of debits cancelled
exports('CancelDirectDebitsByResource', function(identifier, resourceName)
    if not identifier or not resourceName then return 0 end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_direct_debits WHERE owner = ? AND source_resource = ?',
        { identifier, resourceName }
    )

    MySQL.query.await(
        'DELETE FROM bank_direct_debits WHERE owner = ? AND source_resource = ?',
        { identifier, resourceName }
    )

    return tonumber(count) or 0
end)

Citizen.CreateThread(function()
    Wait(20000)

    local intervalMinutes = Config.DirectDebits.IntervalMinutes or 60
    local cronExpr = string.format('*/%d * * * *', math.max(1, intervalMinutes))

    if intervalMinutes >= 60 then
        local hours = math.floor(intervalMinutes / 60)
        cronExpr = string.format('0 */%d * * *', hours)
    end

    print(string.format('^3[Bank System] Direct debits cron: "%s" (every %d min)^7', cronExpr, intervalMinutes))

    lib.cron.new(cronExpr, function()
        local pendingDebits = MySQL.query.await([[
            SELECT * FROM bank_direct_debits
            WHERE enabled = 1 AND next_execution <= NOW()
        ]])

        if not pendingDebits or #pendingDebits == 0 then return end

        local success, failed = 0, 0

        for _, debit in ipairs(pendingDebits) do
            local amount = tonumber(debit.amount)
            local account = MySQL.single.await(
                'SELECT * FROM bank_accounts WHERE id = ?',
                { debit.account_id }
            )

            if account and tonumber(account.balance) >= amount then
                MySQL.query.await(
                    'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
                    { amount, debit.account_id }
                )

                MySQL.insert.await([[
                    INSERT INTO bank_transactions (account_id, type, amount, description)
                    VALUES (?, 'direct_debit', ?, ?)
                ]], {
                    debit.account_id,
                    -amount,
                    'Domiciliación: ' .. debit.creditor_name .. (debit.description and (' - ' .. debit.description) or '')
                })

                local dayOfWeek = 2
                local nextExec = CalculateNextExecution(debit.frequency, dayOfWeek, 12, 0)
                MySQL.query.await(
                    'UPDATE bank_direct_debits SET last_executed = NOW(), next_execution = ? WHERE id = ?',
                    { nextExec, debit.id }
                )

                if Config.DirectDebits.NotifyOnPayment then
                    local playerData = GetPlayerFromIdentifier(debit.owner)
                    if playerData and playerData.source then
                        Notify(playerData.source, 'info',
                            Locale('server.debit_charged', debit.creditor_name, amount) or
                            '💳 Domiciliación cobrada: ' .. debit.creditor_name .. ' - $' .. amount)
                        TriggerClientEvent('muhaddil_bank:refreshData', playerData.source)
                    end
                end

                success = success + 1
            else
                if Config.DirectDebits.NotifyOnFailure then
                    local playerData = GetPlayerFromIdentifier(debit.owner)
                    if playerData and playerData.source then
                        Notify(playerData.source, 'error',
                            Locale('server.debit_failed', debit.creditor_name) or
                            '⚠️ Domiciliación fallida por fondos insuficientes: ' .. debit.creditor_name)
                        TriggerClientEvent('muhaddil_bank:refreshData', playerData.source)
                    end
                end

                if Config.DirectDebits.PenaltyOnMiss and Config.DirectDebits.PenaltyRate then
                    local penalty = math.ceil(amount * (Config.DirectDebits.PenaltyRate / 100))

                    if account then
                        MySQL.insert.await([[
                            INSERT INTO bank_transactions (account_id, type, amount, description)
                            VALUES (?, 'debit_penalty', ?, ?)
                        ]], {
                            debit.account_id,
                            penalty,
                            'Penalización por domiciliación impagada: ' .. debit.creditor_name
                        })
                    end
                end

                local dayOfWeek = 2
                local nextExec = CalculateNextExecution(debit.frequency, dayOfWeek, 12, 0)
                MySQL.query.await(
                    'UPDATE bank_direct_debits SET next_execution = ? WHERE id = ?',
                    { nextExec, debit.id }
                )

                failed = failed + 1
            end
        end

        if success > 0 or failed > 0 then
            print(string.format('^2[Bank System] Direct debits processed. Success: %d | Failed: %d^7', success, failed))
        end
    end, { debug = false })
end)

print('^2[Bank System] Direct Debits module loaded^7')
