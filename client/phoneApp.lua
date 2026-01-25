local identifier = "muhaddil_bank"

while GetResourceState("lb-phone") ~= "started" do
    Wait(500)
end

local function addApp()
    local added, errorMessage = exports["lb-phone"]:AddCustomApp({
        identifier = identifier,

        name = "Banco",
        description = "Gestiona tus cuentas bancarias",
        developer = "Muhaddil",

        defaultApp = true,
        size = 128000,

        images = {
            "https://cfx-nui-" .. GetCurrentResourceName() .. "/phone-app-ui/assets/screenshot.png"
        },

        ui = GetCurrentResourceName() .. "/phone-app-ui/index.html",
        icon = "https://cfx-nui-" .. GetCurrentResourceName() .. "/phone-app-ui/assets/icon.jpg",

        fixBlur = true
    })

    if not added then
        print("Could not add bank app:", errorMessage)
    end
end

addApp()

AddEventHandler("onResourceStart", function(resource)
    if resource == "lb-phone" then
        addApp()
    end
end)

RegisterNUICallback("getBankDataPhone", function(data, cb)
    local bankData = lib.callback.await('muhaddil_bank:phone:getData', false)
    cb(bankData)
end)

RegisterNUICallback("transferPhone", function(data, cb)
    TriggerServerEvent('muhaddil_bank:phone:transfer', data)
    cb("ok")
end)

RegisterNUICallback("requestLoanPhone", function(data, cb)
    TriggerServerEvent('muhaddil_bank:phone:requestLoan', data)
    cb("ok")
end)

RegisterNUICallback("payLoanPhone", function(data, cb)
    TriggerServerEvent('muhaddil_bank:phone:payLoan', data, true)
    cb("ok")
end)

RegisterNUICallback("createAccountPhone", function(data, cb)
    TriggerServerEvent('muhaddil_bank:phone:createAccount', data)
    cb("ok")
end)

RegisterNUICallback("toggleCardBlockPhone", function(data, cb)
    TriggerServerEvent('muhaddil_bank:phone:toggleCardBlock', data)
    cb("ok")
end)

RegisterNetEvent('muhaddil_bank:phone:updateData', function(data)
    exports["lb-phone"]:SendCustomAppMessage(identifier, {
        type = "updateData",
        data = data
    })
end)

RegisterNetEvent('muhaddil_bank:phone:notify', function(message, type)
    exports["lb-phone"]:SendCustomAppMessage(identifier, {
        type = "notify",
        message = message,
        notifyType = type or "info"
    })
end)
