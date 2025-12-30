"use client"

import type React from "react"
import { useEffect } from "react"
import { Button } from "./ui/Button"
import {
    Plus,
    Wallet,
    UserPlus,
    UserMinus,
    Trash2,
    Building2,
    TrendingUp,
    TrendingDown,
    ArrowRightLeft,
    Percent,
    Info,
    CreditCard,
    Sparkles,
    ChevronRight,
} from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface Account {
    id: number
    owner: string
    account_name: string
    balance: string
    created_at: string
}

interface DashboardProps {
    selectedAccount: Account | null
    accounts: Account[]
    sharedAccounts: Account[]
    onSelectAccount: (id: number) => void
    onAction: (
        action:
            | "deposit"
            | "withdraw"
            | "transfer"
            | "createAccount"
            | "addSharedUser"
            | "removeSharedUser"
            | "deleteAccount",
    ) => void
    maxAccounts?: number
    currentBank?: string
    currentBankType?: string
    currentBankCommissionRate?: number
}

const AccountCard: React.FC<{
    account: Account
    isSelected: boolean
    isShared?: boolean
    onClick: () => void
    index: number
}> = ({ account, isSelected, isShared = false, onClick, index }) => {
    const colors = [
        { gradient: "from-violet-600 to-indigo-600", glow: "violet-500", icon: "bg-violet-500" },
        { gradient: "from-emerald-600 to-teal-600", glow: "emerald-500", icon: "bg-emerald-500" },
        { gradient: "from-amber-500 to-orange-600", glow: "amber-500", icon: "bg-amber-500" },
        { gradient: "from-rose-500 to-pink-600", glow: "rose-500", icon: "bg-rose-500" },
        { gradient: "from-cyan-500 to-blue-600", glow: "cyan-500", icon: "bg-cyan-500" },
    ]
    const colorScheme = colors[index % colors.length]

    return (
        <div
            onClick={onClick}
            className={`
                group relative overflow-hidden rounded-2xl cursor-pointer 
                transition-all duration-500 ease-out
                ${isSelected
                    ? `bg-gradient-to-br ${colorScheme.gradient} shadow-2xl shadow-${colorScheme.glow}/30 scale-[1.02]`
                    : "bg-white/[0.03] hover:bg-white/[0.08] border border-white/[0.06] hover:border-white/[0.12]"
                }
            `}
        >
            {/* Background decoration */}
            {isSelected && (
                <>
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-10 -mt-10" />
                    <div className="absolute bottom-0 left-0 w-24 h-24 bg-black/20 rounded-full blur-2xl -ml-8 -mb-8" />
                </>
            )}

            <div className="relative z-10 p-5">
                <div className="flex items-start justify-between mb-4">
                    <div
                        className={`
                        p-3 rounded-xl transition-all duration-300
                        ${isSelected
                                ? "bg-white/20 backdrop-blur-sm"
                                : `${colorScheme.icon}/10 group-hover:${colorScheme.icon}/20`
                            }
                    `}
                    >
                        {isShared ? (
                            <CreditCard size={22} className={isSelected ? "text-white" : `text-${colorScheme.glow}`} />
                        ) : (
                            <Wallet size={22} className={isSelected ? "text-white" : `text-${colorScheme.glow}`} />
                        )}
                    </div>

                    <div
                        className={`
                        flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium
                        ${isSelected ? "bg-white/20 text-white" : "bg-white/5 text-white/50"}
                    `}
                    >
                        {isShared && <Sparkles size={10} />}
                        <span>**** {account.id}</span>
                    </div>
                </div>

                <div className="space-y-1 mb-4">
                    <p
                        className={`
                        text-sm font-medium
                        ${isSelected ? "text-white/70" : "text-white/40"}
                    `}
                    >
                        {isShared ? "Cuenta Compartida" : "Cuenta Personal"}
                    </p>
                    <h3
                        className={`
                        text-lg font-bold tracking-tight
                        ${isSelected ? "text-white" : "text-white/90"}
                    `}
                    >
                        {account.account_name}
                    </h3>
                </div>

                <div className="flex items-end justify-between">
                    <div>
                        <p
                            className={`
                            text-xs font-medium mb-1
                            ${isSelected ? "text-white/60" : "text-white/30"}
                        `}
                        >
                            Balance
                        </p>
                        <p
                            className={`
                            text-2xl font-bold tracking-tight
                            ${isSelected ? "text-white" : "text-white/90"}
                        `}
                        >
                            ${Number.parseFloat(account.balance).toLocaleString()}
                        </p>
                    </div>

                    <div
                        className={`
                        p-2 rounded-full transition-all duration-300
                        ${isSelected ? "bg-white/20" : "bg-white/5 group-hover:bg-white/10"}
                    `}
                    >
                        <ChevronRight size={18} className={isSelected ? "text-white" : "text-white/50"} />
                    </div>
                </div>
            </div>
        </div>
    )
}

export const Dashboard: React.FC<DashboardProps> = ({
    selectedAccount,
    accounts,
    sharedAccounts,
    onSelectAccount,
    onAction,
    maxAccounts,
    currentBank,
    currentBankType,
    currentBankCommissionRate,
}) => {
    const { t } = useLocale()
    const canCreateAccount = maxAccounts === undefined || accounts.length < maxAccounts

    const commissionRate = typeof currentBankCommissionRate === "number" ? currentBankCommissionRate : 0
    const commissionText = `${(commissionRate * 100).toFixed(1)}%`
    const feeText = commissionRate > 0 ? commissionText : t("common.free")

    useEffect(() => {
        if (!selectedAccount) return

        const updated =
            accounts.find((acc) => acc.id === selectedAccount.id) ||
            sharedAccounts.find((acc) => acc.id === selectedAccount.id)

        if (!updated) {
            onSelectAccount(0)
        }
    }, [selectedAccount, accounts, sharedAccounts])

    const accountExists = selectedAccount && [...accounts, ...sharedAccounts].some((acc) => acc.id === selectedAccount.id)

    if (!accountExists) return null

    const isOwner = accounts.some((acc) => acc.id === selectedAccount.id)

    const bankTypeLabel =
        currentBankType === "state"
            ? t("dashboard.bankInfo.bankTypes.state")
            : currentBankType === "private"
                ? t("dashboard.bankInfo.bankTypes.private")
                : currentBankType || "-"

    const totalBalance = accounts.reduce(
        (acc, curr) => acc + Number(curr.balance),
        0,
    )

    const selectedAccountBalance = selectedAccount
        ? Number(selectedAccount.balance)
        : 0


    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-[rgb(var(--accent-primary))] via-[rgb(var(--accent-secondary))] to-[rgb(var(--accent-glow))] p-6 md:p-8 shadow-2xl shadow-[rgba(var(--accent-glow),0.3)]">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />
                <div className="absolute bottom-0 left-0 w-64 h-64 bg-black/10 rounded-full blur-3xl -ml-16 -mb-16" />

                <div className="relative z-10">
                    <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
                        <div>
                            <p className="text-white/80 font-medium mb-2 text-sm md:text-base">{t("dashboard.totalBalance")}</p>
                            <h2 className="text-4xl md:text-5xl font-bold text-white tracking-tight">
                                ${totalBalance.toLocaleString()}
                            </h2>
                            {selectedAccount && (
                                <p className="mt-2 text-white/70 text-sm">
                                    {t("dashboard.selectedAccountBalance")}:{" "}
                                    <span className="font-semibold text-white">
                                        ${selectedAccountBalance.toLocaleString()}
                                    </span>
                                </p>
                            )}
                        </div>
                        <div className="bg-white/20 backdrop-blur-md px-4 py-2 rounded-lg border border-white/20 shadow-lg">
                            <span className="text-white font-medium">{selectedAccount?.account_name}</span>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6 pt-6 border-t border-white/20">
                        <div className="bg-white/10 backdrop-blur-sm p-4 rounded-xl border border-white/20">
                            <div className="flex items-center gap-2 mb-2">
                                <Building2 size={16} className="text-white/80" />
                                <p className="text-white/70 text-xs font-medium uppercase tracking-wider">
                                    {t("dashboard.bankInfo.associated")}
                                </p>
                            </div>
                            <p className="text-white font-semibold text-lg">
                                {currentBank && currentBank.trim()
                                    ? currentBank
                                    : `${t("sidebar.bankName")} ${t("sidebar.bankSubtitle")}`}
                            </p>
                        </div>

                        <div className="bg-white/10 backdrop-blur-sm p-4 rounded-xl border border-white/20">
                            <div className="flex items-center gap-2 mb-2">
                                <Percent size={16} className="text-white/80" />
                                <p className="text-white/70 text-xs font-medium uppercase tracking-wider">
                                    {t("dashboard.bankInfo.commission")}
                                </p>
                            </div>
                            <p className="text-white font-semibold text-lg">{commissionText}</p>
                        </div>

                        <div className="bg-white/10 backdrop-blur-sm p-4 rounded-xl border border-white/20">
                            <div className="flex items-center gap-2 mb-2">
                                <Info size={16} className="text-white/80" />
                                <p className="text-white/70 text-xs font-medium uppercase tracking-wider">
                                    {t("dashboard.bankInfo.bankType")}
                                </p>
                            </div>
                            <p className="text-white font-semibold text-lg">{bankTypeLabel}</p>
                        </div>
                    </div>

                    <div className="bg-white/10 backdrop-blur-sm p-4 rounded-xl border border-white/20 mb-6">
                        <h4 className="text-white font-semibold mb-3 flex items-center gap-2">
                            <TrendingDown size={18} />
                            {t("dashboard.feeCalculator.title")}
                        </h4>

                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-sm">
                            <div className="flex items-center gap-2">
                                <TrendingUp size={14} className="text-green-400" />
                                <span className="text-white/70">{t("dashboard.feeCalculator.deposit")}:</span>
                                <span className="text-green-400 font-semibold">{feeText}</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <TrendingDown size={14} className="text-orange-400" />
                                <span className="text-white/70">{t("dashboard.feeCalculator.withdraw")}:</span>
                                <span className="text-orange-400 font-semibold">{feeText}</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <ArrowRightLeft size={14} className="text-blue-400" />
                                <span className="text-white/70">{t("dashboard.feeCalculator.transfer")}:</span>
                                <span className="text-blue-400 font-semibold">{feeText}</span>
                            </div>
                        </div>

                        <p className="mt-4 text-xs text-white/50 italic">{t("dashboard.feeCalculator.disclaimer")}</p>
                    </div>

                    {isOwner && (
                        <div className="flex flex-wrap gap-3 pt-4 border-t border-white/20">
                            <Button
                                onClick={() => onAction("addSharedUser")}
                                className="bg-white/10 text-white hover:bg-white/20 border border-white/20 backdrop-blur-sm"
                                icon={<UserPlus size={18} />}
                            >
                                {t("dashboard.actions.addUser")}
                            </Button>
                            <Button
                                onClick={() => onAction("removeSharedUser")}
                                className="bg-white/10 text-white hover:bg-white/20 border border-white/20 backdrop-blur-sm"
                                icon={<UserMinus size={18} />}
                            >
                                {t("dashboard.actions.removeUser")}
                            </Button>
                            <Button
                                onClick={() => onAction("deleteAccount")}
                                className="bg-red-500/20 text-white hover:bg-red-500/30 border border-red-500/30 ml-auto backdrop-blur-sm"
                                icon={<Trash2 size={18} />}
                            >
                                {t("dashboard.actions.deleteAccount")}
                            </Button>
                        </div>
                    )}
                </div>
            </div>

            <div className="space-y-6">
                {/* Your Accounts Section */}
                <div>
                    <div className="flex items-center justify-between mb-4">
                        <div className="flex items-center gap-3">
                            <div className="p-2 rounded-lg bg-gradient-to-br from-violet-500/20 to-indigo-500/20 border border-violet-500/20">
                                <Wallet size={18} className="text-violet-400" />
                            </div>
                            <div>
                                <h3 className="text-lg font-bold text-white">{t("dashboard.yourAccounts")}</h3>
                                <p className="text-xs text-white/40">
                                    {accounts.length} cuenta{accounts.length !== 1 ? "s" : ""} activa{accounts.length !== 1 ? "s" : ""}
                                </p>
                            </div>
                        </div>

                        {canCreateAccount && (
                            <Button
                                variant="secondary"
                                className="bg-white/5 hover:bg-white/10 border border-white/10 hover:border-violet-500/40 text-white/70 hover:text-violet-400 transition-all duration-300"
                                icon={<Plus size={16} />}
                                onClick={() => onAction("createAccount")}
                            >
                                <span className="hidden sm:inline">{t("dashboard.newAccount")}</span>
                            </Button>
                        )}
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                        {accounts.map((acc, index) => (
                            <AccountCard
                                key={acc.id}
                                account={acc}
                                isSelected={selectedAccount?.id === acc.id}
                                onClick={() => onSelectAccount(acc.id)}
                                index={index}
                            />
                        ))}

                        {/* Create account card */}
                        {canCreateAccount && (
                            <div
                                onClick={() => onAction("createAccount")}
                                className="
                                    group relative overflow-hidden rounded-2xl cursor-pointer p-5
                                    border-2 border-dashed border-white/10 hover:border-violet-500/40
                                    bg-white/[0.02] hover:bg-violet-500/5
                                    transition-all duration-300
                                    flex flex-col items-center justify-center min-h-[180px]
                                "
                            >
                                <div className="p-4 rounded-full bg-white/5 group-hover:bg-violet-500/20 transition-all duration-300 mb-3">
                                    <Plus size={24} className="text-white/30 group-hover:text-violet-400 transition-colors" />
                                </div>
                                <p className="text-white/40 group-hover:text-violet-400 font-medium transition-colors">
                                    {t("dashboard.newAccount")}
                                </p>
                            </div>
                        )}
                    </div>

                    {!canCreateAccount && maxAccounts !== undefined && (
                        <div className="mt-4 p-4 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center gap-3">
                            <Info size={18} className="text-amber-400 shrink-0" />
                            <p className="text-amber-200/80 text-sm">{t("dashboard.maxAccountsReached", { max: maxAccounts })}</p>
                        </div>
                    )}
                </div>

                {/* Shared Accounts Section */}
                {sharedAccounts.length > 0 && (
                    <div>
                        <div className="flex items-center gap-3 mb-4">
                            <div className="p-2 rounded-lg bg-gradient-to-br from-emerald-500/20 to-teal-500/20 border border-emerald-500/20">
                                <CreditCard size={18} className="text-emerald-400" />
                            </div>
                            <div>
                                <h3 className="text-lg font-bold text-white">{t("dashboard.sharedAccounts")}</h3>
                                <p className="text-xs text-white/40">
                                    {sharedAccounts.length} cuenta{sharedAccounts.length !== 1 ? "s" : ""} compartida
                                    {sharedAccounts.length !== 1 ? "s" : ""}
                                </p>
                            </div>
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                            {sharedAccounts.map((acc, index) => (
                                <AccountCard
                                    key={acc.id}
                                    account={acc}
                                    isSelected={selectedAccount?.id === acc.id}
                                    isShared
                                    onClick={() => onSelectAccount(acc.id)}
                                    index={index + accounts.length}
                                />
                            ))}
                        </div>
                    </div>
                )}
            </div>
        </div>
    )
}
