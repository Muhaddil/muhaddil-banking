-- Comandos de Administrador
-- Estos comandos están disponibles para administradores del servidor

-- Helper: Verificar si el jugador es admin
function IsPlayerAdmin(source)
    -- ESX
    if FrameWork == "esx" then
        local xPlayer = ESX.GetPlayerFromId(source)
        return xPlayer and (xPlayer.getGroup() == "admin" or xPlayer.getGroup() == "superadmin")
    end
    
    -- QBCore
    if FrameWork == "qb" then
        return QBCore.Functions.HasPermission(source, "admin")
    end
    
    return false
end

-- Comando: Ver todas las cuentas del servidor
RegisterCommand('bankadmin', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
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

-- Comando: Añadir dinero a una cuenta
RegisterCommand('bankaddmoney', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
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
        
        TriggerClientEvent('muhaddil_bank:notify', source, 'success', string.format('Se añadieron $%.2f a la cuenta #%d', amount, accountId))
        print(string.format("^2[ADMIN] %s añadió $%.2f a la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
    end
end, false)

-- Comando: Remover dinero de una cuenta
RegisterCommand('bankremovemoney', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
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
        
        TriggerClientEvent('muhaddil_bank:notify', source, 'success', string.format('Se removieron $%.2f de la cuenta #%d', amount, accountId))
        print(string.format("^2[ADMIN] %s removió $%.2f de la cuenta #%d^7", GetPlayerName(source), amount, accountId))
    else
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
    end
end, false)

-- Comando: Ver préstamos activos
RegisterCommand('bankloans', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
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

-- Comando: Cancelar préstamo
RegisterCommand('bankcancelloan', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
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

-- Comando: Ver info de una cuenta específica
RegisterCommand('bankinfo', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end
    
    local accountId = tonumber(args[1])
    
    if not accountId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankinfo [ID de cuenta]')
        return
    end
    
    local accounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE id = ?', {accountId})
    
    if #accounts == 0 then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Cuenta no encontrada')
        return
    end
    
    local account = accounts[1]
    
    -- Obtener usuarios compartidos
    local shared = MySQL.query.await('SELECT user_identifier FROM bank_shared_access WHERE account_id = ?', {accountId})
    
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

-- Comando: Reset completo del banco de un jugador
RegisterCommand('bankreset', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'No tienes permisos')
        return
    end
    
    local targetId = tonumber(args[1])
    
    if not targetId then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Uso: /bankreset [ID del jugador]')
        return
    end
    
    local targetIdentifier = GetIdentifier(targetId)
    if not targetIdentifier then
        TriggerClientEvent('muhaddil_bank:notify', source, 'error', 'Jugador no encontrado')
        return
    end
    
    -- Eliminar cuentas
    MySQL.query.await('DELETE FROM bank_accounts WHERE owner = ?', {targetIdentifier})
    
    -- Cancelar préstamos
    MySQL.query.await('UPDATE bank_loans SET status = "cancelled", remaining = 0 WHERE user_identifier = ?', {targetIdentifier})
    
    TriggerClientEvent('muhaddil_bank:notify', source, 'success', 'Banco del jugador reseteado')
    TriggerClientEvent('muhaddil_bank:notify', targetId, 'error', 'Tu banco ha sido reseteado por un administrador')
    print(string.format("^2[ADMIN] %s reseteó el banco de %s^7", GetPlayerName(source), GetPlayerName(targetId)))
end, false)

print("^2[Bank System] Comandos de administrador cargados^7")
print("^3Comandos disponibles:^7")
print("  ^5/bankadmin^7 - Ver top 50 cuentas")
print("  ^5/bankaddmoney [ID] [cantidad]^7 - Añadir dinero")
print("  ^5/bankremovemoney [ID] [cantidad]^7 - Remover dinero")
print("  ^5/bankloans^7 - Ver préstamos activos")
print("  ^5/bankcancelloan [ID]^7 - Cancelar préstamo")
print("  ^5/bankinfo [ID]^7 - Ver info de cuenta")
print("  ^5/bankreset [ID jugador]^7 - Resetear banco de jugador")