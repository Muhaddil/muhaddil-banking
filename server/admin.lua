RegisterCommand('bankadmin', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts ORDER BY balance DESC LIMIT 50', {})

    print("^2========== TOP 50 CUENTAS ==========^7")
    for i, acc in ipairs(accounts) do
        print(string.format("^3#%d^7 | Owner: ^2%s^7 | Nombre: ^5%s^7 | Balance: ^1$%.2f^7",
            i, acc.owner, acc.account_name, acc.balance))
    end
    print("^2=====================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', 'Revisa la consola del servidor')
end, false)

RegisterCommand('bankaddmoney', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local accountId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not accountId or not amount then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankaddmoney [ID de cuenta] [cantidad]')
        return
    end

    local affectedRows = MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', {
        amount, accountId
    })

    if affectedRows > 0 then
        MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
            accountId, 'admin_deposit', amount, 'Depósito administrativo'
        })

        TriggerClientEvent('muhaddil_bank:notify', source, 'success',
            string.format('Se añadieron $%.2f a la cuenta #%d', amount, accountId))
        print(string.format("^2[ADMIN] %s añadió $%.2f a la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
    end
end, false)

RegisterCommand('bankremovemoney', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local accountId = tonumber(args[1])
    local amount = tonumber(args[2])

    if not accountId or not amount then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankremovemoney [ID de cuenta] [cantidad]')
        return
    end

    local affectedRows = MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', {
        amount, accountId
    })

    if affectedRows > 0 then
        MySQL.insert.await('INSERT INTO bank_transactions (account_id, type, amount, description) VALUES (?, ?, ?, ?)', {
            accountId, 'admin_withdrawal', -amount, 'Retiro administrativo'
        })

        TriggerClientEvent('muhaddil_bank:notify', source, 'success',
            string.format('Se removieron $%.2f de la cuenta #%d', amount, accountId))
        print(string.format("^2[ADMIN] %s removió $%.2f de la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
    end
end, false)

RegisterCommand('bankloans', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local loans = MySQL.query.await('SELECT * FROM bank_loans WHERE status = "active" ORDER BY remaining DESC', {})

    print("^2========== PRÉSTAMOS ACTIVOS ==========^7")
    for i, loan in ipairs(loans) do
        print(string.format("^3#%d^7 | Usuario: ^2%s^7 | Monto: ^1$%.2f^7 | Restante: ^1$%.2f^7",
            loan.id, loan.user_identifier, loan.amount, loan.remaining))
    end
    print("^2========================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', 'Revisa la consola del servidor')
end, false)

RegisterCommand('bankcancelloan', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local loanId = tonumber(args[1])

    if not loanId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankcancelloan [ID del préstamo]')
        return
    end

    local affectedRows = MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE id = ?', {
        loanId
    })

    if affectedRows > 0 then
        TriggerClientEvent('muhaddil_bank:notify', source, 'success', string.format('Préstamo #%d cancelado', loanId))
        print(string.format("^2[ADMIN] %s canceló el préstamo #%d^7", GetPlayerName(source), loanId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Préstamo no encontrado')
    end
end, false)

RegisterCommand('bankinfo', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local accountId = tonumber(args[1])

    if not accountId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankinfo [ID de cuenta]')
        return
    end

    local accounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE id = ?', { accountId })

    if #accounts == 0 then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
        return
    end

    local account = accounts[1]

    local shared = MySQL.query.await('SELECT user_identifier FROM bank_shared_access WHERE account_id = ?', { accountId })

    print("^2========== INFO DE CUENTA #" .. accountId .. " ==========^7")
    print("^3Nombre:^7 " .. account.account_name)
    print("^3Owner:^7 " .. account.owner)
    print("^3Balance:^7 $" .. string.format("%.2f", account.balance))
    print("^3Creada:^7 " .. account.created_at)

    if #shared > 0 then
        print("^3Usuarios compartidos:^7")
        for _, user in ipairs(shared) do
            print("  - " .. user.user_identifier)
        end
    else
        print("^3Usuarios compartidos:^7 Ninguno")
    end

    print("^2=============================================^7")

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', 'Revisa la consola del servidor')
end, false)

RegisterCommand('bankreset', function(source, args, rawCommand)
    if not hasPermission(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end

    local targetId = tonumber(args[1])

    if not targetId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankreset [ID del jugador]')
        return
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Jugador no encontrado')
        return
    end

    MySQL.query.await('DELETE FROM bank_accounts WHERE owner = ?', { targetIdentifier })

    MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE user_identifier = ?',
        { targetIdentifier })

    TriggerClientEvent('muhaddil_bank:notify', source, 'success', 'Banco del jugador reseteado')
    TriggerClientEvent('muhaddil_bank:notify', targetId, 'error', 'Tu banco ha sido reseteado por un administrador')
    print(string.format("^2[ADMIN] %s reseteó el banco de %s^7", GetPlayerName(source), GetPlayerName(targetId)))
end, false)

-- print("^2[Bank System] Comandos de administrador cargados^7")
-- print("^3Comandos disponibles:^7")
-- print("  ^5/bankadmin^7 - Ver top 50 cuentas")
-- print("  ^5/bankaddmoney [ID] [cantidad]^7 - Añadir dinero")
-- print("  ^5/bankremovemoney [ID] [cantidad]^7 - Remover dinero")
-- print("  ^5/bankloans^7 - Ver préstamos activos")
-- print("  ^5/bankcancelloan [ID]^7 - Cancelar préstamo")
-- print("  ^5/bankinfo [ID]^7 - Ver info de cuenta")
-- print("  ^5/bankreset [ID jugador]^7 - Resetear banco de jugador")

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
            { accountId, 'admin_deposit', amount, reason or 'Depósito administrativo' }
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
            { accountId, 'admin_withdrawal', -amount, reason or 'Retiro administrativo' }
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
