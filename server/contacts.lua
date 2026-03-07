lib.callback.register('muhaddil_bank:getContacts', function(source)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return {} end

    local contacts = MySQL.query.await([[
        SELECT bc.*, ba.account_name, ba.owner as account_owner
        FROM bank_contacts bc
        LEFT JOIN bank_accounts ba ON bc.contact_account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.contact_name ASC
    ]], { identifier })

    return contacts or {}
end)

RegisterNetEvent('muhaddil_bank:addContact', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.Contacts.Enabled then
        return Notify(src, 'error', Locale('server.contacts_disabled'))
    end

    local contactName = data.contactName
    local contactAccountId = tonumber(data.contactAccountId)
    local notes = data.notes or ''

    if not contactName or contactName == '' then
        return Notify(src, 'error', Locale('server.invalid_name'))
    end

    if not contactAccountId then
        return Notify(src, 'error', Locale('server.invalid_account'))
    end

    local targetAccount = MySQL.single.await('SELECT id FROM bank_accounts WHERE id = ?', { contactAccountId })
    if not targetAccount then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_contacts WHERE owner = ?', { identifier })
    if count >= Config.Contacts.MaxContacts then
        return Notify(src, 'error', Locale('server.max_contacts_reached'))
    end

    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_contacts WHERE owner = ? AND contact_account_id = ?',
        { identifier, contactAccountId }
    )
    if exists > 0 then
        return Notify(src, 'error', Locale('server.contact_already_exists'))
    end

    MySQL.insert.await([[
        INSERT INTO bank_contacts (owner, contact_name, contact_account_id, notes)
        VALUES (?, ?, ?, ?)
    ]], { identifier, contactName, contactAccountId, notes })

    Notify(src, 'success', Locale('server.contact_added'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:updateContact', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local contactId = tonumber(data.contactId)
    local contactName = data.contactName
    local notes = data.notes or ''

    if not contactId or not contactName or contactName == '' then
        return Notify(src, 'error', Locale('server.invalid_data'))
    end

    local contact = MySQL.single.await(
        'SELECT * FROM bank_contacts WHERE id = ? AND owner = ?',
        { contactId, identifier }
    )
    if not contact then
        return Notify(src, 'error', Locale('server.contact_not_found'))
    end

    MySQL.query.await(
        'UPDATE bank_contacts SET contact_name = ?, notes = ? WHERE id = ?',
        { contactName, notes, contactId }
    )

    Notify(src, 'success', Locale('server.contact_updated'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:removeContact', function(contactId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    contactId = tonumber(contactId)
    if not contactId then return end

    local contact = MySQL.single.await(
        'SELECT * FROM bank_contacts WHERE id = ? AND owner = ?',
        { contactId, identifier }
    )
    if not contact then
        return Notify(src, 'error', Locale('server.contact_not_found'))
    end

    MySQL.query.await('DELETE FROM bank_contacts WHERE id = ?', { contactId })

    Notify(src, 'success', Locale('server.contact_removed'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

print('^2[Bank System] Contacts system loaded^7')
