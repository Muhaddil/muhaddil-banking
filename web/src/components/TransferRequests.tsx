"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { ArrowLeftRight, Send, Check, XCircle, Clock, Plus, X, Ban } from "lucide-react"
import { useLocale } from "../hooks/useLocale"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"

interface TransferRequest {
    id: number
    requester_identifier: string
    target_identifier: string
    amount: string
    requester_account_id: number
    target_account_id: number | null
    requester_account_name?: string
    status: string
    message: string | null
    created_at: string
    resolved_at: string | null
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface TransferRequestsConfig {
    enabled: boolean
    maxPending: number
}

interface TransferRequestsProps {
    incoming: TransferRequest[]
    outgoing: TransferRequest[]
    accounts: Account[]
    config: TransferRequestsConfig
    onCreateRequest: (data: { targetPlayerId: number; amount: number; fromAccountId: number; message: string }) => void
    onAcceptRequest: (data: { requestId: number; fromAccountId: number }) => void
    onRejectRequest: (requestId: number) => void
    onCancelRequest: (requestId: number) => void
}

export const TransferRequests: React.FC<TransferRequestsProps> = ({
    incoming, outgoing, accounts, config, onCreateRequest, onAcceptRequest, onRejectRequest, onCancelRequest
}) => {
    const { t } = useLocale()
    const [activeTab, setActiveTab] = useState<'incoming' | 'outgoing'>('incoming')
    const [showCreateModal, setShowCreateModal] = useState(false)
    const [showAcceptModal, setShowAcceptModal] = useState<TransferRequest | null>(null)

    const [targetPlayerId, setTargetPlayerId] = useState("")
    const [amount, setAmount] = useState("")
    const [fromAccountId, setFromAccountId] = useState<number>(accounts[0]?.id || 0)
    const [message, setMessage] = useState("")
    const [acceptAccountId, setAcceptAccountId] = useState<number>(accounts[0]?.id || 0)

    const handleCreate = () => {
        if (!targetPlayerId || !amount || !fromAccountId) return
        onCreateRequest({
            targetPlayerId: parseInt(targetPlayerId),
            amount: parseFloat(amount),
            fromAccountId,
            message
        })
        setShowCreateModal(false)
        setTargetPlayerId("")
        setAmount("")
        setMessage("")
    }

    const handleAccept = () => {
        if (!showAcceptModal) return
        onAcceptRequest({ requestId: showAcceptModal.id, fromAccountId: acceptAccountId })
        setShowAcceptModal(null)
    }

    const getStatusBadge = (status: string) => {
        const styles: Record<string, string> = {
            pending: 'bg-yellow-500/20 text-yellow-400',
            accepted: 'bg-green-500/20 text-green-400',
            rejected: 'bg-red-500/20 text-red-400',
            cancelled: 'bg-gray-500/20 text-gray-400',
            expired: 'bg-orange-500/20 text-orange-400'
        }
        const icons: Record<string, React.ReactNode> = {
            pending: <Clock size={12} />,
            accepted: <Check size={12} />,
            rejected: <XCircle size={12} />,
            cancelled: <Ban size={12} />,
            expired: <Clock size={12} />
        }
        return (
            <span className={`px-2 py-1 rounded-full text-xs font-medium flex items-center gap-1 ${styles[status] || styles.pending}`}>
                {icons[status]} {t(`transferRequests.status.${status}`)}
            </span>
        )
    }

    const formatDate = (dateStr: string) => {
        const date = new Date(dateStr)
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <ArrowLeftRight className="text-[rgb(var(--accent-glow))]" size={24} />
                        {t("transferRequests.title")}
                    </h2>
                    <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">{t("transferRequests.subtitle")}</p>
                </div>
                <Button onClick={() => setShowCreateModal(true)} className="flex items-center gap-2">
                    <Plus size={16} /> {t("transferRequests.newRequest")}
                </Button>
            </div>

            <div className="flex gap-2">
                <button onClick={() => setActiveTab('incoming')}
                    className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${activeTab === 'incoming'
                        ? 'bg-[rgba(var(--accent-primary),0.2)] text-white border border-[rgba(var(--accent-primary),0.3)]'
                        : 'text-[rgb(var(--text-secondary))] hover:bg-white/5'
                        }`}>
                    {t("transferRequests.incoming")}
                    {incoming.length > 0 && (
                        <span className="ml-2 px-2 py-0.5 bg-[rgb(var(--accent-glow))] text-white rounded-full text-xs">
                            {incoming.length}
                        </span>
                    )}
                </button>
                <button onClick={() => setActiveTab('outgoing')}
                    className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${activeTab === 'outgoing'
                        ? 'bg-[rgba(var(--accent-primary),0.2)] text-white border border-[rgba(var(--accent-primary),0.3)]'
                        : 'text-[rgb(var(--text-secondary))] hover:bg-white/5'
                        }`}>
                    {t("transferRequests.outgoing")}
                </button>
            </div>

            {activeTab === 'incoming' && (
                incoming.length === 0 ? (
                    <Card className="p-8 text-center">
                        <ArrowLeftRight size={48} className="mx-auto mb-4 text-[rgb(var(--text-secondary))] opacity-40" />
                        <p className="text-[rgb(var(--text-secondary))]">{t("transferRequests.noIncoming")}</p>
                    </Card>
                ) : (
                    <div className="grid gap-3">
                        {incoming.map(req => (
                            <Card key={req.id} className="p-4">
                                <div className="flex items-center justify-between mb-2">
                                    <div className="flex items-center gap-2">
                                        <Send size={16} className="text-[rgb(var(--accent-glow))]" />
                                        <span className="text-white font-medium">
                                            ${parseFloat(req.amount).toLocaleString()}
                                        </span>
                                    </div>
                                    {getStatusBadge(req.status)}
                                </div>
                                <p className="text-xs text-[rgb(var(--text-secondary))] mb-1">
                                    {t("transferRequests.from")}: {req.requester_identifier.substring(0, 20)}...
                                </p>
                                {req.message && (
                                    <p className="text-xs text-[rgb(var(--text-secondary))] mb-2 italic">"{req.message}"</p>
                                )}
                                <p className="text-xs text-[rgb(var(--text-secondary))] mb-3">{formatDate(req.created_at)}</p>
                                {req.status === 'pending' && (
                                    <div className="flex gap-2">
                                        <Button onClick={() => { setShowAcceptModal(req); setAcceptAccountId(accounts[0]?.id || 0); }}
                                            className="flex-1 text-sm">
                                            <Check size={14} className="mr-1" /> {t("transferRequests.accept")}
                                        </Button>
                                        <Button onClick={() => onRejectRequest(req.id)} variant="ghost"
                                            className="flex-1 text-sm text-red-400 border-red-400/30 hover:bg-red-500/10">
                                            <XCircle size={14} className="mr-1" /> {t("transferRequests.reject")}
                                        </Button>
                                    </div>
                                )}
                            </Card>
                        ))}
                    </div>
                )
            )}

            {activeTab === 'outgoing' && (
                outgoing.length === 0 ? (
                    <Card className="p-8 text-center">
                        <ArrowLeftRight size={48} className="mx-auto mb-4 text-[rgb(var(--text-secondary))] opacity-40" />
                        <p className="text-[rgb(var(--text-secondary))]">{t("transferRequests.noOutgoing")}</p>
                    </Card>
                ) : (
                    <div className="grid gap-3">
                        {outgoing.map(req => (
                            <Card key={req.id} className="p-4">
                                <div className="flex items-center justify-between mb-2">
                                    <span className="text-white font-medium">${parseFloat(req.amount).toLocaleString()}</span>
                                    {getStatusBadge(req.status)}
                                </div>
                                <p className="text-xs text-[rgb(var(--text-secondary))] mb-1">
                                    {t("transferRequests.to")}: {req.target_identifier.substring(0, 20)}...
                                </p>
                                {req.message && <p className="text-xs text-[rgb(var(--text-secondary))] mb-2 italic">"{req.message}"</p>}
                                <p className="text-xs text-[rgb(var(--text-secondary))] mb-3">{formatDate(req.created_at)}</p>
                                {req.status === 'pending' && (
                                    <Button onClick={() => onCancelRequest(req.id)} variant="ghost"
                                        className="w-full text-sm text-red-400 border-red-400/30 hover:bg-red-500/10">
                                        {t("transferRequests.cancel")}
                                    </Button>
                                )}
                            </Card>
                        ))}
                    </div>
                )
            )}

            {showCreateModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("transferRequests.newRequest")}</h3>
                            <button onClick={() => setShowCreateModal(false)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("transferRequests.targetPlayer")}</label>
                                <input type="number" value={targetPlayerId} onChange={e => setTargetPlayerId(e.target.value)}
                                    placeholder={t("transferRequests.playerIdPlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("transferRequests.amount")}</label>
                                <input type="number" value={amount} onChange={e => setAmount(e.target.value)}
                                    placeholder="1000"
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("transferRequests.receiveIn")}</label>
                                <Select
                                    value={String(fromAccountId)}
                                    onValueChange={(value: string) => setFromAccountId(Number(value))}
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder={t("transferRequests.receiveIn")} />
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
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("transferRequests.message")}</label>
                                <input type="text" value={message} onChange={e => setMessage(e.target.value)}
                                    placeholder={t("transferRequests.messagePlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <Button onClick={handleCreate} className="w-full">{t("transferRequests.send")}</Button>
                        </div>
                    </Card>
                </div>
            )}

            {showAcceptModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("transferRequests.acceptRequest")}</h3>
                            <button onClick={() => setShowAcceptModal(null)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <p className="text-sm text-[rgb(var(--text-secondary))]">
                                {t("transferRequests.acceptAmount")}: <span className="text-white font-bold">${parseFloat(showAcceptModal.amount).toLocaleString()}</span>
                            </p>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("transferRequests.payFrom")}</label>
                                <Select
                                    value={String(acceptAccountId)}
                                    onValueChange={(value: string) => setAcceptAccountId(Number(value))}
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder={t("transferRequests.payFrom")} />
                                    </SelectTrigger>
                                    <SelectContent>
                                        {accounts.map(a => (
                                            <SelectItem key={a.id} value={String(a.id)}>
                                                {a.account_name} (${parseFloat(a.balance).toLocaleString()})
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>
                            </div>
                            <Button onClick={handleAccept} className="w-full">{t("transferRequests.confirmAccept")}</Button>
                        </div>
                    </Card>
                </div>
            )}
        </div>
    )
}