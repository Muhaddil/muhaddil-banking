"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { useLocale } from "../hooks/useLocale" // Added for i18n support
import {
    Building2,
    TrendingUp,
    DollarSign,
    Award,
    Crown,
    ArrowRightLeft,
    Wallet,
    X,
    Edit,
    Percent,
    ShoppingBag,
    Sparkles,
    BarChart3,
} from "lucide-react"
import { fetchNui } from "../utils/fetchNui"
import toast from "react-hot-toast"

interface OwnedBank {
    id: number
    bank_id: string
    owner: string
    bank_name: string
    commission_rate: string
    total_earned: string
    pending_earnings?: string
    purchased_at: string
}

interface AvailableBank {
    id: string
    name: string
    price: number
    coords?: { x: number; y: number; z: number }
}

interface BankManagerProps {
    ownedBanks: OwnedBank[]
    availableBanks?: AvailableBank[]
}

type ModalType = "none" | "transfer" | "commission" | "rename" | "sell"

export const BankManager: React.FC<BankManagerProps> = ({ ownedBanks, availableBanks = [] }) => {
    const { t } = useLocale() // Fixed to destructure t from useLocale
    const [selectedBank, setSelectedBank] = useState<OwnedBank | null>(null)
    const [modalType, setModalType] = useState<ModalType>("none")
    const [formData, setFormData] = useState({
        targetPlayerId: "",
        commissionRate: "",
        newName: "",
    })

    const handleSellBank = (bank: OwnedBank) => {
        setSelectedBank(bank)
        setModalType("sell")
    }

    const confirmSellBank = () => {
        if (!selectedBank) return
        fetchNui("sellBank", { bankId: selectedBank.bank_id })
        closeModal()
    }

    const handlePurchaseBank = (bankId: string) => {
        fetchNui("purchaseBank", { bankId })
    }

    const handleTransferBank = () => {
        if (!selectedBank) return
        const targetId = Number.parseInt(formData.targetPlayerId)
        if (isNaN(targetId) || targetId <= 0) {
            toast.error(t("banks.invalidPlayerId"))
            return
        }
        fetchNui("transferBank", { bankId: selectedBank.bank_id, targetPlayerId: targetId })
        closeModal()
    }

    const handleUpdateCommission = () => {
        if (!selectedBank) return
        const rate = Number.parseFloat(formData.commissionRate) / 100
        if (isNaN(rate) || rate < 0.005 || rate > 0.03) {
            toast.error(t("banks.commissionRangeError"))
            return
        }
        fetchNui("updateCommission", { bankId: selectedBank.bank_id, newRate: rate })
        closeModal()
    }

    const handleWithdrawEarnings = (bankId: string) => {
        fetchNui("withdrawEarnings", { bankId })
    }

    const handleRenameBank = () => {
        if (!selectedBank) return
        if (!formData.newName || formData.newName.length < 3) {
            toast.error(t("banks.nameLengthError"))
            return
        }
        fetchNui("renameBank", { bankId: selectedBank.bank_id, newName: formData.newName })
        closeModal()
    }

    const openModal = (bank: OwnedBank, type: ModalType) => {
        setSelectedBank(bank)
        setModalType(type)
        setFormData({
            targetPlayerId: "",
            commissionRate: (Number.parseFloat(bank.commission_rate) * 100).toFixed(1),
            newName: bank.bank_name,
        })
    }

    const closeModal = () => {
        setModalType("none")
        setSelectedBank(null)
        setFormData({ targetPlayerId: "", commissionRate: "", newName: "" })
    }

    const formatMoney = (value: string | number) => {
        const num = typeof value === "string" ? Number.parseFloat(value) : value

        if (!num || isNaN(num)) {
            return "$0"
        }

        if (Math.abs(num) >= 1_000_000) {
            const formatted = (num / 1_000_000).toFixed(num % 1_000_000 === 0 ? 0 : 1)
            return `$${formatted}M`
        }

        if (Math.abs(num) >= 1_000) {
            const formatted = (num / 1_000).toFixed(num % 1_000 === 0 ? 0 : 1)
            return `$${formatted}K`
        }

        return new Intl.NumberFormat("es-ES", {
            style: "currency",
            currency: "USD",
            minimumFractionDigits: 0,
            maximumFractionDigits: 2,
        }).format(num)
    }

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-blue-600 via-indigo-600 to-purple-700 p-8 md:p-10 shadow-2xl">
                <div className="absolute top-0 right-0 w-96 h-96 bg-white/10 rounded-full blur-3xl -mr-24 -mt-24" />
                <div className="absolute bottom-0 left-0 w-80 h-80 bg-purple-500/30 rounded-full blur-3xl -ml-20 -mb-20" />
                <div className="absolute top-1/2 left-1/2 w-72 h-72 bg-blue-400/20 rounded-full blur-3xl" />

                <div className="relative z-10 flex flex-col lg:flex-row justify-between items-center gap-8">
                    <div className="flex-1 text-center lg:text-left">
                        <div className="flex items-center justify-center lg:justify-start gap-3 mb-4">
                            <div className="p-3 bg-white/20 rounded-2xl backdrop-blur-md shadow-xl">
                                <Crown className="text-yellow-200" size={28} />
                            </div>
                            <span className="px-4 py-1.5 bg-white/20 backdrop-blur-md rounded-full text-white text-sm font-semibold border border-white/30 shadow-lg">
                                Premium Investment
                            </span>
                        </div>
                        <h2 className="text-4xl md:text-5xl font-bold text-white mb-4 leading-tight">
                            {t("banks.bankManagement")}
                        </h2>
                        <p className="text-white/95 text-lg max-w-2xl leading-relaxed">{t("banks.manageDescription")}</p>
                    </div>

                    <div className="bg-white/15 backdrop-blur-xl p-8 rounded-3xl border border-white/30 shadow-2xl min-w-[300px]">
                        <div className="text-center mb-6">
                            <div className="inline-flex items-center gap-2 px-3 py-1 bg-emerald-500/20 rounded-full mb-3">
                                <Sparkles size={14} className="text-emerald-300" />
                                <span className="text-emerald-100 text-xs font-semibold">{t("banks.specialPrice")}</span>
                            </div>
                            <div className="flex items-center justify-center gap-2 mb-2">
                                <DollarSign className="text-white" size={36} />
                                <p className="text-6xl font-black text-white tracking-tight">1M</p>
                            </div>
                            <p className="text-white/70 text-sm">{t("banks.perBank")}</p>
                        </div>

                        <div className="space-y-3">
                            <div className="flex items-center gap-3 text-white/95 text-sm bg-white/10 rounded-xl p-3">
                                <div className="p-1.5 bg-yellow-400/20 rounded-lg">
                                    <Award size={16} className="text-yellow-300" />
                                </div>
                                <span className="font-medium">{t("banks.commissions")}</span>
                            </div>
                            <div className="flex items-center gap-3 text-white/95 text-sm bg-white/10 rounded-xl p-3">
                                <div className="p-1.5 bg-green-400/20 rounded-lg">
                                    <TrendingUp size={16} className="text-green-300" />
                                </div>
                                <span className="font-medium">{t("banks.passiveIncome")}</span>
                            </div>
                            <div className="flex items-center gap-3 text-white/95 text-sm bg-white/10 rounded-xl p-3">
                                <div className="p-1.5 bg-blue-400/20 rounded-lg">
                                    <BarChart3 size={16} className="text-blue-300" />
                                </div>
                                <span className="font-medium">{t("banks.fullManagement")}</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {availableBanks.length > 0 && (
                <div>
                    <div className="flex items-center gap-3 mb-6">
                        <div className="p-3 bg-gradient-to-r from-[rgb(var(--accent-primary))]/20 to-[rgb(var(--accent-secondary))]/20 rounded-xl border border-[rgb(var(--accent-primary))]/20">
                            <ShoppingBag className="text-[rgb(var(--accent-primary))]" size={24} />
                        </div>
                        <div>
                            <h2 className="text-2xl font-bold text-[rgb(var(--text-primary))]">{t("banks.availableBanks")}</h2>
                            <p className="text-[rgb(var(--text-secondary))] text-sm">{t("banks.purchaseDescription")}</p>
                        </div>
                    </div>

                    <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                        {availableBanks.map((bank) => (
                            <Card
                                key={bank.id}
                                className="group relative overflow-hidden bg-[rgb(var(--bg-card))] border-white/10 hover:border-[rgb(var(--accent-primary))]/50 transition-all duration-300 hover:shadow-2xl hover:shadow-[rgba(var(--accent-glow),0.3)]"
                            >
                                <div className="p-6 space-y-6">
                                    <div className="flex items-start justify-between">
                                        <div className="p-4 bg-gradient-to-br from-[rgb(var(--accent-primary))]/15 to-[rgb(var(--accent-secondary))]/10 rounded-2xl border border-[rgb(var(--accent-primary))]/20">
                                            <Building2 className="text-[rgb(var(--accent-primary))]" size={28} />
                                        </div>
                                        <div className="flex items-center gap-1.5 px-3 py-1.5 bg-emerald-500/15 rounded-full border border-emerald-500/30">
                                            {/* <div className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" /> */}
                                            <span className="text-emerald-300 text-xs font-semibold">{t("banks.available")}</span>
                                        </div>
                                    </div>

                                    <div>
                                        <h3 className="text-2xl font-bold text-[rgb(var(--text-primary))] leading-tight">{bank.name}</h3>
                                    </div>

                                    <div className="pt-4 border-t border-white/10">
                                        <p className="text-[rgb(var(--text-secondary))] text-xs font-medium mb-2 uppercase tracking-wide">
                                            {t("banks.price")}
                                        </p>
                                        <div className="flex items-baseline gap-2 mb-5">
                                            <span className="text-4xl font-black text-[rgb(var(--text-primary))] tracking-tight">
                                                {formatMoney(bank.price)}
                                            </span>
                                        </div>

                                        <Button
                                            onClick={() => handlePurchaseBank(bank.id)}
                                            className="
        relative w-full h-14 text-base font-extrabold
        bg-gradient-to-r from-emerald-500 via-green-500 to-lime-500
        text-white
        border border-emerald-300/60
        shadow-[0_0_25px_rgba(34,197,94,0.45)]
        hover:shadow-[0_0_40px_rgba(34,197,94,0.75)]
        transition-all duration-300
        hover:scale-[1.03]
        animate-pulse-slow
        overflow-hidden
    "
                                        >
                                            <span className="absolute inset-0 bg-gradient-to-r from-white/30 to-transparent opacity-20 pointer-events-none" />

                                            <ShoppingBag size={20} className="mr-2 drop-shadow-lg" />
                                            {t("banks.buy")}
                                        </Button>

                                    </div>
                                </div>
                            </Card>
                        ))}
                    </div>
                </div>
            )}

            <div className="flex items-center justify-between mb-4">
                <h3 className="text-2xl font-bold text-[rgb(var(--text-primary))] flex items-center gap-3">
                    <div className="p-2 bg-blue-500/20 rounded-xl">
                        <Building2 size={24} className="text-blue-400" />
                    </div>
                    {t("banks.myBranches")}
                </h3>
                <div className="px-4 py-2 bg-blue-500/20 rounded-xl border border-blue-500/30">
                    <span className="text-blue-400 font-bold text-lg">{ownedBanks.length}/3</span>
                </div>
            </div>

            <div className="grid gap-6">
                {ownedBanks.length === 0 ? (
                    <div className="text-center py-20 bg-gradient-to-br from-white/5 to-white/[0.02] rounded-3xl border border-white/10">
                        <div className="w-24 h-24 bg-gradient-to-br from-blue-500/20 to-purple-500/20 rounded-full flex items-center justify-center mx-auto mb-6 shadow-xl">
                            <Building2 className="text-blue-400" size={48} />
                        </div>
                        <p className="text-[rgb(var(--text-primary))] text-xl font-semibold mb-2">{t("banks.noBranches")}</p>
                        <p className="text-[rgb(var(--text-secondary))] text-base max-w-md mx-auto">
                            {t("banks.startDescription")}
                        </p>
                    </div>
                ) : (
                    ownedBanks.map((bank) => (
                        <Card
                            key={bank.id}
                            className="transition-all duration-300 hover:border-blue-500/30 hover:shadow-xl hover:shadow-blue-500/10"
                        >
                            <div className="flex flex-col gap-6">
                                <div className="flex flex-col md:flex-row items-start md:items-center gap-4">
                                    <div className="relative">
                                        <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-blue-500 via-indigo-500 to-purple-600 flex items-center justify-center shadow-2xl">
                                            <Building2 className="text-white" size={40} />
                                        </div>
                                        <div className="absolute -bottom-1 -right-1 p-1.5 bg-yellow-400 rounded-lg shadow-lg">
                                            <Crown size={14} className="text-yellow-900" />
                                        </div>
                                    </div>

                                    <div className="flex-1 min-w-0">
                                        <p className="text-3xl font-bold text-[rgb(var(--text-primary))] mb-2 break-words leading-tight">
                                            {bank.bank_name}
                                        </p>
                                        <div className="flex items-center gap-2 text-[rgb(var(--text-secondary))] text-sm">
                                            <div className="w-2 h-2 bg-green-400 rounded-full animate-pulse" />
                                            <span>
                                                {t("banks.acquiredOn")}{" "}
                                                {new Date(bank.purchased_at).toLocaleDateString("es-ES", {
                                                    year: "numeric",
                                                    month: "long",
                                                    day: "numeric",
                                                })}
                                            </span>
                                        </div>
                                    </div>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                                    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-green-500/10 to-emerald-500/5 p-4 border border-green-500/20">
                                        <div className="absolute top-0 right-0 w-20 h-20 bg-green-400/10 rounded-full blur-2xl" />
                                        <div className="relative flex items-center gap-3">
                                            <div className="p-2.5 bg-green-500/20 rounded-xl">
                                                <TrendingUp size={20} className="text-green-400" />
                                            </div>
                                            <div>
                                                <p className="text-[rgb(var(--text-secondary))] text-xs font-medium mb-0.5">
                                                    {t("banks.commission")}
                                                </p>
                                                <p className="text-[rgb(var(--text-primary))] font-bold text-lg">
                                                    {(Number.parseFloat(bank.commission_rate) * 100).toFixed(1)}%
                                                </p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-yellow-500/10 to-orange-500/5 p-4 border border-yellow-500/20">
                                        <div className="absolute top-0 right-0 w-20 h-20 bg-yellow-400/10 rounded-full blur-2xl" />
                                        <div className="relative flex items-center gap-3">
                                            <div className="p-2.5 bg-yellow-500/20 rounded-xl">
                                                <DollarSign size={20} className="text-yellow-400" />
                                            </div>
                                            <div>
                                                <p className="text-[rgb(var(--text-secondary))] text-xs font-medium mb-0.5">
                                                    {t("banks.totalEarned")}
                                                </p>
                                                <p className="text-[rgb(var(--text-primary))] font-bold text-lg">
                                                    {formatMoney(bank.total_earned)}
                                                </p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-br from-emerald-500/10 to-teal-500/5 p-4 border border-emerald-500/20">
                                        <div className="absolute top-0 right-0 w-20 h-20 bg-emerald-400/10 rounded-full blur-2xl" />
                                        <div className="relative flex items-center gap-3">
                                            <div className="p-2.5 bg-emerald-500/20 rounded-xl">
                                                <Wallet size={20} className="text-emerald-400" />
                                            </div>
                                            <div>
                                                <p className="text-[rgb(var(--text-secondary))] text-xs font-medium mb-0.5">
                                                    {t("banks.pending")}
                                                </p>
                                                <p className="text-[rgb(var(--text-primary))] font-bold text-lg">
                                                    {formatMoney(bank.pending_earnings || "0")}
                                                </p>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <div className="flex flex-wrap gap-3 pt-4 border-t border-white/10">
                                    <button
                                        onClick={() => handleWithdrawEarnings(bank.bank_id)}
                                        className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-emerald-600/20 to-green-600/20 hover:from-emerald-600/30 hover:to-green-600/30 text-emerald-300 rounded-xl transition-all text-sm font-semibold hover:scale-105 border border-emerald-500/20 shadow-lg hover:shadow-emerald-500/20"
                                    >
                                        <Wallet size={16} />
                                        {t("banks.withdrawEarnings")}
                                    </button>

                                    <button
                                        onClick={() => openModal(bank, "commission")}
                                        className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-blue-600/20 to-indigo-600/20 hover:from-blue-600/30 hover:to-indigo-600/30 text-blue-300 rounded-xl transition-all text-sm font-semibold hover:scale-105 border border-blue-500/20 shadow-lg hover:shadow-blue-500/20"
                                    >
                                        <Percent size={16} />
                                        {t("banks.changeCommission")}
                                    </button>

                                    <button
                                        onClick={() => openModal(bank, "rename")}
                                        className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-slate-600/20 to-gray-600/20 hover:from-slate-600/30 hover:to-gray-600/30 text-slate-300 rounded-xl transition-all text-sm font-semibold hover:scale-105 border border-slate-500/20 shadow-lg hover:shadow-slate-500/20"
                                    >
                                        <Edit size={16} />
                                        {t("banks.rename")}
                                    </button>

                                    <button
                                        onClick={() => openModal(bank, "transfer")}
                                        className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-purple-600/20 to-pink-600/20 hover:from-purple-600/30 hover:to-pink-600/30 text-purple-300 rounded-xl transition-all text-sm font-semibold hover:scale-105 border border-purple-500/20 shadow-lg hover:shadow-purple-500/20"
                                    >
                                        <ArrowRightLeft size={16} />
                                        {t("banks.transfer")}
                                    </button>

                                    <button
                                        onClick={() => handleSellBank(bank)}
                                        className="flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-red-600/20 to-rose-600/20 hover:from-red-600/30 hover:to-rose-600/30 text-red-300 rounded-xl transition-all text-sm font-semibold ml-auto hover:scale-105 border border-red-500/20 shadow-lg hover:shadow-red-500/20"
                                    >
                                        <DollarSign size={16} />
                                        {t("banks.sell")}
                                    </button>
                                </div>
                            </div>
                        </Card>
                    ))
                )}
            </div>

            {modalType !== "none" && selectedBank && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm animate-in">
                    <div className="bg-[rgb(var(--bg-card))] p-6 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl mx-4 animate-scale-in">
                        <div className="flex items-center justify-between mb-6">
                            <h3 className="text-xl font-bold text-white">
                                {modalType === "transfer" && t("banks.transferBank")}
                                {modalType === "commission" && t("banks.changeCommission")}
                                {modalType === "rename" && t("banks.renameBank")}
                                {modalType === "sell" && t("banks.sellBank")}
                            </h3>
                            <button onClick={closeModal} className="text-slate-400 hover:text-white transition-colors">
                                <X size={20} />
                            </button>
                        </div>

                        <div className="space-y-4">
                            {modalType === "sell" && (
                                <>
                                    <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-4">
                                        <p className="text-amber-200 text-sm">{t("banks.sellConfirmation")}</p>
                                    </div>
                                    <div className="bg-[rgb(var(--bg-secondary))] rounded-xl p-4 space-y-2">
                                        <div className="flex justify-between text-sm">
                                            <span className="text-[rgb(var(--text-muted))]">{t("banks.bankName")}:</span>
                                            <span className="text-[rgb(var(--text-primary))] font-medium">{selectedBank.bank_name}</span>
                                        </div>
                                        <div className="flex justify-between text-sm">
                                            <span className="text-[rgb(var(--text-muted))]">{t("banks.pendingEarnings")}:</span>
                                            <span className="text-emerald-400 font-bold">
                                                {formatMoney(selectedBank.pending_earnings || "0")}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="flex gap-3 pt-2">
                                        <Button variant="secondary" onClick={closeModal} className="flex-1">
                                            {t("common.cancel")}
                                        </Button>
                                        <Button onClick={confirmSellBank} className="flex-1 bg-red-600 hover:bg-red-500 text-white">
                                            {t("banks.confirmSell")}
                                        </Button>
                                    </div>
                                </>
                            )}

                            {modalType === "transfer" && (
                                <>
                                    <p className="text-slate-400 text-sm">
                                        {t("banks.transferDescription", { bankName: selectedBank.bank_name })}
                                    </p>
                                    <input
                                        type="number"
                                        placeholder={t("banks.playerIdPlaceholder")}
                                        value={formData.targetPlayerId}
                                        onChange={(e) => setFormData({ ...formData, targetPlayerId: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-slate-700 rounded-xl p-3 text-white outline-none focus:border-purple-500 transition-colors"
                                    />
                                    <Button onClick={handleTransferBank} className="w-full bg-purple-600 hover:bg-purple-500 text-white">
                                        {t("banks.transfer")}
                                    </Button>
                                </>
                            )}

                            {modalType === "commission" && (
                                <>
                                    <p className="text-slate-400 text-sm">{t("banks.commissionDescription")}</p>
                                    <input
                                        type="number"
                                        step="0.1"
                                        min="0.5"
                                        max="3"
                                        placeholder="0.5 - 3"
                                        value={formData.commissionRate}
                                        onChange={(e) => setFormData({ ...formData, commissionRate: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-slate-700 rounded-xl p-3 text-white outline-none focus:border-blue-500 transition-colors"
                                    />
                                    <Button onClick={handleUpdateCommission} className="w-full bg-blue-600 hover:bg-blue-500 text-white">
                                        {t("banks.updateCommission")}
                                    </Button>
                                </>
                            )}

                            {modalType === "rename" && (
                                <>
                                    <p className="text-slate-400 text-sm">{t("banks.renameDescription")}</p>
                                    <input
                                        type="text"
                                        placeholder={t("banks.newNamePlaceholder")}
                                        value={formData.newName}
                                        onChange={(e) => setFormData({ ...formData, newName: e.target.value })}
                                        className="w-full bg-slate-800/50 border border-slate-700 rounded-xl p-3 text-white outline-none focus:border-slate-500 transition-colors"
                                    />
                                    <Button onClick={handleRenameBank} className="w-full bg-slate-600 hover:bg-slate-500 text-white">
                                        {t("banks.rename")}
                                    </Button>
                                </>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    )
}
