"use client"

import type React from "react"
import { Card } from "./ui/Card"
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip } from "recharts"
import { TrendingUp, TrendingDown, DollarSign, Activity } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface StatsViewProps {
    data: any[]
    totalIncome: number
    totalExpense: number
    currentBalance: number
}

export const StatsView: React.FC<StatsViewProps> = ({ data, totalIncome, totalExpense, currentBalance }) => {
    const { t } = useLocale()
    const netFlow = totalIncome - totalExpense
    const isPositive = netFlow >= 0

    return (
        <div className="space-y-6 animate-in">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-blue-500 to-blue-600 p-6 shadow-xl shadow-blue-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <DollarSign size={24} className="text-white" />
                            </div>
                            <Activity size={40} className="text-white/20" />
                        </div>
                        <p className="text-blue-100 text-sm mb-1 font-medium">{t("stats.currentBalance")}</p>
                        <p className="text-3xl font-bold text-white">${currentBalance.toLocaleString()}</p>
                    </div>
                </div>

                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-emerald-500 to-emerald-600 p-6 shadow-xl shadow-emerald-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <TrendingUp size={24} className="text-white" />
                            </div>
                            <TrendingUp size={40} className="text-white/20" />
                        </div>
                        <p className="text-emerald-100 text-sm mb-1 font-medium">{t("stats.totalIncome")}</p>
                        <p className="text-3xl font-bold text-white">${totalIncome.toLocaleString()}</p>
                    </div>
                </div>

                <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-red-500 to-red-600 p-6 shadow-xl shadow-red-500/30">
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10">
                        <div className="flex items-center justify-between mb-3">
                            <div className="p-3 bg-white/20 rounded-xl backdrop-blur-sm">
                                <TrendingDown size={24} className="text-white" />
                            </div>
                            <TrendingDown size={40} className="text-white/20" />
                        </div>
                        <p className="text-red-100 text-sm mb-1 font-medium">{t("stats.totalExpenses")}</p>
                        <p className="text-3xl font-bold text-white">${totalExpense.toLocaleString()}</p>
                    </div>
                </div>

                <div
                    className={`relative overflow-hidden rounded-2xl bg-gradient-to-br p-6 shadow-xl ${isPositive
                        ? "from-purple-500 to-purple-600 shadow-purple-500/30"
                        : "from-orange-500 to-orange-600 shadow-orange-500/30"
                        }`}
                >
                    <div className="absolute top-0 right-0 w-32 h-32 bg-white/10 rounded-full blur-2xl -mr-8 -mt-8" />
                    <div className="relative z-10">
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
                        <p className="text-3xl font-bold text-white">
                            {isPositive ? "+" : ""}${Math.abs(netFlow).toLocaleString()}
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
        </div>
    )
}
