"use client"

import React, { useState, useEffect } from "react"
import { DollarSign, ArrowDownCircle, ArrowUpCircle, CreditCard, Loader2, ArrowLeftRight, Landmark, X, ChevronRight } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface Account {
    id: number
    account_name: string
    balance: string
}

interface Card {
    id: number
    account_id: number
    account_name: string
    card_number: string
    is_blocked: boolean | number
}

interface ATMData {
    cash: number
    cards?: Card[]
    accounts?: Account[]
}

interface AtmInterfaceProps {
    data: ATMData
    requirePin: boolean
    onClose: () => void
    onDeposit: (accountId: number, amount: number) => void
    onWithdraw: (accountId: number, amount: number) => void
    onTransfer: (fromId: number, toId: number, amount: number) => void
    onVerifyPin: (pin: string, cardId: number, accountId: number) => Promise<{ success: boolean; error?: string; accountData?: any }>
}

type ATMView = "cards" | "accounts" | "pin" | "loading" | "menu" | "deposit" | "withdraw" | "transfer"

const ATMSkeleton = () => {
    return (
        <div className="grid grid-cols-2 gap-3">
            {[1, 2, 3].map((i) => (
                <div
                    key={i}
                    className={`flex flex-col items-center gap-3 p-5 bg-[rgb(var(--bg-secondary))]/50 rounded-xl border border-white/5 ${i === 3 ? 'col-span-2' : ''}`}
                >
                    <div className="w-12 h-12 bg-[rgb(var(--bg-muted))]/30 rounded-xl animate-pulse" />
                    <div className="h-4 w-20 bg-[rgb(var(--bg-muted))]/30 rounded animate-pulse" />
                </div>
            ))}
        </div>
    )
}

export const AtmInterface: React.FC<AtmInterfaceProps> = ({
    data,
    requirePin,
    onClose,
    onDeposit,
    onWithdraw,
    onTransfer,
    onVerifyPin,
}) => {
    const { t } = useLocale()
    const [view, setView] = useState<ATMView>(requirePin ? "cards" : "accounts")
    const [selectedCard, setSelectedCard] = useState<Card | null>(null)
    const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
    const [amount, setAmount] = useState("")
    const [targetAccountId, setTargetAccountId] = useState("")
    const [pin, setPin] = useState("")
    const [pinError, setPinError] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [accounts, setAccounts] = useState<Account[]>(data.accounts || [])
    const [loadingReason, setLoadingReason] = useState<"pin" | "account" | null>(null)

    useEffect(() => {
        if (data.accounts && data.accounts.length > 0) {
            setAccounts(data.accounts)
        }
    }, [data.accounts])

    const formatCardNumber = (num: string) => {
        return num.match(/.{1,4}/g)?.join(" ") || num
    }

    const handleCardSelect = (card: Card) => {
        if (card.is_blocked) {
            setPinError("Esta tarjeta está bloqueada")
            return
        }
        setSelectedCard(card)
        setView("pin")
    }

    const handleAccountSelect = (account: Account) => {
        setSelectedAccount(account)
        setLoadingReason("account")
        setView("loading")

        setTimeout(() => {
            setLoadingReason(null)
            setView("menu")
        }, 1200)
    }

    const handlePinSubmit = async () => {
        if (pin.length !== 4) {
            setPinError("El PIN debe tener 4 dígitos")
            return
        }

        if (!selectedCard) {
            setPinError("No hay tarjeta seleccionada")
            return
        }

        setIsLoading(true)
        setPinError("")

        try {
            const result = await onVerifyPin(pin, selectedCard.id, selectedCard.account_id)
            if (result.success && result.accountData) {
                if (result.accountData.account) {
                    setSelectedAccount(result.accountData.account)
                }
                setLoadingReason("pin")
                setView("loading")
                setTimeout(() => {
                    setLoadingReason(null)
                    setView("menu")
                }, 1200)
            } else {
                setPinError(result.error || "PIN incorrecto")
                setPin("")

                if (result.error?.toLowerCase().includes("bloqueada")) {
                    setTimeout(() => {
                        onClose()
                    }, 2000)
                }
            }
        } catch {
            setPinError("Error al verificar PIN")
        } finally {
            setIsLoading(false)
        }
    }

    const handlePinKeyPress = (key: string) => {
        if (pin.length < 4) {
            setPin((prev) => prev + key)
        }
    }

    const handlePinBackspace = () => {
        setPin((prev) => prev.slice(0, -1))
    }

    useEffect(() => {
        if (view !== "pin") return

        const handleKeyDown = (e: KeyboardEvent) => {
            if (isLoading) return

            if (e.key >= "0" && e.key <= "9") {
                handlePinKeyPress(e.key)
            } else if (e.key === "Backspace") {
                handlePinBackspace()
            } else if (e.key === "Enter") {
                handlePinSubmit()
            }
        }

        window.addEventListener("keydown", handleKeyDown)
        return () => window.removeEventListener("keydown", handleKeyDown)
    }, [pin, isLoading, view])

    const handleAction = (action: "deposit" | "withdraw" | "transfer") => {
        if (!selectedAccount) return
        const numAmount = parseFloat(amount)
        if (isNaN(numAmount) || numAmount <= 0) return

        if (action === "deposit") {
            onDeposit(selectedAccount.id, numAmount)
            setSelectedAccount({
                ...selectedAccount,
                balance: (parseFloat(selectedAccount.balance) + numAmount).toString()
            })
        } else if (action === "withdraw") {
            onWithdraw(selectedAccount.id, numAmount)
            setSelectedAccount({
                ...selectedAccount,
                balance: (parseFloat(selectedAccount.balance) - numAmount).toString()
            })
        } else if (action === "transfer") {
            const targetId = parseInt(targetAccountId)
            if (isNaN(targetId)) return
            onTransfer(selectedAccount.id, targetId, numAmount)
            setSelectedAccount({
                ...selectedAccount,
                balance: (parseFloat(selectedAccount.balance) - numAmount).toString()
            })
        }

        setAmount("")
        setTargetAccountId("")
        setView("menu")
    }

    const formatMoney = (value: string | number) => {
        const num = typeof value === "string" ? parseFloat(value) : value
        return new Intl.NumberFormat("es-ES", { style: "currency", currency: "USD" }).format(num)
    }

    const handleBack = () => {
        if (view === "pin") {
            setView("cards")
            setPin("")
            setPinError("")
            setSelectedCard(null)
        } else if (view === "menu") {
            if (requirePin) {
                setSelectedCard(null)
                setSelectedAccount(null)
                setView("cards")
            } else {
                setSelectedAccount(null)
                setView("accounts")
            }
        } else {
            setView("menu")
            setAmount("")
            setTargetAccountId("")
        }
    }

    if (view === "cards") {
        return (
            <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
                <div className="w-full max-w-2xl bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                    <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                                    <CreditCard className="text-white" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.title")}</h2>
                                    <p className="text-white/70 text-sm">{t("atm.selectCard")}</p>
                                </div>
                            </div>
                            <button
                                onClick={onClose}
                                className="text-white/70 hover:text-white transition-all hover:bg-white/10 p-2 rounded-lg"
                            >
                                <X size={20} />
                            </button>
                        </div>
                    </div>

                    <div className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                        {data.cards && data.cards.length > 0 ? (
                            <div className="grid gap-4">
                                {data.cards.map((card) => {
                                    const isBlocked = card.is_blocked === true || card.is_blocked === 1
                                    return (
                                        <button
                                            key={card.id}
                                            onClick={() => handleCardSelect(card)}
                                            disabled={isBlocked}
                                            className={`group relative overflow-hidden rounded-2xl transition-all duration-300 ${isBlocked
                                                ? "opacity-50 cursor-not-allowed"
                                                : "hover:scale-[1.02] hover:shadow-2xl cursor-pointer"
                                                }`}
                                        >
                                            <div className={`p-6 ${isBlocked
                                                ? "bg-[rgb(var(--bg-secondary))] border border-red-500/30"
                                                : "bg-gradient-to-br from-[rgb(var(--bg-secondary))] to-[rgb(var(--bg-card))] border border-white/10"
                                                }`}>
                                                <div className="flex items-center justify-between">
                                                    <div className="flex items-center gap-4">
                                                        <div className="p-3 rounded-xl">
                                                            <CreditCard size={24} className={isBlocked ? "text-red-400" : "text-[rgb(var(--accent-primary))]"} />
                                                        </div>
                                                        <div className="text-left">
                                                            <p className="text-[rgb(var(--text-primary))] font-mono text-lg tracking-wider">
                                                                {formatCardNumber(card.card_number)}
                                                            </p>
                                                            <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">
                                                                {card.account_name}
                                                            </p>
                                                            {isBlocked && (
                                                                <span className="inline-block mt-2 px-2 py-1 bg-red-500/20 text-red-400 text-xs rounded-full border border-red-500/20">
                                                                    {t("cards.blocked")}
                                                                </span>
                                                            )}
                                                        </div>
                                                    </div>
                                                    {!isBlocked && (
                                                        <ChevronRight className="text-[rgb(var(--text-secondary))] group-hover:text-[rgb(var(--text-primary))] group-hover:translate-x-1 transition-all" size={24} />
                                                    )}
                                                </div>
                                            </div>
                                        </button>
                                    )
                                })}
                            </div>
                        ) : (
                            <div className="text-center py-12">
                                <CreditCard size={48} className="mx-auto mb-4 text-[rgb(var(--text-muted))]" />
                                <p className="text-[rgb(var(--text-secondary))] text-lg">{t("cards.noCards")}</p>
                                <p className="text-[rgb(var(--text-muted))] text-sm mt-2">{t("cards.createCardMessage")}</p>
                            </div>
                        )}

                        {pinError && (
                            <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-3 mt-4">
                                <p className="text-red-400 text-sm font-medium text-center">{pinError}</p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        )
    }

    if (view === "accounts") {
        return (
            <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
                <div className="w-full max-w-2xl bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                    <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                                    <Landmark className="text-white" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.title")}</h2>
                                    <p className="text-white/70 text-sm">{t("atm.selectAccount")}</p>
                                </div>
                            </div>
                            <button
                                onClick={onClose}
                                className="text-white/70 hover:text-white transition-all hover:bg-white/10 p-2 rounded-lg"
                            >
                                <X size={20} />
                            </button>
                        </div>
                    </div>

                    <div className="p-6 space-y-4 max-h-[70vh] overflow-y-auto">
                        {accounts && accounts.length > 0 ? (
                            <div className="grid gap-4">
                                {accounts.map((account) => (
                                    <button
                                        key={account.id}
                                        onClick={() => handleAccountSelect(account)}
                                        className="group relative overflow-hidden rounded-2xl transition-all duration-300 hover:scale-[1.02] hover:shadow-2xl cursor-pointer"
                                    >
                                        <div className="p-6 bg-gradient-to-br from-[rgb(var(--bg-secondary))] to-[rgb(var(--bg-card))] border border-white/10">
                                            <div className="flex items-center justify-between">
                                                <div className="flex items-center gap-4">
                                                    <div
                                                        className="p-3 rounded-xl"
                                                        style={{ backgroundColor: 'rgba(var(--accent-primary), 0.2)' }}
                                                    >
                                                        <Landmark
                                                            size={24}
                                                            style={{ color: 'rgb(var(--accent-primary))' }}
                                                        />
                                                    </div>
                                                    <div className="text-left">
                                                        <p className="text-[rgb(var(--text-primary))] font-semibold text-lg">
                                                            {account.account_name}
                                                        </p>
                                                        <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">
                                                            {t("atm.balance")}: {formatMoney(account.balance)}
                                                        </p>
                                                    </div>
                                                </div>
                                                <ChevronRight className="text-[rgb(var(--text-secondary))] group-hover:text-[rgb(var(--text-primary))] group-hover:translate-x-1 transition-all" size={24} />
                                            </div>
                                        </div>
                                    </button>
                                ))}
                            </div>
                        ) : (
                            <div className="text-center py-12">
                                <Landmark size={48} className="mx-auto mb-4 text-[rgb(var(--text-muted))]" />
                                <p className="text-[rgb(var(--text-secondary))] text-lg">{t("atm.noAccounts")}</p>
                            </div>
                        )}
                    </div>
                </div>
            </div>
        )
    }

    if (view === "pin") {
        return (
            <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
                <div className="w-full max-w-md bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                    <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <button
                                    onClick={handleBack}
                                    className="p-2 hover:bg-white/10 rounded-lg transition-all"
                                >
                                    <X size={20} className="text-white" />
                                </button>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.verifyPin")}</h2>
                                    <p className="text-white/70 text-sm">**** {selectedCard?.card_number.slice(-4)}</p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="p-6 space-y-6">
                        <div className="text-center">
                            <p className="text-[rgb(var(--text-secondary))] text-sm mb-6">{t("atm.enterPin")}</p>
                            <div className="flex justify-center gap-3 mb-3">
                                {[0, 1, 2, 3].map((i) => (
                                    <div
                                        key={i}
                                        className={`w-14 h-14 rounded-xl border-2 flex items-center justify-center text-2xl font-bold transition-all ${pin.length > i
                                            ? "bg-gradient-to-br from-[rgb(var(--accent-primary))]/20 to-[rgb(var(--accent-secondary))]/20 border-[rgb(var(--accent-primary))] shadow-lg shadow-[rgba(var(--accent-glow),0.2)]"
                                            : "bg-[rgb(var(--bg-secondary))] border-white/10"
                                            }`}
                                    >
                                        {pin.length > i ? (
                                            <span className="text-[rgb(var(--accent-primary))]">•</span>
                                        ) : (
                                            <span className="text-[rgb(var(--text-muted))]">○</span>
                                        )}
                                    </div>
                                ))}
                            </div>
                            {pinError && (
                                <div className="bg-red-500/10 border border-red-500/30 rounded-xl p-3 mt-4">
                                    <p className="text-red-400 text-sm font-medium">{pinError}</p>
                                </div>
                            )}
                        </div>

                        <div className="grid grid-cols-3 gap-2">
                            {["1", "2", "3", "4", "5", "6", "7", "8", "9", "←", "0", "✓"].map((key) => (
                                <button
                                    key={key}
                                    onClick={() => {
                                        if (key === "←") handlePinBackspace()
                                        else if (key === "✓") handlePinSubmit()
                                        else handlePinKeyPress(key)
                                    }}
                                    disabled={isLoading}
                                    className={`h-16 rounded-xl text-xl font-bold transition-all duration-200 ${key === "✓"
                                        ? "bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] text-white hover:shadow-xl hover:shadow-[rgba(var(--accent-glow),0.4)] hover:scale-105"
                                        : key === "←"
                                            ? "bg-red-500/20 hover:bg-red-500/30 text-red-400 border border-red-500/30"
                                            : "bg-[rgb(var(--bg-secondary))] hover:bg-white/10 text-[rgb(var(--text-primary))] border border-white/5"
                                        } ${isLoading ? "opacity-50 cursor-not-allowed" : ""}`}
                                >
                                    {isLoading && key === "✓" ? <Loader2 className="animate-spin mx-auto" size={20} /> : key}
                                </button>
                            ))}
                        </div>

                        <p className="text-center text-[rgb(var(--text-muted))] text-xs pt-2">{t("atm.pressEsc")}</p>
                    </div>
                </div>
            </div>
        )
    }

    if (view === "loading") {
        return (
            <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
                <div className="w-full max-w-lg bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                    <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                                    <CreditCard className="text-white" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.title")}</h2>
                                    <p className="text-white/70 text-sm">
                                        {selectedCard ? `**** ${selectedCard.card_number.slice(-4)}` : t("atm.terminal")}
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div className="p-6 space-y-4">
                        <div className="bg-[rgb(var(--bg-secondary))] rounded-xl p-4 border border-white/5">
                            <div className="h-3 w-28 bg-[rgb(var(--bg-muted))]/40 rounded mb-3 animate-pulse" />
                            <div className="h-5 w-44 bg-[rgb(var(--bg-muted))]/40 rounded animate-pulse" />
                        </div>

                        <div className="bg-gradient-to-br from-[rgb(var(--accent-primary))]/10 to-[rgb(var(--accent-secondary))]/10 rounded-xl p-5 border border-[rgb(var(--accent-primary))]/20">
                            <div className="flex justify-between items-center">
                                <div className="flex-1">
                                    <div className="h-3 w-32 bg-[rgb(var(--bg-muted))]/40 rounded mb-2 animate-pulse" />
                                    <div className="h-8 w-36 bg-[rgb(var(--bg-muted))]/40 rounded animate-pulse" />
                                </div>
                                <div className="text-right bg-[rgb(var(--bg-card))]/50 px-4 py-3 rounded-lg border border-white/10">
                                    <div className="h-3 w-16 bg-[rgb(var(--bg-muted))]/40 rounded mb-1 animate-pulse" />
                                    <div className="h-5 w-20 bg-[rgb(var(--bg-muted))]/40 rounded animate-pulse" />
                                </div>
                            </div>
                        </div>

                        <div className="pt-2">
                            <ATMSkeleton />
                        </div>

                        <div className="flex items-center justify-center gap-2 pt-4">
                            <Loader2 className="animate-spin text-[rgb(var(--accent-primary))]" size={20} />
                            <p className="text-[rgb(var(--text-secondary))] text-sm font-medium">
                                {loadingReason === "pin"
                                    ? t("atm.verifying")
                                    : t("atm.loadingAccount")}
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        )
    }

    return (
        <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
            <div className="w-full max-w-lg bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-3">
                            {view !== "menu" && (
                                <button
                                    onClick={handleBack}
                                    className="p-2 hover:bg-white/10 rounded-lg transition-all"
                                >
                                    <X size={20} className="text-white" />
                                </button>
                            )}
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                                    <CreditCard className="text-white" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.title")}</h2>
                                    <p className="text-white/70 text-sm">
                                        {selectedCard ? `**** ${selectedCard.card_number.slice(-4)}` : t("atm.terminal")}
                                    </p>
                                </div>
                            </div>
                        </div>
                        <button
                            onClick={onClose}
                            className="text-white/70 hover:text-white transition-all hover:bg-white/10 p-2 rounded-lg"
                        >
                            <X size={20} />
                        </button>
                    </div>
                </div>

                <div className="p-6 space-y-4">
                    <div className="bg-[rgb(var(--bg-secondary))] rounded-xl p-4 border border-white/5">
                        <label className="text-[rgb(var(--text-muted))] text-xs uppercase tracking-wider mb-2 block font-medium">
                            {t("atm.linkedAccount")}
                        </label>
                        <p className="text-[rgb(var(--text-primary))] font-medium text-lg">{selectedAccount?.account_name}</p>
                    </div>

                    <div className="bg-gradient-to-br from-[rgb(var(--accent-primary))]/10 to-[rgb(var(--accent-secondary))]/10 rounded-xl p-5 border border-[rgb(var(--accent-primary))]/20">
                        <div className="flex justify-between items-center">
                            <div>
                                <p className="text-[rgb(var(--text-muted))] text-xs uppercase tracking-wider mb-1">
                                    {t("atm.availableBalance")}
                                </p>
                                <p className="text-3xl font-bold text-[rgb(var(--text-primary))]">
                                    {selectedAccount ? formatMoney(selectedAccount.balance) : "$0.00"}
                                </p>
                            </div>
                            <div className="text-right bg-[rgb(var(--bg-card))]/50 px-4 py-2 rounded-lg border border-white/10">
                                <p className="text-[rgb(var(--text-muted))] text-xs uppercase tracking-wider mb-1">{t("atm.cash")}</p>
                                <p className="text-lg font-bold text-[rgb(var(--text-primary))]">{formatMoney(data.cash)}</p>
                            </div>
                        </div>
                    </div>

                    {view === "menu" && (
                        <div className="grid grid-cols-2 gap-3 pt-2">
                            <button
                                onClick={() => setView("deposit")}
                                className="flex flex-col items-center gap-3 p-5 bg-[rgb(var(--bg-secondary))] hover:bg-white/10 rounded-xl transition-all duration-200 border border-white/5 hover:border-[rgb(var(--success))]/30 group hover:scale-105"
                            >
                                <div className="p-3 bg-[rgb(var(--success))]/20 rounded-xl group-hover:bg-[rgb(var(--success))]/30 transition-colors">
                                    <ArrowDownCircle className="text-[rgb(var(--success))]" size={28} />
                                </div>
                                <span className="text-[rgb(var(--text-primary))] font-medium">{t("atm.deposit")}</span>
                            </button>

                            <button
                                onClick={() => setView("withdraw")}
                                className="flex flex-col items-center gap-3 p-5 bg-[rgb(var(--bg-secondary))] hover:bg-white/10 rounded-xl transition-all duration-200 border border-white/5 hover:border-[rgb(var(--danger))]/30 group hover:scale-105"
                            >
                                <div className="p-3 bg-[rgb(var(--danger))]/20 rounded-xl group-hover:bg-[rgb(var(--danger))]/30 transition-colors">
                                    <ArrowUpCircle className="text-[rgb(var(--danger))]" size={28} />
                                </div>
                                <span className="text-[rgb(var(--text-primary))] font-medium">{t("atm.withdraw")}</span>
                            </button>

                            <button
                                onClick={() => setView("transfer")}
                                className="flex flex-col items-center gap-3 p-5 bg-[rgb(var(--bg-secondary))] hover:bg-white/10 rounded-xl transition-all duration-200 border border-white/5 hover:border-[rgb(var(--accent-primary))]/30 group hover:scale-105 col-span-2"
                            >
                                <div className="p-3 bg-[rgb(var(--accent-primary))]/20 rounded-xl group-hover:bg-[rgb(var(--accent-primary))]/30 transition-colors">
                                    <ArrowLeftRight className="text-[rgb(var(--accent-primary))]" size={28} />
                                </div>
                                <span className="text-[rgb(var(--text-primary))] font-medium">{t("atm.transfer")}</span>
                            </button>
                        </div>
                    )}

                    {view === "deposit" && (
                        <div className="space-y-4 animate-in">
                            <div className="flex items-center gap-2 text-[rgb(var(--success))] pb-2">
                                <ArrowDownCircle size={20} />
                                <span className="font-semibold">{t("atm.depositMoney")}</span>
                            </div>
                            <div className="relative">
                                <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]" size={20} />
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--success))]/50 focus:border-[rgb(var(--success))]/50 outline-none transition-all"
                                />
                            </div>
                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={handleBack}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--bg-secondary))] hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel")}
                                </button>
                                <button
                                    onClick={() => handleAction("deposit")}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--success))] hover:bg-[rgb(var(--success))]/90 text-white shadow-lg shadow-[rgb(var(--success))]/20"
                                >
                                    {t("common.confirm")}
                                </button>
                            </div>
                        </div>
                    )}

                    {view === "withdraw" && (
                        <div className="space-y-4 animate-in">
                            <div className="flex items-center gap-2 text-[rgb(var(--danger))] pb-2">
                                <ArrowUpCircle size={20} />
                                <span className="font-semibold">{t("atm.withdrawMoney")}</span>
                            </div>
                            <div className="relative">
                                <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]" size={20} />
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--danger))]/50 focus:border-[rgb(var(--danger))]/50 outline-none transition-all"
                                />
                            </div>
                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={handleBack}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--bg-secondary))] hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel")}
                                </button>
                                <button
                                    onClick={() => handleAction("withdraw")}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--danger))] hover:bg-[rgb(var(--danger))]/90 text-white shadow-lg shadow-[rgb(var(--danger))]/20"
                                >
                                    {t("common.confirm")}
                                </button>
                            </div>
                        </div>
                    )}

                    {view === "transfer" && (
                        <div className="space-y-4 animate-in">
                            <div className="flex items-center gap-2 text-[rgb(var(--accent-primary))] pb-2">
                                <ArrowLeftRight size={20} />
                                <span className="font-semibold">{t("atm.transferMoney")}</span>
                            </div>
                            <div className="relative">
                                <DollarSign className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]" size={20} />
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--accent-primary))]/50 focus:border-[rgb(var(--accent-primary))]/50 outline-none transition-all"
                                />
                            </div>
                            <div>
                                <label className="text-[rgb(var(--text-muted))] text-xs uppercase tracking-wider mb-2 block font-medium">
                                    {t("atm.targetAccount")}
                                </label>
                                <div className="relative">
                                    <Landmark className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]" size={20} />
                                    <input
                                        type="number"
                                        placeholder="****"
                                        value={targetAccountId}
                                        onChange={(e) => setTargetAccountId(e.target.value)}
                                        className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--accent-primary))]/50 focus:border-[rgb(var(--accent-primary))]/50 outline-none transition-all"
                                    />
                                </div>
                            </div>
                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={handleBack}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--bg-secondary))] hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel")}
                                </button>
                                <button
                                    onClick={() => handleAction("transfer")}
                                    className="flex-1 py-3 rounded-xl bg-[rgb(var(--accent-primary))] hover:bg-[rgb(var(--accent-primary))]/90 text-white shadow-lg shadow-[rgb(var(--accent-primary))]/20"
                                >
                                    {t("common.confirm")}
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}