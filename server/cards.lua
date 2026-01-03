lib.callback.register('muhaddil_bank:hasCard', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE owner = ? AND is_blocked = 0', { identifier })
    return count > 0
end)

lib.callback.register('muhaddil_bank:getPlayerCard', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local card = MySQL.single.await([[
        SELECT bc.*, ba.account_name
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ? AND bc.is_blocked = 0
        ORDER BY bc.created_at DESC LIMIT 1
    ]], { identifier })

    return card
end)

lib.callback.register('muhaddil_bank:getPlayerCards', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local cards = MySQL.query.await([[
        SELECT bc.*, ba.account_name, ba.balance
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.created_at DESC
    ]], { identifier })

    return cards or {}
end)

lib.callback.register('muhaddil_bank:verifyCardPin', function(source, cardId, pin)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return { success = false, error = 'Error de identificación' }
    end

    cardId = tonumber(cardId)
    if not cardId then
        return { success = false, error = 'Tarjeta inválida' }
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then
        return { success = false, error = 'Tarjeta no encontrada' }
    end

    if card.owner ~= identifier then
        return { success = false, error = 'Esta tarjeta no te pertenece' }
    end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then
        return { success = false, error = Locale('server.card_blocked_status') }
    end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { cardId })
        return { success = true, accountId = card.account_id }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, cardId })
            return { success = false, error = Locale('server.card_blocked') }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, cardId })
            local remaining = maxAttempts - failedAttempts
            return { success = false, error = Locale('server.card_failed_attempts', remaining) }
        end
    end
end)

RegisterNetEvent('muhaddil_bank:createCard', function(accountId, pin)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    accountId = tonumber(accountId)
    if not accountId then
        return Notify(src, 'error', Locale('server.invalid_account'))
    end

    if not pin or type(pin) ~= 'string' or #pin ~= 4 or not tonumber(pin) then
        return Notify(src, 'error', Locale('server.invalid_pin'))
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card'))
    end

    local existingCard = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE account_id = ? AND owner = ?',
        { accountId, identifier })
    if existingCard > 0 then
        return Notify(src, 'error', Locale('server.card_exists'))
    end

    local price = Config.Cards.DebitCardPrice or 500
    if not RemovePlayerMoney(src, price) then
        return Notify(src, 'error', Locale('server.not_enough_money', price))
    end

    local cardNumber = GenerateCardNumber()

    MySQL.insert.await([[
        INSERT INTO bank_cards (card_number, account_id, owner, pin, is_blocked, failed_attempts)
        VALUES (?, ?, ?, ?, 0, 0)
    ]], { cardNumber, accountId, identifier, pin })

    Notify(src, 'success', Locale('server.card_created'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:toggleCardBlock', function(cardId, block)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    local blockValue = block and 1 or 0
    MySQL.query.await('UPDATE bank_cards SET is_blocked = ?, failed_attempts = 0 WHERE id = ?', { blockValue, cardId })

    if block then
        Notify(src, 'warning', Locale('server.card_blocked_status'))
    else
        Notify(src, 'success', Locale('server.card_unblocked'))
    end
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:changeCardPin', function(cardId, currentPin, newPin)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    if not newPin or type(newPin) ~= 'string' or #newPin ~= 4 or not tonumber(newPin) then
        return Notify(src, 'error', Locale('server.invalid_pin'))
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then
        return Notify(src, 'error', Locale('server.card_not_found'))
    end

    if card.owner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    if card.pin ~= currentPin then
        return Notify(src, 'error', Locale('server.invalid_pin'))
    end

    MySQL.query.await('UPDATE bank_cards SET pin = ? WHERE id = ?', { newPin, cardId })
    Notify(src, 'success', Locale('server.pin_changed'))
end)

RegisterNetEvent('muhaddil_bank:deleteCard', function(cardId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    MySQL.query.await('DELETE FROM bank_cards WHERE id = ?', { cardId })
    Notify(src, 'success', Locale('server.card_deleted'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

lib.callback.register('muhaddil_bank:verifyCardForATM', function(source, cardNumber, pin)
    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE card_number = ?', { cardNumber })
    if not card then
        return { success = false, error = Locale('server.card_not_found') }
    end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then
        return { success = false, error = Locale('server.card_blocked_status') }
    end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { card.id })
        return { success = true, accountId = card.account_id, cardId = card.id }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, card.id })
            return { success = false, error = Locale('server.card_blocked') }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, card.id })
            local remaining = maxAttempts - failedAttempts
            return { success = false, error = Locale('server.card_failed_attempts', remaining) }
        end
    end
end)

RegisterNetEvent('muhaddil_bank:attemptCardTheft', function(targetServerId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local targetIdentifier = GetPlayerIdentifier(targetServerId)
    if not targetIdentifier then
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, Locale('server.player_not_found'))
        return
    end

    local stealChance = Config.Cards.StealChance or 75
    if math.random(100) > stealChance then
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, Locale('server.card_theft_failed'))
        Notify(targetServerId, 'warning', Locale('server.card_theft_failed_victim'))
        return
    end

    local card = MySQL.single.await([[
        SELECT bc.id, bc.card_number, bc.account_id, ba.balance
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ? AND bc.is_blocked = 0
        ORDER BY bc.created_at DESC LIMIT 1
    ]], { targetIdentifier })

    if not card then
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, Locale('server.victim_no_card'))
        return
    end

    Notify(targetServerId, 'error', Locale('server.card_theft_success_victim'))

    TriggerClientEvent('muhaddil_bank:cardTheftResult', src, true, {
        card_number = card.card_number,
        account_id = card.account_id,
        balance = card.balance
    })
end)

print('^2[Bank System] Cards server loaded^7')

exports('HasCard', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE owner = ? AND is_blocked = 0', { identifier })
    return count > 0
end)

exports('GetPlayerCard', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    return MySQL.single.await([[
        SELECT bc.*, ba.account_name
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ? AND bc.is_blocked = 0
        ORDER BY bc.created_at DESC LIMIT 1
    ]], { identifier })
end)

exports('GetPlayerCards', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    return MySQL.query.await([[
        SELECT bc.*, ba.account_name, ba.balance
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.created_at DESC
    ]], { identifier }) or {}
end)

exports('VerifyCardPin', function(source, cardId, pin)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return { success = false, error = 'Error de identificación' }
    end

    cardId = tonumber(cardId)
    if not cardId then
        return { success = false, error = 'Tarjeta inválida' }
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then
        return { success = false, error = 'Tarjeta no encontrada' }
    end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then
        return { success = false, error = 'Tarjeta bloqueada' }
    end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { cardId })
        return { success = true }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, cardId })
            return { success = false, error = 'Tarjeta bloqueada por demasiados intentos fallidos' }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, cardId })
            return {
                success = false,
                error = 'PIN incorrecto. Te quedan ' ..
                    (maxAttempts - failedAttempts) .. ' intentos'
            }
        end
    end
end)

exports('CreateCard', function(source, accountId, pin)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, Locale('server.invalid_identifier') end

    accountId = tonumber(accountId)
    if not accountId then return false, Locale('server.invalid_account') end

    if not pin or type(pin) ~= 'string' or #pin ~= 4 or not tonumber(pin) then
        return false, Locale('server.invalid_pin')
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return false, Locale('server.invalid_owner_card_perms')
    end

    local existingCard = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE account_id = ? AND owner = ?',
        { accountId, identifier })
    if existingCard > 0 then
        return false, Locale('server.card_exists')
    end

    local price = Config.Cards.DebitCardPrice or 500
    if not RemovePlayerMoney(source, price) then
        return false, Locale('server.not_enough_money')
    end

    local cardNumber = GenerateCardNumber()

    MySQL.insert.await([[
        INSERT INTO bank_cards (card_number, account_id, owner, pin, is_blocked, failed_attempts)
        VALUES (?, ?, ?, ?, 0, 0)
    ]], { cardNumber, accountId, identifier, pin })

    return true
end)

exports('ToggleCardBlock', function(source, cardId, block)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    local blockValue = block and 1 or 0
    MySQL.query.await('UPDATE bank_cards SET is_blocked = ?, failed_attempts = 0 WHERE id = ?', { blockValue, cardId })

    if block then
        Notify(src, 'warning', Locale('server.card_blocked_status'))
    else
        Notify(src, 'success', Locale('server.card_unblocked'))
    end
    return true
end)

exports('ChangeCardPin', function(source, cardId, currentPin, newPin)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    if not newPin or type(newPin) ~= 'string' or #newPin ~= 4 or not tonumber(newPin) then
        return Notify(src, 'error', Locale('server.invalid_pin'))
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then
        return Notify(src, 'error', Locale('server.card_not_found'))
    end

    if card.owner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    if card.pin ~= currentPin then
        return Notify(src, 'error', Locale('server.invalid_pin'))
    end

    MySQL.query.await('UPDATE bank_cards SET pin = ? WHERE id = ?', { newPin, cardId })
    Notify(src, 'success', Locale('server.pin_changed'))
    return true
end)

exports('DeleteCard', function(source, cardId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', Locale('server.invalid_card')) end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', Locale('server.invalid_owner_card_perms'))
    end

    MySQL.query.await('DELETE FROM bank_cards WHERE id = ?', { cardId })
    Notify(src, 'success', Locale('server.card_deleted'))
    return true
end)

exports('VerifyCardForATM', function(cardNumber, pin)
    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE card_number = ?', { cardNumber })
    if not card then
        return { success = false, error = Locale('server.card_not_found') }
    end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then
        return { success = false, error = Locale('server.card_blocked_status') }
    end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { card.id })
        return { success = true, accountId = card.account_id, cardId = card.id }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, card.id })
            return { success = false, error = Locale('server.card_blocked') }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, card.id })
            local remaining = maxAttempts - failedAttempts
            return { success = false, error = Locale('server.card_failed_attempts', remaining) }
        end
    end
end)

exports('GetAccountDataById', function(source, accountId)
    local account = MySQL.single.await('SELECT id, account_name, balance FROM bank_accounts WHERE id = ?', { accountId })
    if not account then return nil end

    local cash = GetPlayerMoney(source)
    return {
        account = account,
        cash = cash
    }
end)
