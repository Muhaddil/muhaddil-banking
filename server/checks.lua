if not Config.Checks or not Config.Checks.Enabled then return end

RegisterNetEvent('muhaddil_bank:createCheck', function(data)
    local src        = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local accountId = tonumber(data.accountId)
    local amount    = tonumber(data.amount)
    local memo      = data.memo or ''

    if not accountId or not amount then
        return Notify(src, 'error', Locale('server.invalid_data') or 'Datos inválidos')
    end

    if amount < Config.Checks.MinAmount then
        return Notify(src, 'error',
            Locale('server.check_min_amount', Config.Checks.MinAmount) or
            'El monto mínimo para un cheque es $' .. Config.Checks.MinAmount)
    end

    if amount > Config.Checks.MaxAmount then
        return Notify(src, 'error',
            Locale('server.check_max_amount', Config.Checks.MaxAmount) or
            'El monto máximo para un cheque es $' .. Config.Checks.MaxAmount)
    end

    local activeCount = MySQL.scalar.await(
        "SELECT COUNT(*) FROM bank_checks WHERE issuer = ? AND status = 'active'",
        { identifier }
    )
    if tonumber(activeCount) >= Config.Checks.MaxActiveChecks then
        return Notify(src, 'error',
            Locale('server.max_checks_reached') or 'Has alcanzado el límite de cheques activos')
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, accountId, identifier, identifier })

    if not account then
        return Notify(src, 'error',
            Locale('server.no_permission_origin') or 'No tienes permiso sobre esta cuenta')
    end

    local totalCost = amount + Config.Checks.Fee
    local balance   = tonumber(account.balance)

    if balance < totalCost then
        return Notify(src, 'error',
            Locale('server.insufficient_balance') or
            'Saldo insuficiente (incluye comisión de $' .. Config.Checks.Fee .. ')')
    end

    local checkCode = GenerateCheckCode()
    local expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (Config.Checks.ExpirationDays * 86400))
    local issuerName = GetPlayerDisplayName(src)

    MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', { totalCost, accountId })

    MySQL.insert.await([[
        INSERT INTO bank_checks (check_code, issuer, from_account_id, amount, memo, expires_at, issuer_name)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { checkCode, identifier, accountId, amount, memo, expiresAt, issuerName })

    MySQL.insert.await([[
        INSERT INTO bank_transactions (account_id, type, amount, description)
        VALUES (?, 'check_issued', ?, ?)
    ]], {
        accountId,
        -totalCost,
        Locale('server.check_issued', checkCode, amount, Config.Checks.Fee)
    })

    if Config.Checks.UseInventoryItem then
        local meta = BuildCheckMetadata(checkCode, amount, memo, issuerName, accountId, expiresAt, false)
        local added = exports.ox_inventory:AddItem(src, Config.Checks.ItemName, 1, meta)
        if not added then
            MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', { totalCost, accountId })
            MySQL.query.await("DELETE FROM bank_checks WHERE check_code = ?", { checkCode })
            return Notify(src, 'error', Locale('server.check_inventory_full'))
        end
    end

    Notify(src, 'success', Locale('server.check_created', checkCode))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:cashCheck', function(data)
    local src        = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if Config.Checks.UseInventoryItem then
        return Notify(src, 'error',
            Locale('server.use_physical_check') or
            'Debes presentar el cheque físico en el banco para cobrarlo')
    end

    local checkCode       = data.checkCode
    local targetAccountId = tonumber(data.accountId)

    if not checkCode or not targetAccountId then
        return Notify(src, 'error', Locale('server.invalid_data') or 'Datos inválidos')
    end

    CashCheckLogic(src, identifier, checkCode, targetAccountId, false)
end)

function CashCheckLogic(src, identifier, checkCode, targetAccountId, isFakeAttempt)
    local check = MySQL.single.await([[
        SELECT * FROM bank_checks WHERE check_code = ? AND status = 'active'
    ]], { checkCode:upper() })

    if not check then
        return Notify(src, 'error',
            Locale('server.check_not_found') or 'Cheque no encontrado o ya utilizado')
    end

    local expiry = MySQL.scalar.await(
        "SELECT UNIX_TIMESTAMP(expires_at) FROM bank_checks WHERE id = ?", { check.id })
    if tonumber(expiry) and os.time() > tonumber(expiry) then
        MySQL.query.await("UPDATE bank_checks SET status = 'expired' WHERE id = ?", { check.id })
        MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            { tonumber(check.amount), check.from_account_id })
        return Notify(src, 'error',
            Locale('server.check_expired') or 'Este cheque ha expirado')
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, targetAccountId, identifier, identifier })

    if not account then
        return Notify(src, 'error',
            Locale('server.no_permission_origin') or 'No tienes permiso sobre esta cuenta')
    end

    local amount = tonumber(check.amount)

    MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
        { amount, targetAccountId })

    MySQL.query.await([[
        UPDATE bank_checks
        SET status = 'cashed', cashed_by = ?, cashed_account_id = ?, cashed_at = NOW()
        WHERE id = ?
    ]], { identifier, targetAccountId, check.id })

    MySQL.insert.await([[
        INSERT INTO bank_transactions (account_id, type, amount, description)
        VALUES (?, 'check_cashed', ?, ?)
    ]], { targetAccountId, amount, 'Cheque cobrado: ' .. checkCode })

    Notify(src, 'success',
        Locale('server.check_cashed', amount) or '✅ Cheque cobrado: $' .. amount)
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    local issuerData = GetPlayerFromIdentifier(check.issuer)
    if issuerData and issuerData.source then
        Notify(issuerData.source, 'info',
            Locale('server.check_was_cashed', checkCode) or
            '📄 Tu cheque ' .. checkCode .. ' fue cobrado')
        TriggerClientEvent('muhaddil_bank:refreshData', issuerData.source)
    end
end

RegisterNetEvent('muhaddil_bank:cashCheckItem', function(data)
    local src        = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.Checks.UseInventoryItem then
        return Notify(src, 'error', 'Esta función requiere UseInventoryItem = true')
    end

    local slot            = tonumber(data.slot)
    local targetAccountId = tonumber(data.accountId)

    if not slot or not targetAccountId then
        return Notify(src, 'error', Locale('server.invalid_data') or 'Datos inválidos')
    end

    local inventory = exports.ox_inventory:GetInventory(src, false)
    if not inventory or not inventory.items then
        return Notify(src, 'error', 'No se pudo leer tu inventario')
    end

    local checkItem = nil
    for _, item in pairs(inventory.items) do
        if item and item.slot == slot and item.name == Config.Checks.ItemName then
            checkItem = item
            break
        end
    end

    if not checkItem or not checkItem.metadata then
        return Notify(src, 'error',
            Locale('server.check_not_found') or 'Cheque no encontrado en tu inventario')
    end

    local meta      = checkItem.metadata
    local checkCode = meta.check_code

    if not checkCode then
        return Notify(src, 'error', 'Cheque inválido o corrupto')
    end

    if meta.is_fake then
        exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, slot)

        Notify(src, 'error',
            Locale('server.check_fake_detected'))

        TriggerEvent('muhaddil_bank:fakeCheckDetected', {
            src        = src,
            identifier = identifier,
            checkCode  = checkCode,
            amount     = meta.amount,
        })

        -- print(string.format(
        --     '^1[Bank] CHEQUE FALSO detectado! Jugador: %s | Código: %s | Monto: $%s^7',
        --     GetPlayerName(src), checkCode, meta.amount
        -- ))
        return
    end

    local dbCheck = MySQL.single.await([[
        SELECT * FROM bank_checks WHERE check_code = ? AND status = 'active'
    ]], { checkCode })

    if not dbCheck then
        exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, slot)
        Notify(src, 'error',
            Locale('server.check_tampered') or
            '🚨 Cheque inválido. Ha sido confiscado.')
        TriggerEvent('muhaddil_bank:fakeCheckDetected', {
            src        = src,
            identifier = identifier,
            checkCode  = checkCode,
            amount     = meta.amount,
        })
        return
    end

    if tonumber(meta.amount) ~= tonumber(dbCheck.amount) then
        exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, slot)
        Notify(src, 'error',
            Locale('server.check_tampered') or
            '🚨 El monto del cheque ha sido alterado. Confiscado.')
        TriggerEvent('muhaddil_bank:fakeCheckDetected', {
            src        = src,
            identifier = identifier,
            checkCode  = checkCode,
            amount     = meta.amount,
        })
        return
    end

    local removed = exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, slot)
    if not removed then
        return Notify(src, 'error', 'No se pudo retirar el cheque del inventario')
    end

    CashCheckLogic(src, identifier, checkCode, targetAccountId, false)
end)

RegisterNetEvent('muhaddil_bank:cancelCheck', function(data)
    local src        = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local checkId = tonumber(data.checkId)
    if not checkId then return end

    local check = MySQL.single.await([[
        SELECT * FROM bank_checks WHERE id = ? AND issuer = ? AND status = 'active'
    ]], { checkId, identifier })

    if not check then
        return Notify(src, 'error',
            Locale('server.check_not_found') or 'Cheque no encontrado o no puedes cancelarlo')
    end

    local amount = tonumber(check.amount)

    MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
        { amount, check.from_account_id })

    MySQL.query.await("UPDATE bank_checks SET status = 'cancelled' WHERE id = ?", { checkId })

    MySQL.insert.await([[
        INSERT INTO bank_transactions (account_id, type, amount, description)
        VALUES (?, 'check_cancelled', ?, ?)
    ]], {
        check.from_account_id,
        amount,
        Locale('server.check_cancelled', amount) or
        'Cheque cancelado y reembolsado: ' .. check.check_code
    })

    if Config.Checks.UseInventoryItem then
        local slot = data.slot
        if slot then
            exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, slot)
        else
            local inventory = exports.ox_inventory:GetInventory(src, false)
            if inventory and inventory.items then
                for _, item in pairs(inventory.items) do
                    if item and item.name == Config.Checks.ItemName
                        and item.metadata
                        and item.metadata.check_code == check.check_code then
                        exports.ox_inventory:RemoveItem(src, Config.Checks.ItemName, 1, nil, item.slot)
                        break
                    end
                end
            end
        end
    end

    Notify(src, 'success',
        Locale('server.check_cancelled', amount) or
        '✅ Cheque cancelado. $' .. amount .. ' reembolsado')
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:forgeCheck', function(data)
    local src        = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.Checks.UseInventoryItem then
        return Notify(src, 'error', 'La falsificación requiere el sistema de items físicos')
    end

    if not Config.Checks.AllowForging then
        return Notify(src, 'error', 'La falsificación de cheques no está habilitada')
    end

    local checkCode  = data.checkCode
    local amount     = tonumber(data.amount)
    local memo       = data.memo or ''
    local issuerName = data.issuerName or 'Desconocido'
    local expiresAt  = data.expiresAt

    if not checkCode or not amount or not expiresAt then
        return Notify(src, 'error', Locale('server.check_forge_no_data'))
    end

    if Config.Checks.ForgeMaterials and #Config.Checks.ForgeMaterials > 0 then
        local hasMaterials = true
        for _, mat in ipairs(Config.Checks.ForgeMaterials) do
            local qty = exports.ox_inventory:GetItemCount(src, mat.item)
            if qty < mat.count then
                hasMaterials = false
                break
            end
        end

        if not hasMaterials then
            return Notify(src, 'error', Locale('server.check_forge_no_materials'))
        end

        for _, mat in ipairs(Config.Checks.ForgeMaterials) do
            exports.ox_inventory:RemoveItem(src, mat.item, mat.count)
        end
    end

    local successChance = Config.Checks.ForgeSuccessChance or 70
    local roll = math.random(1, 100)

    if roll > successChance then
        Notify(src, 'error',
            Locale('server.check_forge_failed'))

        print(Locale('server.check_forge_failed_print',
            GetPlayerName(src), checkCode, amount
        ))
        return
    end

    local fakeMeta       = BuildCheckMetadata(
        checkCode, amount, memo, issuerName, 0, expiresAt, true
    )
    fakeMeta.label       = Locale('server.check_item_title', checkCode, amount)
    fakeMeta.description = Locale('server.check_item_description', issuerName, amount, memo, expiresAt)

    local added          = exports.ox_inventory:AddItem(src, Config.Checks.ItemName, 1, fakeMeta)
    if not added then
        return Notify(src, 'error',
            Locale('server.check_inventory_full') or
            'No tienes espacio en el inventario para el cheque falsificado')
    end

    Notify(src, 'success',
        Locale('server.check_forged'))

    print(Locale('server.check_forged_print', GetPlayerName(src), checkCode, amount))
end)

lib.callback.register('muhaddil_bank:inspectCheck', function(src, slot)
    if not Config.Checks.UseInventoryItem then return nil end

    local inventory = exports.ox_inventory:GetInventory(src, false)
    if not inventory or not inventory.items then return nil end

    for _, item in pairs(inventory.items) do
        if item and item.slot == slot and item.name == Config.Checks.ItemName then
            local meta = item.metadata or {}
            return {
                check_code  = meta.check_code,
                amount      = meta.amount,
                memo        = meta.memo,
                issuer_name = meta.issuer_name,
                expires_at  = meta.expires_at,
                slot        = slot,
            }
        end
    end

    return nil
end)

lib.callback.register('muhaddil_bank:getInventoryChecks', function(src)
    if not Config.Checks.UseInventoryItem then return {} end

    local inventory = exports.ox_inventory:GetInventory(src, false)
    if not inventory or not inventory.items then return {} end

    local checks = {}
    for _, item in pairs(inventory.items) do
        if item and item.name == Config.Checks.ItemName and item.metadata then
            local meta = item.metadata
            if meta.check_code then
                table.insert(checks, {
                    slot        = item.slot,
                    check_code  = meta.check_code,
                    amount      = meta.amount,
                    memo        = meta.memo,
                    issuer_name = meta.issuer_name,
                    expires_at  = meta.expires_at,
                    is_fake     = meta.is_fake or false,
                })
            end
        end
    end

    return checks
end)

Citizen.CreateThread(function()
    Wait(15000)

    lib.cron.new('0 * * * *', function()
        local expired = MySQL.query.await([[
            SELECT * FROM bank_checks
            WHERE status = 'active' AND expires_at < NOW()
        ]])

        if not expired or #expired == 0 then return end

        for _, check in ipairs(expired) do
            local amount = tonumber(check.amount)

            MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
                { amount, check.from_account_id })

            MySQL.query.await("UPDATE bank_checks SET status = 'expired' WHERE id = ?", { check.id })

            MySQL.insert.await([[
                INSERT INTO bank_transactions (account_id, type, amount, description)
                VALUES (?, 'check_expired', ?, ?)
            ]], {
                check.from_account_id,
                amount,
                Locale('server.check_expirated_transaction', check.check_code, amount)
            })

            local issuerData = GetPlayerFromIdentifier(check.issuer)
            if issuerData and issuerData.source then
                Notify(issuerData.source, 'warning',
                    Locale('server.check_expired_refund', check.check_code, amount) or
                    '⏰ Tu cheque ' .. check.check_code .. ' ha expirado. $' .. amount .. ' reembolsado')
                TriggerClientEvent('muhaddil_bank:refreshData', issuerData.source)

                if Config.Checks.UseInventoryItem then
                    local inv = exports.ox_inventory:GetInventory(issuerData.source, false)
                    if inv and inv.items then
                        for _, item in pairs(inv.items) do
                            if item and item.name == Config.Checks.ItemName
                                and item.metadata
                                and item.metadata.check_code == check.check_code then
                                exports.ox_inventory:RemoveItem(
                                    issuerData.source,
                                    Config.Checks.ItemName,
                                    1, nil, item.slot
                                )
                                Notify(issuerData.source, 'warning',
                                    Locale('server.check_expired_destroyed', check.check_code))
                                break
                            end
                        end
                    end
                end
            end
        end

        if #expired > 0 then
            print(Locale('server.checks_expired_and_refunded', #expired))
        end
    end, { debug = false })
end)

print('^2[Bank System] Checks module (physical items) loaded^7')
