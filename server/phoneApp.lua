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
    print('===NO SUPPORTED FRAMEWORK FOUND===')
end

local function GetBankData(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local ownedAccounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE owner = ?', { identifier })

    local sharedAccounts = MySQL.query.await([[
        SELECT ba.* FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], { identifier })

    local allAccounts = {}
    for _, acc in ipairs(ownedAccounts or {}) do
        acc.isOwner = true
        table.insert(allAccounts, acc)
    end
    for _, acc in ipairs(sharedAccounts or {}) do
        acc.isOwner = false
        table.insert(allAccounts, acc)
    end

    -- Obtener transacciones recientes
    local transactions = {}
    for _, acc in ipairs(allAccounts) do
        local accTransactions = MySQL.query.await([[
            SELECT * FROM bank_transactions
            WHERE account_id = ?
            ORDER BY created_at DESC
            LIMIT 10
        ]], { acc.id })

        for _, trans in ipairs(accTransactions or {}) do
            trans.account_name = acc.account_name
            table.insert(transactions, trans)
        end
    end

    -- Ordenar transacciones por fecha
    table.sort(transactions, function(a, b)
        return a.created_at > b.created_at
    end)

    -- Obtener préstamos activos
    local loans = MySQL.query.await([[
        SELECT * FROM bank_loans
        WHERE user_identifier = ? AND status = 'active'
    ]], { identifier })

    -- Obtener tarjetas del jugador
    local cards = MySQL.query.await([[
        SELECT bc.*, ba.account_name, ba.balance
        FROM bank_cards bc
        INNER JOIN bank_accounts ba ON bc.account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.created_at DESC
    ]], { identifier })

    -- Obtener efectivo del jugador
    local cash = GetPlayerMoney(source)

    return {
        accounts = allAccounts,
        transactions = transactions,
        loans = loans or {},
        cards = cards or {}, -- Añadir tarjetas
        cash = cash,
        maxAccounts = 5
    }
end

local function Notify(source, message, type)
    TriggerClientEvent('muhaddil_bank:phone:notify', source, message, type or 'info')
end

lib.callback.register('muhaddil_bank:phone:getData', function(source)
    return GetBankData(source)
end)

RegisterNetEvent('muhaddil_bank:phone:createAccount', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local accountName = data.accountName
    if not accountName or accountName == "" then
        return Notify(src, 'Nombre de cuenta inválido', 'error')
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })
    if count >= 5 then
        return Notify(src, 'Has alcanzado el límite de cuentas', 'error')
    end

    local accountId = MySQL.insert.await('INSERT INTO bank_accounts (owner, account_name, balance) VALUES (?, ?, ?)', {
        identifier, accountName, 0
    })

    if accountId then
        Notify(src, 'Cuenta creada: ' .. accountName, 'success')
        Wait(500)
        local newData = GetBankData(src)
        TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
    else
        Notify(src, 'Error al crear cuenta', 'error')
    end
end)

RegisterNetEvent('muhaddil_bank:phone:transfer', function(data)
    print('Triggered transfer event')
    local src = source

    local ok = exports['muhaddil-banking']:Transfer(
        src,
        data.fromAccountId,
        data.toAccountId,
        data.amount,
        nil
    )

    if not ok then return end


    Notify(src, 'Transferencia completada', 'success')
    local newData = GetBankData(src)
    TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
end)

RegisterNetEvent('muhaddil_bank:phone:requestLoan', function(data)
    local src = source

    local loanData = {
        amount = data.amount,
        installments = data.installments,
        interestRate = Config.Loans.InterestRate
    }

    local success, message = exports['muhaddil-banking']:requestLoan(src, loanData)

    if not success then
        return Notify(src, message, 'error')
    end

    Wait(500)
    local newData = GetBankData(src)
    TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
end)

RegisterNetEvent('muhaddil_bank:phone:payLoan', function(data, isFromPhone)
    local src = source

    local loanId = tonumber(data.loanId)
    local amount = tonumber(data.amount)

    if not loanId or not amount or amount <= 0 then
        return Notify(src, 'Datos inválidos', 'error')
    end

    local success, result = exports['muhaddil-banking']:payLoan(src, loanId, amount, isFromPhone)

    if not success then
        return Notify(src, result, 'error')
    end

    Wait(500)
    local newData = GetBankData(src)
    TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
end)

-- RegisterNetEvent('muhaddil_bank:phone:createCard', function(data)
--     local src = source
--     local identifier = GetPlayerIdentifier(src)
--     if not identifier then return end

--     local accountId = tonumber(data.accountId)
--     local pin = data.pin

--     if not accountId then
--         return Notify(src, 'Cuenta inválida', 'error')
--     end

--     if not pin or type(pin) ~= 'string' or #pin ~= 4 or not tonumber(pin) then
--         return Notify(src, 'El PIN debe ser de 4 dígitos numéricos', 'error')
--     end

--     local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
--     if owner ~= identifier then
--         return Notify(src, 'No eres propietario de esta cuenta', 'error')
--     end

--     local existingCard = MySQL.scalar.await('SELECT COUNT(*) FROM bank_cards WHERE account_id = ? AND owner = ?',
--         { accountId, identifier })
--     if existingCard > 0 then
--         return Notify(src, 'Ya tienes una tarjeta para esta cuenta', 'error')
--     end

--     local price = 500
--     if not RemovePlayerMoney(src, price) then
--         return Notify(src, 'No tienes suficiente dinero ($' .. price .. ')', 'error')
--     end

--     local cardNumber = string.format('%04d%04d%04d%04d',
--         math.random(1000, 9999),
--         math.random(1000, 9999),
--         math.random(1000, 9999),
--         math.random(1000, 9999)
--     )

--     MySQL.insert.await([[
--         INSERT INTO bank_cards (card_number, account_id, owner, pin, is_blocked, failed_attempts)
--         VALUES (?, ?, ?, ?, 0, 0)
--     ]], { cardNumber, accountId, identifier, pin })

--     Notify(src, 'Tarjeta creada exitosamente', 'success')
--     Wait(500)
--     local newData = GetBankData(src)
--     TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
-- end)

RegisterNetEvent('muhaddil_bank:phone:toggleCardBlock', function(data)
    local src = source

    local ok = exports['muhaddil-banking']:ToggleCardBlock(src, data.cardId, data.block)
    if not ok then return end

    if data.block then
        Notify(src, 'Tarjeta bloqueada', 'warning')
    else
        Notify(src, 'Tarjeta desbloqueada', 'success')
    end

    local newData = GetBankData(src)
    TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
end)

-- RegisterNetEvent('muhaddil_bank:phone:deleteCard', function(data)
--     local src = source
--     local identifier = GetPlayerIdentifier(src)
--     if not identifier then return end

--     local cardId = tonumber(data.cardId)

--     if not cardId then
--         return Notify(src, 'Tarjeta inválida', 'error')
--     end

--     local cardOwner = MySQL.scalar.await('SELECT owner FROM bank_cards WHERE id = ?', { cardId })
--     if cardOwner ~= identifier then
--         return Notify(src, 'No tienes permiso para eliminar esta tarjeta', 'error')
--     end

--     MySQL.query.await('DELETE FROM bank_cards WHERE id = ?', { cardId })

--     Notify(src, 'Tarjeta eliminada', 'success')
--     Wait(500)
--     local newData = GetBankData(src)
--     TriggerClientEvent('muhaddil_bank:phone:updateData', src, newData)
-- end)
