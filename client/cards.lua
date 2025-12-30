RegisterNUICallback('createCard', function(data, cb)
    TriggerServerEvent('muhaddil_bank:createCard', data.accountId, data.pin)
    cb('ok')
end)

RegisterNUICallback('toggleCardBlock', function(data, cb)
    TriggerServerEvent('muhaddil_bank:toggleCardBlock', data.cardId, data.block)
    cb('ok')
end)

RegisterNUICallback('changeCardPin', function(data, cb)
    TriggerServerEvent('muhaddil_bank:changeCardPin', data.cardId, data.currentPin, data.newPin)
    cb('ok')
end)

RegisterNUICallback('deleteCard', function(data, cb)
    TriggerServerEvent('muhaddil_bank:deleteCard', data.cardId)
    cb('ok')
end)

RegisterNUICallback('getCards', function(data, cb)
    local cards = lib.callback.await('muhaddil_bank:getPlayerCards', false)
    cb(cards or {})
end)

if Config.Cards.Enabled and Config.Cards.CanStealCards then
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addGlobalPlayer({
            {
                name = 'steal_card',
                icon = 'fas fa-credit-card',
                label = 'Robar Tarjeta',
                distance = 2.0,
                canInteract = function(entity, distance)
                    local ped = PlayerPedId()
                    return IsPedArmed(ped, 4)
                end,
                onSelect = function(data)
                    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity))
                    if targetServerId and targetServerId > 0 then
                        AttemptCardTheft(targetServerId)
                    end
                end
            }
        })
    elseif GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddGlobalPlayer({
            options = {
                {
                    type = "client",
                    icon = 'fas fa-credit-card',
                    label = 'Robar Tarjeta',
                    action = function(entity)
                        local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                        if targetServerId and targetServerId > 0 then
                            AttemptCardTheft(targetServerId)
                        end
                    end,
                    canInteract = function(entity)
                        local ped = PlayerPedId()
                        return IsPedArmed(ped, 4)
                    end
                }
            },
            distance = 2.0
        })
    end
end

function AttemptCardTheft(targetServerId)
    local ped = PlayerPedId()
    TaskPlayAnim(ped, "random@shop_robbery", "robbery_action_a", 8.0, -8.0, 2000, 0, 0, false, false, false)

    if lib.progressBar then
        local success = lib.progressBar({
            duration = 3000,
            label = 'Robando tarjeta...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            }
        })

        if success then
            TriggerServerEvent('muhaddil_bank:attemptCardTheft', targetServerId)
        else
            lib.notify({ type = 'error', description = Locale('client.robbery_cancelled') })
            return
        end
    else
        Wait(3000)
        TriggerServerEvent('muhaddil_bank:attemptCardTheft', targetServerId)
    end

    ClearPedTasks(ped)
end

RegisterNetEvent('muhaddil_bank:cardTheftResult', function(success, cardData)
    if success and cardData then
        lib.notify({ type = 'success', description = Locale('client.card_stolen') })
        stolenCard = cardData
    elseif not success then
        lib.notify({ type = 'error', description = cardData or Locale('client.card_steal_failed') })
    end
end)

local stolenCard = nil

function HasStolenCard()
    return stolenCard ~= nil
end

function GetStolenCard()
    return stolenCard
end

function ClearStolenCard()
    stolenCard = nil
end

exports('HasStolenCard', HasStolenCard)
exports('GetStolenCard', GetStolenCard)
exports('ClearStolenCard', ClearStolenCard)

RegisterCommand('tirartarjeta', function()
    if stolenCard then
        stolenCard = nil
        lib.notify({ type = 'info', description = Locale('client.card_discarded') })
    else
        lib.notify({ type = 'error', description = Locale('client.no_stolen_card') })
    end
end, false)

RegisterNUICallback('atmUseStolenCard', function(data, cb)
    if not stolenCard then
        cb({ success = false, error = 'No tienes una tarjeta robada' })
        return
    end

    local result = lib.callback.await('muhaddil_bank:verifyCardForATM', false, stolenCard.card_number, data.pin)

    if result.success then
        local atmData = lib.callback.await('muhaddil_bank:getAccountDataById', false, result.accountId)
        cb({ success = true, data = atmData })
    else
        cb({ success = false, error = result.error })
        if result.error:find('bloqueada') then
            stolenCard = nil
            lib.notify({ type = 'warning', description = Locale('client.card_blocked_warning') })
            TriggerServerEvent('muhaddil_bank:blockStolenCard', stolenCard)
        end
    end
end)

print('^2[Bank System] Cards client loaded^7')
