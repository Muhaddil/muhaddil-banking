lib.callback.register('muhaddil_bank:getBankDetails', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local bank = MySQL.single.await([[
        SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?
    ]], { bankId, identifier })

    if not bank then
        return {
            hasOwner = false,
            stats = { total_transactions = 0, total_volume = 0 }
        }
    end

    local stats = MySQL.single.await([[
        SELECT
            COUNT(*) as total_transactions,
            COALESCE(SUM(ABS(amount)), 0) as total_volume
        FROM bank_transactions
        WHERE bank_location = ? AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
    ]], { bankId })

    bank.stats = stats
    return bank
end)

-- RegisterNetEvent('muhaddil_bank:sellBank', function(bankId)
--     local src = source
--     local identifier = GetPlayerIdentifier(src)

--     if not identifier then return end

--     if not Config.BankOwnership.Enabled then
--         return Notify(src, 'error', 'La gestión de bancos está deshabilitada')
--     end

--     local bank = MySQL.single.await(
--         'SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
--         { bankId, identifier }
--     )

--     if not bank then
--         Notify(src, 'error', 'No eres el dueño de este banco')
--         return
--     end

--     local refundAmount = math.floor(
--         Config.BankOwnership.PurchasePrice * Config.BankOwnership.SellPercentage
--     )

--     local pendingEarnings = tonumber(bank.pending_earnings) or 0
--     local totalRefund = refundAmount + pendingEarnings

--     MySQL.query.await(
--         'DELETE FROM bank_ownership WHERE bank_id = ? AND owner = ?',
--         { bankId, identifier }
--     )

--     AddPlayerMoney(src, totalRefund)

--     Notify(
--         src,
--         'success',
--         string.format('Has vendido %s por $%s', bank.bank_name, totalRefund)
--     )

--     TriggerClientEvent('muhaddil_bank:refreshData', src)

--     print(string.format(
--         "^3[Bank System] %s vendió %s por $%s^7",
--         GetPlayerName(src),
--         bank.bank_name,
--         totalRefund
--     ))
-- end)

RegisterNetEvent('muhaddil_bank:sellBank', function(bankId)
    local src = source
    local ok, result = exports['muhaddil-banking']:SellBank(src, bankId)

    if not ok then
        return Notify(src, 'error', result)
    end

    Notify(src, 'success',
        Locale('server.bank_sold', result.amount)
    )

    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)


RegisterNetEvent('muhaddil_bank:transferBank', function(bankId, targetPlayerId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', Locale('server.bank_ownership_disabled'))
    end

    targetPlayerId = tonumber(targetPlayerId)
    if not targetPlayerId then
        return Notify(src, 'error', Locale('server.player_not_found'))
    end

    local bank = MySQL.single.await('SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier })
    if not bank then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    local targetIdentifier = GetPlayerIdentifier(targetPlayerId)
    if not targetIdentifier then
        return Notify(src, 'error', Locale('server.target_player_not_found'))
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', Locale('server.cannot_transfer_to_yourself'))
    end

    local targetBankCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_ownership WHERE owner = ?',
        { targetIdentifier })
    if targetBankCount >= Config.BankOwnership.MaxBanksPerPlayer then
        return Notify(src, 'error', Locale('server.max_banks_reached', Config.BankOwnership.MaxBanksPerPlayer))
    end

    MySQL.query.await([[
        UPDATE bank_ownership
        SET owner = ?
        WHERE bank_id = ?
    ]], { targetIdentifier, bankId })

    Notify(src, 'success', Locale('server.bank_transferred', GetPlayerName(targetPlayerId)))
    Notify(targetPlayerId, 'success', Locale('server.bank_received', bank.bank_name))

    TriggerClientEvent('muhaddil_bank:refreshData', src)
    TriggerClientEvent('muhaddil_bank:refreshData', targetPlayerId)

    -- print(string.format("^3[Bank System] %s transfirió %s a %s^7", GetPlayerName(src), bank.bank_name,
    --     GetPlayerName(targetPlayerId)))
end)

RegisterNetEvent('muhaddil_bank:updateCommission', function(bankId, newRate)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', Locale('server.bank_ownership_disabled'))
    end

    newRate = tonumber(newRate)
    if not newRate then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    if newRate < Config.BankOwnership.MinCommissionRate or newRate > Config.BankOwnership.MaxCommissionRate then
        return Notify(src, 'error', Locale('server.invalid_commission'))
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankId })
    if not owner then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    MySQL.query.await('UPDATE bank_ownership SET commission_rate = ? WHERE bank_id = ?', { newRate, bankId })

    Notify(src, 'success', Locale('server.commission_updated', newRate * 100))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:withdrawEarnings', function(bankId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', Locale('server.bank_ownership_disabled'))
    end

    local bank = MySQL.single.await('SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier })
    if not bank then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    local earnings = tonumber(bank.pending_earnings) or 0
    if earnings <= 0 then
        return Notify(src, 'error', Locale('server.no_pending_earnings'))
    end

    AddPlayerMoney(src, earnings)
    MySQL.query.await('UPDATE bank_ownership SET pending_earnings = 0 WHERE bank_id = ?', { bankId })

    Notify(src, 'success', Locale('server.earnings_withdrawn', earnings))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    print(string.format("^2[Bank System] %s retiró $%s de ganancias de %s^7", GetPlayerName(src), earnings,
        bank.bank_name))
end)

RegisterNetEvent('muhaddil_bank:renameBank', function(bankId, newName)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', Locale('server.bank_ownership_disabled'))
    end

    if not newName or type(newName) ~= 'string' or #newName < 3 then
        return Notify(src, 'error', Locale('server.invalid_bank_name'))
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankId })
    if not owner then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.bank_not_owned'))
    end

    MySQL.query.await('UPDATE bank_ownership SET bank_name = ? WHERE bank_id = ?', { newName, bankId })

    Notify(src, 'success', Locale('server.bank_renamed', newName))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

lib.callback.register('muhaddil_bank:getBankReport', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankId })
    if not owner or owner ~= identifier then
        return {}
    end

    local report = MySQL.query.await([[
        SELECT
            type,
            COUNT(*) as count,
            SUM(ABS(amount)) as volume
        FROM bank_transactions
        WHERE bank_location = ? AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY type
    ]], { bankId })

    return report or {}
end)

print('^2[Bank System] Bank management loaded^7')

exports('GetBankDetails', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local bank = MySQL.single.await(
        'SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier }
    )

    if not bank then
        return {
            hasOwner = false,
            stats = { total_transactions = 0, total_volume = 0 }
        }
    end

    local stats = MySQL.single.await([[
        SELECT
            COUNT(*) AS total_transactions,
            COALESCE(SUM(ABS(amount)), 0) AS total_volume
        FROM bank_transactions
        WHERE bank_location = ?
          AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
    ]], { bankId })

    bank.stats = stats
    bank.hasOwner = true

    return bank
end)

exports('SellBank', function(source, bankId)
    if not Config.BankOwnership.Enabled then
        return false, 'La gestión de bancos está deshabilitada'
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    local bank = MySQL.single.await(
        'SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier }
    )

    if not bank then
        return false, 'No eres el dueño de este banco'
    end

    local refund = math.floor(
        Config.BankOwnership.PurchasePrice * Config.BankOwnership.SellPercentage
    )

    local earnings = tonumber(bank.pending_earnings) or 0
    local total = refund + earnings

    MySQL.query.await(
        'DELETE FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier }
    )

    AddPlayerMoney(source, total)

    return true, {
        bankName = bank.bank_name,
        amount = total
    }
end)

exports('TransferBank', function(source, bankId, targetPlayerId)
    if not Config.BankOwnership.Enabled then
        return false, 'La gestión de bancos está deshabilitada'
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    targetPlayerId = tonumber(targetPlayerId)
    if not targetPlayerId then return false, 'ID de jugador inválido' end

    local bank = MySQL.single.await(
        'SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier }
    )

    if not bank then
        return false, 'No eres el dueño de este banco'
    end

    local targetIdentifier = GetPlayerIdentifier(targetPlayerId)
    if not targetIdentifier then
        return false, 'Jugador no encontrado'
    end

    if targetIdentifier == identifier then
        return false, 'No puedes transferirte el banco a ti mismo'
    end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_ownership WHERE owner = ?',
        { targetIdentifier }
    )

    if count >= Config.BankOwnership.MaxBanksPerPlayer then
        return false, 'El jugador ha alcanzado su límite de bancos'
    end

    MySQL.query.await(
        'UPDATE bank_ownership SET owner = ? WHERE bank_id = ?',
        { targetIdentifier, bankId }
    )

    return true, bank.bank_name
end)

exports('UpdateBankCommission', function(source, bankId, newRate)
    if not Config.BankOwnership.Enabled then
        return false, 'La gestión de bancos está deshabilitada'
    end

    newRate = tonumber(newRate)
    if not newRate then return false, 'Tasa inválida' end

    if newRate < Config.BankOwnership.MinCommissionRate
        or newRate > Config.BankOwnership.MaxCommissionRate then
        return false, 'Comisión fuera de rango'
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    local owner = MySQL.scalar.await(
        'SELECT owner FROM bank_ownership WHERE bank_id = ?',
        { bankId }
    )

    if owner ~= identifier then
        return false, 'No eres el dueño de este banco'
    end

    MySQL.query.await(
        'UPDATE bank_ownership SET commission_rate = ? WHERE bank_id = ?',
        { newRate, bankId }
    )

    return true
end)

exports('WithdrawBankEarnings', function(source, bankId)
    if not Config.BankOwnership.Enabled then
        return false, 'La gestión de bancos está deshabilitada'
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    local bank = MySQL.single.await(
        'SELECT * FROM bank_ownership WHERE bank_id = ? AND owner = ?',
        { bankId, identifier }
    )

    if not bank then
        return false, 'No eres el dueño de este banco'
    end

    local earnings = tonumber(bank.pending_earnings) or 0
    if earnings <= 0 then
        return false, 'No tienes ganancias pendientes'
    end

    AddPlayerMoney(source, earnings)

    MySQL.query.await(
        'UPDATE bank_ownership SET pending_earnings = 0 WHERE bank_id = ?',
        { bankId }
    )

    return true, earnings, bank.bank_name
end)

exports('RenameBank', function(source, bankId, newName)
    if not Config.BankOwnership.Enabled then
        return false, Locale('server.bank_ownership_disabled')
    end

    if not newName or type(newName) ~= 'string' or #newName < 3 then
        return false, Locale('server.invalid_name')
    end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, Locale('server.invalid_identifier') end

    local owner = MySQL.scalar.await(
        'SELECT owner FROM bank_ownership WHERE bank_id = ?',
        { bankId }
    )

    if owner ~= identifier then
        return false, Locale('server.not_owner')
    end

    MySQL.query.await(
        'UPDATE bank_ownership SET bank_name = ? WHERE bank_id = ?',
        { newName, bankId }
    )

    return true
end)

exports('GetBankReport', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local owner = MySQL.scalar.await(
        'SELECT owner FROM bank_ownership WHERE bank_id = ?',
        { bankId }
    )

    if owner ~= identifier then
        return {}
    end

    return MySQL.query.await([[
        SELECT
            type,
            COUNT(*) AS count,
            SUM(ABS(amount)) AS volume
        FROM bank_transactions
        WHERE bank_location = ?
          AND created_at > DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY type
    ]], { bankId }) or {}
end)
