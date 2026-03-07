Config = {}

Config.FrameWork = "auto"            -- auto, esx, qb
Config.ESXVer = "new"                -- new, old
Config.OpenCommand = "banco"         -- Command to open the banking system, set to false to disable
Config.Locale = 'es'                 -- es, en
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
