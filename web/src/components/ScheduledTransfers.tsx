"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Clock, Plus, Edit2, Trash2, ToggleLeft, ToggleRight, X, Repeat } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"

interface ScheduledTransfer {
    id: number
    owner: string
    from_account_id: number
    to_account_id: number
    from_account_name?: string
    to_account_name?: string
    amount: string
    frequency: string
    day_of_week: number
    hour: number
    minute: number
    enabled: number
    description: string | null
    last_executed: string | null
    next_execution: string | null
    created_at: string
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface ScheduledConfig {
    enabled: boolean
    maxPerPlayer: number
    minAmount: number
    frequencies: string[]
}

interface ScheduledTransfersProps {
    transfers: ScheduledTransfer[]
    accounts: Account[]
    allAccounts?: Account[]
    config: ScheduledConfig
    onCreateTransfer: (data: any) => void
    onUpdateTransfer: (data: any) => void
    onToggleTransfer: (transferId: number) => void
    onDeleteTransfer: (transferId: number) => void
}

export const ScheduledTransfers: React.FC<ScheduledTransfersProps> = ({
    transfers, accounts, allAccounts, config, onCreateTransfer, onUpdateTransfer, onToggleTransfer, onDeleteTransfer
}) => {
    const { t } = useLocale()
    const [showCreateModal, setShowCreateModal] = useState(false)
    const [editingTransfer, setEditingTransfer] = useState<ScheduledTransfer | null>(null)

    const [fromAccountId, setFromAccountId] = useState<number>(accounts[0]?.id || 0)
    const [toAccountId, setToAccountId] = useState("")
    const [amount, setAmount] = useState("")
    const [frequency, setFrequency] = useState("weekly")
    const [dayOfWeek, setDayOfWeek] = useState(1)
    const [hour, setHour] = useState(12)
    const [minute, setMinute] = useState(0)
    const [description, setDescription] = useState("")

    const openCreate = () => {
        setFromAccountId(accounts[0]?.id || 0)
        setToAccountId("")
        setAmount("")
        setFrequency("weekly")
        setDayOfWeek(1)
        setHour(12)
        setMinute(0)
        setDescription("")
        setShowCreateModal(true)
    }

    const openEdit = (transfer: ScheduledTransfer) => {
        setEditingTransfer(transfer)
        setAmount(transfer.amount)
        setFrequency(transfer.frequency)
        setDayOfWeek(transfer.day_of_week)
        setHour(transfer.hour)
        setMinute(transfer.minute)
        setDescription(transfer.description || "")
    }

    const handleCreate = () => {
        if (!fromAccountId || !toAccountId || !amount) return
        onCreateTransfer({
            fromAccountId,
            toAccountId: parseInt(toAccountId),
            amount: parseFloat(amount),
            frequency,
            dayOfWeek,
            hour,
            minute,
            description
        })
        setShowCreateModal(false)
    }

    const handleUpdate = () => {
        if (!editingTransfer || !amount) return
        onUpdateTransfer({
            transferId: editingTransfer.id,
            amount: parseFloat(amount),
            frequency,
            dayOfWeek,
            hour,
            minute,
            description
        })
        setEditingTransfer(null)
    }

    const getFrequencyLabel = (freq: string) => {
        return t(`scheduledTransfers.freq.${freq}`)
    }

    const getDayLabel = (day: number) => {
        const days = [
            t("scheduledTransfers.days.sun"),
            t("scheduledTransfers.days.mon"),
            t("scheduledTransfers.days.tue"),
            t("scheduledTransfers.days.wed"),
            t("scheduledTransfers.days.thu"),
            t("scheduledTransfers.days.fri"),
            t("scheduledTransfers.days.sat"),
        ]
        return days[day] || days[1]
    }

    const formatTime = (h: number, m: number) => {
        return `${h.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')}`
    }

    const formatDate = (dateStr: string | null) => {
        if (!dateStr) return '-'
        const date = new Date(dateStr)
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Repeat className="text-[rgb(var(--accent-glow))]" size={24} />
                        {t("scheduledTransfers.title")}
                    </h2>
                    <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">
                        {transfers.length}/{config.maxPerPlayer} {t("scheduledTransfers.used")}
                    </p>
                </div>
                <Button onClick={openCreate} className="flex items-center gap-2">
                    <Plus size={16} /> {t("scheduledTransfers.create")}
                </Button>
            </div>

            {transfers.length === 0 ? (
                <Card className="p-8 text-center">
                    <Clock size={48} className="mx-auto mb-4 text-[rgb(var(--text-secondary))] opacity-40" />
                    <p className="text-[rgb(var(--text-secondary))]">{t("scheduledTransfers.noTransfers")}</p>
                </Card>
            ) : (
                <div className="grid gap-4">
                    {transfers.map(transfer => (
                        <Card key={transfer.id} className={`p-5 transition-all ${transfer.enabled ? '' : 'opacity-50'}`}>
                            <div className="flex items-start justify-between mb-3">
                                <div>
                                    <h3 className="text-white font-semibold flex items-center gap-2">
                                        <Repeat size={16} className="text-[rgb(var(--accent-glow))]" />
                                        ${parseFloat(transfer.amount).toLocaleString()}
                                        <span className="text-xs text-[rgb(var(--text-secondary))] font-normal">
                                            {getFrequencyLabel(transfer.frequency)}
                                        </span>
                                    </h3>
                                    {transfer.description && (
                                        <p className="text-sm text-[rgb(var(--text-secondary))] mt-1">{transfer.description}</p>
                                    )}
                                </div>
                                <button onClick={() => onToggleTransfer(transfer.id)}
                                    className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                    {transfer.enabled ? (
                                        <ToggleRight size={24} className="text-green-400" />
                                    ) : (
                                        <ToggleLeft size={24} className="text-[rgb(var(--text-secondary))]" />
                                    )}
                                </button>
                            </div>

                            <div className="grid grid-cols-2 gap-4 mb-3 text-xs">
                                <div>
                                    <span className="text-[rgb(var(--text-secondary))]">{t("scheduledTransfers.from")}:</span>
                                    <p className="text-white">{transfer.from_account_name || `#${transfer.from_account_id}`}</p>
                                </div>
                                <div>
                                    <span className="text-[rgb(var(--text-secondary))]">{t("scheduledTransfers.to")}:</span>
                                    <p className="text-white">{transfer.to_account_name || `#${transfer.to_account_id}`}</p>
                                </div>
                                <div>
                                    <span className="text-[rgb(var(--text-secondary))]">{t("scheduledTransfers.schedule")}:</span>
                                    <p className="text-white">
                                        {transfer.frequency !== 'daily' && `${getDayLabel(transfer.day_of_week)} `}
                                        {formatTime(transfer.hour, transfer.minute)}
                                    </p>
                                </div>
                                <div>
                                    <span className="text-[rgb(var(--text-secondary))]">{t("scheduledTransfers.nextExecution")}:</span>
                                    <p className="text-white">{formatDate(transfer.next_execution)}</p>
                                </div>
                            </div>

                            <div className="flex gap-2">
                                <button onClick={() => openEdit(transfer)}
                                    className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                    <Edit2 size={14} className="text-[rgb(var(--text-secondary))]" />
                                </button>
                                <button onClick={() => onDeleteTransfer(transfer.id)}
                                    className="p-2 hover:bg-red-500/20 rounded-lg transition-colors">
                                    <Trash2 size={14} className="text-red-400" />
                                </button>
                            </div>
                        </Card>
                    ))}
                </div>
            )}

            {(showCreateModal || editingTransfer) && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4 max-h-[85vh] overflow-y-auto">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">
                                {editingTransfer ? t("scheduledTransfers.edit") : t("scheduledTransfers.create")}
                            </h3>
                            <button onClick={() => { setShowCreateModal(false); setEditingTransfer(null); }}
                                className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            {!editingTransfer && (
                                <>
                                    <div>
                                        <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.fromAccount")}</label>
                                        <Select
                                            value={String(fromAccountId)}
                                            onValueChange={(value: string) => setFromAccountId(Number(value))}
                                        >
                                            <SelectTrigger>
                                                <SelectValue placeholder={t("scheduledTransfers.fromAccount")} />
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
                                        <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.toAccountId")}</label>
                                        <input type="number" value={toAccountId} onChange={e => setToAccountId(e.target.value)}
                                            placeholder={t("scheduledTransfers.toAccountPlaceholder")}
                                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                                    </div>
                                </>
                            )}
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.amount")}</label>
                                <input type="number" value={amount} onChange={e => setAmount(e.target.value)}
                                    placeholder={String(config.minAmount)}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.frequency")}</label>
                                <Select
                                    value={frequency}
                                    onValueChange={(value: string) => setFrequency(value)}
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder={t("scheduledTransfers.frequency")} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {config.frequencies.map(f => (
                                            <SelectItem key={f} value={f}>
                                                {getFrequencyLabel(f)}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            {frequency !== 'daily' && (
                                <div>
                                    <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.dayOfWeek")}</label>
                                    <Select
                                        value={String(dayOfWeek)}
                                        onValueChange={(value: string) => setDayOfWeek(Number(value))}
                                    >
                                        <SelectTrigger>
                                            <SelectValue placeholder={t("scheduledTransfers.dayOfWeek")} />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {[0, 1, 2, 3, 4, 5, 6].map(d => (
                                                <SelectItem key={d} value={String(d)}>
                                                    {getDayLabel(d)}
                                                </SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>
                            )}
                            <div className="grid grid-cols-2 gap-2">
                                <div>
                                    <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.hour")}</label>
                                    <input type="number" min={0} max={23} value={hour} onChange={e => setHour(Number(e.target.value))}
                                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                                </div>
                                <div>
                                    <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.minute")}</label>
                                    <input type="number" min={0} max={59} value={minute} onChange={e => setMinute(Number(e.target.value))}
                                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                                </div>
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("scheduledTransfers.description")}</label>
                                <input type="text" value={description} onChange={e => setDescription(e.target.value)}
                                    placeholder={t("scheduledTransfers.descriptionPlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <Button onClick={editingTransfer ? handleUpdate : handleCreate} className="w-full">
                                {editingTransfer ? t("scheduledTransfers.save") : t("scheduledTransfers.create")}
                            </Button>
                        </div>
                    </Card>
                </div>
            )}
        </div>
    )
}