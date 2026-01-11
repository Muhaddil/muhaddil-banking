"use client"

import type React from "react"
import { useState, useEffect } from "react"
import { Button } from "./ui/Button"
import { CreditCard, Lock, Unlock, KeyRound, Trash2, Plus, ShieldCheck, AlertTriangle, X } from "lucide-react"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./ui/Select"
import { useLocale } from "../hooks/useLocale"
import { fetchNui } from "../utils/fetchNui"
import toast from "react-hot-toast"

interface BankCard {
    id: number
    account_id: number
    account_name: string
    card_number: string
    is_blocked: boolean | number
    failed_attempts: number
    created_at: string
}

interface Account {
    id: number
    account_name: string
    balance: string
}

interface CardManagerProps {
    accounts: Account[]
}

export const CardManager: React.FC<CardManagerProps> = ({ accounts }) => {
    const [cards, setCards] = useState<BankCard[]>([])
    const [loading, setLoading] = useState(true)
    const [modalType, setModalType] = useState<"none" | "create" | "pin">("none")
    const [selectedCard, setSelectedCard] = useState<BankCard | null>(null)
    const [deleteCardId, setDeleteCardId] = useState<number | null>(null)
    const [selectedAccountId, setSelectedAccountId] = useState<string>("")
    const [pinData, setPinData] = useState({ current: "", new: "", confirm: "" })
    const [newCardPin, setNewCardPin] = useState("")
    const { t } = useLocale()

    const loadCards = async () => {
        try {
            const data = await fetchNui<BankCard[]>("getCards")
            setCards(data || [])
        } catch (e) {
            console.error(e)
            // setCards([
            //     { id: 1, account_id: 1, account_name: "Cuenta Principal", card_number: "4532891023456789", is_blocked: 0, failed_attempts: 0, created_at: "2023-01-01" },
            //     { id: 2, account_id: 2, account_name: "Ahorros", card_number: "4532123456789012", is_blocked: 1, failed_attempts: 3, created_at: "2023-02-01" }
            // ])
        } finally {
            setLoading(false)
        }
    }

    useEffect(() => {
        loadCards()

        const handleMessage = (event: MessageEvent) => {
            if (event.data.action === "setData") {
                loadCards()
            }
        }

        window.addEventListener("message", handleMessage)

        return () => window.removeEventListener("message", handleMessage)
    }, [])

    const handleCreateCard = async () => {
        if (!selectedAccountId) {
            toast.error(t("cards.selectAccountError"))
            return
        }
        if (newCardPin.length !== 4 || isNaN(Number(newCardPin))) {
            toast.error(t("cards.pinError"))
            return
        }

        try {
            await fetchNui("createCard", {
                accountId: Number.parseInt(selectedAccountId),
                pin: newCardPin,
            })
            closeModal()
            loadCards()
        } catch (e) {
            toast.error(t("cards.createError"))
        }
    }

    const handleToggleBlock = async (card: BankCard) => {
        try {
            await fetchNui("toggleCardBlock", {
                cardId: card.id,
                block: !card.is_blocked,
            })
            loadCards()
        } catch (e) {
            toast.error(t("cards.blockError"))
        }
    }

    const handleChangePin = async () => {
        if (!selectedCard) return
        if (pinData.current.length !== 4 || pinData.new.length !== 4) {
            toast.error(t("cards.pinError"))
            return
        }
        if (pinData.new !== pinData.confirm) {
            toast.error(t("cards.pinMatchError"))
            return
        }

        try {
            await fetchNui("changeCardPin", {
                cardId: selectedCard.id,
                currentPin: pinData.current,
                newPin: pinData.new,
            })
            closeModal()
        } catch (e) {
            toast.error(t("cards.changePinError"))
        }
    }

    const confirmDeleteCard = async () => {
        if (deleteCardId === null) return
        try {
            await fetchNui("deleteCard", { cardId: deleteCardId })
            setDeleteCardId(null)
            loadCards()
        } catch (e) {
            toast.error(t("cards.deleteError"))
        }
    }

    const handleDeleteCard = (cardId: number) => {
        setDeleteCardId(cardId)
    }

    const closeModal = () => {
        setModalType("none")
        setSelectedCard(null)
        setPinData({ current: "", new: "", confirm: "" })
        setNewCardPin("")
        setSelectedAccountId("")
    }

    const formatCardNumber = (num: string) => {
        return num.match(/.{1,4}/g)?.join(" ") || num
    }

    return (
        <div className="space-y-6 animate-in">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-[rgb(var(--text-primary))]">{t("cards.title")}</h2>
                    <p className="text-[rgb(var(--text-secondary))] text-sm">{t("cards.description")}</p>
                </div>
                <Button
                    onClick={() => setModalType("create")}
                    className="bg-emerald-600 hover:bg-emerald-500 text-white shadow-lg shadow-emerald-500/20"
                >
                    <Plus size={18} className="mr-2" />
                    {t("cards.newCard")}
                </Button>
            </div>

            <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
                {cards.map((card) => (
                    <div key={card.id} className="relative group perspective-1000">
                        <div
                            className={`relative h-48 rounded-2xl p-6 text-white shadow-xl transition-all duration-300 transform group-hover:scale-[1.02] ${card.is_blocked
                                ? "bg-slate-800 border border-red-500/30"
                                : "bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 border border-white/10"
                                }`}
                        >
                            <div className="absolute inset-0 opacity-10 bg-[url('https://www.transparenttextures.com/patterns/cubes.png')] rounded-2xl" />
                            <div className="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full blur-2xl -mr-10 -mt-10" />

                            <div className="relative z-10 flex flex-col justify-between h-full">
                                <div className="flex justify-between items-start">
                                    <CreditCard size={32} className="text-white/80" />
                                    <div className="flex items-center gap-2">
                                        {card.is_blocked ? (
                                            <span className="flex items-center gap-1 px-2 py-1 bg-red-500/20 text-red-400 text-xs rounded-full border border-red-500/20">
                                                <Lock size={12} /> {t("cards.blocked")}
                                            </span>
                                        ) : (
                                            <span className="flex items-center gap-1 px-2 py-1 bg-emerald-500/20 text-emerald-400 text-xs rounded-full border border-emerald-500/20">
                                                <ShieldCheck size={12} /> {t("cards.active")}
                                            </span>
                                        )}
                                    </div>
                                </div>

                                <div className="space-y-1">
                                    <p className="text-xs text-white/50 font-medium tracking-wider">{t("cards.cardNumber")}</p>
                                    <p className="text-xl font-mono tracking-widest text-shadow-sm">
                                        {formatCardNumber(card.card_number)}
                                    </p>
                                </div>

                                <div className="flex justify-between items-end">
                                    <div>
                                        <p className="text-[10px] text-white/50 font-medium tracking-wider">{t("cards.linkedAccount")}</p>
                                        <p className="text-sm font-medium text-white/90 truncate max-w-[180px]">{card.account_name}</p>
                                    </div>
                                    <img
                                        src="https://raw.githubusercontent.com/Muhaddil/muhaddil-banking/2d152d8375ec89a70571ad8a593c918168efebda/icons/contactless.png"
                                        alt="NFC"
                                        className="h-8 opacity-80"
                                    />
                                </div>
                            </div>
                        </div>

                        <div className="mt-4 flex gap-2 justify-end">
                            <Button
                                variant="secondary"
                                size="sm"
                                onClick={() => handleToggleBlock(card)}
                                className={
                                    card.is_blocked ? "text-emerald-400 hover:text-emerald-300" : "text-amber-400 hover:text-amber-300"
                                }
                                title={card.is_blocked ? t("cards.unblock") : t("cards.block")}
                            >
                                {card.is_blocked ? <Unlock size={16} /> : <Lock size={16} />}
                            </Button>
                            <Button
                                variant="secondary"
                                size="sm"
                                onClick={() => {
                                    setSelectedCard(card)
                                    setModalType("pin")
                                }}
                                title={t("cards.changePin")}
                            >
                                <KeyRound size={16} />
                            </Button>
                            <Button
                                variant="secondary"
                                size="sm"
                                onClick={() => handleDeleteCard(card.id)}
                                className="text-red-400 hover:text-red-300"
                                title={t("cards.delete")}
                            >
                                <Trash2 size={16} />
                            </Button>
                        </div>
                    </div>
                ))}

                {cards.length === 0 && !loading && (
                    <div className="col-span-full flex flex-col items-center justify-center py-12 text-[rgb(var(--text-secondary))] bg-white/5 rounded-2xl border border-white/10 border-dashed">
                        <CreditCard size={48} className="mb-4 opacity-50" />
                        <p className="text-lg font-medium">{t("cards.noCards")}</p>
                        <p className="text-sm">{t("cards.createCardMessage")}</p>
                    </div>
                )}
            </div>

            {deleteCardId !== null && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
                    <div className="bg-[rgb(var(--bg-card))] p-6 rounded-2xl w-full max-w-sm border border-white/10 shadow-2xl relative">
                        <h3 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
                            <Trash2 className="text-red-400" />
                            {t("cards.confirmDelete")}
                        </h3>
                        <p className="text-sm text-white/80 mb-6">{t("cards.deleteConfirmation")}</p>
                        <div className="flex justify-end gap-3">
                            <Button
                                variant="secondary"
                                onClick={() => setDeleteCardId(null)}
                                className="text-white/70 hover:text-white transition-colors"
                            >
                                {t("cards.cancel")}
                            </Button>
                            <Button className="bg-red-600 hover:bg-red-500 text-white" onClick={confirmDeleteCard}>
                                {t("cards.delete")}
                            </Button>
                        </div>
                    </div>
                </div>
            )}

            {modalType !== "none" && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
                    <div className="bg-[rgb(var(--bg-card))] p-6 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl relative">
                        <button
                            onClick={closeModal}
                            className="absolute top-4 right-4 text-slate-400 hover:text-white transition-colors"
                        >
                            <X size={20} />
                        </button>

                        {modalType === "create" && (
                            <>
                                <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                                    <Plus className="text-emerald-400" />
                                    {t("cards.newCard")}
                                </h3>

                                <div className="space-y-4">
                                    <div>
                                        <label className="block text-sm text-slate-400 mb-2">{t("cards.linkedAccount")}</label>
                                        <Select value={selectedAccountId} onValueChange={setSelectedAccountId}>
                                            <SelectTrigger className="w-full">
                                                <SelectValue placeholder={t("cards.selectAccount")} />
                                            </SelectTrigger>
                                            <SelectContent>
                                                {accounts.map((acc) => (
                                                    <SelectItem key={acc.id} value={acc.id.toString()}>
                                                        {acc.account_name} (${acc.balance})
                                                    </SelectItem>
                                                ))}
                                            </SelectContent>
                                        </Select>
                                    </div>

                                    <div>
                                        <label className="block text-sm text-slate-400 mb-2">{t("cards.securityPin")}</label>
                                        <div className="relative">
                                            <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" size={18} />
                                            <input
                                                type="password"
                                                maxLength={4}
                                                placeholder="****"
                                                value={newCardPin}
                                                onChange={(e) => {
                                                    const val = e.target.value.replace(/\D/g, "").slice(0, 4)
                                                    setNewCardPin(val)
                                                }}
                                                className="w-full bg-slate-800 border border-slate-700 rounded-lg p-3 pl-10 text-white outline-none focus:border-emerald-500 font-mono text-lg tracking-widest"
                                            />
                                        </div>
                                    </div>

                                    <div className="bg-yellow-500/10 border border-yellow-500/20 rounded-lg p-3 flex gap-3 items-start">
                                        <AlertTriangle className="text-yellow-500 shrink-0 mt-0.5" size={16} />
                                        <p className="text-xs text-yellow-200/80">
                                            {t("cards.issuanceCost")}: <span className="font-bold text-yellow-400">$500</span>.
                                            {t("cards.pinReminder")}
                                        </p>
                                    </div>

                                    <Button
                                        onClick={handleCreateCard}
                                        className="w-full bg-emerald-600 hover:bg-emerald-500 text-white mt-2"
                                    >
                                        {t("cards.requestCard")}
                                    </Button>
                                </div>
                            </>
                        )}

                        {modalType === "pin" && selectedCard && (
                            <>
                                <h3 className="text-xl font-bold text-white mb-6 flex items-center gap-2">
                                    <KeyRound className="text-amber-400" />
                                    {t("cards.changePin")}
                                </h3>

                                <div className="space-y-4">
                                    <div>
                                        <label className="block text-sm text-slate-400 mb-2">{t("cards.currentPin")}</label>
                                        <input
                                            type="password"
                                            maxLength={4}
                                            value={pinData.current}
                                            onChange={(e) =>
                                                setPinData({ ...pinData, current: e.target.value.replace(/\D/g, "").slice(0, 4) })
                                            }
                                            className="w-full bg-slate-800 border border-slate-700 rounded-lg p-3 text-white outline-none focus:border-amber-500 font-mono text-center tracking-widest"
                                        />
                                    </div>

                                    <div className="grid grid-cols-2 gap-4">
                                        <div>
                                            <label className="block text-sm text-slate-400 mb-2">{t("cards.newPin")}</label>
                                            <input
                                                type="password"
                                                maxLength={4}
                                                value={pinData.new}
                                                onChange={(e) => setPinData({ ...pinData, new: e.target.value.replace(/\D/g, "").slice(0, 4) })}
                                                className="w-full bg-slate-800 border border-slate-700 rounded-lg p-3 text-white outline-none focus:border-amber-500 font-mono text-center tracking-widest"
                                            />
                                        </div>
                                        <div>
                                            <label className="block text-sm text-slate-400 mb-2">{t("cards.confirmPin")}</label>
                                            <input
                                                type="password"
                                                maxLength={4}
                                                value={pinData.confirm}
                                                onChange={(e) =>
                                                    setPinData({ ...pinData, confirm: e.target.value.replace(/\D/g, "").slice(0, 4) })
                                                }
                                                className="w-full bg-slate-800 border border-slate-700 rounded-lg p-3 text-white outline-none focus:border-amber-500 font-mono text-center tracking-widest"
                                            />
                                        </div>
                                    </div>

                                    <Button onClick={handleChangePin} className="w-full bg-amber-600 hover:bg-amber-500 text-white mt-2">
                                        {t("cards.updatePin")}
                                    </Button>
                                </div>
                            </>
                        )}
                    </div>
                </div>
            )}
        </div>
    )
}
