"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { DollarSign, ArrowDownCircle, ArrowUpCircle, CreditCard, Loader2, ArrowLeftRight, Landmark, X } from "lucide-react"
import { Button } from "./ui/Button"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"
import { useLocale } from "../hooks/useLocale"

interface Account {
    id: number
    account_name: string
    balance: string
}

interface ATMData {
    accounts: Account[]
    cash: number
    cardNumber?: string
}

interface AtmInterfaceProps {
    data: ATMData
    requirePin: boolean
    onClose: () => void
    onDeposit: (accountId: number, amount: number) => void
    onWithdraw: (accountId: number, amount: number) => void
    onTransfer: (fromId: number, toId: number, amount: number) => void
    onVerifyPin: (pin: string) => Promise<{ success: boolean; error?: string }>
}

type ATMView = "pin" | "loading" | "menu" | "deposit" | "withdraw" | "transfer" | "balance"

export const AtmInterface: React.FC<AtmInterfaceProps> = ({
    data,
    requirePin,
    onClose,
    onDeposit,
    onWithdraw,
    onTransfer,
    onVerifyPin,
}) => {
    const [view, setView] = useState<ATMView>(requirePin ? "pin" : "menu")
    const [selectedAccount, setSelectedAccount] = useState<Account | null>(null)
    const [amount, setAmount] = useState("")
    const [targetAccountId, setTargetAccountId] = useState("")
    const [pin, setPin] = useState("")
    const [pinError, setPinError] = useState("")
    const [isLoading, setIsLoading] = useState(false)
    const [isVerified, setIsVerified] = useState(!requirePin)
    const [accounts, setAccounts] = useState<Account[]>(data.accounts)
    const { t } = useLocale()

    if (isVerified) {
        //
    }

    useEffect(() => {
        setAccounts(data.accounts)
    }, [data.accounts])

    useEffect(() => {
        if (data.accounts.length > 0 && !selectedAccount) {
            setSelectedAccount(data.accounts[0])
        }
    }, [data.accounts, selectedAccount])

    const handlePinSubmit = async () => {
        if (pin.length !== 4) {
            setPinError("El PIN debe tener 4 dígitos")
            return
        }

        setIsLoading(true)
        setPinError("")

        try {
            const result = await onVerifyPin(pin)
            if (result.success) {
                setIsVerified(true)
                setView("loading")

                setTimeout(() => {
                    setView("menu")
                }, 1200)
            } else {
                setPinError(result.error || "PIN incorrecto")
                setPin("")

                if (result.error?.toLowerCase().includes("bloqueada")) {
                    onClose()
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
        if (view !== "pin") return;

        const handleKeyDown = (e: KeyboardEvent) => {
            if (isLoading) return;

            if (e.key >= "0" && e.key <= "9") {
                handlePinKeyPress(e.key);
            } else if (e.key === "Backspace") {
                handlePinBackspace();
            } else if (e.key === "Enter") {
                handlePinSubmit();
            }
        };

        window.addEventListener("keydown", handleKeyDown);
        return () => window.removeEventListener("keydown", handleKeyDown);
    }, [pin, isLoading, view]);

    const handleAction = (action: "deposit" | "withdraw" | "transfer") => {
        if (!selectedAccount) return
        const numAmount = Number.parseFloat(amount)
        if (isNaN(numAmount) || numAmount <= 0) return

        let updatedAccounts = [...accounts]

        if (action === "deposit") {
            onDeposit(selectedAccount.id, numAmount)
            updatedAccounts = updatedAccounts.map((acc) =>
                acc.id === selectedAccount.id
                    ? { ...acc, balance: (Number.parseFloat(acc.balance) + numAmount).toString() }
                    : acc,
            )
        } else if (action === "withdraw") {
            onWithdraw(selectedAccount.id, numAmount)
            updatedAccounts = updatedAccounts.map((acc) =>
                acc.id === selectedAccount.id
                    ? { ...acc, balance: (Number.parseFloat(acc.balance) - numAmount).toString() }
                    : acc,
            )
        } else if (action === "transfer") {
            const targetId = Number.parseInt(targetAccountId)
            if (isNaN(targetId)) return
            onTransfer(selectedAccount.id, targetId, numAmount)
            updatedAccounts = updatedAccounts.map((acc) => {
                if (acc.id === selectedAccount.id)
                    return { ...acc, balance: (Number.parseFloat(acc.balance) - numAmount).toString() }
                if (acc.id === targetId) return { ...acc, balance: (Number.parseFloat(acc.balance) + numAmount).toString() }
                return acc
            })
        }

        setAccounts(updatedAccounts)
        setSelectedAccount(updatedAccounts.find((acc) => acc.id === selectedAccount.id) || null)
        setAmount("")
        setTargetAccountId("")
        setView("menu")
    }

    const formatMoney = (value: string | number) => {
        const num = typeof value === "string" ? Number.parseFloat(value) : value
        return new Intl.NumberFormat("es-ES", { style: "currency", currency: "USD" }).format(num)
    }

    if (view === "pin") {
        return (
            <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50 p-4 animate-in">
                <div className="w-full max-w-md bg-[rgb(var(--bg-card))] rounded-3xl overflow-hidden border border-white/10 shadow-2xl">
                    <div className="bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6">
                        <div className="flex items-center justify-between">
                            <div className="flex items-center gap-3">
                                <div className="p-2 bg-white/20 rounded-xl backdrop-blur-sm">
                                    <CreditCard className="text-white" size={24} />
                                </div>
                                <div>
                                    <h2 className="text-white font-bold text-xl">{t("atm.title")}</h2>
                                    <p className="text-white/70 text-sm">{t("atm.secureAccess")}</p>
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
                                    {data.cardNumber ? `${t("atm.card")} **** ${data.cardNumber.slice(-4)}` : t("atm.terminal")}
                                </p>
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
                            {t("atm.selectedAccount")}
                        </label>
                        <Select
                            value={selectedAccount?.id.toString() || ""}
                            onValueChange={(value) => {
                                const acc = accounts.find((a) => a.id === Number.parseInt(value))
                                if (acc) setSelectedAccount(acc)
                            }}
                        >
                            <SelectTrigger className="w-full bg-transparent border-none h-auto p-0 text-[rgb(var(--text-primary))] font-medium text-lg focus:ring-0">
                                <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                                {accounts.map((acc) => (
                                    <SelectItem key={acc.id} value={acc.id.toString()}>
                                        {acc.account_name} - {formatMoney(acc.balance)}
                                    </SelectItem>
                                ))}
                            </SelectContent>
                        </Select>
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

                    {view === "loading" && (
                        <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md z-50">
                            <div className="bg-[rgb(var(--bg-card))] rounded-3xl p-10 border border-white/10 shadow-2xl flex flex-col items-center gap-4 animate-in">
                                <Loader2
                                    size={48}
                                    className="animate-spin text-[rgb(var(--accent-primary))]"
                                />
                                <p className="text-[rgb(var(--text-muted))] text-sm">
                                    {t("modals.common.verifyingAccess")}
                                </p>
                            </div>
                        </div>
                    )}

                    {view === "deposit" && (
                        <div className="space-y-4 animate-in">
                            <div className="flex items-center gap-2 text-[rgb(var(--success))] pb-2">
                                <ArrowDownCircle size={20} />
                                <span className="font-semibold">{t("atm.depositMoney")}</span>
                            </div>
                            <div className="relative">
                                <DollarSign
                                    className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]"
                                    size={20}
                                />
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--success))]/50 focus:border-[rgb(var(--success))]/50 outline-none transition-all"
                                />
                            </div>
                            <div className="flex gap-3 pt-2">
                                <Button
                                    onClick={() => {
                                        setView("menu")
                                        setAmount("")
                                    }}
                                    variant="secondary"
                                    className="flex-1"
                                >
                                    {t("common.cancel")}
                                </Button>
                                <Button
                                    onClick={() => handleAction("deposit")}
                                    className="flex-1 bg-[rgb(var(--success))] hover:bg-[rgb(var(--success))]/90 shadow-lg shadow-[rgb(var(--success))]/20"
                                >
                                    {t("common.confirm")}
                                </Button>
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
                                <DollarSign
                                    className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]"
                                    size={20}
                                />
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={amount}
                                    onChange={(e) => setAmount(e.target.value)}
                                    className="w-full bg-[rgb(var(--bg-secondary))] border border-white/10 rounded-xl p-4 pl-12 text-[rgb(var(--text-primary))] text-lg font-medium focus:ring-2 focus:ring-[rgb(var(--danger))]/50 focus:border-[rgb(var(--danger))]/50 outline-none transition-all"
                                />
                            </div>
                            <div className="flex gap-3 pt-2">
                                <Button
                                    onClick={() => {
                                        setView("menu")
                                        setAmount("")
                                    }}
                                    variant="secondary"
                                    className="flex-1"
                                >
                                    {t("common.cancel")}
                                </Button>
                                <Button
                                    onClick={() => handleAction("withdraw")}
                                    className="flex-1 bg-[rgb(var(--danger))] hover:bg-[rgb(var(--danger))]/90 shadow-lg shadow-[rgb(var(--danger))]/20"
                                >
                                    {t("common.confirm")}
                                </Button>
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
                                <DollarSign
                                    className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]"
                                    size={20}
                                />
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
                                    <Landmark
                                        className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]"
                                        size={20}
                                    />
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
                                <Button
                                    onClick={() => {
                                        setView("menu")
                                        setAmount("")
                                        setTargetAccountId("")
                                    }}
                                    variant="secondary"
                                    className="flex-1"
                                >
                                    {t("common.cancel")}
                                </Button>
                                <Button
                                    onClick={() => handleAction("transfer")}
                                    className="flex-1 bg-[rgb(var(--accent-primary))] hover:bg-[rgb(var(--accent-primary))]/90 shadow-lg shadow-[rgb(var(--accent-primary))]/20"
                                >
                                    {t("common.confirm")}
                                </Button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    )
}
