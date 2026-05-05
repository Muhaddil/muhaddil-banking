"use client"

import type React from "react"
import { useState, useEffect, useCallback, useRef } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import {
    Shield, Search, Users, CreditCard, Banknote, History, Building2,
    Clock, ArrowLeftRight, DollarSign, TrendingUp, X, Trash2, Ban,
    Plus, Minus, PiggyBank, BarChart3, RefreshCcw, AlertTriangle,
    Activity, CheckCircle2, AlertCircle, ChevronRight, Eye,
    Lock, Unlock, Download, Filter, SortAsc, SortDesc,
    FileText, Bell, BellOff, Zap, TrendingDown, UserX,
    Copy, ExternalLink, MoreVertical, ChevronDown, Info,
    Send, RotateCcw, Layers, Target, Hash, Calendar,
    UserCheck, ShieldAlert, ShieldCheck, Database
} from "lucide-react"
import { fetchNui } from "../utils/fetchNui"
import { useLocale } from "../hooks/useLocale"

interface AdminPanelProps {
    onClose: () => void
}

type TabId =
    | "overview" | "alerts" | "users" | "accounts"
    | "loans" | "transactions" | "banks" | "scheduled"
    | "requests" | "audit"

type Severity = "critical" | "warning" | "info"
type SortDirection = "asc" | "desc"

interface Toast {
    id: string
    message: string
    type: "success" | "error" | "info" | "warning"
    timestamp: number
}

interface ConfirmDialog {
    title: string
    description: string
    confirmLabel: string
    variant: "danger" | "warning" | "default"
    onConfirm: () => void
}

interface MoneyModal {
    accountId: number
    accountName?: string
    mode: "add" | "remove"
}

interface AuditEntry {
    id: number
    action: string
    adminId: string
    targetId?: string
    details: string
    timestamp: string
}

interface FilterState {
    search: string
    sortBy: string
    sortDir: SortDirection
    status?: string
    dateFrom?: string
    dateTo?: string
}

function useToasts() {
    const [toasts, setToasts] = useState<Toast[]>([])

    const push = useCallback((message: string, type: Toast["type"] = "info") => {
        const id = Math.random().toString(36).slice(2)
        setToasts(prev => [...prev, { id, message, type, timestamp: Date.now() }])
        setTimeout(() => setToasts(prev => prev.filter(t => t.id !== id)), 3500)
    }, [])

    const dismiss = useCallback((id: string) => {
        setToasts(prev => prev.filter(t => t.id !== id))
    }, [])

    return { toasts, push, dismiss }
}

function useConfirm() {
    const [dialog, setDialog] = useState<ConfirmDialog | null>(null)

    const confirm = useCallback((opts: ConfirmDialog) => {
        setDialog(opts)
    }, [])

    const resolve = useCallback((confirmed: boolean) => {
        if (confirmed && dialog) dialog.onConfirm()
        setDialog(null)
    }, [dialog])

    return { dialog, confirm, resolve }
}

function useAdminAudit() {
    const [log, setLog] = useState<AuditEntry[]>([])

    const record = useCallback((action: string, details: string, targetId?: string) => {
        const entry: AuditEntry = {
            id: Date.now(),
            action,
            adminId: "local_admin",
            targetId,
            details,
            timestamp: new Date().toISOString()
        }
        setLog(prev => [entry, ...prev].slice(0, 200))
    }, [])

    return { log, record }
}

const fmt = {
    money: (val: any) =>
        `$${parseFloat(val || 0).toLocaleString("en-US", { minimumFractionDigits: 0, maximumFractionDigits: 0 })}`,

    date: (dateStr?: string) => {
        if (!dateStr) return "—"
        const d = new Date(dateStr)
        return d.toLocaleDateString() + " " + d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    },

    shortId: (str?: string, len = 20) =>
        str ? (str.length > len ? str.substring(0, len) + "…" : str) : "—",

    percent: (val: number) => `${(val * 100).toFixed(1)}%`,

    copyToClipboard: (text: string) => {
        navigator.clipboard?.writeText(text)
    }
}

const Pill: React.FC<{ label: string; color: "red" | "yellow" | "blue" | "green" | "purple" }> = ({ label, color }) => {
    const map = {
        red: "bg-red-500/20 text-red-400 border-red-500/30",
        yellow: "bg-yellow-500/20 text-yellow-400 border-yellow-500/30",
        blue: "bg-blue-500/20 text-blue-400 border-blue-500/30",
        green: "bg-emerald-500/20 text-emerald-400 border-emerald-500/30",
        purple: "bg-purple-500/20 text-purple-400 border-purple-500/30",
    }
    return (
        <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold tracking-wide border uppercase ${map[color]}`}>
            {label}
        </span>
    )
}

const Skeleton: React.FC<{ className?: string }> = ({ className = "" }) => (
    <div className={`animate-pulse bg-white/5 rounded-lg ${className}`} />
)

const EmptyState: React.FC<{ icon: React.ReactNode; title: string; subtitle?: string }> = ({ icon, title, subtitle }) => (
    <Card className="p-10 flex flex-col items-center justify-center text-center gap-3">
        <div className="p-4 rounded-2xl bg-white/5 text-[rgb(var(--text-secondary))]">{icon}</div>
        <p className="text-white font-semibold">{title}</p>
        {subtitle && <p className="text-[rgb(var(--text-secondary))] text-sm max-w-xs">{subtitle}</p>}
    </Card>
)

const StatCard: React.FC<{ label: string; value: string | number; icon: React.ReactNode; trend?: number; color?: string }> = ({
    label, value, icon, trend, color = "var(--accent-glow)"
}) => (
    <Card className="p-4 group hover:border-white/20 transition-all duration-200">
        <div className="flex items-start justify-between mb-3">
            <div className="p-2 rounded-xl" style={{ background: `rgba(${color},0.12)` }}>
                <span style={{ color: `rgb(${color})` }}>{icon}</span>
            </div>
            {trend !== undefined && (
                <span className={`text-xs font-medium flex items-center gap-0.5 ${trend >= 0 ? "text-emerald-400" : "text-red-400"}`}>
                    {trend >= 0 ? <TrendingUp size={12} /> : <TrendingDown size={12} />}
                    {Math.abs(trend)}%
                </span>
            )}
        </div>
        <p className="text-xs text-[rgb(var(--text-secondary))] mb-1">{label}</p>
        <p className="text-xl font-bold text-white tracking-tight">{value}</p>
    </Card>
)

const ActionBtn: React.FC<{
    onClick: () => void
    icon: React.ReactNode
    label: string
    color?: "green" | "red" | "blue" | "yellow" | "purple"
    disabled?: boolean
}> = ({ onClick, icon, label, color = "blue", disabled }) => {
    const map = {
        green: "hover:bg-emerald-500/20 hover:border-emerald-500/30 text-emerald-400",
        red: "hover:bg-red-500/20 hover:border-red-500/30 text-red-400",
        blue: "hover:bg-blue-500/20 hover:border-blue-500/30 text-blue-400",
        yellow: "hover:bg-yellow-500/20 hover:border-yellow-500/30 text-yellow-400",
        purple: "hover:bg-purple-500/20 hover:border-purple-500/30 text-purple-400",
    }
    return (
        <button
            onClick={onClick}
            disabled={disabled}
            title={label}
            className={`p-1.5 rounded-lg border border-transparent transition-all duration-150 disabled:opacity-40 disabled:cursor-not-allowed ${map[color]}`}
        >
            {icon}
        </button>
    )
}

const ToastContainer: React.FC<{ toasts: Toast[]; dismiss: (id: string) => void }> = ({ toasts, dismiss }) => {
    const map = {
        success: "border-emerald-500/40 bg-emerald-500/10 text-emerald-300",
        error: "border-red-500/40 bg-red-500/10 text-red-300",
        warning: "border-yellow-500/40 bg-yellow-500/10 text-yellow-300",
        info: "border-blue-500/40 bg-blue-500/10 text-blue-300",
    }
    const icons = {
        success: <CheckCircle2 size={14} />,
        error: <AlertCircle size={14} />,
        warning: <AlertTriangle size={14} />,
        info: <Info size={14} />,
    }
    return (
        <div className="fixed bottom-4 right-4 z-[100] flex flex-col gap-2 pointer-events-none">
            {toasts.map(t => (
                <div
                    key={t.id}
                    onClick={() => dismiss(t.id)}
                    className={`pointer-events-auto flex items-center gap-2 px-4 py-2.5 rounded-xl border text-sm font-medium backdrop-blur-sm shadow-xl cursor-pointer animate-in slide-in-from-right-4 ${map[t.type]}`}
                >
                    {icons[t.type]}
                    {t.message}
                    <X size={12} className="ml-2 opacity-60" />
                </div>
            ))}
        </div>
    )
}

const ConfirmDialogModal: React.FC<{ dialog: ConfirmDialog; resolve: (ok: boolean) => void }> = ({ dialog, resolve }) => {
    const { t } = useLocale()
    const varMap = {
        danger: { btn: "bg-red-500 hover:bg-red-600 text-white", icon: <AlertCircle size={24} className="text-red-400" /> },
        warning: { btn: "bg-yellow-500 hover:bg-yellow-600 text-white", icon: <AlertTriangle size={24} className="text-yellow-400" /> },
        default: { btn: "bg-blue-500 hover:bg-blue-600 text-white", icon: <Info size={24} className="text-blue-400" /> },
    }
    const v = varMap[dialog.variant]
    return (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 backdrop-blur-sm">
            <Card className="w-full max-w-sm p-6 mx-4 space-y-4">
                <div className="flex items-center gap-3">
                    {v.icon}
                    <h3 className="text-lg font-bold text-white">{dialog.title}</h3>
                </div>
                <p className="text-sm text-[rgb(var(--text-secondary))]">{dialog.description}</p>
                <div className="flex gap-2">
                    <button onClick={() => resolve(true)} className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold transition-colors ${v.btn}`}>
                        {dialog.confirmLabel}
                    </button>
                    <button onClick={() => resolve(false)} className="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold bg-white/5 hover:bg-white/10 text-white transition-colors">
                        {t("common.cancel")}
                    </button>
                </div>
            </Card>
        </div>
    )
}

const MoneyModalDialog: React.FC<{
    modal: MoneyModal
    onClose: () => void
    onConfirm: (amount: number, note: string) => void
}> = ({ modal, onClose, onConfirm }) => {
    const { t } = useLocale()
    const [amount, setAmount] = useState("")
    const [note, setNote] = useState("")
    const inputRef = useRef<HTMLInputElement>(null)
    const isAdd = modal.mode === "add"

    useEffect(() => { inputRef.current?.focus() }, [])

    const presets = [100, 500, 1000, 5000, 10000]

    return (
        <div className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 backdrop-blur-sm">
            <Card className="w-full max-w-md p-6 mx-4 space-y-4">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div className={`p-2 rounded-lg ${isAdd ? "bg-emerald-500/20" : "bg-red-500/20"}`}>
                            {isAdd ? <Plus size={18} className="text-emerald-400" /> : <Minus size={18} className="text-red-400" />}
                        </div>
                        <div>
                            <h3 className="text-base font-bold text-white">{isAdd ? t("admin.addFunds") : t("admin.withdrawFunds")}</h3>
                            {modal.accountName && (
                                <p className="text-xs text-[rgb(var(--text-secondary))]">{modal.accountName}</p>
                            )}
                        </div>
                    </div>
                    <button onClick={onClose} className="p-1.5 hover:bg-white/10 rounded-lg"><X size={16} className="text-[rgb(var(--text-secondary))]" /></button>
                </div>

                <div>
                    <label className="text-xs text-[rgb(var(--text-secondary))] mb-1.5 block">{t("admin.amount")}</label>
                    <div className="relative">
                        <span className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-secondary))]">$</span>
                        <input
                            ref={inputRef}
                            type="number"
                            value={amount}
                            onChange={e => setAmount(e.target.value)}
                            onKeyDown={e => e.key === "Enter" && amount && onConfirm(parseFloat(amount), note)}
                            placeholder="0"
                            className="w-full bg-white/5 border border-white/10 rounded-xl pl-8 pr-4 py-3 text-white text-lg font-semibold focus:border-[rgba(var(--accent-primary),0.5)] outline-none"
                        />
                    </div>
                    <div className="flex gap-2 mt-2 flex-wrap">
                        {presets.map(p => (
                            <button key={p} onClick={() => setAmount(String(p))}
                                className="px-2.5 py-1 rounded-lg bg-white/5 hover:bg-white/10 text-xs text-[rgb(var(--text-secondary))] hover:text-white transition-colors border border-white/5">
                                ${p.toLocaleString()}
                            </button>
                        ))}
                    </div>
                </div>

                <div>
                    <label className="text-xs text-[rgb(var(--text-secondary))] mb-1.5 block">{t("admin.noteOptional")}</label>
                    <input
                        type="text"
                        value={note}
                        onChange={e => setNote(e.target.value)}
                        placeholder={t("admin.reasonPlaceholder")}
                        className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white text-sm focus:border-[rgba(var(--accent-primary),0.5)] outline-none"
                    />
                </div>

                <div className="flex gap-2">
                    <button
                        onClick={() => amount && onConfirm(parseFloat(amount), note)}
                        disabled={!amount || parseFloat(amount) <= 0}
                        className={`flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${isAdd ? "bg-emerald-500 hover:bg-emerald-600 text-white" : "bg-red-500 hover:bg-red-600 text-white"
                            }`}
                    >
                        {isAdd ? t("admin.confirmDeposit") : t("admin.confirmWithdraw")}
                    </button>
                    <button onClick={onClose} className="flex-1 px-4 py-2.5 rounded-xl text-sm font-semibold bg-white/5 hover:bg-white/10 text-white transition-colors">
                        {t("common.cancel")}
                    </button>
                </div>
            </Card>
        </div>
    )
}

const FiltersBar: React.FC<{
    filter: FilterState
    onChange: (f: Partial<FilterState>) => void
    placeholder?: string
    sortOptions?: { value: string; label: string }[]
    statusOptions?: { value: string; label: string }[]
}> = ({ filter, onChange, placeholder = "Buscar…", sortOptions, statusOptions }) => {
    const { t } = useLocale()

    return (
        <div className="flex flex-wrap gap-2 items-center">
            <div className="relative flex-1 min-w-[180px]">
                <Search size={15} className="absolute left-3 top-1/2 -translate-y-1/2 text-[rgb(var(--text-secondary))]" />
                <input
                    type="text"
                    value={filter.search}
                    onChange={e => onChange({ search: e.target.value })}
                    placeholder={placeholder}
                    className="w-full bg-white/5 border border-white/10 rounded-xl pl-9 pr-4 py-2.5 text-white text-sm focus:border-[rgba(var(--accent-primary),0.5)] outline-none"
                />
            </div>
            {sortOptions && (
                <select
                    value={filter.sortBy}
                    onChange={e => onChange({ sortBy: e.target.value })}
                    className="bg-white/5 border border-white/10 rounded-xl px-3 py-2.5 text-white text-sm outline-none"
                >
                    {sortOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
            )}
            {sortOptions && (
                <button
                    onClick={() => onChange({ sortDir: filter.sortDir === "asc" ? "desc" : "asc" })}
                    className="p-2.5 bg-white/5 border border-white/10 rounded-xl hover:bg-white/10 transition-colors"
                >
                    {filter.sortDir === "asc" ? <SortAsc size={15} className="text-white" /> : <SortDesc size={15} className="text-white" />}
                </button>
            )}
            {statusOptions && (
                <select
                    value={filter.status || ""}
                    onChange={e => onChange({ status: e.target.value || undefined })}
                    className="bg-white/5 border border-white/10 rounded-xl px-3 py-2.5 text-white text-sm outline-none"
                >
                    <option value="">{t("admin.allStatuses")}</option>
                    {statusOptions.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                </select>
            )}
        </div>
    )
}

const AccountRow: React.FC<{
    acc: any
    onAdd: () => void
    onRemove: () => void
    onFreeze: () => void
    onViewHistory?: () => void
}> = ({ acc, onAdd, onRemove, onFreeze, onViewHistory }) => {
    const { t } = useLocale()

    return (
        <div className="flex items-center justify-between py-3 px-1 border-b border-white/5 last:border-0 group">
            <div className="flex items-center gap-3">
                <div className={`w-2 h-2 rounded-full flex-shrink-0 ${acc.frozen ? "bg-red-400" : "bg-emerald-400"}`} />
                <div>
                    <div className="flex items-center gap-2">
                        <p className="text-sm text-white font-medium">{acc.account_name}</p>
                        {acc.frozen && <Pill label={t("cards.blocked")} color="red" />}
                    </div>
                    <div className="flex items-center gap-2 mt-0.5">
                        <p className="text-xs text-[rgb(var(--text-secondary))]">#{acc.id}</p>
                        {acc.account_type && <Pill label={acc.account_type} color="blue" />}
                    </div>
                </div>
            </div>
            <div className="flex items-center gap-1">
                <p className="text-sm font-bold text-white mr-2">{fmt.money(acc.balance)}</p>
                <ActionBtn onClick={onAdd} icon={<Plus size={13} />} label={t("admin.addMoney")} color="green" />
                <ActionBtn onClick={onRemove} icon={<Minus size={13} />} label={t("admin.removeMoney")} color="red" />
                <ActionBtn onClick={onFreeze} icon={acc.frozen ? <Unlock size={13} /> : <Lock size={13} />} label={acc.frozen ? t("admin.unfreezeAccount") : t("admin.freezeAccount")} color="yellow" />
                {onViewHistory && (
                    <ActionBtn onClick={onViewHistory} icon={<History size={13} />} label={t("transactions.history")} color="blue" />
                )}
                <ActionBtn onClick={() => fmt.copyToClipboard(String(acc.id))} icon={<Copy size={13} />} label={t("common.copyId")} color="purple" />
            </div>
        </div>
    )
}

export const AdminPanel: React.FC<AdminPanelProps> = ({ onClose }) => {
    const { t } = useLocale()

    const [activeTab, setActiveTab] = useState<TabId>("overview")
    const [adminData, setAdminData] = useState<any>(null)
    const [alerts, setAlerts] = useState<any[]>([])
    const [loading, setLoading] = useState(true)
    const [refreshing, setRefreshing] = useState(false)

    const [searchQuery, setSearchQuery] = useState("")
    const [searchResult, setSearchResult] = useState<any>(null)
    const [searchLoading, setSearchLoading] = useState(false)
    const [expandedUserId, setExpandedUserId] = useState<string | null>(null)

    const [moneyModal, setMoneyModal] = useState<MoneyModal | null>(null)
    const { dialog: confirmDialog, confirm, resolve: resolveConfirm } = useConfirm()

    const [accountsFilter, setAccountsFilter] = useState<FilterState>({ search: "", sortBy: "balance", sortDir: "desc" })
    const [loansFilter, setLoansFilter] = useState<FilterState>({ search: "", sortBy: "amount", sortDir: "desc", status: "active" })
    const [txFilter, setTxFilter] = useState<FilterState>({ search: "", sortBy: "date", sortDir: "desc" })

    const [dismissedAlerts, setDismissedAlerts] = useState<Set<number>>(new Set())
    const [alertFilter, setAlertFilter] = useState<Severity | "all">("all")

    const { log: auditLog, record: recordAudit } = useAdminAudit()

    const { toasts, push: pushToast, dismiss: dismissToast } = useToasts()

    useEffect(() => {
        const handleEscape = (e: KeyboardEvent) => {
            if (e.key === "Escape") {
                if (moneyModal || confirmDialog) return
                onClose()
            }
        }
        window.addEventListener("keydown", handleEscape)
        return () => window.removeEventListener("keydown", handleEscape)
    }, [onClose, moneyModal, confirmDialog])

    const loadAdminData = useCallback(async (silent = false) => {
        if (!silent) setLoading(true)
        else setRefreshing(true)
        try {
            const result = await fetchNui("getAdminData", {})
            setAdminData(result)
        } catch (e) {
            pushToast(t("admin.errorLoadingAdmin"), "error")
        }
        setLoading(false)
        setRefreshing(false)
    }, [])

    const loadAlerts = useCallback(async () => {
        try {
            const result = await fetchNui("adminGetAlerts", {})
            setAlerts(result || [])
        } catch (e) {
            pushToast(t("admin.errorLoadingAlerts"), "error")
        }
    }, [])

    useEffect(() => {
        loadAdminData()
        loadAlerts()
    }, [])

    useEffect(() => {
        const interval = setInterval(() => {
            if (activeTab === "overview") loadAdminData(true)
        }, 60_000)
        return () => clearInterval(interval)
    }, [activeTab])

    const handleSearch = async () => {
        if (!searchQuery.trim()) return
        setSearchLoading(true)
        try {
            const result = await fetchNui("adminSearchUser", { query: searchQuery.trim() })
            setSearchResult(result)
            if (!result?.error) {
                recordAudit("search_user", `${t("admin.searchLog")} "${searchQuery}"`, result?.identifier)
            }
        } catch {
            pushToast(t("admin.errorSearch"), "error")
        }
        setSearchLoading(false)
    }

    const handleMoneyConfirm = async (amount: number, note: string) => {
        if (!moneyModal) return
        const isAdd = moneyModal.mode === "add"
        try {
            await fetchNui(isAdd ? "adminAddMoney" : "adminRemoveMoney", {
                accountId: moneyModal.accountId,
                amount,
                note,
            })
            pushToast(`${isAdd ? t("admin.fundsAdded") : t("admin.fundsRemoved")}: ${fmt.money(amount)}`, "success")
            recordAudit(
                isAdd ? "add_money" : "remove_money",
                `${fmt.money(amount)}${note ? ` — ${note}` : ""}`,
                String(moneyModal.accountId)
            )
            setMoneyModal(null)
            loadAdminData(true)
            if (searchResult) handleSearch()
        } catch {
            pushToast(t("admin.errorOperation"), "error")
        }
    }

    const handleCancelLoan = (loanId: number, identifier?: string) => {
        confirm({
            title: t("admin.cancelLoanTitle"),
            description: t("admin.cancelLoanDesc"),
            confirmLabel: t("admin.cancelLoanTitle"),
            variant: "danger",
            onConfirm: async () => {
                await fetchNui("adminCancelLoan", { loanId })
                pushToast(t("admin.loanCancelled"), "success")
                recordAudit("cancel_loan", `Loan #${loanId}`, identifier)
                loadAdminData(true)
            }
        })
    }

    const handleFreezeAccount = (accountId: number, frozen: boolean) => {
        confirm({
            title: frozen ? t("admin.unfreezeAccount") : t("admin.freezeAccount"),
            description: frozen
                ? t("admin.accountUnfreezeDesc")
                : t("admin.accountFreezeDesc"),
            confirmLabel: frozen ? t("admin.unfreezeAccount") : t("admin.freezeAccount"),
            variant: frozen ? "default" : "warning",
            onConfirm: async () => {
                await fetchNui("adminFreezeAccount", { accountId })
                pushToast(frozen ? t("admin.accountUnfrozen") : t("admin.accountFrozen"), "success")
                recordAudit(frozen ? "unfreeze_account" : "freeze_account", `Account #${accountId}`)
                loadAdminData(true)
                if (searchResult) handleSearch()
            }
        })
    }

    const handleDeleteScheduled = (transferId: number) => {
        confirm({
            title: t("admin.deleteScheduled"),
            description: t("admin.deleteScheduledDesc"),
            confirmLabel: t("common.delete"),
            variant: "danger",
            onConfirm: async () => {
                await fetchNui("adminDeleteScheduled", { transferId })
                pushToast(t("admin.transferDeleted"), "success")
                recordAudit("delete_scheduled", `Transfer #${transferId}`)
                loadAdminData(true)
            }
        })
    }

    const handleCancelRequest = (requestId: number) => {
        confirm({
            title: t("admin.cancelRequest"),
            description: t("admin.cancelRequestDesc"),
            confirmLabel: t("common.cancel"),
            variant: "warning",
            onConfirm: async () => {
                await fetchNui("adminCancelRequest", { requestId })
                pushToast(t("admin.requestRejected"), "success")
                recordAudit("cancel_request", `Request #${requestId}`)
                loadAdminData(true)
            }
        })
    }

    const handleDismissAlert = (index: number) => {
        setDismissedAlerts(prev => new Set([...prev, index]))
    }

    const filteredAlerts = alerts
        .filter((_, i) => !dismissedAlerts.has(i))
        .filter(a => alertFilter === "all" || a.severity === alertFilter)

    const filteredAccounts = (adminData?.topAccounts || [])
        .filter((a: any) => !accountsFilter.search || a.account_name?.toLowerCase().includes(accountsFilter.search.toLowerCase()) || a.owner?.includes(accountsFilter.search))
        .sort((a: any, b: any) => {
            const dir = accountsFilter.sortDir === "asc" ? 1 : -1
            if (accountsFilter.sortBy === "balance") return (parseFloat(a.balance) - parseFloat(b.balance)) * dir
            return a.account_name?.localeCompare(b.account_name) * dir
        })

    const filteredLoans = (adminData?.allLoans || [])
        .filter((l: any) => !loansFilter.status || l.status === loansFilter.status)
        .filter((l: any) => !loansFilter.search || l.user_identifier?.includes(loansFilter.search))

    const filteredTx = (adminData?.recentTransactions || [])
        .filter((tx: any) => !txFilter.search || tx.type?.toLowerCase().includes(txFilter.search.toLowerCase()) || tx.account_name?.toLowerCase().includes(txFilter.search.toLowerCase()) || tx.description?.toLowerCase().includes(txFilter.search.toLowerCase()))

    const severityIcon = (s: string) => {
        if (s === "critical") return <AlertCircle size={15} className="text-red-400 flex-shrink-0" />
        if (s === "warning") return <AlertTriangle size={15} className="text-yellow-400 flex-shrink-0" />
        return <Activity size={15} className="text-blue-400 flex-shrink-0" />
    }

    const alertTypeLabel = (type: string) => {
        const tr = t("admin." + type);
        return tr !== ("admin." + type) ? tr : type;
    }

    const tabs: { id: TabId; label: string; icon: React.ReactNode; badge?: number }[] = [
        { id: "overview", label: t("admin.overview"), icon: <BarChart3 size={14} /> },
        { id: "alerts", label: t("admin.alerts"), icon: <ShieldAlert size={14} />, badge: filteredAlerts.length },
        { id: "users", label: t("admin.users"), icon: <Users size={14} /> },
        { id: "accounts", label: t("admin.accounts"), icon: <CreditCard size={14} /> },
        { id: "loans", label: t("admin.loans"), icon: <Banknote size={14} /> },
        { id: "transactions", label: t("admin.transactions"), icon: <History size={14} /> },
        { id: "banks", label: t("admin.banks"), icon: <Building2 size={14} /> },
        { id: "scheduled", label: t("admin.scheduled"), icon: <Clock size={14} /> },
        { id: "requests", label: t("admin.requests"), icon: <ArrowLeftRight size={14} />, badge: adminData?.stats?.pendingRequests },
        { id: "audit", label: t("admin.audit"), icon: <FileText size={14} />, badge: auditLog.length > 0 ? auditLog.length : undefined },
    ]

    if (loading) {
        return (
            <div className="flex-1 flex flex-col h-full p-6 gap-4">
                <div className="flex items-center gap-3 mb-2">
                    <Skeleton className="w-10 h-10 rounded-xl" />
                    <div className="space-y-2">
                        <Skeleton className="w-40 h-5" />
                        <Skeleton className="w-24 h-3" />
                    </div>
                </div>
                <div className="grid grid-cols-3 gap-3">
                    {Array.from({ length: 9 }).map((_, i) => <Skeleton key={i} className="h-24" />)}
                </div>
            </div>
        )
    }

    return (
        <>
            <div className="flex-1 flex flex-col h-full overflow-hidden">

                <div className="px-6 py-4 flex items-center justify-between border-b border-white/5 flex-shrink-0">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-red-500 to-orange-500 flex items-center justify-center shadow-lg shadow-red-500/20">
                            <Shield size={18} className="text-white" />
                        </div>
                        <div>
                            <h1 className="text-base font-bold text-white leading-tight">{t("admin.title")}</h1>
                            <p className="text-[11px] text-[rgb(var(--text-secondary))]">
                                {t("admin.subtitle")} · {adminData?.stats?.totalAccounts ?? "—"} {t("admin.active")}
                            </p>
                        </div>
                    </div>
                    <div className="flex items-center gap-1.5">
                        <button
                            onClick={() => { loadAdminData(true); loadAlerts() }}
                            className="p-2 hover:bg-white/10 rounded-lg transition-colors relative"
                            title={t("admin.refreshAdmin")}
                        >
                            <RefreshCcw size={15} className={`text-[rgb(var(--text-secondary))] ${refreshing ? "animate-spin" : ""}`} />
                        </button>
                        <button
                            onClick={onClose}
                            className="p-2 hover:bg-red-500/15 rounded-lg transition-colors"
                        >
                            <X size={15} className="text-red-400" />
                        </button>
                    </div>
                </div>

                <div className="px-4 py-2 flex gap-1 overflow-x-auto border-b border-white/5 flex-shrink-0 scrollbar-none">
                    {tabs.map(tab => (
                        <button
                            key={tab.id}
                            onClick={() => setActiveTab(tab.id)}
                            className={`px-3 py-1.5 rounded-lg text-[11px] font-medium flex items-center gap-1.5 whitespace-nowrap transition-all relative flex-shrink-0 ${activeTab === tab.id
                                ? "bg-[rgba(var(--accent-primary),0.18)] text-white border border-[rgba(var(--accent-primary),0.25)]"
                                : "text-[rgb(var(--text-secondary))] hover:bg-white/5 hover:text-white"
                                }`}
                        >
                            {tab.icon}
                            {tab.label}
                            {tab.badge != null && tab.badge > 0 && (
                                <span className="ml-0.5 min-w-[16px] h-4 px-1 bg-red-500 text-white text-[9px] font-bold rounded-full flex items-center justify-center">
                                    {tab.badge > 99 ? "99+" : tab.badge}
                                </span>
                            )}
                        </button>
                    ))}
                </div>

                <div className="flex-1 overflow-y-auto p-5 space-y-4">

                    {activeTab === "overview" && adminData?.stats && (
                        <>
                            <div className="grid grid-cols-3 gap-3">
                                <StatCard label={t("admin.totalAccounts")} value={adminData.stats.totalAccounts} icon={<CreditCard size={16} />} />
                                <StatCard label={t("admin.totalBalance")} value={fmt.money(adminData.stats.totalBalance)} icon={<DollarSign size={16} />} />
                                <StatCard label={t("admin.activeLoans")} value={adminData.stats.activeLoans} icon={<Banknote size={16} />} />
                                <StatCard label={t("admin.loanAmount")} value={fmt.money(adminData.stats.totalLoanAmount)} icon={<TrendingUp size={16} />} />
                                <StatCard label={t("admin.transactions")} value={adminData.stats.totalTransactions} icon={<History size={16} />} />
                                <StatCard label={t("admin.totalSavings")} value={fmt.money(adminData.stats.totalSavings)} icon={<PiggyBank size={16} />} />
                                <StatCard label={t("admin.activeScheduled")} value={adminData.stats.totalScheduled} icon={<Clock size={16} />} />
                                <StatCard label={t("admin.pendingRequests")} value={adminData.stats.pendingRequests} icon={<ArrowLeftRight size={16} />} />
                                <StatCard label={t("admin.transactionVolume")} value={fmt.money(adminData.stats.totalTransactionVolume)} icon={<BarChart3 size={16} />} />
                            </div>

                            {filteredAlerts.length > 0 && (
                                <Card className="p-4 border-yellow-500/20 bg-yellow-500/5">
                                    <div className="flex items-center justify-between mb-3">
                                        <div className="flex items-center gap-2">
                                            <ShieldAlert size={16} className="text-yellow-400" />
                                            <span className="text-sm font-semibold text-white">
                                                {filteredAlerts.length} alerta{filteredAlerts.length !== 1 ? "s" : ""} activa{filteredAlerts.length !== 1 ? "s" : ""}
                                            </span>
                                        </div>
                                        <button onClick={() => setActiveTab("alerts")} className="text-xs text-yellow-400 hover:underline flex items-center gap-1">
                                            {t("admin.viewAll")} <ChevronRight size={12} />
                                        </button>
                                    </div>
                                    <div className="space-y-1.5">
                                        {filteredAlerts.slice(0, 3).map((alert, i) => (
                                            <div key={i} className="flex items-center gap-2 text-xs text-[rgb(var(--text-secondary))]">
                                                {severityIcon(alert.severity)}
                                                <span>{alertTypeLabel(alert.type)}</span>
                                                <span className="text-white font-medium">{alert.accountName}</span>
                                                {alert.amount && <span className="ml-auto text-white font-semibold">{fmt.money(alert.amount)}</span>}
                                            </div>
                                        ))}
                                    </div>
                                </Card>
                            )}
                        </>
                    )}

                    {activeTab === "alerts" && (
                        <div className="space-y-3">
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-2">
                                    {(["all", "critical", "warning", "info"] as const).map(s => (
                                        <button
                                            key={s}
                                            onClick={() => setAlertFilter(s)}
                                            className={`px-3 py-1 rounded-lg text-xs font-medium transition-all ${alertFilter === s
                                                ? "bg-[rgba(var(--accent-primary),0.2)] text-white border border-[rgba(var(--accent-primary),0.3)]"
                                                : "text-[rgb(var(--text-secondary))] hover:bg-white/5"
                                                }`}
                                        >
                                            {s === "all" ? t("transactions.all") : s.charAt(0).toUpperCase() + s.slice(1)}
                                        </button>
                                    ))}
                                </div>
                                <button onClick={loadAlerts} className="p-1.5 hover:bg-white/10 rounded-lg transition-colors">
                                    <RefreshCcw size={14} className="text-[rgb(var(--text-secondary))]" />
                                </button>
                            </div>

                            {filteredAlerts.length === 0 ? (
                                <EmptyState
                                    icon={<ShieldCheck size={32} />}
                                    title={t("admin.noActiveAlerts")}
                                    subtitle={t("admin.noSuspiciousActivity")}
                                />
                            ) : (
                                filteredAlerts.map((alert, index) => (
                                    <Card key={index} className={`p-4 border-l-2 ${alert.severity === "critical" ? "border-l-red-500" :
                                        alert.severity === "warning" ? "border-l-yellow-500" : "border-l-blue-500"
                                        }`}>
                                        <div className="flex items-start gap-3">
                                            <div className="mt-0.5">{severityIcon(alert.severity)}</div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center justify-between gap-2 mb-1">
                                                    <div className="flex items-center gap-2 flex-wrap">
                                                        <span className="text-sm font-semibold text-white">{alertTypeLabel(alert.type)}</span>
                                                        <Pill
                                                            label={alert.severity}
                                                            color={alert.severity === "critical" ? "red" : alert.severity === "warning" ? "yellow" : "blue"}
                                                        />
                                                    </div>
                                                    <div className="flex items-center gap-1 flex-shrink-0">
                                                        <span className="text-[10px] text-[rgb(var(--text-secondary))]">{fmt.date(alert.date)}</span>
                                                        <button onClick={() => handleDismissAlert(index)} className="p-1 hover:bg-white/10 rounded ml-1" title={t("admin.dismiss")}>
                                                            <X size={11} className="text-[rgb(var(--text-secondary))]" />
                                                        </button>
                                                    </div>
                                                </div>
                                                <p className="text-xs text-[rgb(var(--text-secondary))] mb-1">
                                                    {alert.accountName} · <span className="font-mono">{fmt.shortId(alert.owner, 25)}</span>
                                                </p>
                                                <div className="flex items-center gap-3 flex-wrap">
                                                    {alert.amount && (
                                                        <span className="text-sm font-bold text-white">{fmt.money(alert.amount)}</span>
                                                    )}
                                                    {alert.txCount && (
                                                        <span className="text-xs text-[rgb(var(--text-secondary))]">{alert.txCount} transacciones</span>
                                                    )}
                                                    {alert.description && (
                                                        <span className="text-xs text-[rgb(var(--text-secondary))]">{alert.description}</span>
                                                    )}
                                                </div>
                                            </div>
                                        </div>
                                    </Card>
                                ))
                            )}
                        </div>
                    )}

                    {activeTab === "users" && (
                        <div className="space-y-4">
                            <div className="flex gap-2">
                                <div className="relative flex-1">
                                    <Search size={15} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-[rgb(var(--text-secondary))]" />
                                    <input
                                        type="text"
                                        value={searchQuery}
                                        onChange={e => setSearchQuery(e.target.value)}
                                        onKeyDown={e => e.key === "Enter" && handleSearch()}
                                        placeholder={t("admin.searchUserPlaceholder")}
                                        className="w-full bg-white/5 border border-white/10 rounded-xl pl-10 pr-4 py-2.5 text-white text-sm focus:border-[rgba(var(--accent-primary),0.5)] outline-none"
                                    />
                                </div>
                                <Button onClick={handleSearch} disabled={searchLoading}>
                                    {searchLoading ? <RefreshCcw size={14} className="animate-spin" /> : <Search size={14} />}
                                    <span className="ml-1.5">{t("admin.search")}</span>
                                </Button>
                            </div>

                            {searchLoading && (
                                <div className="space-y-3">
                                    {[1, 2].map(i => <Skeleton key={i} className="h-24" />)}
                                </div>
                            )}

                            {searchResult && !searchLoading && (
                                <div className="space-y-3">
                                    {searchResult.error ? (
                                        <EmptyState icon={<UserX size={28} />} title={t("admin.userNotFound")} subtitle={searchResult.error} />
                                    ) : (
                                        <>
                                            <Card className="p-4">
                                                <div className="flex items-center justify-between">
                                                    <div className="flex items-center gap-3">
                                                        <div className="w-10 h-10 rounded-full bg-gradient-to-br from-blue-500 to-purple-500 flex items-center justify-center">
                                                            <UserCheck size={18} className="text-white" />
                                                        </div>
                                                        <div>
                                                            <p className="text-sm font-semibold text-white">{fmt.shortId(searchResult.identifier, 30)}</p>
                                                            <p className="text-xs text-[rgb(var(--text-secondary))]">Credit score: <span className="text-white font-medium">{searchResult.creditScore ?? "—"}</span></p>
                                                        </div>
                                                    </div>
                                                    <button onClick={() => fmt.copyToClipboard(searchResult.identifier)} className="p-1.5 hover:bg-white/10 rounded-lg" title="Copiar identifier">
                                                        <Copy size={13} className="text-[rgb(var(--text-secondary))]" />
                                                    </button>
                                                </div>
                                                <div className="grid grid-cols-3 gap-3 mt-3 pt-3 border-t border-white/5">
                                                    <div className="text-center">
                                                        <p className="text-lg font-bold text-white">{searchResult.accounts?.length ?? 0}</p>
                                                        <p className="text-[10px] text-[rgb(var(--text-secondary))]">{t("admin.accounts")}</p>
                                                    </div>
                                                    <div className="text-center">
                                                        <p className="text-lg font-bold text-white">{searchResult.loans?.filter((l: any) => l.status === "active").length ?? 0}</p>
                                                        <p className="text-[10px] text-[rgb(var(--text-secondary))]">{t("admin.loans")}</p>
                                                    </div>
                                                    <div className="text-center">
                                                        <p className="text-lg font-bold text-white">{searchResult.transactions?.length ?? 0}</p>
                                                        <p className="text-[10px] text-[rgb(var(--text-secondary))]">{t("admin.transactions")}</p>
                                                    </div>
                                                </div>
                                            </Card>

                                            {searchResult.accounts?.length > 0 && (
                                                <Card className="p-4">
                                                    <h3 className="text-xs font-semibold text-[rgb(var(--text-secondary))] uppercase tracking-wider mb-3">
                                                        Cuentas ({searchResult.accounts.length})
                                                    </h3>
                                                    {searchResult.accounts.map((acc: any) => (
                                                        <AccountRow
                                                            key={acc.id}
                                                            acc={acc}
                                                            onAdd={() => setMoneyModal({ accountId: acc.id, accountName: acc.account_name, mode: "add" })}
                                                            onRemove={() => setMoneyModal({ accountId: acc.id, accountName: acc.account_name, mode: "remove" })}
                                                            onFreeze={() => handleFreezeAccount(acc.id, !!acc.frozen)}
                                                        />
                                                    ))}
                                                </Card>
                                            )}

                                            {searchResult.loans?.length > 0 && (
                                                <Card className="p-4">
                                                    <h3 className="text-xs font-semibold text-[rgb(var(--text-secondary))] uppercase tracking-wider mb-3">
                                                        Préstamos ({searchResult.loans.length})
                                                    </h3>
                                                    {searchResult.loans.map((loan: any) => (
                                                        <div key={loan.id} className="flex items-center justify-between py-2.5 border-b border-white/5 last:border-0">
                                                            <div>
                                                                <div className="flex items-center gap-2">
                                                                    <p className="text-sm text-white font-medium">{fmt.money(loan.amount)}</p>
                                                                    <Pill label={loan.loan_type || "personal"} color="purple" />
                                                                    <Pill label={loan.status} color={loan.status === "active" ? "green" : "blue"} />
                                                                </div>
                                                                <p className="text-xs text-[rgb(var(--text-secondary))] mt-0.5">
                                                                    Pendiente: <span className="text-white">{fmt.money(loan.remaining)}</span>
                                                                </p>
                                                            </div>
                                                            {loan.status === "active" && (
                                                                <ActionBtn onClick={() => handleCancelLoan(loan.id)} icon={<Trash2 size={13} />} label={t("admin.cancelLoanTitle")} color="red" />
                                                            )}
                                                        </div>
                                                    ))}
                                                </Card>
                                            )}

                                            {searchResult.savings?.length > 0 && (
                                                <Card className="p-4">
                                                    <h3 className="text-xs font-semibold text-[rgb(var(--text-secondary))] uppercase tracking-wider mb-3">
                                                        Ahorros ({searchResult.savings.length})
                                                    </h3>
                                                    {searchResult.savings.map((saving: any) => {
                                                        const pct = saving.goal_amount > 0 ? (saving.current_amount / saving.goal_amount) * 100 : 0
                                                        return (
                                                            <div key={saving.id} className="py-2.5 border-b border-white/5 last:border-0">
                                                                <div className="flex justify-between items-center mb-1.5">
                                                                    <p className="text-sm text-white">{saving.goal_name || t("admin.savings")}</p>
                                                                    <p className="text-xs text-[rgb(var(--text-secondary))]">
                                                                        {fmt.money(saving.current_amount)} / {fmt.money(saving.goal_amount)}
                                                                    </p>
                                                                </div>
                                                                <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                                                                    <div className="h-full bg-emerald-500 rounded-full" style={{ width: `${Math.min(pct, 100)}%` }} />
                                                                </div>
                                                                <p className="text-[10px] text-[rgb(var(--text-secondary))] mt-1">{pct.toFixed(1)}% {t("admin.completed")}</p>
                                                            </div>
                                                        )
                                                    })}
                                                </Card>
                                            )}

                                            {searchResult.contacts?.length > 0 && (
                                                <Card className="p-4">
                                                    <h3 className="text-xs font-semibold text-[rgb(var(--text-secondary))] uppercase tracking-wider mb-3">
                                                        Contactos ({searchResult.contacts.length})
                                                    </h3>
                                                    <div className="grid grid-cols-2 gap-2">
                                                        {searchResult.contacts.map((c: any) => (
                                                            <div key={c.id} className="flex items-center gap-2 py-1.5">
                                                                <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center flex-shrink-0">
                                                                    <Users size={11} className="text-[rgb(var(--text-secondary))]" />
                                                                </div>
                                                                <div>
                                                                    <p className="text-xs text-white">{c.contact_name}</p>
                                                                    <p className="text-[10px] text-[rgb(var(--text-secondary))]">#{c.contact_account_id}</p>
                                                                </div>
                                                            </div>
                                                        ))}
                                                    </div>
                                                </Card>
                                            )}

                                            {searchResult.transactions?.length > 0 && (
                                                <Card className="p-4">
                                                    <h3 className="text-xs font-semibold text-[rgb(var(--text-secondary))] uppercase tracking-wider mb-3">
                                                        Transacciones recientes ({searchResult.transactions.length})
                                                    </h3>
                                                    <div className="max-h-52 overflow-y-auto space-y-0 divide-y divide-white/5">
                                                        {searchResult.transactions.map((tx: any) => (
                                                            <div key={tx.id} className="flex items-center justify-between py-2">
                                                                <div>
                                                                    <p className="text-xs text-white">{tx.type} · {tx.account_name}</p>
                                                                    <p className="text-[10px] text-[rgb(var(--text-secondary))]">{fmt.date(tx.created_at)}</p>
                                                                </div>
                                                                <span className={`text-sm font-bold ${parseFloat(tx.amount) >= 0 ? "text-emerald-400" : "text-red-400"}`}>
                                                                    {fmt.money(tx.amount)}
                                                                </span>
                                                            </div>
                                                        ))}
                                                    </div>
                                                </Card>
                                            )}
                                        </>
                                    )}
                                </div>
                            )}
                        </div>
                    )}

                    {activeTab === "accounts" && (
                        <div className="space-y-3">
                            <FiltersBar
                                filter={accountsFilter}
                                onChange={f => setAccountsFilter(prev => ({ ...prev, ...f }))}
                                placeholder={t("admin.searchAccountOwner")}
                                sortOptions={[
                                    { value: "balance", label: t("admin.byBalance") },
                                    { value: "name", label: t("admin.byName") },
                                ]}
                            />
                            {filteredAccounts.length === 0 ? (
                                <EmptyState icon={<CreditCard size={28} />} title={t("admin.noAccounts")} />
                            ) : (
                                <Card className="p-4 divide-y divide-white/5">
                                    {filteredAccounts.map((acc: any) => (
                                        <AccountRow
                                            key={acc.id}
                                            acc={acc}
                                            onAdd={() => setMoneyModal({ accountId: acc.id, accountName: acc.account_name, mode: "add" })}
                                            onRemove={() => setMoneyModal({ accountId: acc.id, accountName: acc.account_name, mode: "remove" })}
                                            onFreeze={() => handleFreezeAccount(acc.id, !!acc.frozen)}
                                        />
                                    ))}
                                </Card>
                            )}
                        </div>
                    )}

                    {activeTab === "loans" && (
                        <div className="space-y-3">
                            <FiltersBar
                                filter={loansFilter}
                                onChange={f => setLoansFilter(prev => ({ ...prev, ...f }))}
                                placeholder={t("admin.search")}
                                statusOptions={[
                                    { value: "active", label: t("admin.active") },
                                    { value: "paid", label: t("admin.paid") },
                                    { value: "defaulted", label: t("admin.defaulted") },
                                ]}
                            />
                            {filteredLoans.length === 0 ? (
                                <EmptyState icon={<Banknote size={28} />} title={t("admin.noLoans")} subtitle={t("admin.noLoansFilter")} />
                            ) : (
                                <div className="space-y-2">
                                    {filteredLoans.map((loan: any) => (
                                        <Card key={loan.id} className="p-3.5 flex items-center justify-between">
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-2 mb-1">
                                                    <p className="text-sm font-semibold text-white">{fmt.money(loan.amount)}</p>
                                                    <Pill label={loan.loan_type || "personal"} color="purple" />
                                                    <Pill label={loan.status} color={loan.status === "active" ? "green" : loan.status === "defaulted" ? "red" : "blue"} />
                                                </div>
                                                <p className="text-xs text-[rgb(var(--text-secondary))] truncate">
                                                    {fmt.shortId(loan.user_identifier, 28)}
                                                </p>
                                                <p className="text-xs text-[rgb(var(--text-secondary))]">
                                                    Pendiente: <span className="text-white">{fmt.money(loan.remaining)}</span>
                                                </p>
                                            </div>
                                            <div className="flex items-center gap-1 ml-3">
                                                <ActionBtn onClick={() => fmt.copyToClipboard(loan.user_identifier)} icon={<Copy size={13} />} label={t("common.copyId")} color="blue" />
                                                {loan.status === "active" && (
                                                    <ActionBtn onClick={() => handleCancelLoan(loan.id, loan.user_identifier)} icon={<Trash2 size={13} />} label={t("admin.cancelLoanTitle")} color="red" />
                                                )}
                                            </div>
                                        </Card>
                                    ))}
                                </div>
                            )}
                        </div>
                    )}

                    {activeTab === "transactions" && (
                        <div className="space-y-3">
                            <FiltersBar
                                filter={txFilter}
                                onChange={f => setTxFilter(prev => ({ ...prev, ...f }))}
                                placeholder={t("admin.searchTypeAccountDesc")}
                            />
                            <div className="space-y-1.5 max-h-[60vh] overflow-y-auto">
                                {filteredTx.length === 0 ? (
                                    <EmptyState icon={<History size={28} />} title={t("admin.noTransactions")} />
                                ) : filteredTx.map((tx: any) => (
                                    <Card key={tx.id} className="px-4 py-3 flex items-center gap-3">
                                        <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${parseFloat(tx.amount) >= 0 ? "bg-emerald-500/15" : "bg-red-500/15"}`}>
                                            {parseFloat(tx.amount) >= 0
                                                ? <TrendingUp size={14} className="text-emerald-400" />
                                                : <TrendingDown size={14} className="text-red-400" />}
                                        </div>
                                        <div className="flex-1 min-w-0">
                                            <div className="flex items-center gap-2">
                                                <p className="text-xs font-medium text-white">{tx.type}</p>
                                                <Pill label={tx.account_name || `#${tx.account_id}`} color="blue" />
                                            </div>
                                            <p className="text-[11px] text-[rgb(var(--text-secondary))] truncate">{tx.description || "—"}</p>
                                            <p className="text-[10px] text-[rgb(var(--text-secondary))]">{fmt.date(tx.created_at)}</p>
                                        </div>
                                        <span className={`text-sm font-bold flex-shrink-0 ${parseFloat(tx.amount) >= 0 ? "text-emerald-400" : "text-red-400"}`}>
                                            {fmt.money(tx.amount)}
                                        </span>
                                    </Card>
                                ))}
                            </div>
                        </div>
                    )}

                    {activeTab === "banks" && (
                        <div className="space-y-3">
                            {!adminData?.bankOwnerships?.length ? (
                                <EmptyState icon={<Building2 size={28} />} title={t("admin.noRegisteredBanks")} />
                            ) : adminData.bankOwnerships.map((bank: any) => (
                                <Card key={bank.id} className="p-4">
                                    <div className="flex items-center justify-between">
                                        <div className="flex items-center gap-3">
                                            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-blue-500 to-cyan-500 flex items-center justify-center flex-shrink-0">
                                                <Building2 size={16} className="text-white" />
                                            </div>
                                            <div>
                                                <p className="text-sm font-semibold text-white">{bank.bank_name}</p>
                                                <p className="text-xs text-[rgb(var(--text-secondary))]">{fmt.shortId(bank.owner, 25)}</p>
                                            </div>
                                        </div>
                                        <div className="text-right">
                                            <p className="text-sm text-white">{t("admin.commission")}: <span className="font-bold">{fmt.percent(bank.commission_rate || 0.01)}</span></p>
                                            <p className="text-xs text-emerald-400 font-medium">{t("admin.earned")}: {fmt.money(bank.total_earned)}</p>
                                        </div>
                                    </div>
                                </Card>
                            ))}
                        </div>
                    )}

                    {activeTab === "scheduled" && (
                        <div className="space-y-2">
                            {!adminData?.allScheduled?.length ? (
                                <EmptyState icon={<Clock size={28} />} title={t("admin.noScheduledTransfers")} />
                            ) : adminData.allScheduled.map((st: any) => (
                                <Card key={st.id} className="p-3.5 flex items-center gap-3">
                                    <div className={`w-2 h-2 rounded-full flex-shrink-0 ${st.enabled ? "bg-emerald-400" : "bg-[rgb(var(--text-secondary))]"}`} />
                                    <div className="flex-1 min-w-0">
                                        <div className="flex items-center gap-2 mb-0.5">
                                            <p className="text-sm font-semibold text-white">{fmt.money(st.amount)}</p>
                                            <Pill label={st.frequency} color="purple" />
                                        </div>
                                        <p className="text-xs text-[rgb(var(--text-secondary))] truncate">
                                            {st.from_account_name || `#${st.from_account_id}`} → {st.to_account_name || `#${st.to_account_id}`}
                                        </p>
                                        <p className="text-[10px] text-[rgb(var(--text-secondary))]">
                                            {t("admin.nextExec")}: {fmt.date(st.next_execution)} · {fmt.shortId(st.owner, 18)}
                                        </p>
                                    </div>
                                    <ActionBtn onClick={() => handleDeleteScheduled(st.id)} icon={<Trash2 size={13} />} label={t("common.delete")} color="red" />
                                </Card>
                            ))}
                        </div>
                    )}

                    {activeTab === "requests" && (
                        <div className="space-y-2">
                            {!adminData?.allPendingRequests?.length ? (
                                <EmptyState icon={<ArrowLeftRight size={28} />} title={t("admin.noPendingRequests")} />
                            ) : adminData.allPendingRequests.map((req: any) => (
                                <Card key={req.id} className="p-3.5 flex items-center gap-3">
                                    <div className="flex-1 min-w-0">
                                        <p className="text-sm font-bold text-white">{fmt.money(req.amount)}</p>
                                        <p className="text-xs text-[rgb(var(--text-secondary))] mt-0.5">
                                            <span className="font-mono">{fmt.shortId(req.requester_identifier, 15)}</span>
                                            <span className="mx-1.5 text-white">→</span>
                                            <span className="font-mono">{fmt.shortId(req.target_identifier, 15)}</span>
                                        </p>
                                        <p className="text-[10px] text-[rgb(var(--text-secondary))]">{fmt.date(req.created_at)}</p>
                                    </div>
                                    <ActionBtn onClick={() => handleCancelRequest(req.id)} icon={<Ban size={13} />} label={t("admin.cancelRequest")} color="red" />
                                </Card>
                            ))}
                        </div>
                    )}

                    {activeTab === "audit" && (
                        <div className="space-y-3">
                            <div className="flex items-center justify-between">
                                <p className="text-xs text-[rgb(var(--text-secondary))]">{auditLog.length} {t("admin.actionsRecordedInSession")}</p>
                                <Pill label={t("admin.sessionOnly")} color="yellow" />
                            </div>
                            {auditLog.length === 0 ? (
                                <EmptyState icon={<Database size={28} />} title={t("admin.noActionsRecorded")} subtitle={t("admin.noActionsDesc")} />
                            ) : (
                                <div className="space-y-1.5">
                                    {auditLog.map(entry => (
                                        <Card key={entry.id} className="px-4 py-3 flex items-start gap-3">
                                            <div className="w-7 h-7 rounded-lg bg-white/5 flex items-center justify-center flex-shrink-0 mt-0.5">
                                                <Zap size={12} className="text-[rgb(var(--accent-glow))]" />
                                            </div>
                                            <div className="flex-1 min-w-0">
                                                <div className="flex items-center gap-2">
                                                    <span className="text-xs font-semibold text-white font-mono">{entry.action}</span>
                                                    {entry.targetId && (
                                                        <span className="text-[10px] text-[rgb(var(--text-secondary))] font-mono">→ {entry.targetId}</span>
                                                    )}
                                                </div>
                                                <p className="text-xs text-[rgb(var(--text-secondary))]">{entry.details}</p>
                                            </div>
                                            <span className="text-[10px] text-[rgb(var(--text-secondary))] flex-shrink-0">{fmt.date(entry.timestamp)}</span>
                                        </Card>
                                    ))}
                                </div>
                            )}
                        </div>
                    )}

                </div>
            </div>

            {moneyModal && (
                <MoneyModalDialog
                    modal={moneyModal}
                    onClose={() => setMoneyModal(null)}
                    onConfirm={handleMoneyConfirm}
                />
            )}

            {confirmDialog && (
                <ConfirmDialogModal dialog={confirmDialog} resolve={resolveConfirm} />
            )}

            <ToastContainer toasts={toasts} dismiss={dismissToast} />
        </>
    )
}