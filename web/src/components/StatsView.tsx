"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { Card } from "./ui/Card"
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip } from "recharts"
import { TrendingUp, TrendingDown, DollarSign, Activity } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { createPortal } from "react-dom"

interface StatsViewProps {
    data: any[]
    totalIncome: number
    totalExpense: number
    currentBalance: number
    hasAccount?: boolean
}

const StatsView: React.FC<StatsViewProps> = ({ data, totalIncome, totalExpense, currentBalance, hasAccount }) => {
    const { t } = useLocale()
    const netFlow = totalIncome - totalExpense
    const isPositive = netFlow >= 0

    const [tooltip, setTooltip] = useState<{
        text: string
        x: number
        y: number
    } | null>(null)

    const showTooltip = (e: React.MouseEvent, text: string) => {
        setTooltip({
            text,
            x: e.clientX,
            y: e.clientY
        })
    }

    const hideTooltip = () => setTooltip(null)

    const hasTransactions = data.length > 0
    const hasFinancialActivity = totalIncome > 0 || totalExpense > 0

    const formatCurrency = (value: number): string => {
        const abs = Math.abs(value)
        if (abs >= 1_000_000_000) return `$${(value / 1_000_000_000).toFixed(2)}B`
        if (abs >= 1_000_000) return `$${(value / 1_000_000).toFixed(2)}M`
        if (abs >= 1_000) return `$${(value / 1_000).toFixed(1)}K`
        return `$${value.toLocaleString()}`
    }

    const getFontSize = (value: number): string => {
        const len = formatCurrency(value).length
        if (len > 12) return "text-lg"
        if (len > 9) return "text-xl"
        if (len > 7) return "text-2xl"
        return "text-3xl"
    }

    if (!hasTransactions && !hasFinancialActivity) {
        return (
            <div className="space-y-6 animate-in">
                <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-slate-700 via-slate-800 to-slate-900 p-12 md:p-16 shadow-2xl">
                    <div className="absolute top-0 right-0 w-96 h-96 bg-white/5 rounded-full blur-3xl -mr-32 -mt-32" />
                    <div className="absolute bottom-0 left-0 w-96 h-96 bg-white/5 rounded-full blur-3xl -ml-32 -mb-32" />

                    <div className="relative z-10 text-center max-w-2xl mx-auto">
                        <div className="inline-flex p-6 rounded-3xl bg-white/10 backdrop-blur-sm mb-6">
                            <Activity size={48} className="text-white/70" />
                        </div>

                        <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">
                            {t("stats.emptyState.title") || "Sin actividad financiera"}
                        </h2>

                        <p className="text-lg text-white/60 mb-8">
                            {t("stats.emptyState.subtitle") || "Realiza tu primera transacción para ver tus estadísticas aquí"}
                        </p>

                        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-8">
                            <div className="bg-white/5 backdrop-blur-sm p-6 rounded-2xl border border-white/10">
                                <TrendingUp size={32} className="text-emerald-400/50 mx-auto mb-3" />
                                <p className="text-white/50 text-sm font-medium">
                                    {t("stats.emptyState.deposit") || "Deposita dinero"}
                                </p>
                            </div>

                            <div className="bg-white/5 backdrop-blur-sm p-6 rounded-2xl border border-white/10">
                                <TrendingDown size={32} className="text-red-400/50 mx-auto mb-3" />
                                <p className="text-white/50 text-sm font-medium">
                                    {t("stats.emptyState.withdraw") || "Retira fondos"}
                                </p>
                            </div>

                            <div className="bg-white/5 backdrop-blur-sm p-6 rounded-2xl border border-white/10">
                                <DollarSign size={32} className="text-blue-400/50 mx-auto mb-3" />
                                <p className="text-white/50 text-sm font-medium">
                                    {t("stats.emptyState.transfer") || "Transfiere dinero"}
                                </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-6 animate-in">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-blue-500 to-blue-600 p-6 shadow-xl shadow-blue-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10 min-w-0">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <DollarSign size={24} className="text-white" />
                            </div>
                            <Activity size={40} className="text-white/20" />
                        </div>
                        <p className="text-blue-100 text-sm mb-1 font-medium">{t("stats.currentBalance")}</p>
                        <p className={`${getFontSize(currentBalance)} font-bold text-white truncate cursor-help`}
                            onMouseEnter={(e) => showTooltip(e, `$${currentBalance.toLocaleString()}`)}
                            onMouseMove={(e) => showTooltip(e, `$${currentBalance.toLocaleString()}`)}
                            onMouseLeave={hideTooltip}>
                            {formatCurrency(currentBalance)}
                        </p>
                    </div>
                </div>

                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-600 p-6 shadow-xl shadow-emerald-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10 min-w-0">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <TrendingUp size={24} className="text-white" />
                            </div>
                            <TrendingUp size={40} className="text-white/20" />
                        </div>
                        <p className="text-emerald-100 text-sm mb-1 font-medium">{t("stats.totalIncome")}</p>
                        <p className={`${getFontSize(totalIncome)} font-bold text-white truncate cursor-help`}
                            onMouseEnter={(e) => showTooltip(e, `$${totalIncome.toLocaleString()}`)}
                            onMouseMove={(e) => showTooltip(e, `$${totalIncome.toLocaleString()}`)}
                            onMouseLeave={hideTooltip}>
                            {formatCurrency(totalIncome)}
                        </p>
                    </div>
                </div>

                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-red-500 to-red-600 p-6 shadow-xl shadow-red-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10 min-w-0">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <TrendingDown size={24} className="text-white" />
                            </div>
                            <TrendingDown size={40} className="text-white/20" />
                        </div>
                        <p className="text-red-100 text-sm mb-1 font-medium">{t("stats.totalExpenses")}</p>
                        <p className={`${getFontSize(totalExpense)} font-bold text-white truncate cursor-help`}
                            onMouseEnter={(e) => showTooltip(e, `$${totalExpense.toLocaleString()}`)}
                            onMouseMove={(e) => showTooltip(e, `$${totalExpense.toLocaleString()}`)}
                            onMouseLeave={hideTooltip}>
                            {formatCurrency(totalExpense)}
                        </p>
                    </div>
                </div>

                <div
                    className={`relative overflow-hidden rounded-2xl bg-gradient-to-br p-6 shadow-xl ${isPositive
                        ? "from-purple-500 to-purple-600 shadow-purple-500/30"
                        : "from-orange-500 to-orange-600 shadow-orange-500/30"
                        }`}
                >
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10 min-w-0">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                {isPositive ? (
                                    <TrendingUp size={24} className="text-white" />
                                ) : (
                                    <TrendingDown size={24} className="text-white" />
                                )}
                            </div>
                            <Activity size={40} className="text-white/20" />
                        </div>
                        <p className={`text-sm mb-1 font-medium ${isPositive ? "text-purple-100" : "text-orange-100"}`}>
                            {t("stats.netFlow")}
                        </p>
                        <p className={`${getFontSize(netFlow)} font-bold text-white truncate cursor-help`}
                            onMouseEnter={(e) => showTooltip(e, `${isPositive ? "+" : "-"}$${Math.abs(netFlow).toLocaleString()}`)}
                            onMouseMove={(e) => showTooltip(e, `${isPositive ? "+" : "-"}$${Math.abs(netFlow).toLocaleString()}`)}
                            onMouseLeave={hideTooltip}>
                            {isPositive ? "+" : "-"}{formatCurrency(Math.abs(netFlow))}
                        </p>
                    </div>
                </div>
            </div>

            <Card title={t("stats.financialActivity")} subtitle={t("stats.last7Days")}>
                <div className="h-[400px] w-full mt-4">
                    {data.length > 0 ? (
                        <ResponsiveContainer width="100%" height={400}>
                            <BarChart data={data}>
                                <defs>
                                    <linearGradient id="incomeGradient" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor="#10b981" stopOpacity={0.8} />
                                        <stop offset="100%" stopColor="#10b981" stopOpacity={0.4} />
                                    </linearGradient>
                                    <linearGradient id="expenseGradient" x1="0" y1="0" x2="0" y2="1">
                                        <stop offset="0%" stopColor="#ef4444" stopOpacity={0.8} />
                                        <stop offset="100%" stopColor="#ef4444" stopOpacity={0.4} />
                                    </linearGradient>
                                </defs>
                                <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                                <XAxis dataKey="date" stroke="#94a3b8" fontSize={12} tickLine={false} axisLine={false} />
                                <YAxis
                                    stroke="#94a3b8"
                                    fontSize={12}
                                    tickLine={false}
                                    axisLine={false}
                                    tickFormatter={(value) => `$${value}`}
                                />
                                <Tooltip
                                    contentStyle={{
                                        backgroundColor: "rgb(var(--bg-card))",
                                        border: "1px solid rgba(255,255,255,0.1)",
                                        borderRadius: "12px",
                                        boxShadow: "0 10px 15px -3px rgba(0, 0, 0, 0.5)",
                                    }}
                                    cursor={false}
                                    labelStyle={{ color: "#fff" }}
                                    itemStyle={{ color: "#fff" }}
                                />
                                <Bar dataKey="income" name={t("stats.income")} fill="url(#incomeGradient)" radius={[8, 8, 0, 0]} />
                                <Bar dataKey="expense" name={t("stats.expenses")} fill="url(#expenseGradient)" radius={[8, 8, 0, 0]} />
                            </BarChart>
                        </ResponsiveContainer>
                    ) : (
                        <div className="h-full flex items-center justify-center">
                            <div className="text-center">
                                <Activity className="text-[rgb(var(--text-muted))] mx-auto mb-4" size={48} />
                                <p className="text-[rgb(var(--text-secondary))]">{t("stats.noData")}</p>
                            </div>
                        </div>
                    )}
                </div>
            </Card>
            {tooltip &&
                createPortal(
                    <div
                        className="fixed z-[99999] px-3 py-1.5 rounded-lg bg-gray-900 text-white text-sm font-medium shadow-xl border border-white/10 pointer-events-none"
                        style={{
                            top: `${tooltip.y}px`,
                            left: `${tooltip.x}px`,
                            transform: "translate(-50%, calc(-100% - 12px))",
                            whiteSpace: "nowrap",
                        }}
                    >
                        {tooltip.text}

                        <div className="absolute left-1/2 top-full -translate-x-1/2 border-4 border-transparent border-t-gray-900" />
                    </div>,
                    document.body
                )}
        </div>
    )
}

export default StatsView