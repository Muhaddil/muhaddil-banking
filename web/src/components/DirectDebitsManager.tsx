"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Receipt, Power, Trash2, Building, RefreshCw, AlertCircle } from "lucide-react"
import { fetchNui } from "../utils/fetchNui"
import { useLocale } from "../hooks/useLocale"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"
import { formatDate } from '../utils/formatDate'

interface DirectDebit {
    id: number
    owner: string
    account_id: number
    account_name: string
    creditor_name: string
    description: string
    amount: string
    frequency: string
    enabled: number
    last_executed: string | null
    next_execution: string | null
    source_resource: string
    created_at: string
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface DirectDebitsManagerProps {
    debits: DirectDebit[]
    accounts: Account[]
    config: {
        enabled: boolean
        maxPerPlayer: number
    }
}

const freqLabels: Record<string, string> = {
    daily: "Diaria",
    weekly: "Semanal",
    biweekly: "Quincenal",
    monthly: "Mensual",
}

export const DirectDebitsManager: React.FC<DirectDebitsManagerProps> = ({ debits, accounts, config }) => {
    const { t, locale } = useLocale()
    const [confirmDelete, setConfirmDelete] = useState<number | null>(null)

    const activeDebits = debits.filter((d) => d.enabled === 1)
    const monthlyTotal = debits
        .filter((d) => d.enabled === 1)
        .reduce((sum, d) => {
            const amount = parseFloat(d.amount)
            switch (d.frequency) {
                case "daily": return sum + amount * 30
                case "weekly": return sum + amount * 4
                case "biweekly": return sum + amount * 2
                case "monthly": return sum + amount
                default: return sum + amount
            }
        }, 0)

    const handleToggle = (debitId: number) => {
        fetchNui("toggleDirectDebit", { debitId })
    }

    const handleCancel = (debitId: number) => {
        fetchNui("cancelDirectDebit", { debitId })
        setConfirmDelete(null)
    }

    const handleChangeAccount = (debitId: number, accountId: number) => {
        fetchNui("changeDebitAccount", { debitId, accountId })
    }

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6 md:p-8 shadow-2xl shadow-[rgba(var(--accent-glow),0.3)]">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />
                <div className="relative z-10">
                    <h2 className="text-3xl font-bold text-white mb-2">{t("directDebits.title") || "Domiciliaciones"}</h2>
                    <p className="text-white/80 max-w-lg">{t("directDebits.subtitle") || "Gestiona tus pagos automáticos y domiciliaciones bancarias"}</p>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">{t("directDebits.activeDebits") || "Domiciliaciones Activas"}</p>
                    <p className="text-2xl font-bold text-white">{activeDebits.length} / {config.maxPerPlayer}</p>
                </Card>
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">{t("directDebits.monthlyEstimate") || "Estimado Mensual"}</p>
                    <p className="text-2xl font-bold text-white">${monthlyTotal.toLocaleString()}</p>
                </Card>
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">{t("directDebits.totalDebits") || "Total Domiciliaciones"}</p>
                    <p className="text-2xl font-bold text-white">{debits.length}</p>
                </Card>
            </div>

            <div className="p-4 rounded-xl bg-blue-500/10 border border-blue-500/20 flex items-start gap-3">
                <AlertCircle size={18} className="text-blue-400 shrink-0 mt-0.5" />
                <p className="text-blue-200/80 text-sm">
                    {t("directDebits.infoNotice") || "Las domiciliaciones son registradas automáticamente por otros servicios (alquiler, impuestos, facturas). Desde aquí puedes activarlas, desactivarlas o cancelarlas."}
                </p>
            </div>

            <div className="grid gap-4">
                {debits.length === 0 ? (
                    <Card className="text-center py-12">
                        <div className="w-16 h-16 bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] rounded-full flex items-center justify-center mx-auto mb-4 shadow-lg">
                            <Receipt className="text-white" size={32} />
                        </div>
                        <h3 className="text-xl font-bold text-white mb-2">{t("directDebits.noDebits") || "Sin domiciliaciones"}</h3>
                        <p className="text-[rgb(var(--text-secondary))] max-w-md mx-auto">
                            {t("directDebits.noDebitsDesc") || "No tienes ninguna domiciliación registrada. Estas se crean automáticamente cuando contratas servicios como viviendas o vehículos."}
                        </p>
                    </Card>
                ) : (
                    debits.map((debit) => {
                        const isEnabled = debit.enabled === 1
                        return (
                            <Card key={debit.id} className={`relative overflow-hidden hover:scale-[1.005] transition-all duration-300 ${!isEnabled ? "opacity-60" : ""}`}>
                                <div className={`absolute left-0 top-0 bottom-0 w-1 ${isEnabled ? "bg-gradient-to-b from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))]" : "bg-gradient-to-b from-gray-500 to-gray-600"}`} />

                                <div className="flex flex-col lg:flex-row items-start lg:items-center justify-between gap-4">
                                    <div className="flex items-start gap-4 flex-1">
                                        <div className={`p-3 rounded-xl ${isEnabled ? "bg-[rgba(var(--accent-primary),0.2)]" : "bg-gray-500/20"}`}>
                                            <Building className={isEnabled ? "text-[rgb(var(--accent-glow))]" : "text-gray-400"} size={24} />
                                        </div>
                                        <div className="flex-1">
                                            <h4 className="text-white font-bold text-lg">{debit.creditor_name}</h4>
                                            {debit.description && (
                                                <p className="text-[rgb(var(--text-secondary))] text-sm">{debit.description}</p>
                                            )}
                                            <div className="flex flex-wrap items-center gap-3 mt-2 text-xs text-[rgb(var(--text-muted))]">
                                                <span className="flex items-center gap-1">
                                                    <RefreshCw size={12} />
                                                    {t(`scheduledTransfers.freq.${debit.frequency}`) || freqLabels[debit.frequency] || debit.frequency}
                                                </span>
                                                <span>
                                                    {t("directDebits.account") || "Cuenta"}: {debit.account_name || `#${debit.account_id}`}
                                                </span>
                                                {debit.next_execution && (
                                                    <span>
                                                        {t("directDebits.nextCharge") || "Próximo cobro"}: {formatDate(debit.next_execution, locale)}
                                                    </span>
                                                )}
                                                {debit.source_resource && debit.source_resource !== "unknown" && (
                                                    <span className="px-2 py-0.5 rounded-full bg-white/5 border border-white/10">
                                                        {debit.source_resource}
                                                    </span>
                                                )}
                                            </div>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-3">
                                        <div className="text-right mr-2">
                                            <p className="text-2xl font-bold text-white">${parseFloat(debit.amount).toLocaleString()}</p>
                                            <p className="text-xs text-[rgb(var(--text-muted))]">
                                                /{t(`scheduledTransfers.freq.${debit.frequency}`) || freqLabels[debit.frequency] || debit.frequency}
                                            </p>
                                        </div>

                                        <div className="w-[120px]">
                                            <Select value={debit.account_id.toString()} onValueChange={(val) => handleChangeAccount(debit.id, parseInt(val))}>
                                                <SelectTrigger className="w-full bg-black/20 border-white/10 text-white h-[34px] rounded-lg text-xs" title={t("directDebits.changeAccount") || "Cambiar cuenta"}>
                                                    <SelectValue />
                                                </SelectTrigger>
                                                <SelectContent>
                                                    {accounts.map((acc) => (
                                                        <SelectItem key={acc.id} value={acc.id.toString()}>
                                                            {acc.account_name}
                                                        </SelectItem>
                                                    ))}
                                                </SelectContent>
                                            </Select>
                                        </div>

                                        <button
                                            onClick={() => handleToggle(debit.id)}
                                            className={`p-2 rounded-lg transition-all ${isEnabled ? "bg-green-500/20 text-green-400 hover:bg-green-500/30" : "bg-gray-500/20 text-gray-400 hover:bg-gray-500/30"}`}
                                            title={isEnabled ? (t("directDebits.disable") || "Desactivar") : (t("directDebits.enable") || "Activar")}
                                        >
                                            <Power size={18} />
                                        </button>

                                        {confirmDelete === debit.id ? (
                                            <div className="flex gap-1">
                                                <button
                                                    onClick={() => handleCancel(debit.id)}
                                                    className="px-3 py-2 rounded-lg bg-red-500/20 text-red-400 hover:bg-red-500/30 text-xs font-medium transition-all"
                                                >
                                                    {t("common.confirm") || "Confirmar"}
                                                </button>
                                                <button
                                                    onClick={() => setConfirmDelete(null)}
                                                    className="px-3 py-2 rounded-lg bg-white/5 text-white/50 hover:bg-white/10 text-xs transition-all"
                                                >
                                                    ✕
                                                </button>
                                            </div>
                                        ) : (
                                            <button
                                                onClick={() => setConfirmDelete(debit.id)}
                                                className="p-2 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 transition-all"
                                                title={t("directDebits.cancel") || "Cancelar domiciliación"}
                                            >
                                                <Trash2 size={18} />
                                            </button>
                                        )}
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
