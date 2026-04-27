local function OpenChecksNui(payload)
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

exports('useCheck', function(data)
    local slot = data.slot or data.currentSlot

    local checkData = lib.callback.await('muhaddil_bank:inspectCheck', false, slot)

    if not checkData then
        lib.notify({ title = 'Error', description = 'No se pudo leer el cheque', type = 'error' })
        return
    end

    TriggerEvent('muhaddil_bank:openCheckViewer', {
        slot      = slot,
        checkData = checkData,
    })
end)

AddEventHandler('muhaddil_bank:openCheckViewer', function(data)
    OpenChecksNui({
        action    = 'openCheckViewer',
        checkSlot = data.slot,
        checkData = data.checkData,
    })
end)

RegisterNetEvent('muhaddil_bank:openForgeMenu', function()
    OpenChecksNui({
        action = 'openForgeMenu',
    })
end)
