function CreateBlips()
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
end

if Config.ATMs.Enabled and Config.ATMBlip.Enabled and not Config.ATMs.Target then
    function CreateATMBlips()
        for _, coords in pairs(Config.ATMs.Locations) do
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, Config.ATMBlip.Sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.ATMBlip.Scale)
            SetBlipColour(blip, Config.ATMBlip.Color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.ATMBlip.Label)
            EndTextCommandSetBlipName(blip)
        end
    end

    CreateATMBlips()
end

function GetClosestBankId(coords)
    local closestBank = nil
    local closestDist = 999999

    for _, bank in pairs(Config.BankLocations) do
        local dist = #(coords - bank.coords)
        if dist < closestDist then
            closestDist = dist
            closestBank = bank
        end
    end

    return closestBank and closestBank.id or nil
end

function playAnim(dict, anim, duration)
    local ped = PlayerPedId()

    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end

    TaskPlayAnim(
        ped,
        dict,
        anim,
        8.0,
        -8.0,
        duration or -1,
        49, -- upper body + repeat
        0,
        false,
        false,
        false
    )
end

function stopAnim(dict, anim)
    local ped = PlayerPedId()
    StopAnimTask(ped, dict, anim, 1.0)
end

function FaceATM(ped)
    local coords = GetEntityCoords(ped)
    local atm = GetClosestObjectOfType(coords, 1.5, `prop_atm_01`, false, false, false)
        or GetClosestObjectOfType(coords, 1.5, `prop_atm_02`, false, false, false)
        or GetClosestObjectOfType(coords, 1.5, `prop_atm_03`, false, false, false)

    if not atm then return end

    local atmCoords = GetEntityCoords(atm)
    local heading = GetHeadingFromVector_2d(
        atmCoords.x - coords.x,
        atmCoords.y - coords.y
    )

    SetEntityHeading(ped, heading)
end

function ATMTarget(ATM_MODELS, isATMOpen)
    if Config.ATMs.TargetSystem == 'ox' then
        exports.ox_target:addModel(ATM_MODELS, {
            {
                name = 'use_atm',
                icon = 'fa-solid fa-credit-card',
                label = Locale('client.use_atm'),
                distance = Config.ATMs.TargetDistance,
                onSelect = function(data)
                    if isATMOpen then return end
                    OpenATM()
                end
            }
        })
    elseif Config.ATMs.TargetSystem == 'qb' then
        exports['qb-target']:AddTargetModel(joaat(ATM_MODELS), {
            options = {
                {
                    label = Locale('client.use_atm'),
                    icon = "fas fa-glass-water",
                    action = function(entity)
                        if isATMOpen then return end
                        OpenATM()
                    end
                }
            },
            distance = 2.0
        })
    end
end
