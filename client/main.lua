local ESX = nil
local QBCore = nil
local isOpen = false
local ESXVer = Config.ESXVer
local FrameWork = nil

-- Inicializar Framework
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

-- Crear blips
Citizen.CreateThread(function()
    for _, bank in pairs(Config.BankLocations) do
        if bank.blip then
            local blip = AddBlipForCoord(bank.coords.x, bank.coords.y, bank.coords.z)
            SetBlipSprite(blip, Config.Blip.Sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blip.Scale)
            SetBlipColour(blip, Config.Blip.Color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(bank.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Markers y zona de interacción
Citizen.CreateThread(function()
    while true do
        local sleep = 500
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearBank = false

        for _, bank in pairs(Config.BankLocations) do
            local distance = #(playerCoords - bank.coords)

            if distance < 15.0 then
                sleep = 0
                nearBank = true
                DrawMarker(27, bank.coords.x, bank.coords.y, bank.coords.z - 0.99, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 0.5, 0, 150, 200, 100, false, false, 2, false, nil, nil, false)

                if distance < 2.0 then
                    lib.showTextUI('[E] - Abrir Banco')
                    
                    if IsControlJustReleased(0, 38) then
                        OpenBank()
                    end
                end
            end
        end

        if not nearBank then
            lib.hideTextUI()
        end

        Wait(sleep)
    end
end)

function OpenBank()
    if isOpen then return end
    
    -- Usar ox_lib callback para obtener datos de manera síncrona (await)
    local data = lib.callback.await('muhaddil_bank:getData', false)
    
    if not data then
        return lib.notify({type = 'error', description = 'Error al conectar con el banco'})
    end

    isOpen = true
    SetNuiFocus(true, true)
    
    SendNUIMessage({
        action = 'setData',
        data = data
    })
    
    SendNUIMessage({
        action = 'setVisible',
        data = true
    })
end

function CloseBank()
    isOpen = false
    SetNuiFocus(false, false)
    -- SendNUIMessage({
    --     action = 'setVisible',
    --     data = false
    -- })
    lib.hideTextUI()
end

-- Notificaciones desde el servidor
RegisterNetEvent('muhaddil_bank:notify', function(type, message)
    lib.notify({type = type, description = message})
    
    -- También enviar a la NUI si es necesario
    SendNUIMessage({
        action = 'notify',
        type = type,
        message = message
    })
end)

-- NUI Callbacks
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
    TriggerServerEvent('muhaddil_bank:transfer', data)
    cb('ok')
end)

RegisterNUICallback('deposit', function(data, cb)
    TriggerServerEvent('muhaddil_bank:deposit', data.accountId, data.amount)
    cb('ok')
end)

RegisterNUICallback('withdraw', function(data, cb)
    TriggerServerEvent('muhaddil_bank:withdraw', data.accountId, data.amount)
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
    TriggerServerEvent('muhaddil_bank:purchaseBank', data.bankName)
    cb('ok')
end)

-- Evento para refrescar datos
RegisterNetEvent('muhaddil_bank:refreshData', function()
    if not isOpen then return end
    
    local data = lib.callback.await('muhaddil_bank:getData', false)
    if data then
        SendNUIMessage({
            action = 'setData',
            data = data
        })
    end
end)

-- Evento para abrir banco (desde comando)
RegisterNetEvent('muhaddil_bank:openBank', function()
    OpenBank()
end)