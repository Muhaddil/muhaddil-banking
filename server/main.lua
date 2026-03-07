local ESX = nil
local QBCore = nil
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

lib.callback.register('muhaddil_bank:getAvailableBanks', function(source)
    local available = {}

    for _, bankLocation in ipairs(Config.BankLocations) do
        if bankLocation.purchasable then
            local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankLocation.id })

            table.insert(available, {
                id = bankLocation.id,
                name = bankLocation.name,
                coords = bankLocation.coords,
                isOwned = owner ~= nil,
                owner = owner,
                price = Config.BankOwnership.PurchasePrice
            })
        end
    end

    return available
end)

lib.callback.register('muhaddil_bank:getData', function(source, bankId)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then return nil end

    local currentBankInfo = nil
    if bankId and type(bankId) == 'string' then
        local bankLocation = nil
        for _, bank in ipairs(Config.BankLocations) do
            if bank.id == bankId then
                bankLocation = bank
                break
            end
        end

        if bankLocation then
            local ownedBank = MySQL.single.await('SELECT commission_rate FROM bank_ownership WHERE bank_id = ?',
                { bankId })
            local commissionRate = 0
            if Config.BankOwnership.Enabled and ownedBank and ownedBank.commission_rate then
                commissionRate = tonumber(ownedBank.commission_rate) or 0
            end

            local isOwned = ownedBank ~= nil
            local bankType = bankLocation.bankType or (isOwned and 'private' or 'state')
            currentBankInfo = {
                id = bankLocation.id,
                name = bankLocation.name,
                bankType = bankType,
                commissionRate = commissionRate,
                isOwned = isOwned
            }
        end
    end

    local ownedAccounts = MySQL.query.await('SELECT * FROM bank_accounts WHERE owner = ?', { identifier })

    local sharedAccounts = MySQL.query.await([[
        SELECT ba.* FROM bank_accounts ba
        INNER JOIN bank_shared_access bsa ON ba.id = bsa.account_id
        WHERE bsa.user_identifier = ?
    ]], { identifier })

    local allAccounts = {}
    for _, acc in ipairs(ownedAccounts or {}) do
        acc.isOwner = true
        table.insert(allAccounts, acc)
    end
    for _, acc in ipairs(sharedAccounts or {}) do
        acc.isOwner = false
        table.insert(allAccounts, acc)
    end

    local transactions = {}
    for _, acc in ipairs(allAccounts) do
        local accTransactions = MySQL.query.await([[
            SELECT * FROM bank_transactions
            WHERE account_id = ?
            ORDER BY created_at DESC
            LIMIT 50
        ]], { acc.id })

        for _, trans in ipairs(accTransactions or {}) do
            trans.account_name = acc.account_name
            table.insert(transactions, trans)
        end
    end

    table.sort(transactions, function(a, b)
        return a.created_at > b.created_at
    end)

    local loans = MySQL.query.await([[
        SELECT * FROM bank_loans
        WHERE user_identifier = ? AND (status = 'active' OR status = 'paid')
        ORDER BY created_at DESC
    ]], { identifier })

    local loanPayments = {}
    for _, loan in ipairs(loans or {}) do
        local payments = MySQL.query.await([[
            SELECT * FROM bank_loan_payments
            WHERE loan_id = ?
            ORDER BY created_at DESC
        ]], { loan.id })
        loanPayments[tostring(loan.id)] = payments or {}
    end

    local ownedBanks = MySQL.query.await([[
        SELECT * FROM bank_ownership
        WHERE owner = ?
    ]], { identifier })

    local availableBanks = {}
    for _, bankLocation in ipairs(Config.BankLocations) do
        if bankLocation.purchasable then
            local owner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankLocation.id })

            if not owner then
                table.insert(availableBanks, {
                    id = bankLocation.id,
                    name = bankLocation.name,
                    price = Config.BankOwnership.PurchasePrice
                })
            end
        end
    end

    local savings = MySQL.query.await([[
        SELECT bsa.*, ba.account_name
        FROM bank_savings_accounts bsa
        INNER JOIN bank_accounts ba ON bsa.account_id = ba.id
        WHERE bsa.owner = ?
        ORDER BY bsa.created_at DESC
    ]], { identifier })

    local contacts = MySQL.query.await([[
        SELECT bc.*, ba.account_name as contact_account_name
        FROM bank_contacts bc
        LEFT JOIN bank_accounts ba ON bc.contact_account_id = ba.id
        WHERE bc.owner = ?
        ORDER BY bc.contact_name ASC
    ]], { identifier })

    local incomingRequests = MySQL.query.await([[
        SELECT btr.*, ba.account_name as requester_account_name
        FROM bank_transfer_requests btr
        LEFT JOIN bank_accounts ba ON btr.requester_account_id = ba.id
        WHERE btr.target_identifier = ? AND btr.status = 'pending'
        ORDER BY btr.created_at DESC
    ]], { identifier })

    local outgoingRequests = MySQL.query.await([[
        SELECT btr.*, ba.account_name as requester_account_name
        FROM bank_transfer_requests btr
        LEFT JOIN bank_accounts ba ON btr.requester_account_id = ba.id
        WHERE btr.requester_identifier = ?
        ORDER BY btr.created_at DESC
        LIMIT 50
    ]], { identifier })

    local scheduledTransfers = MySQL.query.await([[
        SELECT bst.*,
            ba_from.account_name as from_account_name,
            ba_to.account_name as to_account_name
        FROM bank_scheduled_transfers bst
        LEFT JOIN bank_accounts ba_from ON bst.from_account_id = ba_from.id
        LEFT JOIN bank_accounts ba_to ON bst.to_account_id = ba_to.id
        WHERE bst.owner = ?
        ORDER BY bst.created_at DESC
    ]], { identifier })

    local creditScore = GetPlayerCreditScore(identifier)

    local cash = GetPlayerMoney(source)

    return {
        accounts = allAccounts,
        maxAccounts = Config.Accounts.MaxPerPlayer,
        transactions = transactions,
        loans = loans or {},
        loanPayments = loanPayments,
        loanConfig = {
            types = Config.Loans.Types,
            maxActiveLoans = Config.Loans.MaxActiveLoans,
            earlyRepaymentDiscount = Config.Loans.EarlyRepaymentDiscount,
            creditScoreEnabled = Config.Loans.CreditScore and Config.Loans.CreditScore.Enabled or false,
        },
        creditScore = creditScore,
        ownedBanks = ownedBanks or {},
        availableBanks = availableBanks,
        savings = savings or {},
        savingsConfig = {
            enabled = Config.Savings.Enabled,
            maxPerAccount = Config.Savings.MaxPerAccount,
            interestRate = Config.Savings.InterestRate,
            minDeposit = Config.Savings.MinDeposit,
            maxGoalAmount = Config.Savings.MaxGoalAmount,
        },
        contacts = contacts or {},
        contactsConfig = {
            enabled = Config.Contacts.Enabled,
            maxContacts = Config.Contacts.MaxContacts,
        },
        transferRequests = {
            incoming = incomingRequests or {},
            outgoing = outgoingRequests or {},
        },
        transferRequestsConfig = {
            enabled = Config.TransferRequests.Enabled,
            maxPending = Config.TransferRequests.MaxPendingRequests,
        },
        scheduledTransfers = scheduledTransfers or {},
        scheduledTransfersConfig = {
            enabled = Config.ScheduledTransfers.Enabled,
            maxPerPlayer = Config.ScheduledTransfers.MaxPerPlayer,
            minAmount = Config.ScheduledTransfers.MinAmount,
            frequencies = Config.ScheduledTransfers.Frequencies,
        },
        cash = cash,
        playerIdentifier = identifier,
        currentBankInfo = currentBankInfo
    }
end)

RegisterNetEvent('muhaddil_bank:createAccount', function(data)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local accountName = data.accountName or data.name
    if not accountName or accountName == "" then
        return Notify(src, 'error', Locale('server.invalid_account_name'))
    end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM bank_accounts WHERE owner = ?', { identifier })
    if count >= Config.Accounts.MaxPerPlayer then
        return Notify(src, 'error', Locale('server.max_accounts_reached', Config.Accounts.MaxPerPlayer))
    end

    local isFirstAccount = (count == 0)
    local initialBalance = Config.Accounts.InitialBalance

    if isFirstAccount then
        local frameworkMoney = GetPlayerBankMoney(src)
        if frameworkMoney > 0 then
            initialBalance = frameworkMoney
        end
    end

    local accountId = MySQL.insert.await('INSERT INTO bank_accounts (owner, account_name, balance) VALUES (?, ?, ?)', {
        identifier, accountName, initialBalance
    })

    if isFirstAccount and initialBalance > Config.Accounts.InitialBalance then
        MySQL.insert.await([[
            INSERT INTO bank_transactions (account_id, type, amount, description)
            VALUES (?, ?, ?, ?)
        ]], { accountId, 'import', initialBalance, 'Importación inicial' })
    end

    Notify(src, 'success', Locale('server.account_created', accountName))
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:addSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.only_owner_can_add'))
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', Locale('server.player_not_found'))
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', Locale('server.cannot_add_yourself'))
    end

    local sharedCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ?', { accountId })
    if sharedCount >= Config.Accounts.MaxSharedUsers then
        return Notify(src, 'error', Locale('server.max_shared_users'))
    end

    local exists = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
            accountId, targetIdentifier
        })
    if exists > 0 then
        return Notify(src, 'error', Locale('server.user_already_has_access'))
    end

    MySQL.insert.await('INSERT INTO bank_shared_access (account_id, user_identifier) VALUES (?, ?)', {
        accountId, targetIdentifier
    })

    Notify(src, 'success', Locale('server.user_added'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    if GetPlayerName(targetId) then
        Notify(targetId, 'info', Locale('server.added_to_shared_account'))
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

RegisterNetEvent('muhaddil_bank:removeSharedUser', function(accountId, targetId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.only_owner_can_remove'))
    end

    local targetIdentifier = GetPlayerIdentifier(targetId)
    if not targetIdentifier then
        return Notify(src, 'error', Locale('server.player_not_found'))
    end

    if targetIdentifier == identifier then
        return Notify(src, 'error', Locale('server.cannot_remove_yourself'))
    end

    MySQL.query.await('DELETE FROM bank_shared_access WHERE account_id = ? AND user_identifier = ?', {
        accountId, targetIdentifier
    })

    Notify(src, 'success', Locale('server.user_removed'))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    if GetPlayerName(targetId) then
        Notify(targetId, 'warning', Locale('server.removed_from_shared_account'))
        TriggerClientEvent('muhaddil_bank:refreshData', targetId)
    end
end)

RegisterNetEvent('muhaddil_bank:deleteAccount', function(accountId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    local owner = MySQL.scalar.await('SELECT owner FROM bank_accounts WHERE id = ?', { accountId })
    if owner ~= identifier then
        return Notify(src, 'error', Locale('server.no_permission_delete'))
    end

    MySQL.query.await('DELETE FROM bank_accounts WHERE id = ?', { accountId })
    Notify(src, 'success', Locale('server.account_deleted'))
    TriggerEvent('muhaddil_bank:afterDeleteAccount', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

RegisterNetEvent('muhaddil_bank:transfer', function(data)
    local src = source

    print('Triggered transfer event')

    local success = exports['muhaddil-banking']:Transfer(
        src,
        data.fromAccountId,
        data.toAccountId,
        data.amount,
        data.bankLocation
    )

    if success then
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    end
end)

RegisterNetEvent('muhaddil_bank:deposit', function(accountId, amount, bankLocation)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if amount <= 0 then return Notify(src, 'error', Locale('server.invalid_amount')) end

    if RemovePlayerMoney(src, amount) then
        MySQL.query.await('UPDATE bank_accounts SET balance = balance + ? WHERE id = ?', { amount, accountId })
        MySQL.insert.await(
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            {
                accountId, 'deposit', amount, Locale('server.efectiveDeposit'), bankLocation
            })

        if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnDeposit and bankLocation then
            ApplyBankCommission(bankLocation, amount)
        end

        Notify(src, 'success', Locale('server.deposit_completed'))
        TriggerEvent('muhaddil_bank:afterDeposit', src)
        TriggerClientEvent('muhaddil_bank:refreshData', src)
    else
        Notify(src, 'error', Locale('server.insufficient_cash'))
    end
end)

RegisterNetEvent('muhaddil_bank:withdraw', function(accountId, amount, bankLocation)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    local balance = MySQL.scalar.await('SELECT balance FROM bank_accounts WHERE id = ?', { accountId })
    balance = tonumber(balance)

    if not balance then
        return Notify(src, 'error', Locale('server.account_not_found'))
    end

    if balance < amount then
        return Notify(src, 'error', Locale('server.insufficient_balance'))
    end

    MySQL.query.await('UPDATE bank_accounts SET balance = balance - ? WHERE id = ?', { amount, accountId })
    AddPlayerMoney(src, amount)

    MySQL.insert.await(
        'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)', {
            accountId, 'withdrawal', -amount, Locale('server.efectiveWithdraw'), bankLocation
        })

    if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnWithdraw and bankLocation then
        ApplyBankCommission(bankLocation, amount)
    end

    Notify(src, 'success', Locale('server.withdraw_completed'))
    TriggerEvent('muhaddil_bank:afterWithdraw', src)
    TriggerClientEvent('muhaddil_bank:refreshData', src)
end)

function requestLoan(src, data)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return false, 'No se pudo obtener el identificador del jugador.' end

    local amount = tonumber(data.amount)
    local installments = tonumber(data.installments)
    local loanType = data.loanType or 'personal'

    local typeConfig = Config.Loans.Types and Config.Loans.Types[loanType]
    if not typeConfig then
        loanType = 'personal'
        typeConfig = Config.Loans.Types and Config.Loans.Types['personal'] or {
            MaxAmount = Config.Loans.MaxAmount,
            InterestRate = Config.Loans.InterestRate,
            MaxInstallments = Config.Loans.MaxInstallments
        }
    end

    local interestRate = tonumber(data.interestRate) or (typeConfig.InterestRate * 100)

    if not amount or amount <= 0 or not installments or installments <= 0 then
        return false, 'Datos inválidos'
    end

    local minAmount = Config.Loans.MinAmount
    local maxAmount = typeConfig.MaxAmount or Config.Loans.MaxAmount
    local maxInstallments = typeConfig.MaxInstallments or Config.Loans.MaxInstallments

    if amount < minAmount or amount > maxAmount then
        return false, Notify(src, 'error', Locale('server.invalid_amount'))
    end

    if installments > maxInstallments then
        installments = maxInstallments
    end

    local maxActiveLoans = Config.Loans.MaxActiveLoans or 1
    local activeLoans = MySQL.scalar.await(
        'SELECT COUNT(*) FROM bank_loans WHERE user_identifier = ? AND status = "active"', { identifier }
    )
    if activeLoans >= maxActiveLoans then
        return false, Locale('server.max_loans_reached')
    end

    local creditScore = GetPlayerCreditScore(identifier)

    local totalWithInterest = amount * (1 + (interestRate / 100))

    local loanId = MySQL.insert.await([[
        INSERT INTO bank_loans (user_identifier, amount, remaining, interest_rate, installments, loan_type, credit_score_snapshot)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { identifier, amount, totalWithInterest, interestRate, installments, loanType, creditScore })

    AddPlayerMoney(src, amount)
    Notify(src, 'success', Locale('server.loan_approved') .. ': $' .. amount)
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    return true
end

RegisterNetEvent('muhaddil_bank:requestLoan', function(data)
    requestLoan(source, data)
end)

function payLoan(src, loanId, amount, isFromPhone)
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return false, 'No se pudo obtener el identificador del jugador.' end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return false, Locale('server.invalid_amount')
    end

    local loan = MySQL.single.await(
        'SELECT * FROM bank_loans WHERE id = ? AND user_identifier = ? AND status = ?',
        { loanId, identifier, 'active' }
    )

    if not loan then
        return false, Locale('server.loan_not_found')
    end

    local remaining = tonumber(loan.remaining)
    if not remaining then
        return false, Locale('server.loan_not_found')
    end

    local discount = 0
    if amount >= remaining and Config.Loans.EarlyRepaymentDiscount then
        local paidInstallments = tonumber(loan.paid_installments) or 0
        if paidInstallments < (tonumber(loan.installments) - 1) then
            discount = math.floor(remaining * Config.Loans.EarlyRepaymentDiscount)
            remaining = remaining - discount
        end
    end

    if amount > remaining then
        amount = remaining
    end

    local paymentSuccess = false
    if isFromPhone then
        paymentSuccess = RemovePlayerBankMoney(src, amount)
    else
        paymentSuccess = RemovePlayerMoney(src, amount)
    end

    if paymentSuccess then
        local newRemaining = remaining - amount
        local status = (newRemaining <= 0) and 'paid' or 'active'
        local newPaidInstallments = (tonumber(loan.paid_installments) or 0) + 1

        MySQL.query.await(
            'UPDATE bank_loans SET remaining = ?, status = ?, paid_installments = ? WHERE id = ?',
            { math.max(0, newRemaining), status, newPaidInstallments, loanId }
        )

        MySQL.insert.await([[
            INSERT INTO bank_loan_payments (loan_id, amount, payment_type)
            VALUES (?, ?, 'manual')
        ]], { loanId, amount })

        if discount > 0 then
            Notify(src, 'info', Locale('server.early_repayment_discount', discount))
        end

        Notify(src, 'success', Locale('server.payment_completed', math.max(0, newRemaining)))
        TriggerClientEvent('muhaddil_bank:refreshData', src)
        return true, math.max(0, newRemaining)
    else
        return false, Locale('server.insufficient_money')
    end
end

RegisterNetEvent('muhaddil_bank:payLoan', function(loanId, amount, isFromPhone)
    payLoan(source, loanId, amount, isFromPhone)
end)

RegisterNetEvent('muhaddil_bank:purchaseBank', function(bankId)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    if not Config.BankOwnership.Enabled then
        return Notify(src, 'error', Locale('server.bank_ownership_disabled'))
    end

    local bankExists = false
    local bankName = nil
    for _, bank in ipairs(Config.BankLocations) do
        if bank.id == bankId and bank.purchasable then
            bankExists = true
            bankName = bank.name
            break
        end
    end

    if not bankExists then
        return Notify(src, 'error', Locale('server.bank_not_purchasable'))
    end

    local currentOwner = MySQL.scalar.await('SELECT owner FROM bank_ownership WHERE bank_id = ?', { bankId })
    if currentOwner then
        return Notify(src, 'error', Locale('server.bank_already_owned'))
    end

    local playerBankCount = MySQL.scalar.await('SELECT COUNT(*) FROM bank_ownership WHERE owner = ?', { identifier })
    if playerBankCount >= Config.BankOwnership.MaxBanksPerPlayer then
        return Notify(src, 'error',
            Locale('server.max_banks_reached', Config.BankOwnership.MaxBanksPerPlayer))
    end

    if not RemovePlayerMoney(src, Config.BankOwnership.PurchasePrice) then
        return Notify(src, 'error', Locale('server.insufficient_money_bank', Config.BankOwnership.PurchasePrice))
    end

    MySQL.insert.await('INSERT INTO bank_ownership (bank_id, owner, bank_name, commission_rate) VALUES (?, ?, ?, ?)', {
        bankId, identifier, bankName, Config.BankOwnership.DefaultCommissionRate
    })

    Notify(src, 'success', Locale('server.bank_purchased', bankName))
    TriggerClientEvent('muhaddil_bank:refreshData', src)

    -- print(string.format("^2[Bank System] %s compró el banco %s (%s)^7", GetPlayerName(src), bankName, bankId))
end)

RegisterCommand(Config.OpenCommand, function(source, args, rawCommand)
    TriggerClientEvent('muhaddil_bank:openBank', source)
end, false)

local function processLoanPayments()
    print('^3[Bank System] Running automatic loan payments...^7')

    local activeLoans = MySQL.query.await([[
        SELECT * FROM bank_loans
        WHERE status = 'active'
    ]])

    if not activeLoans or #activeLoans == 0 then
        print('^3[Bank System] No active loans found.^7')
        return
    end

    local paid, failed, completed = 0, 0, 0

    for _, loan in ipairs(activeLoans) do
        local installmentAmount = math.ceil(loan.amount / loan.installments)
        local remaining         = tonumber(loan.remaining) or 0

        if installmentAmount > remaining then
            installmentAmount = math.ceil(remaining)
        end

        local account = MySQL.single.await([[
            SELECT * FROM bank_accounts
            WHERE owner = ?
            ORDER BY balance DESC
            LIMIT 1
        ]], { loan.user_identifier })

        if account and tonumber(account.balance) >= installmentAmount then
            MySQL.query.await(
                'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
                { installmentAmount, account.id }
            )

            local newRemaining = remaining - installmentAmount
            local status       = (newRemaining <= 0) and 'paid' or 'active'

            MySQL.query.await(
                'UPDATE bank_loans SET remaining = ?, status = ? WHERE id = ?',
                { newRemaining, status, loan.id }
            )

            MySQL.insert.await([[
                INSERT INTO bank_transactions (account_id, type, amount, description)
                VALUES (?, 'loan_payment', ?, ?)
            ]], {
                account.id,
                -installmentAmount,
                'Pago automático de préstamo #' .. loan.id
            })

            local playerData = GetPlayerFromIdentifier(loan.user_identifier)
            local playerId   = playerData and playerData.source or nil

            if playerId then
                if status == 'paid' then
                    Notify(playerId, 'success',
                        Locale('server.loan_paid_off', loan.id) or
                        '✅ Tu préstamo #' .. loan.id .. ' ha sido completamente pagado.')
                    completed = completed + 1
                else
                    Notify(playerId, 'info',
                        Locale('server.auto_payment_done', installmentAmount, newRemaining) or
                        '💳 Pago automático: $' .. installmentAmount .. ' descontado. Restante: $' .. newRemaining)
                end
                TriggerClientEvent('muhaddil_bank:refreshData', playerId)
            end

            paid = paid + 1
        else
            if Config.Loans.AutoPayment.PenaltyOnMiss and Config.Loans.AutoPayment.PenaltyRate then
                local penalty = math.ceil(remaining * (Config.Loans.AutoPayment.PenaltyRate / 100))

                MySQL.query.await(
                    'UPDATE bank_loans SET remaining = remaining + ? WHERE id = ?',
                    { penalty, loan.id }
                )

                if account then
                    MySQL.insert.await([[
                        INSERT INTO bank_transactions (account_id, type, amount, description)
                        VALUES (?, 'loan_penalty', ?, ?)
                    ]], {
                        account.id,
                        penalty,
                        'Penalización por impago - Préstamo #' .. loan.id
                    })
                end

                local playerData = GetPlayerFromIdentifier(loan.user_identifier)
                local playerId   = playerData and playerData.source or nil

                if playerId then
                    Notify(playerId, 'error',
                        Locale('server.loan_payment_failed', loan.id, penalty) or
                        '⚠️ Sin fondos para pago automático del préstamo #' ..
                        loan.id .. '. Penalización aplicada: +$' .. penalty)
                    TriggerClientEvent('muhaddil_bank:refreshData', playerId)
                end
            end

            failed = failed + 1
        end
    end

    print(string.format(
        '^2[Bank System] Auto-payments done. Paid: %d | Completed: %d | Failed (no funds): %d^7',
        paid, completed, failed
    ))
end

if Config.Loans.AutoPayment.Enabled then
    Wait(10000)
    local cronExpr = buildCronExpression(Config.Loans.AutoPayment.IntervalHours)

    print(string.format(
        '^3[Bank System] Registering auto-loan cron with expression: "%s" (every %dh)^7',
        cronExpr, Config.Loans.AutoPayment.IntervalHours
    ))

    lib.cron.new(cronExpr, function(task, date)
        processLoanPayments()
    end, { debug = false })
end

exports('Transfer', function(source, fromAccountId, toAccountId, amount, bankLocation)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    if not identifier then return end

    fromAccountId = tonumber(fromAccountId)
    toAccountId   = tonumber(toAccountId)
    amount        = tonumber(amount)
    print(amount)
    local bankLocation = bankLocation

    if not fromAccountId or not toAccountId then
        return Notify(src, 'error', Locale('server.invalid_account'))
    end

    if not amount or amount <= 0 then
        return Notify(src, 'error', Locale('server.invalid_amount'))
    end

    local account = MySQL.single.await([[
        SELECT ba.*
        FROM bank_accounts ba
        LEFT JOIN bank_shared_access bsa
            ON ba.id = bsa.account_id AND bsa.user_identifier = ?
        WHERE ba.id = ? AND (ba.owner = ? OR bsa.user_identifier = ?)
    ]], { identifier, fromAccountId, identifier, identifier })

    if not account then
        return Notify(src, 'error', Locale('server.no_permission_origin'))
    end

    account.balance = tonumber(account.balance)
    if not account.balance or account.balance < amount then
        return Notify(src, 'error', Locale('server.insufficient_balance'))
    end

    local success = MySQL.transaction.await({
        {
            query = 'UPDATE bank_accounts SET balance = balance - ? WHERE id = ?',
            values = { amount, fromAccountId }
        },
        {
            query = 'UPDATE bank_accounts SET balance = balance + ? WHERE id = ?',
            values = { amount, toAccountId }
        },
        {
            query =
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            values = { fromAccountId, 'transfer_out', -amount, 'Transferencia a cuenta #' .. toAccountId, bankLocation }
        },
        {
            query =
            'INSERT INTO bank_transactions (account_id, type, amount, description, bank_location) VALUES (?, ?, ?, ?, ?)',
            values = { toAccountId, 'transfer_in', amount, 'Transferencia desde cuenta #' .. fromAccountId, bankLocation }
        }
    })

    if not success then
        return Notify(src, 'error', Locale('server.transfer_error'))
    end

    if Config.BankOwnership.Enabled and Config.BankOwnership.CommissionOnTransfer and bankLocation then
        ApplyBankCommission(bankLocation, amount)
    end

    Notify(src, 'success', Locale('server.transfer_completed'))
    TriggerEvent('muhaddil_bank:afterTransfer', src)

    return true
end)

exports('requestLoan', requestLoan)
exports('payLoan', payLoan)

print('^2[Bank System] Server initialized successfully^7')
