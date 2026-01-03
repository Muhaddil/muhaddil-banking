local ESX = nil
local QBCore = nil
local isOpen = false
local currentBankLocation = nil
local currentBankName = nil
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

local targetSystem = nil
if GetResourceState('ox_target') == 'started' then
    targetSystem = 'ox_target'
elseif GetResourceState('qb-target') == 'started' then
    targetSystem = 'qb-target'
end

local spawnedPeds = {}
local targetZones = {}

Citizen.CreateThread(function()
    while true do
        local sleep = 2000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)

        for _, bank in pairs(Config.BankLocations) do
            if bank.useped and bank.pedcoords and bank.pedmodel then
                local distance = #(playerCoords - vector3(bank.pedcoords.x, bank.pedcoords.y, bank.pedcoords.z))

                if distance < 50.0 and not spawnedPeds[bank.id] then
                    RequestModel(bank.pedmodel)
                    while not HasModelLoaded(bank.pedmodel) do
                        Wait(1)
                    end

                    local ped = CreatePed(4, bank.pedmodel, bank.pedcoords.x, bank.pedcoords.y, bank.pedcoords.z - 1.0,
                        bank.pedcoords.w, false, true)
                    FreezeEntityPosition(ped, true)
                    SetEntityInvincible(ped, true)
                    SetBlockingOfNonTemporaryEvents(ped, true)

                    spawnedPeds[bank.id] = ped

                    if targetSystem == 'ox_target' then
                        exports.ox_target:addLocalEntity(ped, {
                            {
                                name = 'bank_' .. bank.id,
                                icon = 'fas fa-university',
                                label = Locale('client.open', bank.name),
                                onSelect = function()
                                    OpenBank(bank.id, bank.name)
                                end
                            }
                        })
                    elseif targetSystem == 'qb-target' then
                        exports['qb-target']:AddTargetEntity(ped, {
                            options = {
                                {
                                    icon = 'fas fa-university',
                                    label = Locale('client.open', bank.name),
                                    action = function()
                                        OpenBank(bank.id, bank.name)
                                    end
                                }
                            },
                            distance = 2.5
                        })
                    end
                elseif distance >= 50.0 and spawnedPeds[bank.id] then
                    if targetSystem == 'ox_target' then
                        exports.ox_target:removeLocalEntity(spawnedPeds[bank.id])
                    elseif targetSystem == 'qb-target' then
                        exports['qb-target']:RemoveTargetEntity(spawnedPeds[bank.id])
                    end

                    DeleteEntity(spawnedPeds[bank.id])
                    spawnedPeds[bank.id] = nil
                end
            end
        end

        Wait(sleep)
    end
end)

Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearBank = false
        local markerShow = false

        for _, bank in pairs(Config.BankLocations) do
            if not bank.useped then
                local distance = #(playerCoords - bank.coords)

                if distance < 15.0 then
                    sleep = 0
                    nearBank = true

                    DrawMarker(27, bank.coords.x, bank.coords.y, bank.coords.z - 0.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5,
                        1.5, 0.5, 0, 150, 200, 100, false, false, 2, false, nil, nil, false)

                    if distance < 2.0 then
                        if not markerShow then
                            lib.showTextUI(Locale('client.open_bank'))
                            markerShow = true
                        end
                        if IsControlJustReleased(0, 38) then
                            OpenBank(bank.id, bank.name)
                        end
                    end
                end
            end
        end

        if not nearBank and markerShow == true then
            lib.hideTextUI()
            markerShow = false
        end

        Wait(sleep)
    end
end)

function OpenBank(bankId, bankName)
    if isOpen then return end
    local data = lib.callback.await('muhaddil_bank:getData', false, bankId)
    if not data then
        return lib.notify({ type = 'error', description = Locale('client.bank_connection_error') })
    end
    isOpen = true
    currentBankLocation = bankId
    currentBankName = bankName
    currentBankType = data.currentBankInfo.bankType
    commissionRate = data.currentBankInfo.commissionRate
    bankManagementEnabled = Config.BankOwnership.Enabled
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'setData',
        data = data,
        currentBank = bankName,
        currentBankId = bankId,
        currentBankType = currentBankType,
        commissionRate = commissionRate,
        bankManagementEnabled = bankManagementEnabled
    })
    SendNUIMessage({
        action = 'setVisible',
        data = true
    })
end

function CloseBank()
    isOpen = false
    currentBankLocation = nil
    currentBankName = nil
    SetNuiFocus(false, false)
    lib.hideTextUI()
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for _, ped in pairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
end)

RegisterNetEvent('muhaddil_bank:notify', function(type, message)
    lib.notify({ type = type, description = message })

    SendNUIMessage({
        action = 'notify',
        type = type,
        message = message
    })
end)

RegisterNUICallback('close', function(data, cb)
    CloseBank()
    cb('ok')
end)

RegisterNUICallback('createAccount', function(data, cb)
    TriggerServerEvent('muhaddil_bank:createAccount', data)
    cb('ok')
end)

RegisterNUICallback('deleteAccount', function(data, cb)
    TriggerServerEvent('muhaddil_bank:deleteAccount', data.accountId)
    cb('ok')
end)

RegisterNUICallback('addSharedUser', function(data, cb)
    TriggerServerEvent('muhaddil_bank:addSharedUser', data.accountId, data.targetId)
    cb('ok')
end)

RegisterNUICallback('removeSharedUser', function(data, cb)
    TriggerServerEvent('muhaddil_bank:removeSharedUser', data.accountId, data.targetId)
    cb('ok')
end)

RegisterNUICallback('transfer', function(data, cb)
    data.bankLocation = currentBankLocation
    TriggerServerEvent('muhaddil_bank:transfer', data)
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('muhaddil_bank:deposit', data.accountId, data.amount, currentBankLocation)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('muhaddil_bank:withdraw', data.accountId, data.amount, currentBankLocation)
    cb('ok')
end)

RegisterNUICallback('requestLoan', function(data, cb)
    TriggerServerEvent('muhaddil_bank:requestLoan', data)
    cb('ok')
end)

RegisterNUICallback('payLoan', function(data, cb)
    TriggerServerEvent('muhaddil_bank:payLoan', data.loanId, data.amount)
    cb('ok')
end)

RegisterNUICallback('purchaseBank', function(data, cb)
    TriggerServerEvent('muhaddil_bank:purchaseBank', data.bankId)
    cb('ok')
end)

RegisterNUICallback('sellBank', function(data, cb)
    TriggerServerEvent('muhaddil_bank:sellBank', data.bankId)
    cb('ok')
end)

RegisterNUICallback('transferBank', function(data, cb)
    TriggerServerEvent('muhaddil_bank:transferBank', data.bankId, data.targetPlayerId)
    cb('ok')
end)

RegisterNUICallback('updateCommission', function(data, cb)
    TriggerServerEvent('muhaddil_bank:updateCommission', data.bankId, data.newRate)
    cb('ok')
end)

RegisterNUICallback('withdrawEarnings', function(data, cb)
    TriggerServerEvent('muhaddil_bank:withdrawEarnings', data.bankId)
    cb('ok')
end)

RegisterNUICallback('renameBank', function(data, cb)
    TriggerServerEvent('muhaddil_bank:renameBank', data.bankId, data.newName)
    cb('ok')
end)

RegisterNetEvent('muhaddil_bank:refreshData', function()
    if not isOpen then return end

    local data = lib.callback.await('muhaddil_bank:getData', false, currentBankLocation)
    if data then
        SendNUIMessage({
            action = 'setData',
            data = data,
            currentBank = currentBankName,
            currentBankId = currentBankLocation
        })
    end
end)

RegisterNetEvent('muhaddil_bank:openBank', function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestBankId = GetClosestBankId(playerCoords)

    if closestBankId then
        for _, bank in pairs(Config.BankLocations) do
            if bank.id == closestBankId then
                OpenBank(bank.id, bank.name)
                break
            end
        end
    else
        lib.notify({ type = 'error', description = Locale('client.not_near_bank') })
    end
end)

function SetLocale()
    Wait(1000)
    SendNUIMessage({
        action = 'setLocale',
        locale = Config.Locale
    })
end

CreateBlips()
SetLocale()

exports('OpenBankById', function(bankId)
    if isOpen then return false end

    for _, bank in pairs(Config.BankLocations) do
        if bank.id == bankId then
            OpenBank(bank.id, bank.name)
            return true
        end
    end

    return false
end)

exports('OpenNearestBank', function()
    if isOpen then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestBankId = GetClosestBankId(playerCoords)

    if not closestBankId then
        return false
    end

    for _, bank in pairs(Config.BankLocations) do
        if bank.id == closestBankId then
            OpenBank(bank.id, bank.name)
            return true
        end
    end

    return false
end)

exports('CloseBank', function()
    if not isOpen then return false end
    CloseBank()
    return true
end)

exports('IsBankOpen', function()
    return isOpen
end)

exports('GetFramework', function()
    return FrameWork
end)

exports('GetCurrentBank', function()
    if not isOpen then return nil end

    return {
        bankId = currentBankLocation,
        bankName = currentBankName
    }
end)

exports('RefreshBankData', function()
    if not isOpen then return false end

    TriggerEvent('muhaddil_bank:refreshData')
    return true
end)
