"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { ArrowUpRight, ArrowDownLeft, Search, Filter } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface Transaction {
    id: number
    account_id: number
    type: string
    amount: string
    description: string
    created_at: string
}

interface TransactionHistoryProps {
    transactions: Transaction[]
}

export const TransactionHistory: React.FC<TransactionHistoryProps> = ({ transactions }) => {
    const { t } = useLocale()
    const [searchTerm, setSearchTerm] = useState("")
    const [filterType, setFilterType] = useState<"all" | "income" | "expense">("all")

    const filteredTransactions = transactions.filter((tx) => {
        const amount = Number.parseFloat(tx.amount)
        const matchesSearch = tx.description.toLowerCase().includes(searchTerm.toLowerCase())
        const matchesFilter =
            filterType === "all" || (filterType === "income" && amount > 0) || (filterType === "expense" && amount < 0)
        return matchesSearch && matchesFilter
    })

    return (
        <div className="space-y-6 animate-in">
            <div className="flex flex-col md:flex-row gap-4">
                <div className="flex-1 relative">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--text-muted))]" size={20} />
                    <input
                        type="text"
                        placeholder={t("transactions.search")}
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-10 pr-4 py-3 rounded-xl bg-[rgb(var(--bg-card))] border border-white/10 text-white placeholder:text-[rgb(var(--text-muted))] focus:border-[rgb(var(--accent-primary))] focus:outline-none transition-all duration-200"
                    />
                </div>

                <div className="flex gap-2 bg-[rgb(var(--bg-card))] p-1 rounded-xl border border-white/10">
                    <button
                        onClick={() => setFilterType("all")}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${filterType === "all"
                                ? "bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] text-white shadow-lg"
                                : "text-[rgb(var(--text-secondary))] hover:text-white"
                            }`}
                    >
                        {t("transactions.all")}
                    </button>
                    <button
                        onClick={() => setFilterType("income")}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${filterType === "income"
                                ? "bg-gradient-to-r from-green-500 to-emerald-600 text-white shadow-lg"
                                : "text-[rgb(var(--text-secondary))] hover:text-white"
                            }`}
                    >
                        {t("transactions.income")}
                    </button>
                    <button
                        onClick={() => setFilterType("expense")}
                        className={`px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 ${filterType === "expense"
                                ? "bg-gradient-to-r from-red-500 to-rose-600 text-white shadow-lg"
                                : "text-[rgb(var(--text-secondary))] hover:text-white"
                            }`}
                    >
                        {t("transactions.expenses")}
                    </button>
                </div>
            </div>

            <Card
                title={t("transactions.history")}
                subtitle={t("transactions.count", { count: filteredTransactions.length })}
            >
                <div className="space-y-3 mt-4 max-h-[600px] overflow-y-auto custom-scrollbar pr-2">
                    {filteredTransactions.length === 0 ? (
                        <div className="text-center py-16">
                            <div className="w-16 h-16 bg-[rgb(var(--bg-secondary))] rounded-full flex items-center justify-center mx-auto mb-4">
                                <Filter className="text-[rgb(var(--text-muted))]" size={32} />
                            </div>
                            <p className="text-[rgb(var(--text-secondary))]">
                                {searchTerm || filterType !== "all" ? t("transactions.noResults") : t("transactions.noTransactions")}
                            </p>
                        </div>
                    ) : (
                        filteredTransactions.map((tx) => {
                            const amount = Number.parseFloat(tx.amount)
                            const isIncome = amount > 0

                            return (
                                <div
                                    key={tx.id}
                                    className="group flex items-center justify-between p-4 rounded-xl bg-white/5 hover:bg-white/10 transition-all duration-300 border border-white/5 hover:border-white/10 hover:scale-[1.01] cursor-pointer"
                                >
                                    <div className="flex items-center gap-4">
                                        <div
                                            className={`p-3 rounded-full transition-all duration-300 ${isIncome
                                                    ? "bg-emerald-500/20 text-emerald-400 group-hover:bg-emerald-500/30"
                                                    : "bg-red-500/20 text-red-400 group-hover:bg-red-500/30"
                                                }`}
                                        >
                                            {isIncome ? <ArrowDownLeft size={20} /> : <ArrowUpRight size={20} />}
                                        </div>
                                        <div>
                                            <p className="text-white font-medium">{tx.description}</p>
                                            <div className="flex items-center gap-2 mt-1">
                                                <p className="text-sm text-[rgb(var(--text-secondary))]">
                                                    {new Date(tx.created_at).toLocaleDateString("es-ES", {
                                                        day: "numeric",
                                                        month: "short",
                                                        year: "numeric",
                                                    })}
                                                </p>
                                                <span className="text-[rgb(var(--text-muted))]">•</span>
                                                <p className="text-xs text-[rgb(var(--text-muted))] uppercase tracking-wide">{tx.type}</p>
                                            </div>
                                        </div>
                                    </div>
                                    <div className="text-right">
                                        <p className={`font-bold text-lg ${isIncome ? "text-emerald-400" : "text-red-400"}`}>
                                            {isIncome ? "+" : ""}${Math.abs(amount).toLocaleString()}
                                        </p>
                                    </div>
                                </div>
                            )
                        })
                    )}
                </div>
            </Card>
        </div>
    )
}
