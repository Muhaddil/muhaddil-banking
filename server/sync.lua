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
    else
        print('===NO SUPPORTED FRAMEWORK FOUND===')
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

local lastKnownBalance = {}

local function GetTotalBankBalance(identifier)
    local total = 0
    local ownedAccounts = MySQL.query.await('SELECT balance FROM bank_accounts WHERE owner = ?', { identifier })

    for _, acc in ipairs(ownedAccounts or {}) do
        total = total + tonumber(acc.balance)
    end

    return total
end

local function GetPrimaryAccount(identifier)
    local account = MySQL.single.await([[
        SELECT * FROM bank_accounts
        WHERE owner = ?
        ORDER BY created_at ASC
        LIMIT 1
    ]], { identifier })

    return account
end

function SyncFrameworkBank(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        return
    end

    local totalBalance = GetTotalBankBalance(identifier)
    local frameworkBalance = GetPlayerBankMoney(source)

    if totalBalance == nil then
        return
    end

    if frameworkBalance == nil then
        return
    end

    if frameworkBalance == totalBalance then
        return
    end

    if frameworkBalance > totalBalance then
        local diff = frameworkBalance - totalBalance
        RemovePlayerBankMoney(source, diff)
    elseif frameworkBalance < totalBalance then
        local diff = totalBalance - frameworkBalance
        AddPlayerBankMoney(source, diff)
    end

    lastKnownBalance[identifier] = totalBalance
end

function DetectExternalChanges(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local frameworkBalance = GetPlayerBankMoney(source)
    local customBalance = GetTotalBankBalance(identifier)
    local lastBalance = lastKnownBalance[identifier] or customBalance

    local frameworkDiff = frameworkBalance - lastBalance

    if math.abs(frameworkDiff) < 0.01 then return end

    local primaryAccount = GetPrimaryAccount(identifier)
    if not primaryAccount then return end

    local oldBalance = tonumber(primaryAccount.balance)
    local newBalance = math.max(0, oldBalance + frameworkDiff)

    MySQL.query.await('UPDATE bank_accounts SET balance = ? WHERE id = ?', { newBalance, primaryAccount.id })

    local transType = frameworkDiff > 0 and 'external_deposit' or 'external_withdrawal'
    local description = frameworkDiff > 0
        and Locale('server.externalDeposit', frameworkDiff)
        or Locale('server.externalWithdraw', string.format("%.2f", math.abs(frameworkDiff)))

    MySQL.insert.await([[
        INSERT INTO bank_transactions (account_id, type, amount, description)
        VALUES (?, ?, ?, ?)
    ]], { primaryAccount.id, transType, frameworkDiff, description })

    lastKnownBalance[identifier] = frameworkBalance
    TriggerClientEvent('muhaddil_bank:refreshData', source)
end

function ImportFrameworkBank(source, accountId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end

    local frameworkBankMoney = GetPlayerBankMoney(source)

    if frameworkBankMoney > 0 then
        MySQL.query.await('UPDATE bank_accounts SET balance = ? WHERE id = ?', { frameworkBankMoney, accountId })

        MySQL.insert.await([[
            INSERT INTO bank_transactions (account_id, type, amount, description)
            VALUES (?, ?, ?, ?)
        ]], { accountId, 'import', frameworkBankMoney, 'Importación inicial' })

        lastKnownBalance[identifier] = frameworkBankMoney

        return true
    end

    return false
end

lib.callback.register('muhaddil_bank:isFirstAccount', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return false end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })
    return count == 0
end)

RegisterNetEvent('muhaddil_bank:afterDeposit', function(src)
    SyncFrameworkBank(src)
end)

RegisterNetEvent('muhaddil_bank:afterWithdraw', function(src)
    SyncFrameworkBank(src)
end)

RegisterNetEvent('muhaddil_bank:afterTransfer', function(src)
    SyncFrameworkBank(src)
end)

RegisterNetEvent('muhaddil_bank:afterDeleteAccount', function(src)
    SyncFrameworkBank(src)
end)

CreateThread(function()
    while true do
        Wait(30000) -- 30 seconds

        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                DetectExternalChanges(src)
            end
        end
    end
end)

AddEventHandler('playerJoining', function()
    local src = source
    Wait(5000)

    local identifier = GetPlayerIdentifier(src)
    if identifier then
        local hasAccounts = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })

        if hasAccounts > 0 then
            SyncFrameworkBank(src)
            Wait(2000)
            DetectExternalChanges(src)
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if identifier then
        lastKnownBalance[identifier] = nil
    end
end)

if FrameWork == 'esx' then
    AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
        Wait(3000)
        local identifier = xPlayer.identifier
        local hasAccounts = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })

        if hasAccounts > 0 then
            SyncFrameworkBank(playerId)
            Wait(2000)
            DetectExternalChanges(playerId)
        end
    end)
end

if FrameWork == 'qb' then
    AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
        Wait(3000)
        local src = Player.PlayerData.source
        local identifier = Player.PlayerData.citizenid

        local hasAccounts = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })

        if hasAccounts > 0 then
            SyncFrameworkBank(src)
            Wait(2000)
            DetectExternalChanges(src)
        end
    end)
end

RegisterCommand('banksync', function(source, args, rawCommand)
    if source == 0 then
        print('^3[Bank Sync] ' .. Locale('server.syncing_all_players') .. '^7')
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                SyncFrameworkBank(src)
                DetectExternalChanges(src)
            end
        end
        print('^2[Bank Sync] ' .. Locale('server.synced') .. '^7')
    else
        if hasPermission(source) then
            if args[1] then
                local targetId = tonumber(args[1])
                if targetId and GetPlayerName(targetId) then
                    SyncFrameworkBank(targetId)
                    DetectExternalChanges(targetId)
                    Notify(source, 'success', Locale('server.player_synced'))
                else
                    Notify(source, 'error', Locale('server.player_not_found'))
                end
            else
                SyncFrameworkBank(source)
                DetectExternalChanges(source)
                Notify(source, 'success', Locale('server.player_synced'))
            end
        end
    end
end, false)

RegisterCommand('bankstatus', function(source, args, rawCommand)
    if source == 0 then return end
    if not hasPermission(source) then return end

    local identifier = GetPlayerIdentifier(source)
    if not identifier then return end

    local customBalance = GetTotalBankBalance(identifier)
    local frameworkBalance = GetPlayerBankMoney(source)
    local cached = lastKnownBalance[identifier] or 0

    print('^3========== ' .. GetPlayerName(source) .. ' ==========^7')
    print('^2Custom:^7 $' .. string.format('%.2f', customBalance))
    print('^2Framework:^7 $' .. string.format('%.2f', frameworkBalance))
    print('^2Cache:^7 $' .. string.format('%.2f', cached))
    print('^2Diff:^7 $' .. string.format('%.2f', frameworkBalance - customBalance))
    print('^3======================================^7')

    Notify(source, 'info', Locale('server.check_console'))
end, false)

exports('SyncFrameworkBank', SyncFrameworkBank)
exports('DetectExternalChanges', DetectExternalChanges)
exports('GetTotalBankBalance', function(identifier)
    return GetTotalBankBalance(identifier)
end)

print('^2[Bank System] Sync cargado^7')
