"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Plus, FileText, X, Clock, CheckCircle, XCircle, AlertTriangle, Ban, Copy, Package } from "lucide-react"
import { fetchNui } from "../utils/fetchNui"
import { useLocale } from "../hooks/useLocale"
import toast from "react-hot-toast"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"

interface Check {
    id: number
    check_code: string
    issuer: string
    issuer_name?: string
    from_account_id: number
    from_account_name: string
    amount: string
    memo: string
    status: string
    expires_at: string
    cashed_by: string | null
    cashed_at: string | null
    created_at: string
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface PhysicalCheckData {
    slot: number
    check_code: string
    amount: string | number
    memo?: string
    issuer_name?: string
    expires_at?: string
}

interface CheckManagerProps {
    checks: Check[]
    accounts: Account[]
    config: {
        enabled: boolean
        maxAmount: number
        minAmount: number
        fee: number
        expirationDays: number
        maxActiveChecks: number
        useInventoryItem?: boolean
        allowForging?: boolean
    }
}

const statusConfig: Record<string, { icon: React.ReactNode; color: string; bg: string }> = {
    active: { icon: <Clock size={14} />, color: "text-yellow-400", bg: "bg-yellow-500/20 border-yellow-500/30" },
    cashed: { icon: <CheckCircle size={14} />, color: "text-green-400", bg: "bg-green-500/20 border-green-500/30" },
    expired: { icon: <AlertTriangle size={14} />, color: "text-orange-400", bg: "bg-orange-500/20 border-orange-500/30" },
    cancelled: { icon: <Ban size={14} />, color: "text-red-400", bg: "bg-red-500/20 border-red-500/30" },
}

export const CheckManager: React.FC<CheckManagerProps> = ({
    checks,
    accounts,
    config,
}) => {
    const { t } = useLocale()
    const [showCreate, setShowCreate] = useState(false)
    const [showCash, setShowCash] = useState(false)
    const [showForge, setShowForge] = useState(false)
    const [createData, setCreateData] = useState({ accountId: "", amount: "", memo: "" })
    const [cashData, setCashData] = useState({ checkCode: "", accountId: "", slot: "" })
    const [forgeData, setForgeData] = useState({ checkCode: "", amount: "", issuerName: "", memo: "", expiresAt: "" })
    const [inventoryChecks, setInventoryChecks] = useState<any[]>([])

    const activeChecks = checks.filter((c) => c.status === "active")

    useEffect(() => {
        if (showCash && config.useInventoryItem) {
            fetchNui("getInventoryChecks").then((data) => {
                setInventoryChecks(Array.isArray(data) ? data : [])
            }).catch(() => setInventoryChecks([]))
        }
    }, [showCash, config.useInventoryItem])

    const handleCreate = () => {
        if (!createData.accountId || !createData.amount) {
            return toast.error(t("checks.fillRequired") || "Completa los campos obligatorios")
        }
        const amount = parseFloat(createData.amount)
        if (amount < config.minAmount || amount > config.maxAmount) {
            return toast.error(t("checks.invalidAmount") || "Monto fuera de rango")
        }

        fetchNui("createCheck", {
            accountId: parseInt(createData.accountId),
            amount,
            memo: createData.memo,
        })
        setCreateData({ accountId: "", amount: "", memo: "" })
        setShowCreate(false)
    }

    const handleCash = () => {
        if (!cashData.checkCode || !cashData.accountId) {
            return toast.error(t("checks.fillRequired") || "Completa los campos obligatorios")
        }

        if (config.useInventoryItem) {
            if (!cashData.slot) {
                return toast.error(t("checks.noPhysicalCheck") || "No tienes el cheque físico seleccionado")
            }
            fetchNui("cashCheckItem", {
                slot: parseInt(cashData.slot),
                accountId: parseInt(cashData.accountId),
            })
        } else {
            fetchNui("cashCheck", {
                checkCode: cashData.checkCode,
                accountId: parseInt(cashData.accountId),
            })
        }

        setCashData({ checkCode: "", accountId: "", slot: "" })
        setShowCash(false)
    }

    const handleForge = () => {
        if (!forgeData.checkCode || !forgeData.amount || !forgeData.issuerName) {
            return toast.error("Completa los campos obligatorios")
        }

        fetchNui("forgeCheck", {
            checkCode: forgeData.checkCode.toUpperCase(),
            amount: parseFloat(forgeData.amount),
            issuerName: forgeData.issuerName,
            memo: forgeData.memo,
            expiresAt: forgeData.expiresAt || undefined
        })
        setForgeData({ checkCode: "", amount: "", issuerName: "", memo: "", expiresAt: "" })
        setShowForge(false)
    }

    const handleCancel = (check: Check) => {
        fetchNui("cancelCheck", {
            checkId: check.id,
        })
    }

    const copyCode = (code: string) => {
        fetchNui("copyToClipboard", { text: code })
        toast.success(t("checks.codeCopied") || "Código copiado al portapapeles")
    }

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] p-6 md:p-8 shadow-2xl shadow-[rgba(var(--accent-glow),0.3)]">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />
                <div className="relative z-10 flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
                    <div>
                        <h2 className="text-3xl font-bold text-white mb-2">
                            {t("checks.title") || "Cheques"}
                        </h2>
                        <p className="text-white/80 max-w-md">
                            {config.useInventoryItem
                                ? (t("checks.subtitlePhysical") || "Cheques bancarios físicos — presenta el item en el banco para cobrar")
                                : (t("checks.subtitle") || "Emite y cobra cheques bancarios transferibles")}
                        </p>
                    </div>
                    <div className="flex gap-3">
                        <Button
                            onClick={() => { setCashData({ checkCode: "", accountId: "", slot: "" }); setShowCash(true) }}
                            className="bg-white/20 hover:bg-white/30 border border-white/20 backdrop-blur-sm"
                            icon={<CheckCircle size={18} />}
                        >
                            {t("checks.cashCheck") || "Cobrar Cheque"}
                        </Button>
                        <Button
                            onClick={() => setShowCreate(true)}
                            icon={<Plus size={18} />}
                            className="bg-white/20 hover:bg-white/30 border border-white/20 backdrop-blur-sm"
                        >
                            {t("checks.createCheck") || "Emitir Cheque"}
                        </Button>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">
                        {t("checks.activeChecks") || "Cheques Activos"}
                    </p>
                    <p className="text-2xl font-bold text-white">
                        {activeChecks.length} / {config.maxActiveChecks}
                    </p>
                </Card>
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">
                        {t("checks.issuanceFee") || "Comisión de Emisión"}
                    </p>
                    <p className="text-2xl font-bold text-white">${config.fee}</p>
                </Card>
                <Card className="!p-4">
                    <p className="text-[rgb(var(--text-secondary))] text-xs mb-1">
                        {t("checks.expiration") || "Expiración"}
                    </p>
                    <p className="text-2xl font-bold text-white">
                        {config.expirationDays} {t("checks.days") || "días"}
                    </p>
                </Card>
            </div>

            {config.useInventoryItem && (
                <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-4 flex items-start gap-3">
                    <Package size={18} className="text-blue-400 mt-0.5 flex-shrink-0" />
                    <p className="text-blue-300 text-sm">
                        {t("checks.physicalModeNotice") ||
                            "Modo cheque físico activado. Al emitir un cheque recibirás un item en tu inventario. " +
                            "Para cobrar un cheque debes tener el item físico y presentarlo aquí. " +
                            "Los cheques se pueden entregar a otros jugadores directamente desde el inventario."}
                    </p>
                </div>
            )}

            <div className="grid gap-4">
                {checks.length === 0 ? (
                    <Card className="text-center py-12">
                        <div className="w-16 h-16 bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] rounded-full flex items-center justify-center mx-auto mb-4 shadow-lg">
                            <FileText className="text-white" size={32} />
                        </div>
                        <h3 className="text-xl font-bold text-white mb-2">
                            {t("checks.noChecks") || "No hay cheques"}
                        </h3>
                        <p className="text-[rgb(var(--text-secondary))] mb-6">
                            {t("checks.noChecksDesc") || "Emite tu primer cheque para transferir dinero de forma segura"}
                        </p>
                        <Button onClick={() => setShowCreate(true)} variant="secondary">
                            {t("checks.createFirst") || "Emitir primer cheque"}
                        </Button>
                    </Card>
                ) : (
                    checks.map((check) => {
                        const status = statusConfig[check.status] || statusConfig.active
                        return (
                            <Card key={check.id} className="relative overflow-hidden hover:scale-[1.005] transition-all duration-300">
                                <div className={`absolute left-0 top-0 bottom-0 w-1 ${check.status === "active" ? "bg-gradient-to-b from-yellow-400 to-yellow-600" :
                                    check.status === "cashed" ? "bg-gradient-to-b from-green-400 to-green-600" :
                                        "bg-gradient-to-b from-gray-400 to-gray-600"
                                    }`} />

                                <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4">
                                    <div className="flex items-center gap-4">
                                        <div className={`p-3 rounded-xl ${check.status === "active" ? "bg-yellow-500/20" :
                                            check.status === "cashed" ? "bg-green-500/20" : "bg-gray-500/20"
                                            }`}>
                                            <FileText className={status.color} size={24} />
                                        </div>
                                        <div>
                                            <div className="flex items-center gap-2 mb-1">
                                                <button
                                                    onClick={() => copyCode(check.check_code)}
                                                    className="flex items-center gap-1 text-white font-bold text-lg hover:text-[rgb(var(--accent-glow))] transition-colors"
                                                    title={t("checks.copyCode") || "Copiar código"}
                                                >
                                                    {check.check_code}
                                                    <Copy size={14} className="opacity-50" />
                                                </button>
                                                <span className={`px-2 py-0.5 rounded-full text-xs font-medium border ${status.bg} ${status.color} flex items-center gap-1`}>
                                                    {status.icon}
                                                </span>
                                            </div>
                                            <p className="text-[rgb(var(--text-secondary))] text-sm">
                                                {t("checks.from") || "De"}: {check.from_account_name || `#${check.from_account_id}`}
                                                {check.memo && ` • ${check.memo}`}
                                            </p>
                                            {check.issuer_name && (
                                                <p className="text-[rgb(var(--text-muted))] text-xs">
                                                    Firmado por: {check.issuer_name}
                                                </p>
                                            )}
                                            <p className="text-[rgb(var(--text-muted))] text-xs mt-1">
                                                {new Date(check.created_at).toLocaleDateString("es-ES", { day: "numeric", month: "short", year: "numeric" })}
                                                {check.status === "active" && ` • ${t("checks.expiresOn") || "Expira"}: ${new Date(check.expires_at).toLocaleDateString("es-ES", { day: "numeric", month: "short" })}`}
                                                {check.status === "cashed" && check.cashed_at && ` • Cobrado: ${new Date(check.cashed_at).toLocaleDateString("es-ES", { day: "numeric", month: "short" })}`}
                                            </p>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-4">
                                        <p className="text-2xl font-bold text-white">
                                            ${parseFloat(check.amount).toLocaleString()}
                                        </p>
                                        {check.status === "active" && (
                                            <button
                                                onClick={() => handleCancel(check)}
                                                className="p-2 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-400 transition-all"
                                                title={t("checks.cancel") || "Cancelar"}
                                            >
                                                <XCircle size={18} />
                                            </button>
                                        )}
                                    </div>
                                </div>
                            </Card>
                        )
                    })
                )}
            </div>

            {showCreate && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md animate-in">
                    <div className="bg-[rgb(var(--bg-card))] p-6 md:p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl animate-scale-in mx-4">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold text-white">
                                {t("checks.createCheck") || "Emitir Cheque"}
                            </h3>
                            <button onClick={() => setShowCreate(false)} className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                <X className="text-white" size={20} />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.selectAccount") || "Cuenta de origen"}
                                </label>
                                <Select
                                    value={createData.accountId}
                                    onValueChange={(val) => setCreateData({ ...createData, accountId: val })}
                                >
                                    <SelectTrigger className="w-full bg-black/20 border-white/10 text-white h-[50px] rounded-xl">
                                        <SelectValue placeholder={t("checks.selectAccountPlaceholder") || "Seleccionar cuenta..."} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {accounts.map((acc) => (
                                            <SelectItem key={acc.id} value={acc.id.toString()}>
                                                {acc.account_name} — ${parseFloat(acc.balance).toLocaleString()}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.amount") || "Monto"} (${config.minAmount.toLocaleString()} — ${config.maxAmount.toLocaleString()})
                                </label>
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={createData.amount}
                                    onChange={(e) => setCreateData({ ...createData, amount: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-[rgb(var(--accent-primary))] outline-none"
                                />
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.memo") || "Concepto (opcional)"}
                                </label>
                                <input
                                    type="text"
                                    placeholder={t("checks.memoPlaceholder") || "Pago de vehículo..."}
                                    value={createData.memo}
                                    onChange={(e) => setCreateData({ ...createData, memo: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-[rgb(var(--accent-primary))] outline-none"
                                />
                            </div>

                            <div className="bg-white/5 p-3 rounded-xl border border-white/10 text-sm space-y-1">
                                <p className="text-[rgb(var(--text-secondary))]">
                                    {t("checks.feeNotice") || "Comisión de emisión"}:{" "}
                                    <span className="text-white font-semibold">${config.fee}</span>
                                </p>
                                {config.useInventoryItem && (
                                    <p className="text-blue-300 text-xs flex items-center gap-1">
                                        <Package size={12} />
                                        {t("checks.itemWillBeCreated") || "Recibirás un item de cheque físico en tu inventario"}
                                    </p>
                                )}
                            </div>

                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={() => setShowCreate(false)}
                                    className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel") || "Cancelar"}
                                </button>
                                <button
                                    onClick={handleCreate}
                                    className="flex-1 py-3 rounded-xl bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 text-white font-medium transition-all shadow-lg shadow-indigo-500/30"
                                >
                                    {t("checks.issue") || "Emitir Cheque"}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {showCash && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md animate-in">
                    <div className="bg-[rgb(var(--bg-card))] p-6 md:p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl animate-scale-in mx-4">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold text-white">
                                {t("checks.cashCheck") || "Cobrar Cheque"}
                            </h3>
                            <button onClick={() => setShowCash(false)} className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                <X className="text-white" size={20} />
                            </button>
                        </div>

                        <div className="space-y-4">
                            {config.useInventoryItem ? (
                                <div>
                                    <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                        {t("checks.selectCheckFromInventory") || "Seleccionar Cheque del Bolsillo"}
                                    </label>
                                    <Select
                                        value={cashData.slot}
                                        onValueChange={(val) => {
                                            const selected = inventoryChecks.find(c => c.slot.toString() === val)
                                            if (selected) {
                                                setCashData({ ...cashData, slot: val, checkCode: selected.check_code })
                                            }
                                        }}
                                    >
                                        <SelectTrigger className="w-full bg-black/20 border-white/10 text-white h-[50px] rounded-xl font-mono">
                                            <SelectValue placeholder={t("checks.selectCheck")} />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {inventoryChecks.length === 0 ? (
                                                <SelectItem value="none" disabled>
                                                    {t("checks.noChecksInInventory")}
                                                </SelectItem>
                                            ) : (
                                                inventoryChecks.map((chk) => (
                                                    <SelectItem key={chk.slot} value={chk.slot.toString()} className="font-mono">
                                                        {chk.check_code} — ${parseFloat(chk.amount).toLocaleString()} {chk.is_fake ? <span className="text-red-400 font-bold text-xs ml-1">(FALSO)</span> : <span className="text-emerald-400 font-bold text-xs ml-1">(REAL)</span>}
                                                    </SelectItem>
                                                ))
                                            )}
                                        </SelectContent>
                                    </Select>
                                    {inventoryChecks.length === 0 && (
                                        <p className="text-yellow-400 text-xs mt-2 flex items-center gap-1">
                                            <Package size={12} />
                                            {t("checks.noChecksInInventory") || "No se detectaron cheques en tu inventario."}
                                        </p>
                                    )}
                                </div>
                            ) : (
                                <div>
                                    <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                        {t("checks.checkCode") || "Código del Cheque"}
                                    </label>
                                    <input
                                        type="text"
                                        placeholder="CHK-XXXX-XXXX"
                                        value={cashData.checkCode}
                                        onChange={(e) => setCashData({ ...cashData, checkCode: e.target.value.toUpperCase() })}
                                        className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-[rgb(var(--accent-primary))] outline-none font-mono tracking-wider"
                                    />
                                </div>
                            )}

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.depositTo") || "Depositar en cuenta"}
                                </label>
                                <Select
                                    value={cashData.accountId}
                                    onValueChange={(val) => setCashData({ ...cashData, accountId: val })}
                                >
                                    <SelectTrigger className="w-full bg-black/20 border-white/10 text-white h-[50px] rounded-xl">
                                        <SelectValue placeholder={t("checks.selectAccountPlaceholder") || "Seleccionar cuenta..."} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {accounts.map((acc) => (
                                            <SelectItem key={acc.id} value={acc.id.toString()}>
                                                {acc.account_name} — ${parseFloat(acc.balance).toLocaleString()}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>

                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={() => setShowCash(false)}
                                    className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel") || "Cancelar"}
                                </button>
                                <button
                                    onClick={handleCash}
                                    disabled={config.useInventoryItem && !cashData.slot}
                                    className="flex-1 py-3 rounded-xl bg-gradient-to-r from-green-600 to-green-700 hover:from-green-700 hover:to-green-800 disabled:opacity-40 disabled:cursor-not-allowed text-white font-medium transition-all shadow-lg shadow-green-500/30"
                                >
                                    {t("checks.confirmCash") || "Cobrar Cheque"}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}

            {showForge && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md animate-in">
                    <div className="bg-[rgb(var(--bg-card))] p-6 md:p-8 rounded-2xl w-full max-w-md border border-red-500/30 shadow-2xl animate-scale-in mx-4">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold text-red-400 flex items-center gap-2">
                                <AlertTriangle size={24} />
                                {t("checks.forgeTitle") || "Falsificar Cheque"}
                            </h3>
                            <button onClick={() => setShowForge(false)} className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                <X className="text-white" size={20} />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.codeToClone") || "Código del cheque a clonar"}
                                </label>
                                <input
                                    type="text"
                                    placeholder="CHK-XXXX-XXXX"
                                    value={forgeData.checkCode}
                                    onChange={(e) => setForgeData({ ...forgeData, checkCode: e.target.value.toUpperCase() })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-red-500 outline-none font-mono tracking-wider uppercase"
                                />
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.forgeAmount") || "Monto a falsificar"}
                                </label>
                                <input
                                    type="number"
                                    placeholder="0.00"
                                    value={forgeData.amount}
                                    onChange={(e) => setForgeData({ ...forgeData, amount: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-red-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.forgeIssuerName") || "Nombre del supuesto emisor"}
                                </label>
                                <input
                                    type="text"
                                    placeholder="Ej: Juan García"
                                    value={forgeData.issuerName}
                                    onChange={(e) => setForgeData({ ...forgeData, issuerName: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-red-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.memo") || "Concepto (opcional)"}
                                </label>
                                <input
                                    type="text"
                                    placeholder="Ej: Pago de deuda"
                                    value={forgeData.memo}
                                    onChange={(e) => setForgeData({ ...forgeData, memo: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-red-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-2 block">
                                    {t("checks.forgeExpiresAt") || "Fecha de expiración (opcional)"}
                                </label>
                                <input
                                    type="text"
                                    placeholder="YYYY-MM-DD HH:MM:SS"
                                    value={forgeData.expiresAt}
                                    onChange={(e) => setForgeData({ ...forgeData, expiresAt: e.target.value })}
                                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-red-500 outline-none"
                                />
                            </div>

                            <div className="flex gap-3 pt-2">
                                <button
                                    onClick={() => setShowForge(false)}
                                    className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-all"
                                >
                                    {t("common.cancel") || "Cancelar"}
                                </button>
                                <button
                                    onClick={handleForge}
                                    className="flex-1 py-3 rounded-xl bg-gradient-to-r from-red-600 to-red-700 hover:from-red-700 hover:to-red-800 text-white font-medium transition-all shadow-lg shadow-red-500/30"
                                >
                                    {t("checks.confirmForge") || "Falsificar"}
                                </button>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}