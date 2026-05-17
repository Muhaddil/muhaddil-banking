# 🏦 muhaddil-banking

A comprehensive and modern banking system for FiveM with support for multiple accounts, loans, private banks, and more.

## 💳 Features

- **Multiple Accounts**: Players can create and manage multiple personal and shared accounts.
- **Private Banks**: Ability to purchase and manage banks, earning commissions on transactions in the area.
- **Loan System**: Flexible loans with configurable interest rates, installments, and credit scoring.
- **Direct Debits**: Set up recurring payments for services, subscriptions, or shared expenses.
- **ATM & Cards**: Integrated ATM system with physical debit cards, PIN management, and blocking features.
- **Checks & Transfers**: Write physical checks or transfer money instantly using unique account IDs.
- **Framework Support**: Automatically detects and works with **ESX** and **QB-Core**.
- **Admin Panel**: Powerful in-game tools for managing accounts, loans, and monitoring transactions.

## 🌟 Preview

Watch the video preview of the banking system in action:

https://youtu.be/rdEg3VhTgkI

## 📋 Requirements

- [ox_lib](https://github.com/CommunityOx/ox_lib)
- [oxmysql](https://github.com/CommunityOx/oxmysql)
- [es_extended](https://github.com/esx-framework/esx_core) OR [qb-core](https://github.com/qbcore-framework/qb-core)

## 🚀 Installation

1. Download the resource.
2. Extract it into your `resources` folder.
3. Add `ensure muhaddil-banking` to your `server.cfg`.
4. The database tables will be created automatically on the first start (or use `install.sql`).
5. Configure the settings in `shared/config.lua` to match your server's needs.

## 🎮 Usage

Players can access the banking system through physical bank locations, ATMs, or via command:

```bash
/banco
```

### Admin Commands:

- `/bankadmin`: Opens the comprehensive administration panel.
- `/bankinfo [accountId]`: View detailed information and history of a specific account.
- `/bankloans`: Monitor all active loans in the server.
- `/bankreset [playerId]`: Reset all banking data for a specific player.

## ⚙️ Configuration

You can customize the core behavior in `shared/config.lua`:
## 🛠️ Exports

The script provides extensive exports for integration with other resources:

### Server-side

#### 📂 Core & Transactions
- `exports['muhaddil-banking']:Transfer(source, fromId, toId, amount, bankLocation)`: Triggers a transfer between accounts.
- `exports['muhaddil-banking']:GetTotalBankBalance(identifier)`: Returns total balance across all accounts for a player.
- `exports['muhaddil-banking']:AddMoneyToAccount(accountId, amount, reason)`: Programmatically add funds to an account.
- `exports['muhaddil-banking']:RemoveMoneyFromAccount(accountId, amount, reason)`: Programmatically remove funds from an account.
- `exports['muhaddil-banking']:SyncFrameworkBank(playerId)`: Forces a balance synchronization with the active framework.
- `exports['muhaddil-banking']:ResolveAccountId(input)`: Resolves an IBAN or numeric ID to an account ID.

#### 💳 Cards System
- `exports['muhaddil-banking']:HasCard(source)`: Returns whether the player has at least one bank card.
- `exports['muhaddil-banking']:GetPlayerCards(source)`: Returns a list of all cards owned by the player.
- `exports['muhaddil-banking']:CreateCard(source, accountId, pin)`: Generates a new physical card for an account.
- `exports['muhaddil-banking']:ToggleCardBlock(source, cardId, block)`: Blocks or unblocks a specific bank card.
- `exports['muhaddil-banking']:ChangeCardPin(source, cardId, currentPin, newPin)`: Updates the PIN for a card.
- `exports['muhaddil-banking']:DeleteCard(source, cardId)`: Permanently removes a card.

#### 🏦 Bank Management (Private Banks)
- `exports['muhaddil-banking']:GetBankDetails(source, bankId)`: Returns ownership and configuration details of a bank.
- `exports['muhaddil-banking']:UpdateBankCommission(source, bankId, newRate)`: Updates the transaction commission for a bank.
- `exports['muhaddil-banking']:WithdrawBankEarnings(source, bankId)`: Withdraws the accumulated profit from a bank.
- `exports['muhaddil-banking']:SellBank(source, bankId)`: Sells the bank ownership.
- `exports['muhaddil-banking']:TransferBank(source, bankId, targetPlayerId)`: Transfers ownership to another player.

#### 🔄 Recurring Payments & Loans
- `exports['muhaddil-banking']:RegisterDirectDebit(identifier, accountId, creditor, amount, frequency)`: Sets up a recurring payment.
- `exports['muhaddil-banking']:CancelDirectDebitById(debitId)`: Cancels an active direct debit.
- `exports['muhaddil-banking']:GetPlayerCreditScore(identifier)`: Returns the current credit score for a player.

#### 🛡️ Administration
- `exports['muhaddil-banking']:GetTopAccounts(limit)`: Returns a list of the richest accounts.
- `exports['muhaddil-banking']:GetActiveLoans()`: Returns all currently active loans in the server.
- `exports['muhaddil-banking']:CancelLoan(loanId)`: Administratively cancels a loan.
- `exports['muhaddil-banking']:GetAccountInfo(accountId)`: Returns full administrative details of an account.
- `exports['muhaddil-banking']:ResetPlayerBank(identifier)`: Completely resets all banking data for a player.

### Client-side

- `exports['muhaddil-banking']:OpenBankById(bankId)`: Opens the banking UI for a specific bank location.
- `exports['muhaddil-banking']:OpenNearestBank()`: Opens the UI for the closest bank location.
- `exports['muhaddil-banking']:CloseBank()`: Closes the banking UI.
- `exports['muhaddil-banking']:IsBankOpen()`: Returns whether the banking UI is currently open.
- `exports['muhaddil-banking']:GetCurrentBank()`: Returns information about the currently open bank location.
- `exports['muhaddil-banking']:OpenATM()`: Opens the ATM interface.
- `exports['muhaddil-banking']:IsATMOpen()`: Returns whether the ATM interface is open.
- `exports['muhaddil-banking']:useCheck(data)`: Triggers the logic for using a physical check.
- `exports['muhaddil-banking']:HasStolenCard()`: Checks if the player is carrying a reported stolen card.

## Support

You can join the discord for support:
https://discord.gg/V58gaTqsK8
