"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import {
    Shield, Search, Users, CreditCard, Banknote, History, Building2,
    Clock, ArrowLeftRight, DollarSign, TrendingUp, X, Trash2, Ban,
    Plus, Minus, PiggyBank, BarChart3, RefreshCcw
} from "lucide-react"
import { fetchNui } from "../utils/fetchNui"
import { useLocale } from "../hooks/useLocale"

interface AdminPanelProps {
    onClose: () => void
}

export const AdminPanel: React.FC<AdminPanelProps> = ({ onClose }) => {
    const { t } = useLocale()
    const [activeTab, setActiveTab] = useState('overview')
    const [adminData, setAdminData] = useState<any>(null)
    const [loading, setLoading] = useState(true)
    const [searchQuery, setSearchQuery] = useState("")
    const [searchResult, setSearchResult] = useState<any>(null)

    const [addMoneyModal, setAddMoneyModal] = useState<{ accountId: number } | null>(null)
    const [removeMoneyModal, setRemoveMoneyModal] = useState<{ accountId: number } | null>(null)
    const [actionAmount, setActionAmount] = useState("")

    const loadAdminData = async () => {
        setLoading(true)
        try {
            const result = await fetchNui('getAdminData', {})
            setAdminData(result)
        } catch (e) {
            console.error(e)
        }
        setLoading(false)
    }

    useEffect(() => { loadAdminData() }, [])

    const handleSearch = async () => {
        if (!searchQuery) return
        try {
            const result = await fetchNui('adminSearchUser', { query: searchQuery })
            setSearchResult(result)
        } catch (e) {
            console.error(e)
        }
    }

    const handleAddMoney = async () => {
        if (!addMoneyModal || !actionAmount) return
        await fetchNui('adminAddMoney', { accountId: addMoneyModal.accountId, amount: parseFloat(actionAmount) })
        setAddMoneyModal(null)
        setActionAmount("")
        loadAdminData()
    }

    const handleRemoveMoney = async () => {
        if (!removeMoneyModal || !actionAmount) return
        await fetchNui('adminRemoveMoney', { accountId: removeMoneyModal.accountId, amount: parseFloat(actionAmount) })
        setRemoveMoneyModal(null)
        setActionAmount("")
        loadAdminData()
    }

    const handleCancelLoan = async (loanId: number) => {
        await fetchNui('adminCancelLoan', { loanId })
        loadAdminData()
    }

    const handleFreezeAccount = async (accountId: number) => {
        await fetchNui('adminFreezeAccount', { accountId })
        loadAdminData()
    }

    const handleDeleteScheduled = async (transferId: number) => {
        await fetchNui('adminDeleteScheduled', { transferId })
        loadAdminData()
    }

    const handleCancelRequest = async (requestId: number) => {
        await fetchNui('adminCancelRequest', { requestId })
        loadAdminData()
    }

    const formatMoney = (val: any) => {
        return `$${parseFloat(val || 0).toLocaleString()}`
    }

    const formatDate = (dateStr: string) => {
        if (!dateStr) return '-'
        const d = new Date(dateStr)
        return d.toLocaleDateString() + ' ' + d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }

    const tabs = [
        { id: 'overview', label: t("admin.overview"), icon: <BarChart3 size={16} /> },
        { id: 'users', label: t("admin.users"), icon: <Users size={16} /> },
        { id: 'accounts', label: t("admin.accounts"), icon: <CreditCard size={16} /> },
        { id: 'loans', label: t("admin.loans"), icon: <Banknote size={16} /> },
        { id: 'transactions', label: t("admin.transactions"), icon: <History size={16} /> },
        { id: 'banks', label: t("admin.banks"), icon: <Building2 size={16} /> },
        { id: 'scheduled', label: t("admin.scheduled"), icon: <Clock size={16} /> },
        { id: 'requests', label: t("admin.requests"), icon: <ArrowLeftRight size={16} /> },
    ]

    if (loading) {
        return (
            <div className="flex-1 flex items-center justify-center">
                <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-[rgb(var(--accent-glow))]" />
            </div>
        )
    }

    return (
        <div className="flex-1 flex flex-col h-full">
            <div className="p-6 flex items-center justify-between border-b border-white/5">
                <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-red-500 to-orange-500 flex items-center justify-center">
                        <Shield size={20} className="text-white" />
                    </div>
                    <div>
                        <h1 className="text-xl font-bold text-white">{t("admin.title")}</h1>
                        <p className="text-xs text-[rgb(var(--text-secondary))]">{t("admin.subtitle")}</p>
                    </div>
                </div>
                <div className="flex items-center gap-2">
                    <button onClick={loadAdminData} className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                        <RefreshCcw size={18} className="text-[rgb(var(--text-secondary))]" />
                    </button>
                    <button onClick={onClose} className="p-2 hover:bg-red-500/20 rounded-lg transition-colors">
                        <X size={18} className="text-red-400" />
                    </button>
                </div>
            </div>

            <div className="px-6 py-3 flex gap-1 overflow-x-auto border-b border-white/5">
                {tabs.map(tab => (
                    <button key={tab.id} onClick={() => setActiveTab(tab.id)}
                        className={`px-3 py-2 rounded-lg text-xs font-medium flex items-center gap-1.5 whitespace-nowrap transition-all ${activeTab === tab.id
                            ? 'bg-[rgba(var(--accent-primary),0.2)] text-white border border-[rgba(var(--accent-primary),0.3)]'
                            : 'text-[rgb(var(--text-secondary))] hover:bg-white/5'
                            }`}>
                        {tab.icon} {tab.label}
                    </button>
                ))}
            </div>

            <div className="flex-1 overflow-y-auto p-6">
                {activeTab === 'overview' && adminData?.stats && (
                    <div className="grid grid-cols-3 gap-4">
                        {[
                            { label: t("admin.totalAccounts"), value: adminData.stats.totalAccounts, icon: <CreditCard size={20} /> },
                            { label: t("admin.totalBalance"), value: formatMoney(adminData.stats.totalBalance), icon: <DollarSign size={20} /> },
                            { label: t("admin.activeLoans"), value: adminData.stats.activeLoans, icon: <Banknote size={20} /> },
                            { label: t("admin.loanAmount"), value: formatMoney(adminData.stats.totalLoanAmount), icon: <TrendingUp size={20} /> },
                            { label: t("admin.totalTransactions"), value: adminData.stats.totalTransactions, icon: <History size={20} /> },
                            { label: t("admin.totalSavings"), value: formatMoney(adminData.stats.totalSavings), icon: <PiggyBank size={20} /> },
                            { label: t("admin.activeScheduled"), value: adminData.stats.totalScheduled, icon: <Clock size={20} /> },
                            { label: t("admin.pendingRequests"), value: adminData.stats.pendingRequests, icon: <ArrowLeftRight size={20} /> },
                            { label: t("admin.transactionVolume"), value: formatMoney(adminData.stats.totalTransactionVolume), icon: <BarChart3 size={20} /> },
                        ].map((stat, i) => (
                            <Card key={i} className="p-4">
                                <div className="flex items-center gap-3">
                                    <div className="p-2 rounded-lg bg-[rgba(var(--accent-primary),0.15)]">
                                        <span className="text-[rgb(var(--accent-glow))]">{stat.icon}</span>
                                    </div>
                                    <div>
                                        <p className="text-xs text-[rgb(var(--text-secondary))]">{stat.label}</p>
                                        <p className="text-lg font-bold text-white">{stat.value}</p>
                                    </div>
                                </div>
                            </Card>
                        ))}
                    </div>
                )}

                {activeTab === 'users' && (
                    <div className="space-y-4">
                        <div className="flex gap-2">
                            <div className="relative flex-1">
                                <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-secondary))]" />
                                <input type="text" value={searchQuery} onChange={e => setSearchQuery(e.target.value)}
                                    onKeyDown={e => e.key === 'Enter' && handleSearch()}
                                    placeholder={t("admin.searchPlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl pl-11 pr-4 py-3 text-white text-sm" />
                            </div>
                            <Button onClick={handleSearch}>{t("admin.search")}</Button>
                        </div>

                        {searchResult && (
                            <div className="space-y-4">
                                {searchResult.error ? (
                                    <Card className="p-4 text-center text-red-400">{searchResult.error}</Card>
                                ) : (
                                    <>
                                        <Card className="p-4">
                                            <h3 className="text-white font-medium mb-2">{t("admin.userInfo")}</h3>
                                            <p className="text-sm text-[rgb(var(--text-secondary))]">ID: {searchResult.identifier}</p>
                                            <p className="text-sm text-[rgb(var(--text-secondary))]">{t("admin.creditScore")}: {searchResult.creditScore}</p>
                                        </Card>

                                        {searchResult.accounts?.length > 0 && (
                                            <Card className="p-4">
                                                <h3 className="text-white font-medium mb-3">{t("admin.accounts")} ({searchResult.accounts.length})</h3>
                                                {searchResult.accounts.map((acc: any) => (
                                                    <div key={acc.id} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                                                        <div>
                                                            <p className="text-sm text-white">{acc.account_name}</p>
                                                            <p className="text-xs text-[rgb(var(--text-secondary))]">#{acc.id}</p>
                                                        </div>
                                                        <div className="flex items-center gap-2">
                                                            <p className="text-sm font-bold text-white">{formatMoney(acc.balance)}</p>
                                                            <button onClick={() => { setAddMoneyModal({ accountId: acc.id }); setActionAmount(""); }}
                                                                className="p-1 hover:bg-green-500/20 rounded" title={t("admin.addMoney")}>
                                                                <Plus size={14} className="text-green-400" />
                                                            </button>
                                                            <button onClick={() => { setRemoveMoneyModal({ accountId: acc.id }); setActionAmount(""); }}
                                                                className="p-1 hover:bg-red-500/20 rounded" title={t("admin.removeMoney")}>
                                                                <Minus size={14} className="text-red-400" />
                                                            </button>
                                                            <button onClick={() => handleFreezeAccount(acc.id)}
                                                                className="p-1 hover:bg-blue-500/20 rounded" title={t("admin.freeze")}>
                                                                <Ban size={14} className="text-blue-400" />
                                                            </button>
                                                        </div>
                                                    </div>
                                                ))}
                                            </Card>
                                        )}

                                        {searchResult.loans?.length > 0 && (
                                            <Card className="p-4">
                                                <h3 className="text-white font-medium mb-3">{t("admin.loans")} ({searchResult.loans.length})</h3>
                                                {searchResult.loans.map((loan: any) => (
                                                    <div key={loan.id} className="flex items-center justify-between py-2 border-b border-white/5 last:border-0">
                                                        <div>
                                                            <p className="text-sm text-white">{formatMoney(loan.amount)} - {loan.loan_type || 'personal'}</p>
                                                            <p className="text-xs text-[rgb(var(--text-secondary))]">{t("admin.remaining")}: {formatMoney(loan.remaining)} | {loan.status}</p>
                                                        </div>
                                                        {loan.status === 'active' && (
                                                            <button onClick={() => handleCancelLoan(loan.id)}
                                                                className="p-1 hover:bg-red-500/20 rounded" title={t("admin.cancelLoan")}>
                                                                <Trash2 size={14} className="text-red-400" />
                                                            </button>
                                                        )}
                                                    </div>
                                                ))}
                                            </Card>
                                        )}
                                    </>
                                )}
                            </div>
                        )}
                    </div>
                )}

                {activeTab === 'accounts' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.topAccounts")}</h3>
                        {adminData?.topAccounts?.map((acc: any) => (
                            <Card key={acc.id} className="p-4 flex items-center justify-between">
                                <div>
                                    <p className="text-sm text-white">{acc.account_name}</p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">{acc.owner} | #{acc.id}</p>
                                </div>
                                <div className="flex items-center gap-2">
                                    <p className="text-sm font-bold text-white">{formatMoney(acc.balance)}</p>
                                    <button onClick={() => { setAddMoneyModal({ accountId: acc.id }); setActionAmount(""); }}
                                        className="p-1 hover:bg-green-500/20 rounded"><Plus size={14} className="text-green-400" /></button>
                                    <button onClick={() => { setRemoveMoneyModal({ accountId: acc.id }); setActionAmount(""); }}
                                        className="p-1 hover:bg-red-500/20 rounded"><Minus size={14} className="text-red-400" /></button>
                                </div>
                            </Card>
                        ))}
                    </div>
                )}

                {activeTab === 'loans' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.activeLoans")}</h3>
                        {adminData?.allLoans?.length === 0 ? (
                            <Card className="p-4 text-center text-[rgb(var(--text-secondary))]">{t("admin.noLoans")}</Card>
                        ) : adminData?.allLoans?.map((loan: any) => (
                            <Card key={loan.id} className="p-4 flex items-center justify-between">
                                <div>
                                    <p className="text-sm text-white">{loan.user_identifier?.substring(0, 25)}...</p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">
                                        {formatMoney(loan.amount)} | {t("admin.remaining")}: {formatMoney(loan.remaining)} | {loan.loan_type || 'personal'}
                                    </p>
                                </div>
                                <button onClick={() => handleCancelLoan(loan.id)}
                                    className="p-2 hover:bg-red-500/20 rounded-lg" title={t("admin.cancelLoan")}>
                                    <Trash2 size={14} className="text-red-400" />
                                </button>
                            </Card>
                        ))}
                    </div>
                )}

                {activeTab === 'transactions' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.recentTransactions")}</h3>
                        <div className="max-h-[60vh] overflow-y-auto space-y-2">
                            {adminData?.recentTransactions?.map((tx: any) => (
                                <Card key={tx.id} className="p-3">
                                    <div className="flex items-center justify-between">
                                        <div>
                                            <p className="text-sm text-white">{tx.type} | {tx.account_name || `#${tx.account_id}`}</p>
                                            <p className="text-xs text-[rgb(var(--text-secondary))]">{tx.description}</p>
                                            <p className="text-xs text-[rgb(var(--text-secondary))]">{formatDate(tx.created_at)}</p>
                                        </div>
                                        <p className={`text-sm font-bold ${parseFloat(tx.amount) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                                            {formatMoney(tx.amount)}
                                        </p>
                                    </div>
                                </Card>
                            ))}
                        </div>
                    </div>
                )}

                {activeTab === 'banks' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.bankOwnerships")}</h3>
                        {adminData?.bankOwnerships?.length === 0 ? (
                            <Card className="p-4 text-center text-[rgb(var(--text-secondary))]">{t("admin.noBanks")}</Card>
                        ) : adminData?.bankOwnerships?.map((bank: any) => (
                            <Card key={bank.id} className="p-4">
                                <div className="flex items-center justify-between">
                                    <div>
                                        <p className="text-sm text-white font-medium">{bank.bank_name}</p>
                                        <p className="text-xs text-[rgb(var(--text-secondary))]">{bank.owner}</p>
                                    </div>
                                    <div className="text-right">
                                        <p className="text-sm text-white">{t("admin.commission")}: {((bank.commission_rate || 0.01) * 100).toFixed(1)}%</p>
                                        <p className="text-xs text-green-400">{t("admin.earned")}: {formatMoney(bank.total_earned)}</p>
                                    </div>
                                </div>
                            </Card>
                        ))}
                    </div>
                )}

                {activeTab === 'scheduled' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.allScheduled")}</h3>
                        {adminData?.allScheduled?.length === 0 ? (
                            <Card className="p-4 text-center text-[rgb(var(--text-secondary))]">{t("admin.noScheduled")}</Card>
                        ) : adminData?.allScheduled?.map((st: any) => (
                            <Card key={st.id} className="p-4 flex items-center justify-between">
                                <div>
                                    <p className="text-sm text-white">{formatMoney(st.amount)} {st.frequency} | {st.owner?.substring(0, 20)}...</p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">
                                        {st.from_account_name || `#${st.from_account_id}`} → {st.to_account_name || `#${st.to_account_id}`}
                                    </p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">
                                        {st.enabled ? '✅' : '❌'} | {t("admin.nextExec")}: {formatDate(st.next_execution)}
                                    </p>
                                </div>
                                <button onClick={() => handleDeleteScheduled(st.id)}
                                    className="p-2 hover:bg-red-500/20 rounded-lg">
                                    <Trash2 size={14} className="text-red-400" />
                                </button>
                            </Card>
                        ))}
                    </div>
                )}

                {activeTab === 'requests' && (
                    <div className="space-y-3">
                        <h3 className="text-white font-medium">{t("admin.pendingRequests")}</h3>
                        {adminData?.allPendingRequests?.length === 0 ? (
                            <Card className="p-4 text-center text-[rgb(var(--text-secondary))]">{t("admin.noRequests")}</Card>
                        ) : adminData?.allPendingRequests?.map((req: any) => (
                            <Card key={req.id} className="p-4 flex items-center justify-between">
                                <div>
                                    <p className="text-sm text-white">{formatMoney(req.amount)}</p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">
                                        {req.requester_identifier?.substring(0, 15)}... → {req.target_identifier?.substring(0, 15)}...
                                    </p>
                                    <p className="text-xs text-[rgb(var(--text-secondary))]">{formatDate(req.created_at)}</p>
                                </div>
                                <button onClick={() => handleCancelRequest(req.id)}
                                    className="p-2 hover:bg-red-500/20 rounded-lg">
                                    <Ban size={14} className="text-red-400" />
                                </button>
                            </Card>
                        ))}
                    </div>
                )}
            </div>

            {addMoneyModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-sm p-6 mx-4">
                        <h3 className="text-lg font-bold text-white mb-4">{t("admin.addMoney")}</h3>
                        <input type="number" value={actionAmount} onChange={e => setActionAmount(e.target.value)}
                            placeholder={t("admin.amount")}
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white mb-4" />
                        <div className="flex gap-2">
                            <Button onClick={handleAddMoney} className="flex-1">{t("admin.confirm")}</Button>
                            <Button onClick={() => setAddMoneyModal(null)} variant="ghost" className="flex-1">{t("admin.cancel")}</Button>
                        </div>
                    </Card>
                </div>
            )}

            {removeMoneyModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-sm p-6 mx-4">
                        <h3 className="text-lg font-bold text-white mb-4">{t("admin.removeMoney")}</h3>
                        <input type="number" value={actionAmount} onChange={e => setActionAmount(e.target.value)}
                            placeholder={t("admin.amount")}
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white mb-4" />
                        <div className="flex gap-2">
                            <Button onClick={handleRemoveMoney} className="flex-1">{t("admin.confirm")}</Button>
                            <Button onClick={() => setRemoveMoneyModal(null)} variant="ghost" className="flex-1">{t("admin.cancel")}</Button>
                        </div>
                    </Card>
                </div>
            )}
        </div>
    )
}
