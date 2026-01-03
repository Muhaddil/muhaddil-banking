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
        label = Locale('client.opening_atm'),
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

    local data = lib.callback.await('muhaddil_bank:getATMData', false)

    if not data then
        return lib.notify({ type = 'error', description = Locale('client.atm_connection_error') })
    end

    if Config.Cards.Enabled and Config.Cards.RequireCardForATM then
        if not data.cards or #data.cards == 0 then
            return lib.notify({ type = 'error', description = Locale('client.need_debit_card') })
        end
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
        label = Locale('client.closing_atm'),
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
    local result = lib.callback.await('muhaddil_bank:verifyCardPin', false, data.cardId, data.pin)

    if result.success then
        currentCard = data.cardId
        local accountData = lib.callback.await('muhaddil_bank:getAccountDataById', false, data.accountId)
        cb({ success = true, accountData = accountData })
    else
        cb({ success = false, error = result.error })
    end
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
