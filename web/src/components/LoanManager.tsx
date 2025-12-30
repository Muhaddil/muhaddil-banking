"use client"

import type React from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Plus, AlertCircle, TrendingDown, Calendar, Percent } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface Loan {
    id: number
    user_identifier: string
    amount: string
    remaining: string
    interest_rate: number
    installments: number
    status: string
    created_at: string
}

interface LoanManagerProps {
    loans: Loan[]
    onRequestLoan: () => void
    onPayLoan: (loanId: number, amount: number) => void
}

export const LoanManager: React.FC<LoanManagerProps> = ({ loans, onRequestLoan, onPayLoan }) => {
    const { t } = useLocale()

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6 md:p-8 shadow-2xl shadow-[rgba(var(--accent-glow),0.3)]">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />
                <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                    <div>
                        <h2 className="text-3xl font-bold text-white mb-2">{t("loans.title")}</h2>
                        <p className="text-white/80 max-w-md">{t("loans.subtitle")}</p>
                    </div>
                    <Button
                        onClick={onRequestLoan}
                        icon={<Plus size={18} />}
                        className="bg-white/20 hover:bg-white/30 border border-white/20 backdrop-blur-sm"
                    >
                        {t("loans.requestLoan")}
                    </Button>
                </div>
            </div>

            <div className="grid gap-6">
                {loans.length === 0 ? (
                    <Card className="text-center py-16">
                        <div className="w-20 h-20 bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] rounded-full flex items-center justify-center mx-auto mb-6 shadow-lg shadow-[rgba(var(--accent-glow),0.3)]">
                            <AlertCircle className="text-white" size={40} />
                        </div>
                        <h3 className="text-2xl font-bold text-white mb-3">{t("loans.noLoans")}</h3>
                        <p className="text-[rgb(var(--text-secondary))] mb-8 max-w-md mx-auto leading-relaxed">
                            {t("loans.noLoansDesc")}
                        </p>
                        <Button onClick={onRequestLoan} variant="secondary" className="shadow-lg">
                            {t("loans.requestNow")}
                        </Button>
                    </Card>
                ) : (
                    loans.map((loan) => {
                        const amount = Number.parseFloat(loan.amount)
                        const remaining = Number.parseFloat(loan.remaining)
                        const totalWithInterest = amount * (1 + loan.interest_rate / 100)
                        const paid = totalWithInterest - remaining
                        const progress = (paid / totalWithInterest) * 100

                        return (
                            <Card key={loan.id} className="relative overflow-hidden hover:scale-[1.01] transition-all duration-300">
                                <div className="absolute left-0 top-0 bottom-0 w-1 bg-gradient-to-b from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))]" />

                                <div className="flex flex-col lg:flex-row gap-6 relative z-10">
                                    <div className="flex-1">
                                        <div className="flex items-center gap-3 mb-6">
                                            <div className="p-2 bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] rounded-lg shadow-lg">
                                                <TrendingDown className="text-white" size={20} />
                                            </div>
                                            <h3 className="text-xl font-bold text-white">{t("loans.loanId", { id: loan.id })}</h3>
                                            <span className="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-xs font-medium border border-yellow-500/30">
                                                {t("loans.active")}
                                            </span>
                                        </div>

                                        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                                            <div className="bg-white/5 p-4 rounded-xl border border-white/5">
                                                <div className="flex items-center gap-2 mb-2">
                                                    <div className="p-1.5 bg-blue-500/20 rounded-lg">
                                                        <TrendingDown className="text-blue-400" size={14} />
                                                    </div>
                                                    <p className="text-[rgb(var(--text-secondary))] text-xs">{t("loans.originalAmount")}</p>
                                                </div>
                                                <p className="text-white font-bold text-lg">${amount.toLocaleString()}</p>
                                            </div>

                                            <div className="bg-white/5 p-4 rounded-xl border border-white/5">
                                                <div className="flex items-center gap-2 mb-2">
                                                    <div className="p-1.5 bg-orange-500/20 rounded-lg">
                                                        <Percent className="text-orange-400" size={14} />
                                                    </div>
                                                    <p className="text-[rgb(var(--text-secondary))] text-xs">{t("loans.interest")}</p>
                                                </div>
                                                <p className="text-white font-bold text-lg">{loan.interest_rate}%</p>
                                            </div>

                                            <div className="bg-white/5 p-4 rounded-xl border border-white/5">
                                                <div className="flex items-center gap-2 mb-2">
                                                    <div className="p-1.5 bg-purple-500/20 rounded-lg">
                                                        <Calendar className="text-purple-400" size={14} />
                                                    </div>
                                                    <p className="text-[rgb(var(--text-secondary))] text-xs">{t("loans.installments")}</p>
                                                </div>
                                                <p className="text-white font-bold text-lg">{loan.installments}</p>
                                            </div>

                                            <div className="bg-white/5 p-4 rounded-xl border border-white/5">
                                                <div className="flex items-center gap-2 mb-2">
                                                    <div className="p-1.5 bg-green-500/20 rounded-lg">
                                                        <Calendar className="text-green-400" size={14} />
                                                    </div>
                                                    <p className="text-[rgb(var(--text-secondary))] text-xs">{t("loans.date")}</p>
                                                </div>
                                                <p className="text-white font-medium text-sm">
                                                    {new Date(loan.created_at).toLocaleDateString("es-ES", {
                                                        day: "numeric",
                                                        month: "short",
                                                    })}
                                                </p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="flex-1 flex flex-col justify-center bg-gradient-to-br from-white/5 to-white/10 p-6 rounded-xl border border-white/10 backdrop-blur-sm">
                                        <div className="flex justify-between items-end mb-3">
                                            <div>
                                                <p className="text-[rgb(var(--text-secondary))] text-sm mb-1">{t("loans.remaining")}</p>
                                                <p className="text-4xl font-bold text-white">${remaining.toLocaleString()}</p>
                                            </div>
                                            <div className="text-right">
                                                <p className="text-2xl font-bold text-[rgb(var(--accent-glow))]">{progress.toFixed(0)}%</p>
                                                <p className="text-xs text-[rgb(var(--text-muted))]">{t("loans.paid")}</p>
                                            </div>
                                        </div>

                                        <div className="h-4 bg-[rgb(var(--bg-secondary))] rounded-full overflow-hidden mb-6 shadow-inner">
                                            <div
                                                className="h-full bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] transition-all duration-500 shadow-lg relative overflow-hidden"
                                                style={{ width: `${progress}%` }}
                                            >
                                                <div className="absolute inset-0 bg-white/20 animate-pulse" />
                                            </div>
                                        </div>

                                        <Button onClick={() => onPayLoan(loan.id, remaining)} className="w-full shadow-xl">
                                            {t("loans.payInstallment")}
                                        </Button>
                                    </div>
                                </div>
                            </Card>
                        )
                    })
                )}
            </div>
        </div>
    )
}
