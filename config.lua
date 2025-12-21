Config = {}

Config.FrameWork = 'auto' -- Select the framework being used: 'esx' for ESX Framework or 'qb' for QBCore Framework.
Config.ESXVer = 'new'-- Select ESX version, 'new' or 'old'

-- Comandos
Config.OpenCommand = "banco"

-- Sistema de préstamos
Config.Loans = {
    MinAmount = 1000,
    MaxAmount = 500000,
    InterestRate = 0.05, -- 5%
    MaxInstallments = 12,
    MinCreditScore = 50
}

-- Sistema de bancos privados
Config.BankOwnership = {
    Enabled = true,
    PurchasePrice = 1000000,
    CommissionRate = 0.01, -- 1% de cada transacción
    MaxBanksPerPlayer = 3
}

-- Límites de cuentas
Config.Accounts = {
    MaxPerPlayer = 5,
    MaxSharedUsers = 5,
    InitialBalance = 0
}

-- Transacciones
Config.Transactions = {
    MinTransfer = 1,
    MaxTransfer = 999999999,
    TransferFee = 0, -- 0% por defecto, el owner del banco puede cobrarlo
}

-- Ubicaciones de bancos (puedes añadir más)
Config.BankLocations = {
    {name = "Banco Central", coords = vector3(149.46, -1040.53, 29.37), blip = true},
    {name = "Paleto Bay Bank", coords = vector3(-112.20, 6469.91, 31.63), blip = true},
    {name = "Great Ocean Highway", coords = vector3(-1212.98, -330.84, 37.79), blip = true},
    {name = "Pacific Standard Bank", coords = vector3(241.72, 227.97, 106.29), blip = true}
}

-- Blips
Config.Blip = {
    Sprite = 108,
    Color = 2,
    Scale = 0.8,
    Label = "Banco"
}

-- Sistema de seguridad
Config.Security = {
    MaxDailyTransfers = 50,              -- Máximo de transferencias por día
    MaxTransferAmount = 1000000,         -- Máximo por transferencia
    CooldownBetweenTransfers = 1,        -- Segundos entre transferencias
    RequireConfirmation = true,          -- Requiere confirmación para montos grandes
    LogAllTransactions = true            -- Registrar todas las transacciones
}

-- Sistema de ATMs (Cajeros Automáticos) - OPCIONAL
Config.ATMs = {
    Enabled = false,                     -- Deshabilitado por defecto
    WithdrawLimit = 5000,                -- Límite de retiro por transacción
    Fee = 10,                            -- Comisión por uso
    Locations = {
        -- Añade coordenadas de ATMs aquí cuando lo habilites
        -- vector3(147.44, -1035.77, 29.34),
        -- vector3(-1205.02, -324.28, 37.86),
    }
}

-- Sistema de Tarjetas - OPCIONAL
Config.Cards = {
    Enabled = false,                     -- Deshabilitado por defecto
    DebitCardPrice = 500,                -- Precio de tarjeta de débito
    DailyWithdrawLimit = 10000,          -- Límite de retiro diario
    RequireCardForATM = false            -- Requiere tarjeta para usar ATM
}

-- Sistema de Intereses - OPCIONAL
Config.Interest = {
    Enabled = false,                     -- Deshabilitado por defecto
    Rate = 0.001,                        -- 0.1% diario
    MinBalance = 10000,                  -- Balance mínimo para generar interés
    PaymentInterval = 86400              -- 24 horas en segundos
}

-- Sistema de Cheques - OPCIONAL
Config.Checks = {
    Enabled = false,                     -- Deshabilitado por defecto
    MinAmount = 100,                     -- Monto mínimo del cheque
    MaxAmount = 100000,                  -- Monto máximo del cheque
    ExpiryDays = 7,                      -- Días hasta que expire
    Fee = 25                             -- Comisión por crear cheque
}