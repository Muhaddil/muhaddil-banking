Security = {}

-- ============================================================
-- RATE LIMITING
-- ============================================================
local rateLimits = {}

---@param src number Player server ID
---@param action string Action name (e.g., 'transfer', 'deposit')
---@param cooldown number Cooldown in seconds
---@return boolean allowed, number remainingSeconds
function Security.CheckRateLimit(src, action, cooldown)
    cooldown = cooldown or 2
    local key = src .. ':' .. action
    local now = os.time()

    if rateLimits[key] and (now - rateLimits[key]) < cooldown then
        return false, cooldown - (now - rateLimits[key])
    end

    rateLimits[key] = now
    return true, 0
end

-- Clean up rate limits periodically
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for key, timestamp in pairs(rateLimits) do
            if (now - timestamp) > 120 then
                rateLimits[key] = nil
            end
        end
    end
end)

-- ============================================================
-- INPUT VALIDATION
-- ============================================================

---@param value any The value to validate
---@param min number|nil Minimum value (inclusive)
---@param max number|nil Maximum value (inclusive)
---@return boolean valid, number|nil sanitizedValue
function Security.ValidateAmount(value, min, max)
    local num = tonumber(value)
    if not num then return false, nil end

    -- Reject NaN and Inf
    if num ~= num or num == math.huge or num == -math.huge then
        return false, nil
    end

    -- Round to 2 decimal places
    num = math.floor(num * 100 + 0.5) / 100

    if min and num < min then return false, nil end
    if max and num > max then return false, nil end

    return true, num
end

---@param value any The account ID to validate
---@return boolean valid, number|nil sanitizedId
function Security.ValidateAccountId(value)
    local num = tonumber(value)
    if not num or num <= 0 or num ~= math.floor(num) then
        return false, nil
    end
    return true, num
end

---@param value any The card ID to validate
---@return boolean valid, number|nil sanitizedId
function Security.ValidateCardId(value)
    return Security.ValidateAccountId(value)
end

---@param pin any The PIN to validate (must be 4-digit string)
---@return boolean valid, string|nil sanitizedPin
function Security.ValidatePin(pin)
    if type(pin) ~= 'string' then return false, nil end
    if #pin ~= 4 then return false, nil end
    if not tonumber(pin) then return false, nil end
    -- Reject all-same digits (0000, 1111, etc.) - optional but good practice
    if pin:sub(1,1):rep(4) == pin then return false, nil end
    return true, pin
end

---@param value any The player server ID
---@return boolean valid, number|nil sanitizedId
function Security.ValidatePlayerId(value)
    local num = tonumber(value)
    if not num or num <= 0 or num > 1000 or num ~= math.floor(num) then
        return false, nil
    end
    return true, num
end

---@param str any String to validate
---@param minLen number Minimum length
---@param maxLen number Maximum length
---@return boolean valid, string|nil sanitizedString
function Security.ValidateString(str, minLen, maxLen)
    if type(str) ~= 'string' then return false, nil end
    str = str:match('^%s*(.-)%s*$') -- trim
    if #str < (minLen or 1) then return false, nil end
    if maxLen and #str > maxLen then
        str = str:sub(1, maxLen)
    end
    return true, str
end

---@param value any The frequency string
---@return boolean valid
function Security.ValidateFrequency(value)
    local valid = { daily = true, weekly = true, biweekly = true, monthly = true }
    return valid[value] == true
end

---@param value any Integer to validate
---@param min number Minimum value
---@param max number Maximum value
---@return boolean valid, number|nil sanitizedValue
function Security.ValidateInteger(value, min, max)
    local num = tonumber(value)
    if not num then return false, nil end
    num = math.floor(num + 0.5)
    if min and num < min then return false, nil end
    if max and num > max then return false, nil end
    return true, num
end

-- ============================================================
-- SANITIZE & VALIDATE EVENT DATA
-- ============================================================

---@param data table The data table from NUI/client
---@return table sanitized The sanitized data table
function Security.SanitizeData(data)
    if type(data) ~= 'table' then return {} end
    local sanitized = {}
    for k, v in pairs(data) do
        if type(v) == 'string' then
            local trimmed = v:match('^%s*(.-)%s*$')
            if trimmed and #trimmed > 0 then
                sanitized[k] = trimmed:sub(1, 500)
            end
        elseif type(v) == 'number' then
            if v == v and v ~= math.huge and v ~= -math.huge then
                sanitized[k] = v
            end
        elseif type(v) == 'boolean' then
            sanitized[k] = v
        end
    end
    return sanitized
end

-- ============================================================
-- ABUSE DETECTION
-- ============================================================
local abuseTracker = {}
local ABUSE_THRESHOLD = 20
local ABUSE_WINDOW = 60

---@param src number Player server ID
---@param action string Action name
---@return boolean isAbusing
function Security.TrackAbuse(src, action)
    local key = src .. ':abuse:' .. action
    local now = os.time()

    if not abuseTracker[key] then
        abuseTracker[key] = { count = 1, firstSeen = now }
        return false
    end

    local entry = abuseTracker[key]

    if (now - entry.firstSeen) > ABUSE_WINDOW then
        entry.count = 1
        entry.firstSeen = now
        return false
    end

    entry.count = entry.count + 1

    if entry.count >= ABUSE_THRESHOLD then
        print(('[Bank Security] ⚠ Player %d may be abusing %s (%d times in %ds)'):format(
            src, action, entry.count, ABUSE_WINDOW
        ))
        return true
    end

    return false
end

-- Clean up abuse tracker periodically
CreateThread(function()
    while true do
        Wait(120000)
        local now = os.time()
        for key, entry in pairs(abuseTracker) do
            if (now - entry.firstSeen) > ABUSE_WINDOW * 2 then
                abuseTracker[key] = nil
            end
        end
    end
end)

print('^2[Bank System] Security module loaded^7')

-- ============================================================
-- TRANSACTION LIMITS
-- ============================================================

---@param identifier string Player identifier
---@param transactionType string 'withdrawal', 'deposit', 'transfer_out'
---@param amount number Amount being transacted
---@return boolean allowed, string|nil errorKey
function Security.CheckTransactionLimits(identifier, transactionType, amount)
    if not Config.TransactionLimits or not Config.TransactionLimits.Enabled then
        return true, nil
    end

    -- Map transaction types to config limit keys
    local limitMap = {
        ['withdrawal']    = { daily = 'DailyWithdrawLimit',    monthly = 'MonthlyWithdrawLimit' },
        ['deposit']       = { daily = 'DailyDepositLimit',     monthly = 'MonthlyDepositLimit' },
        ['transfer_out']  = { daily = 'DailyTransferLimit',    monthly = 'MonthlyTransferLimit' },
    }

    local limits = limitMap[transactionType]
    if not limits then return true, nil end

    -- Check daily limit
    local dailyLimit = Config.TransactionLimits[limits.daily]
    if dailyLimit then
        local dailyTotal = MySQL.scalar.await([[
            SELECT COALESCE(SUM(ABS(amount)), 0)
            FROM bank_transactions bt
            INNER JOIN bank_accounts ba ON bt.account_id = ba.id
            WHERE ba.owner = ? AND bt.type = ? AND bt.created_at >= CURDATE()
        ]], { identifier, transactionType }) or 0

        if (dailyTotal + amount) > dailyLimit then
            return false, 'server.daily_limit_reached'
        end
    end

    -- Check monthly limit
    local monthlyLimit = Config.TransactionLimits[limits.monthly]
    if monthlyLimit then
        local monthlyTotal = MySQL.scalar.await([[
            SELECT COALESCE(SUM(ABS(amount)), 0)
            FROM bank_transactions bt
            INNER JOIN bank_accounts ba ON bt.account_id = ba.id
            WHERE ba.owner = ? AND bt.type = ? AND bt.created_at >= DATE_FORMAT(NOW(), '%Y-%m-01')
        ]], { identifier, transactionType }) or 0

        if (monthlyTotal + amount) > monthlyLimit then
            return false, 'server.monthly_limit_reached'
        end
    end

    return true, nil
end
