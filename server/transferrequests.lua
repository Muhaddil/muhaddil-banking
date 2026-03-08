lib.callback.register('muhaddil_bank:getTransferRequests', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return { incoming = {}, outgoing = {} } end

    local incoming = MySQL.query.await([[
        SELECT btr.*, ba.account_name as requester_account_name
        FROM bank_transfer_requests btr
        LEFT JOIN bank_accounts ba ON btr.requester_account_id = ba.id
        WHERE btr.target_identifier = ? AND btr.status = 'pending'
        ORDER BY btr.created_at DESC
    ]], { identifier })

    local outgoing = MySQL.query.await([[
        SELECT btr.*, ba.account_name as requester_account_name
        FROM bank_transfer_requests btr
        LEFT JOIN bank_accounts ba ON btr.requester_account_id = ba.id
        WHERE btr.requester_identifier = ?
        ORDER BY btr.created_at DESC
        LIMIT 50
    ]], { identifier })

    return {
        incoming = incoming or {},
        outgoing = outgoing or {}
    }
end)

RegisterNetEvent('muhaddil_bank:createTransferRequest', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.TransferRequests.Enabled then
        return Notify(src, 'error', Locale('server.transfer_requests_disabled'))
    end

    local targetPlayerId = tonumber(data.targetPlayerId)
    local amount = tonumber(data.amount)
    local fromAccountId = tonumber(data.fromAccountId)
    local message = data.message or ''

    if not targetPlayerId or not amount or amount <= 0 or not fromAccountId then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    local account = MySQL.single.await(
        'SELECT * FROM bank_accounts WHERE id = ? AND owner = ?',
        { fromAccountId, identifier }
    )
    if not account then
        return Notify(src, 'error', Locale('server.no_permission_origin'))
    end

    local targetIdentifier = GetPlayerIdentifier(targetPlayerId)
    if not targetIdentifier then
        return Notify(src, 'error', Locale('server.player_not_found'))
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', Locale('server.cannot_request_yourself'))
    end

    local pendingCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM bank_transfer_requests
        WHERE requester_identifier = ? AND status = 'pending'
    ]], { identifier })

    if pendingCount >= Config.TransferRequests.MaxPendingRequests then
        return Notify(src, 'error', Locale('server.max_requests_reached'))
    end

    MySQL.insert.await([[
        INSERT INTO bank_transfer_requests (requester_identifier, target_identifier, amount, requester_account_id, message)
        VALUES (?, ?, ?, ?, ?)
    ]], { identifier, targetIdentifier, amount, fromAccountId, message })

    Notify(src, 'success', Locale('server.request_sent'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    if GetPlayerName(targetPlayerId) then
        Notify(targetPlayerId, 'info', Locale('server.new_transfer_request', amount))
        TriggerClientEvent('muhaddil_bank:refreshData', targetPlayerId)
    end
end)

RegisterNetEvent('muhaddil_bank:acceptTransferRequest', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local requestId = tonumber(data.requestId)
    local fromAccountId = tonumber(data.fromAccountId)

    if not requestId or not fromAccountId then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    local request = MySQL.single.await([[
        SELECT * FROM bank_transfer_requests
        WHERE id = ? AND target_identifier = ? AND status = 'pending'
    ]], { requestId, identifier })

    if not request then
        return Notify(src, 'error', Locale('server.request_not_found'))
    end

    local balance = tonumber(MySQL.scalar.await(
        'SELECT balance FROM bank_accounts WHERE id = ? AND owner = ?',
        { fromAccountId, identifier }
    ))

    if not balance or balance < tonumber(request.amount) then
        return Notify(src, 'error', Locale('server.insufficient_balance'))
    end

    local amount = tonumber(request.amount)

    local success = MySQL.transaction.await({
        {
            query = 'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
            values = { amount, fromAccountId }
        },
        {
            query = 'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            values = { amount, request.requester_account_id }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { fromAccountId, 'request_payment', -amount, 'Pago de solicitud #' .. requestId }
        },
        {
            query = 'INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)',
            values = { request.requester_account_id, 'request_received', amount, 'Solicitud recibida #' .. requestId }
        },
        {
            query =
            'UPDATE bank_transfer_requests SET status = ?, target_account_id = ?, resolved_at = NOW() WHERE id = ?',
            values = { 'accepted', fromAccountId, requestId }
        }
    })

    if not success then
        return Notify(src, 'error', Locale('server.transfer_error'))
    end

    Notify(src, 'success', Locale('server.request_accepted'))
    TriggerEvent('muhaddil_bank:afterTransfer', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    local requesterData = GetPlayerFromIdentifier(request.requester_identifier)
    if requesterData then
        local requesterId = requesterData.source
        if requesterId then
            Notify(requesterId, 'success', Locale('server.request_was_accepted', amount))
            TriggerEvent('muhaddil_bank:afterTransfer', requesterId)
            TriggerClientEvent('muhaddil_bank:refreshData', requesterId)
            TriggerClientEvent('muhaddil_bank:phone:notify', requesterId,
                Locale('server.solicitation_paid_phone', amount), 'success')
        end
    end
end)

RegisterNetEvent('muhaddil_bank:rejectTransferRequest', function(requestId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    requestId = tonumber(requestId)
    if not requestId then return end

    local request = MySQL.single.await([[
        SELECT * FROM bank_transfer_requests
        WHERE id = ? AND target_identifier = ? AND status = 'pending'
    ]], { requestId, identifier })

    if not request then
        return Notify(src, 'error', Locale('server.request_not_found'))
    end

    MySQL.query.await(
        "UPDATE bank_transfer_requests SET status = 'rejected', resolved_at = NOW() WHERE id = ?",
        { requestId }
    )

    Notify(src, 'success', Locale('server.request_rejected'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    local requesterData = GetPlayerFromIdentifier(request.requester_identifier)
    if requesterData then
        local requesterId = requesterData.source
        if requesterId then
            Notify(requesterId, 'warning', Locale('server.request_was_rejected'))
            TriggerClientEvent('muhaddil_bank:refreshData', requesterId)
        end
    end
end)

RegisterNetEvent('muhaddil_bank:cancelTransferRequest', function(requestId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    requestId = tonumber(requestId)
    if not requestId then return end

    local request = MySQL.single.await([[
        SELECT * FROM bank_transfer_requests
        WHERE id = ? AND requester_identifier = ? AND status = 'pending'
    ]], { requestId, identifier })

    if not request then
        return Notify(src, 'error', Locale('server.request_not_found'))
    end

    MySQL.query.await(
        "UPDATE bank_transfer_requests SET status = 'cancelled', resolved_at = NOW() WHERE id = ?",
        { requestId }
    )

    Notify(src, 'success', Locale('server.request_cancelled'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

if Config.TransferRequests.Enabled then
    Wait(15000)
    lib.cron.new('0 * * * *', function()
        local expired = MySQL.update.await([[
            UPDATE bank_transfer_requests
            SET status = 'expired', resolved_at = NOW()
            WHERE status = 'pending' AND created_at < DATE_SUB(NOW(), INTERVAL ? HOUR)
        ]], { Config.TransferRequests.ExpirationHours })

        if expired and expired > 0 then
            print(string.format('^3[Bank System] Expired %d transfer requests^7', expired))
        end
    end, { debug = false })
end

print('^2[Bank System] Transfer requests system loaded^7')
