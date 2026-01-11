"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Plus, AlertCircle, TrendingDown, Calendar, Percent, X } from "lucide-react"
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
    const [paymentModal, setPaymentModal] = useState<{ isOpen: boolean; loan: Loan | null }>({
        isOpen: false,
        loan: null,
    })
    const [paymentAmount, setPaymentAmount] = useState("")

    const handleOpenPaymentModal = (loan: Loan) => {
        setPaymentModal({ isOpen: true, loan })
        setPaymentAmount("")
    }

    const handleClosePaymentModal = () => {
        setPaymentModal({ isOpen: false, loan: null })
        setPaymentAmount("")
    }

    const handleConfirmPayment = () => {
        if (!paymentModal.loan || !paymentAmount) return
        const amount = parseFloat(paymentAmount)
        const remaining = parseFloat(paymentModal.loan.remaining)

        if (amount <= 0 || amount > remaining) return

        onPayLoan(paymentModal.loan.id, amount)
        handleClosePaymentModal()
    }

    const handlePayAll = () => {
        if (!paymentModal.loan) return
        const remaining = parseFloat(paymentModal.loan.remaining)
        setPaymentAmount(remaining.toString())
    }

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

                                <div className="space-y-6 relative z-10">
                                    <div className="flex items-center justify-between flex-wrap gap-3">
                                        <div className="flex items-center gap-3">
                                            <div className="p-2 bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] rounded-lg shadow-lg">
                                                <TrendingDown className="text-white" size={20} />
                                            </div>
                                            <h3 className="text-xl font-bold text-white">{t("loans.loanId", { id: loan.id })}</h3>
                                            <span className="px-3 py-1 rounded-full bg-yellow-500/20 text-yellow-400 text-xs font-medium border border-yellow-500/30">
                                                {t("loans.active")}
                                            </span>
                                        </div>
                                    </div>

                                    <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
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

                                    <div className="bg-gradient-to-br from-white/5 to-white/10 p-6 rounded-xl border border-white/10 backdrop-blur-sm">
                                        <div className="flex justify-between items-end mb-4">
                                            <div>
                                                <p className="text-[rgb(var(--text-secondary))] text-sm mb-1">{t("loans.remaining")}</p>
                                                <p className="text-3xl lg:text-4xl font-bold text-white">${remaining.toLocaleString()}</p>
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

                                        <Button onClick={() => handleOpenPaymentModal(loan)} className="w-full shadow-xl">
                                            {t("loans.payInstallment")}
                                        </Button>
                                    </div>
                                </div>
                            </Card>
                        )
                    })
                )}
            </div>

            {paymentModal.isOpen && paymentModal.loan && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md animate-in">
                    <div className="bg-[rgb(var(--bg-card))] p-6 md:p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl animate-scale-in mx-4">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold text-white">Pagar Préstamo</h3>
                            <button
                                onClick={handleClosePaymentModal}
                                className="p-2 hover:bg-white/10 rounded-lg transition-colors"
                            >
                                <X className="text-white" size={20} />
                            </button>
                        </div>

                        <div className="space-y-6">
                            <div className="bg-gradient-to-br from-white/5 to-white/10 p-4 rounded-xl border border-white/10">
                                <p className="text-[rgb(var(--text-secondary))] text-sm mb-1">Monto restante</p>
                                <p className="text-3xl font-bold text-white">
                                    ${Number.parseFloat(paymentModal.loan.remaining).toLocaleString()}
                                </p>
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("loans.paymentAmount")}
                                </label>
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={paymentAmount}
                                    onChange={(e) => setPaymentAmount(e.target.value)}
                                    max={paymentModal.loan.remaining}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white text-lg font-semibold focus:border-[rgb(var(--accent-primary))] outline-none"
                                />
                            </div>

                            <div className="grid grid-cols-2 gap-3">
                                <button
                                    onClick={() => setPaymentAmount((Number.parseFloat(paymentModal.loan!.remaining) / 2).toFixed(2))}
                                    className="py-2 px-4 rounded-xl bg-white/5 hover:bg-white/10 text-white text-sm transition-all duration-200 border border-white/10"
                                >
                                    {t("loans.payHalf")}
                                </button>
                                <button
                                    onClick={handlePayAll}
                                    className="py-2 px-4 rounded-xl bg-white/5 hover:bg-white/10 text-white text-sm transition-all duration-200 border border-white/10"
                                >
                                    {t("loans.payAll")}
                                </button>
                            </div>

                            <div className="flex gap-3 pt-4">
                                <button
                                    onClick={handleClosePaymentModal}
                                    className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-all duration-200 hover:scale-105"
                                >
                                    {t("loans.cancel")}
                                </button>
                                <button
                                    onClick={handleConfirmPayment}
                                    disabled={!paymentAmount || parseFloat(paymentAmount) <= 0 || parseFloat(paymentAmount) > parseFloat(paymentModal.loan.remaining)}
                                    className="flex-1 py-3 rounded-xl bg-white/15 hover:bg-white/20 text-white transition-all duration-200 font-medium hover:scale-105 hover:shadow-lg hover:shadow-[rgba(var(--accent-glow),0.4)] disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100"
                                >
                                    {t("loans.confirmPayment")}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}