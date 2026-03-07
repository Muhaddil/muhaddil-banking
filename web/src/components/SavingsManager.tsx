"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { PiggyBank, Plus, Target, TrendingUp, ArrowDown, ArrowUp, Trash2, X } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"

interface SavingsGoal {
    id: number
    account_id: number
    account_name: string
    goal_name: string
    goal_amount: string
    current_amount: string
    interest_rate: number
    last_interest_date: string
    created_at: string
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface SavingsConfig {
    enabled: boolean
    maxPerAccount: number
    interestRate: number
    minDeposit: number
    maxGoalAmount: number
}

interface SavingsManagerProps {
    savings: SavingsGoal[]
    accounts: Account[]
    config: SavingsConfig
    onCreateSavings: (data: { accountId: number; goalName: string; goalAmount: number }) => void
    onDepositSavings: (data: { savingsId: number; amount: number }) => void
    onWithdrawSavings: (data: { savingsId: number; amount: number }) => void
    onDeleteSavings: (savingsId: number) => void
}

export const SavingsManager: React.FC<SavingsManagerProps> = ({
    savings, accounts, config, onCreateSavings, onDepositSavings, onWithdrawSavings, onDeleteSavings
}) => {
    const { t } = useLocale()
    const [showCreateModal, setShowCreateModal] = useState(false)
    const [showDepositModal, setShowDepositModal] = useState<SavingsGoal | null>(null)
    const [showWithdrawModal, setShowWithdrawModal] = useState<SavingsGoal | null>(null)

    const [selectedAccount, setSelectedAccount] = useState<number>(accounts[0]?.id || 0)
    const [goalName, setGoalName] = useState("")
    const [goalAmount, setGoalAmount] = useState("")

    const [amount, setAmount] = useState("")

    const handleCreate = () => {
        if (!goalName || !goalAmount || !selectedAccount) return
        onCreateSavings({ accountId: selectedAccount, goalName, goalAmount: parseFloat(goalAmount) })
        setShowCreateModal(false)
        setGoalName("")
        setGoalAmount("")
    }

    const handleDeposit = () => {
        if (!showDepositModal || !amount) return
        onDepositSavings({ savingsId: showDepositModal.id, amount: parseFloat(amount) })
        setShowDepositModal(null)
        setAmount("")
    }

    const handleWithdraw = () => {
        if (!showWithdrawModal || !amount) return
        onWithdrawSavings({ savingsId: showWithdrawModal.id, amount: parseFloat(amount) })
        setShowWithdrawModal(null)
        setAmount("")
    }

    const getProgress = (current: string, goal: string) => {
        const c = parseFloat(current) || 0
        const g = parseFloat(goal) || 1
        return Math.min(100, (c / g) * 100)
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <PiggyBank className="text-[rgb(var(--accent-glow))]" size={24} />
                        {t("savings.title")}
                    </h2>
                    <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">{t("savings.subtitle")}</p>
                </div>
                <Button onClick={() => setShowCreateModal(true)} className="flex items-center gap-2">
                    <Plus size={16} /> {t("savings.createGoal")}
                </Button>
            </div>

            <Card className="p-4 flex items-center gap-3">
                <TrendingUp size={20} className="text-green-400" />
                <span className="text-sm text-[rgb(var(--text-secondary))]">
                    {t("savings.interestInfo", { rate: String((config.interestRate * 100).toFixed(1)) })}
                </span>
            </Card>

            {savings.length === 0 ? (
                <Card className="p-8 text-center">
                    <PiggyBank size={48} className="mx-auto mb-4 text-[rgb(var(--text-secondary))] opacity-40" />
                    <p className="text-[rgb(var(--text-secondary))]">{t("savings.noSavings")}</p>
                </Card>
            ) : (
                <div className="grid gap-4">
                    {savings.map((s) => {
                        const progress = getProgress(s.current_amount, s.goal_amount)
                        return (
                            <Card key={s.id} className="p-5">
                                <div className="flex items-start justify-between mb-3">
                                    <div>
                                        <h3 className="text-white font-semibold flex items-center gap-2">
                                            <Target size={16} className="text-[rgb(var(--accent-glow))]" />
                                            {s.goal_name}
                                        </h3>
                                        <p className="text-xs text-[rgb(var(--text-secondary))] mt-1">
                                            {t("savings.account")}: {s.account_name}
                                        </p>
                                    </div>
                                    <button onClick={() => onDeleteSavings(s.id)}
                                        className="p-2 hover:bg-red-500/20 rounded-lg transition-colors">
                                        <Trash2 size={16} className="text-red-400" />
                                    </button>
                                </div>

                                <div className="mb-3">
                                    <div className="flex justify-between text-sm mb-1">
                                        <span className="text-[rgb(var(--text-secondary))]">{t("savings.progress")}</span>
                                        <span className="text-white font-medium">{progress.toFixed(1)}%</span>
                                    </div>
                                    <div className="w-full h-3 bg-white/10 rounded-full overflow-hidden">
                                        <div
                                            className="h-full rounded-full bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] transition-all duration-500"
                                            style={{ width: `${progress}%` }}
                                        />
                                    </div>
                                </div>

                                <div className="flex items-center justify-between mb-4">
                                    <div>
                                        <p className="text-xs text-[rgb(var(--text-secondary))]">{t("savings.current")}</p>
                                        <p className="text-lg font-bold text-white">${parseFloat(s.current_amount).toLocaleString()}</p>
                                    </div>
                                    <div className="text-right">
                                        <p className="text-xs text-[rgb(var(--text-secondary))]">{t("savings.goal")}</p>
                                        <p className="text-lg font-bold text-[rgb(var(--accent-glow))]">
                                            ${parseFloat(s.goal_amount).toLocaleString()}
                                        </p>
                                    </div>
                                </div>

                                <div className="flex gap-2">
                                    <Button onClick={() => { setShowDepositModal(s); setAmount(""); }}
                                        className="flex-1 flex items-center justify-center gap-2 text-sm">
                                        <ArrowDown size={14} /> {t("savings.deposit")}
                                    </Button>
                                    <Button onClick={() => { setShowWithdrawModal(s); setAmount(""); }}
                                        variant="ghost"
                                        className="flex-1 flex items-center justify-center gap-2 text-sm">
                                        <ArrowUp size={14} /> {t("savings.withdraw")}
                                    </Button>
                                </div>
                            </Card>
                        )
                    })}
                </div>
            )}

            {showCreateModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("savings.createGoal")}</h3>
                            <button onClick={() => setShowCreateModal(false)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("savings.selectAccount")}</label>
                                <Select
                                    value={String(selectedAccount)}
                                    onValueChange={(value: string) => setSelectedAccount(Number(value))}
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder={t("savings.selectAccount")} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {accounts.map(a => (
                                            <SelectItem key={a.id} value={String(a.id)}>
                                                {a.account_name}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("savings.goalName")}</label>
                                <input type="text" value={goalName} onChange={e => setGoalName(e.target.value)}
                                    placeholder={t("savings.goalNamePlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("savings.goalAmount")}</label>
                                <input type="number" value={goalAmount} onChange={e => setGoalAmount(e.target.value)}
                                    placeholder="10000"
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <Button onClick={handleCreate} className="w-full">{t("savings.create")}</Button>
                        </div>
                    </Card>
                </div>
            )}

            {showDepositModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("savings.depositTo")} {showDepositModal.goal_name}</h3>
                            <button onClick={() => setShowDepositModal(null)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <p className="text-sm text-[rgb(var(--text-secondary))]">
                                {t("savings.minDeposit")}: ${config.minDeposit}
                            </p>
                            <input type="number" value={amount} onChange={e => setAmount(e.target.value)}
                                placeholder={t("savings.amount")}
                                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            <Button onClick={handleDeposit} className="w-full">{t("savings.confirmDeposit")}</Button>
                        </div>
                    </Card>
                </div>
            )}

            {showWithdrawModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("savings.withdrawFrom")} {showWithdrawModal.goal_name}</h3>
                            <button onClick={() => setShowWithdrawModal(null)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <p className="text-sm text-[rgb(var(--text-secondary))]">
                                {t("savings.available")}: ${parseFloat(showWithdrawModal.current_amount).toLocaleString()}
                            </p>
                            <input type="number" value={amount} onChange={e => setAmount(e.target.value)}
                                placeholder={t("savings.amount")}
                                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            <Button onClick={handleWithdraw} className="w-full">{t("savings.confirmWithdraw")}</Button>
                        </div>
                    </Card>
                </div>
            )}
        </div>
    )
}