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
            local remaining = maxAttempts - failedAttempts
            return { success = false, error = 'PIN incorrecto. Te quedan ' .. remaining .. ' intentos' }
        end
    end
end)

RegisterNetEvent('muhaddil_bank:createCard', function(accountId, pin)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    accountId = tonumber(accountId)
    if not accountId then
        return Notify(src, 'error', 'Cuenta inválida')
    end

    if not pin or type(pin) ~= 'string' or #pin ~= 4 or not tonumber(pin) then
        return Notify(src, 'error', 'El PIN debe tener exactamente 4 dígitos')
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', 'Solo el dueño de la cuenta puede crear tarjetas')
    end

    local existingCard = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE account_id = ? AND owner = ?',
        { accountId, identifier })
    if existingCard > 0 then
        return Notify(src, 'error', 'Ya tienes una tarjeta para esta cuenta')
    end

    local price = Config.Cards.DebitCardPrice or 500
    if not RemovePlayerMoney(src, price) then
        return Notify(src, 'error', 'Necesitas $' .. price .. ' para crear la tarjeta')
    end

    local cardNumber = GenerateCardNumber()

    MySQL.insert.await([[
        INSERT INTO bank_cards (card_number, account_id, owner, pin, is_blocked, failed_attempts)
        VALUES (?, ?, ?, ?, 0, 0)
    ]], { cardNumber, accountId, identifier, pin })

    Notify(src, 'success', 'Tarjeta creada exitosamente')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:toggleCardBlock', function(cardId, block)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', 'Tarjeta inválida') end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', 'No tienes permisos sobre esta tarjeta')
    end

    local blockValue = block and 1 or 0
    MySQL.query.await('UPDATE bank_cards SET is_blocked = ?, failed_attempts = 0 WHERE id = ?', { blockValue, cardId })

    if block then
        Notify(src, 'warning', 'Tarjeta bloqueada')
    else
        Notify(src, 'success', 'Tarjeta desbloqueada')
    end
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:changeCardPin', function(cardId, currentPin, newPin)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', 'Tarjeta inválida') end

    if not newPin or type(newPin) ~= 'string' or #newPin ~= 4 or not tonumber(newPin) then
        return Notify(src, 'error', 'El nuevo PIN debe tener exactamente 4 dígitos')
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then
        return Notify(src, 'error', 'Tarjeta no encontrada')
    end

    if card.owner ~= identifier then
        return Notify(src, 'error', 'No tienes permisos sobre esta tarjeta')
    end

    if card.pin ~= currentPin then
        return Notify(src, 'error', 'PIN actual incorrecto')
    end

    MySQL.query.await('UPDATE bank_cards SET pin = ? WHERE id = ?', { newPin, cardId })
    Notify(src, 'success', 'PIN cambiado exitosamente')
end)

RegisterNetEvent('muhaddil_bank:deleteCard', function(cardId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    cardId = tonumber(cardId)
    if not cardId then return Notify(src, 'error', 'Tarjeta inválida') end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return Notify(src, 'error', 'No tienes permisos sobre esta tarjeta')
    end

    MySQL.query.await('DELETE FROM bank_cards WHERE id = ?', { cardId })
    Notify(src, 'success', 'Tarjeta eliminada')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

lib.callback.register('muhaddil_bank:verifyCardForATM', function(source, cardNumber, pin)
    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE card_number = ?', { cardNumber })
    if not card then
        return { success = false, error = 'Tarjeta no válida' }
    end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then
        return { success = false, error = 'Tarjeta bloqueada' }
    end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { card.id })
        return { success = true, accountId = card.account_id, cardId = card.id }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, card.id })
            return { success = false, error = 'Tarjeta bloqueada por seguridad' }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, card.id })
            local remaining = maxAttempts - failedAttempts
            return { success = false, error = 'PIN incorrecto. Te quedan ' .. remaining .. ' intentos' }
        end
    end
end)

RegisterNetEvent('muhaddil_bank:attemptCardTheft', function(targetServerId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local targetIdentifier = GetPlayerIdentifier(targetServerId)
    if not targetIdentifier then
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, 'Jugador no encontrado')
        return
    end

    local stealChance = Config.Cards.StealChance or 75
    if math.random(100) > stealChance then
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, 'Fallaste al intentar robar')
        Notify(targetServerId, 'warning', 'Alguien intentó robarte la tarjeta')
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
        TriggerClientEvent('muhaddil_bank:cardTheftResult', src, false, 'La víctima no tiene tarjeta')
        return
    end

    Notify(targetServerId, 'error', '¡Te han robado la tarjeta bancaria!')

    TriggerClientEvent('muhaddil_bank:cardTheftResult', src, true, {
        card_number = card.card_number,
        account_id = card.account_id,
        balance = card.balance
    })
end)

lib.callback.register('muhaddil_bank:getAccountDataById', function(source, accountId)
    local account = MySQL.single.await('SELECT id, account_name, balance FROM bank_accounts WHERE id = ?', { accountId })
    if not account then return nil end

    local cash = GetPlayerMoney(source)
    return {
        accounts = { account },
        cash = cash
    }
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
    if not identifier then return false, 'Identificador inválido' end

    accountId = tonumber(accountId)
    if not accountId then return false, 'Cuenta inválida' end

    if not pin or type(pin) ~= 'string' or #pin ~= 4 or not tonumber(pin) then
        return false, 'El PIN debe tener exactamente 4 dígitos'
    end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return false, 'Solo el dueño de la cuenta puede crear tarjetas'
    end

    local existingCard = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE account_id = ? AND owner = ?',
        { accountId, identifier })
    if existingCard > 0 then
        return false, 'Ya tienes una tarjeta para esta cuenta'
    end

    local price = Config.Cards.DebitCardPrice or 500
    if not RemovePlayerMoney(source, price) then
        return false, 'Necesitas $' .. price .. ' para crear la tarjeta'
    end

    local cardNumber = GenerateCardNumber()

    MySQL.insert.await([[
        INSERT INTO bank_cards (card_number, account_id, owner, pin, is_blocked, failed_attempts)
        VALUES (?, ?, ?, ?, 0, 0)
    ]], { cardNumber, accountId, identifier, pin })

    return true
end)

exports('ToggleCardBlock', function(source, cardId, block)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    cardId = tonumber(cardId)
    if not cardId then return false, 'Tarjeta inválida' end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then
        return false, 'No tienes permisos sobre esta tarjeta'
    end

    local blockValue = block and 1 or 0
    MySQL.query.await('UPDATE bank_cards SET is_blocked = ?, failed_attempts = 0 WHERE id = ?', { blockValue, cardId })

    return true
end)

exports('ChangeCardPin', function(source, cardId, currentPin, newPin)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    cardId = tonumber(cardId)
    if not cardId then return false, 'Tarjeta inválida' end

    if not newPin or type(newPin) ~= 'string' or #newPin ~= 4 or not tonumber(newPin) then
        return false, 'El nuevo PIN debe tener exactamente 4 dígitos'
    end

    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE id = ?', { cardId })
    if not card then return false, 'Tarjeta no encontrada' end
    if card.owner ~= identifier then return false, 'No tienes permisos sobre esta tarjeta' end
    if card.pin ~= currentPin then return false, 'PIN actual incorrecto' end

    MySQL.query.await('UPDATE bank_cards SET pin = ? WHERE id = ?', { newPin, cardId })
    return true
end)

exports('DeleteCard', function(source, cardId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false, 'Identificador inválido' end

    cardId = tonumber(cardId)
    if not cardId then return false, 'Tarjeta inválida' end

    local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
    if cardOwner ~= identifier then return false, 'No tienes permisos sobre esta tarjeta' end

    MySQL.query.await('DELETE FROM bank_cards WHERE id = ?', { cardId })
    return true
end)

exports('VerifyCardForATM', function(cardNumber, pin)
    local card = MySQL.single.await('SELECT * FROM bank_cards WHERE card_number = ?', { cardNumber })
    if not card then return { success = false, error = 'Tarjeta no válida' } end

    local isBlocked = tonumber(card.is_blocked) or 0
    local failedAttempts = tonumber(card.failed_attempts) or 0
    local maxAttempts = Config.Cards.MaxFailedPINAttempts or 3

    if isBlocked == 1 then return { success = false, error = 'Tarjeta bloqueada' } end

    if card.pin == pin then
        MySQL.query.await('UPDATE bank_cards SET failed_attempts = 0 WHERE id = ?', { card.id })
        return { success = true, accountId = card.account_id, cardId = card.id }
    else
        failedAttempts = failedAttempts + 1
        if failedAttempts >= maxAttempts then
            MySQL.query.await('UPDATE bank_cards SET is_blocked = 1, failed_attempts = ? WHERE id = ?',
                { failedAttempts, card.id })
            return { success = false, error = 'Tarjeta bloqueada por seguridad' }
        else
            MySQL.query.await('UPDATE bank_cards SET failed_attempts = ? WHERE id = ?', { failedAttempts, card.id })
            return {
                success = false,
                error = 'PIN incorrecto. Te quedan ' ..
                    (maxAttempts - failedAttempts) .. ' intentos'
            }
        end
    end
end)

exports('GetAccountDataById', function(source, accountId)
    local account = MySQL.single.await('SELECT id, account_name, balance FROM bank_accounts WHERE id = ?', { accountId })
    if not account then return nil end

    local cash = GetPlayerMoney(source)
    return { accounts = { account }, cash = cash }
end)
