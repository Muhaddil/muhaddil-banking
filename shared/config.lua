Config = {}

Config.FrameWork = "auto"            -- auto, esx, qb
Config.ESXVer = "new"                -- new, old
Config.OpenCommand = "banco"         -- Command to open the banking system, set to false to disable
Config.Locale = 'en'                 -- es, en
Config.AutoVersionChecker = true     -- Enable automatic version checking

Config.DisablePhoneApp = true        -- Disable the phone app, useful if you want to use a custom phone or no phone at all

Config.AllowedGroups = {             -- Groups that can use the banking system (admin)
    qb = { "admin", "god" },         -- QBCore roles
    esx = { "admin", "superadmin" }, -- ESX groups
    ace = { "banking_system" }       -- ACE permissions
}

-- Bank Locations
Config.BankLocations = {
    {
        id = "bank_legion",                                           -- Unique identifier for the bank
        name = "Banco Legion Square",                                 -- Name of the bank
        coords = vector3(149.46, -1040.53, 29.37),                    -- Coordinates of the bank
        useped = true,                                                -- Use a ped at the bank
        pedcoords = vector4(149.4139, -1042.1110, 29.3680, 336.3652), -- Coordinates of the ped
        pedmodel = "ig_bankman",                                      -- Model of the ped
        blip = true,                                                  -- Enable blip
        purchasable = true                                            -- Enable purchase
    },
    {
        id = "bank_del_perro",
        name = "Del Perro Boulevard",
        coords = vector3(-1212.74, -330.48, 37.79),
        useped = true,
        pedcoords = vector4(-1211.95, -332.07, 37.78, 28.65),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    },
    {
        id = "bank_hawick",
        name = "Banco Hawick Avenue",
        coords = vector3(-350.77, -49.57, 49.04),
        useped = true,
        pedcoords = vector4(-351.31, -51.31, 49.04, 337.81),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    },
    {
        id = "bank_alta",
        name = "Banco Alta Street",
        coords = vector3(314.39, -278.81, 54.17),
        useped = true,
        pedcoords = vector4(313.8434, -280.4339, 54.1646, 339.3568),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    },
    {
        id = "bank_sandy",
        name = "Banco Sandy Shores",
        coords = vector3(1174.94, 2706.42, 38.09),
        useped = true,
        pedcoords = vector4(1174.96, 2708.20, 38.09, 179.74),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    },
    {
        id = "bank_pacific",
        name = "Pacific Standard Bank",
        coords = vector3(243.05, 224.29, 106.29),
        useped = true,
        pedcoords = vector4(243.70, 226.30, 106.29, 162.98),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = false
    },
    {
        id = "bank_great_ocean",
        name = "Banco Great Ocean Highway",
        coords = vector3(-2963.14, 482.95, 15.70),
        useped = true,
        pedcoords = vector4(-2960.97, 482.91, 15.70, 88.16),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    },
    {
        id = "bank_paleto",
        name = "Banco Paleto Bay",
        coords = vector3(-112.2633, 6468.7690, 31.6267),
        useped = true,
        pedcoords = vector4(-111.2205, 6470.1367, 31.6267, 132.3241),
        pedmodel = "ig_bankman",
        blip = true,
        purchasable = true
    }
}

Config.Blip = {   -- Blip for the bank locations
    Sprite = 108, -- https://docs.fivem.net/docs/game-references/blips/
    Scale = 0.8,  -- Scale of the blip
    Color = 2     -- Color of the blip
}

-- Account Settings
Config.Accounts = {
    MaxPerPlayer = 5,   -- Max accounts per player
    InitialBalance = 0, -- Initial balance for new accounts (if framework account has balance it will use that)
    MaxSharedUsers = 5  -- Max users per shared account
}

-- Loan Settings
Config.Loans = {
    MinAmount = 1000,     -- Minimum amount for the loan
    MaxAmount = 100000,   -- Maximum amount for the loan
    InterestRate = 0.10,  -- 10% interest rate
    MaxInstallments = 24, -- Max installments for the loan

    AutoPayment = {
        Enabled       = true, -- If true, the loan will be paid automatically
        IntervalHours = 24,   -- Every how many hours the loan will be paid
        PenaltyOnMiss = true, -- If true, the loan will be penalized if there are no funds
        PenaltyRate   = 5,    -- % of penalty on the remaining amount
    }
}

-- Bank Ownership Settings
Config.BankOwnership = {
    Enabled = true,          -- Enable bank ownership
    PurchasePrice = 1000000, -- Price to purchase a bank
    SellPercentage = 0.50,   -- 50% of the purchase price
    MaxBanksPerPlayer = 3,   -- Max banks per player
    InteractionRadius = 3.5, -- Radius to interact with the bank (for antiexploit purposes)

    -- Commission Settings
    DefaultCommissionRate = 0.01, -- 1%
    MinCommissionRate = 0.005,    -- 0.5%
    MaxCommissionRate = 0.03,     -- 3%

    -- Transactions that generate commission, some have to be set to true to work
    CommissionOnDeposit = false, -- If true, the bank will earn commission on deposits
    CommissionOnWithdraw = true, -- If true, the bank will earn commission on withdrawals
    CommissionOnTransfer = true, -- If true, the bank will earn commission on transfers
    CommissionOnLoan = false     -- If true, the bank will earn commission on loans
}

-- ATM Settings
Config.ATMs = {
    Enabled = true,
    Fee = 5, -- $5 per transaction
    DepositLimit = 50000,
    WithdrawLimit = 50000,
    Target = true,       -- Use target?
    TargetSystem = "ox", -- ox, qb
    TargetDistance = 2.5,
    TargetModels = {
        `prop_atm_01`,
        `prop_atm_02`,
        `prop_atm_03`,
        `prop_fleeca_atm`
    },
    Locations = { -- Manual ATM locations (TextUI) --> Disabled if using target
        -- Does not spawn props, only TextUI
        vector3(147.60, -1035.77, 29.34),
        vector3(-1212.63, -331.52, 37.79),
        vector3(-2962.71, 483.00, 15.70),
        vector3(-112.44, 6470.03, 31.63),
        vector3(1175.74, 2706.80, 38.09),
        -- Add more here
    }
}

-- Transaction Limits (per player)
Config.TransactionLimits = {
    Enabled = false,               -- Enable daily/monthly limits
    DailyWithdrawLimit = 500000,   -- Max cash withdrawal per day
    DailyDepositLimit = 1000000,   -- Max cash deposit per day
    DailyTransferLimit = 1000000,  -- Max transfer per day
    MonthlyWithdrawLimit = 10000000,
    MonthlyDepositLimit = 20000000,
    MonthlyTransferLimit = 20000000,
}

Config.ATMBlip = {
    Enabled = false,            --> Disabled if using target
    Sprite = 277,               -- https://docs.fivem.net/docs/game-references/blips/
    Scale = 0.6,                -- Scale of the blip
    Color = 2,                  -- Color of the blip
    Label = "Cajero Automático" -- Label of the blip
}

-- Card Settings
Config.Cards = {
    Enabled = true,
    RequireCardForATM = true, -- If true, you need a card to use ATM (it can be created in a bank)
    DebitCardPrice = 500,
    MaxFailedPINAttempts = 3,

    -- Theft Settings
    CanStealCards = true,
    StealChance = 75 -- 75% chance of success
}

-- Savings Account Settings
Config.Savings = {
    Enabled = true,
    MaxPerAccount = 3,          -- Max savings goals per bank account
    InterestRate = 1.0,         -- 1% interest rate
    InterestIntervalHours = 24, -- Every 24 hours
    MinDeposit = 100,           -- Minimum deposit amount
    MaxGoalAmount = 1000000,    -- Maximum goal amount
}

-- Contacts Settings
Config.Contacts = {
    Enabled = true,
    MaxContacts = 20, -- Max contacts per player
}

-- Transfer Requests Settings
Config.TransferRequests = {
    Enabled = true,
    MaxPendingRequests = 10, -- Max pending requests per player
    ExpirationHours = 72,    -- Requests expire after 72 hours
}

-- Expanded Loan Settings
Config.Loans.Types = {
    personal = { MaxAmount = 100000, InterestRate = 0.10, MaxInstallments = 24 },
    business = { MaxAmount = 500000, InterestRate = 0.08, MaxInstallments = 48 },
    mortgage = { MaxAmount = 2000000, InterestRate = 0.05, MaxInstallments = 120 },
}
Config.Loans.MaxActiveLoans = 3
Config.Loans.CreditScore = {
    Enabled = true,
    BaseScore = 500,
    MaxScore = 850,
    MinScore = 300,
    PaymentBonus = 10,  -- Points gained per on-time payment
    MissedPenalty = 25, -- Points lost per missed payment
    PaidLoanBonus = 20, -- Bonus for fully paying off a loan
    -- Interest rate multipliers based on credit score
    ScoreTiers = {
        { minScore = 750, interestMultiplier = 0.85, label = 'excellent' }, -- -15% interest
        { minScore = 650, interestMultiplier = 1.00, label = 'good' },      -- Normal interest
        { minScore = 500, interestMultiplier = 1.10, label = 'fair' },      -- +10% interest
        { minScore = 300, interestMultiplier = 1.25, label = 'poor' },      -- +25% interest
    },
    DenyBelowScore = 350,                                                   -- Deny loans below this score (0 to disable)
}
Config.Loans.EarlyRepaymentDiscount = 0.05                                  -- 5% discount for paying off early

-- Scheduled Transfers Settings
Config.ScheduledTransfers = {
    Enabled = true,
    MaxPerPlayer = 10, -- Max scheduled transfers per player
    MinAmount = 50,    -- Minimum transfer amount
    Frequencies = { 'daily', 'weekly', 'biweekly', 'monthly' },
}

-- IBAN Settings
Config.IBAN = {
    Enabled = true,
    -- Zone prefixes based on locations
    ZonePrefixes = {
        bank_legion      = 'LS',  -- Los Santos (Legion Square)
        bank_del_perro   = 'DPB', -- Del Perro Boulevard
        bank_hawick      = 'HWK', -- Hawick Avenue
        bank_alta        = 'ALT', -- Alta Street
        bank_sandy       = 'SS',  -- Sandy Shores
        bank_pacific     = 'PS',  -- Pacific Standard
        bank_great_ocean = 'GOH', -- Great Ocean Highway
        bank_paleto      = 'PB',  -- Paleto Bay
    },
    DefaultPrefix = 'LS',         -- Fallback prefix
}

-- Checks Settings
Config.Checks = {
    Enabled            = true,
    MaxAmount          = 1000000,                       -- Max check amount
    MinAmount          = 100,                           -- Min check amount
    Fee                = 50,                            -- Fee to issue a check ($50)
    ExpirationDays     = 7,                             -- Days until check expires
    MaxActiveChecks    = 10,                            -- Max active checks per player
    ItemName           = 'bank_check',                  -- Inventory item name (needs ox_inventory or similar)
    UseInventoryItem   = true,                          -- If true, creates an inventory item. If false, uses NUI only.

    AllowForging       = true,                          -- Allow forging checks
    ForgeLocation      = {                              -- NPC/Location to open forge menu
        enabled = true,
        coords = vector3(695.5828, -966.1284, 23.9673), -- Example location
        useped = true,
        pedcoords = vector4(695.5828, -966.1284, 23.9673, 88.8138),
        pedmodel = "g_m_m_chigoon_01",
        label = "Forger"
    },
    ForgeSuccessChance = 65,                     -- % of success when forging (0-100)
    ForgeCost          = 0,                      -- Cost in $ (0 = no monetary cost)
    ForgeMaterials     = {
        { item = 'counterfeit_kit', count = 1 }, -- Forgery kit
        -- { item = 'paper',           count = 2 }, -- Special paper
    },
}


-- Direct Debits Settings
Config.DirectDebits = {
    Enabled = true,
    MaxPerPlayer = 15,      -- Max direct debits per player
    IntervalMinutes = 60,   -- How often to process direct debits (in minutes)
    NotifyOnPayment = true, -- Notify player when a debit is charged
    NotifyOnFailure = true, -- Notify player when a debit fails
    PenaltyOnMiss = false,  -- Apply penalty if debit fails
    PenaltyRate = 5,        -- % penalty on missed debit
}

-- Admin Panel Settings
Config.AdminPanel = {
    Enabled = true,
    Command = 'bankpanel', -- Command to open admin panel
}
