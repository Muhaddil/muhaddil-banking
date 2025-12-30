local isATMOpen = false
local currentCard = nil
local ATM_MODELS = Config.ATMs.TargetModels

if Config.ATMs.Enabled and not Config.ATMs.Target then
    Citizen.CreateThread(function()
        while true do
            local sleep = 1000
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local nearATM = false
            local closestATM = nil
            local closestDist = 999

            for _, atmCoords in pairs(Config.ATMs.Locations) do
                local distance = #(playerCoords - atmCoords)

                if distance < 2.0 then
                    sleep = 0
                    if distance < closestDist then
                        closestDist = distance
                        closestATM = atmCoords
                    end
                end
            end

            if closestATM and closestDist < 1.5 then
                nearATM = true
                if not isATMOpen then
                    lib.showTextUI('[E] - Usar Cajero')

                    if IsControlJustReleased(0, 38) then
                        OpenATM()
                    end
                end
            end

            if not nearATM and not isATMOpen then
                lib.hideTextUI()
            end

            Wait(sleep)
        end
    end)
end

if Config.ATMs.Target then
    Wait(1000) -- Wait till functions.lua is loaded
    ATMTarget(ATM_MODELS, isATMOpen)
end

function OpenATM()
    if isATMOpen then return end

    local success = lib.progressBar({
        duration = 2500,
        label = 'Accediendo al cajero...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'amb@prop_human_atm@male@idle_a',
            clip = 'idle_a'
        },
    })

    if not success then return end

    if Config.Cards.Enabled and Config.Cards.RequireCardForATM then
        local hasCard = lib.callback.await('muhaddil_bank:hasCard', false)
        if not hasCard then
            return lib.notify({ type = 'error', description = 'Necesitas una tarjeta de débito para usar el cajero' })
        end

        currentCard = lib.callback.await('muhaddil_bank:getPlayerCard', false)
        if not currentCard then
            return lib.notify({ type = 'error', description = 'No se encontró tu tarjeta' })
        end

        if currentCard.is_blocked then
            return lib.notify({ type = 'error', description = 'Tu tarjeta está bloqueada' })
        end
    end

    local data = lib.callback.await('muhaddil_bank:getATMData', false)

    if not data then
        return lib.notify({ type = 'error', description = 'Error al conectar con el cajero' })
    end

    isATMOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openATM',
        data = data,
        requirePin = Config.Cards.Enabled and Config.Cards.RequireCardForATM
    })
end

function CloseATM()
    if not isATMOpen then return end
    SetNuiFocus(false, false)

    local success = lib.progressBar({
        duration = 1500,
        label = 'Cerrando sesión...',
        useWhileDead = false,
        canCancel = false,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        anim = {
            dict = 'amb@prop_human_atm@male@exit',
            clip = 'exit'
        },
    })

    isATMOpen = false
    currentCard = nil

    SendNUIMessage({
        action = 'closeATM'
    })

    lib.hideTextUI()
end

RegisterNUICallback('closeATM', function(data, cb)
    CloseATM()
    cb('ok')
end)

RegisterNUICallback('atmVerifyPin', function(data, cb)
    if not currentCard then
        cb({ success = false, error = 'No hay tarjeta insertada' })
        return
    end

    local result = lib.callback.await('muhaddil_bank:verifyCardPin', false, currentCard.id, data.pin)
    cb(result)
end)

RegisterNUICallback('atmDeposit', function(data, cb)
    TriggerServerEvent('muhaddil_bank:atmDeposit', data.accountId, data.amount)
    cb('ok')
end)

RegisterNUICallback('atmWithdraw', function(data, cb)
    TriggerServerEvent('muhaddil_bank:atmWithdraw', data.accountId, data.amount)
    cb('ok')
end)

RegisterNUICallback('atmTransfer', function(data, cb)
    TriggerServerEvent('muhaddil_bank:atmTransfer', data.fromAccountId, data.toAccountId, data.amount)
    cb('ok')
end)

RegisterNetEvent('muhaddil_bank:refreshATMData', function()
    if not isATMOpen then return end

    local data = lib.callback.await('muhaddil_bank:getATMData', false)
    if data then
        SendNUIMessage({
            action = 'updateATMData',
            data = data
        })
    end
end)

exports('OpenATM', OpenATM)
exports('CloseATM', CloseATM)
exports('IsATMOpen', function() return isATMOpen end)
