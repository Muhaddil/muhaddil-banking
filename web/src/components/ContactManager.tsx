"use client"

import type React from "react"
import { useState } from "react"
import { Card } from "./ui/Card"
import { Button } from "./ui/Button"
import { Users, Plus, Edit2, Trash2, Send, Search, X, User } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface Contact {
    id: number
    owner: string
    contact_name: string
    contact_account_id: number
    contact_account_name?: string
    notes: string | null
    created_at: string
}

interface ContactsConfig {
    enabled: boolean
    maxContacts: number
}

interface ContactManagerProps {
    contacts: Contact[]
    config: ContactsConfig
    onAddContact: (data: { contactName: string; contactAccountId: number; notes: string }) => void
    onUpdateContact: (data: { contactId: number; contactName: string; notes: string }) => void
    onRemoveContact: (contactId: number) => void
    onQuickTransfer?: (accountId: number) => void
}

export const ContactManager: React.FC<ContactManagerProps> = ({
    contacts, config, onAddContact, onUpdateContact, onRemoveContact, onQuickTransfer
}) => {
    const { t } = useLocale()
    const [showAddModal, setShowAddModal] = useState(false)
    const [editingContact, setEditingContact] = useState<Contact | null>(null)
    const [searchTerm, setSearchTerm] = useState("")

    const [contactName, setContactName] = useState("")
    const [contactAccountId, setContactAccountId] = useState("")
    const [notes, setNotes] = useState("")

    const filteredContacts = contacts.filter(c =>
        c.contact_name.toLowerCase().includes(searchTerm.toLowerCase())
    )

    const handleAdd = () => {
        if (!contactName || !contactAccountId) return
        onAddContact({ contactName, contactAccountId: parseInt(contactAccountId), notes })
        setShowAddModal(false)
        setContactName("")
        setContactAccountId("")
        setNotes("")
    }

    const handleUpdate = () => {
        if (!editingContact || !contactName) return
        onUpdateContact({ contactId: editingContact.id, contactName, notes })
        setEditingContact(null)
        setContactName("")
        setNotes("")
    }

    const openEdit = (contact: Contact) => {
        setEditingContact(contact)
        setContactName(contact.contact_name)
        setNotes(contact.notes || "")
    }

    const getInitials = (name: string) => {
        return name.split(' ').map(w => w[0]).join('').toUpperCase().slice(0, 2)
    }

    return (
        <div className="space-y-6">
            <div className="flex items-center justify-between">
                <div>
                    <h2 className="text-2xl font-bold text-white flex items-center gap-2">
                        <Users className="text-[rgb(var(--accent-glow))]" size={24} />
                        {t("contacts.title")}
                    </h2>
                    <p className="text-[rgb(var(--text-secondary))] text-sm mt-1">
                        {contacts.length}/{config.maxContacts} {t("contacts.used")}
                    </p>
                </div>
                <Button onClick={() => setShowAddModal(true)} className="flex items-center gap-2">
                    <Plus size={16} /> {t("contacts.addContact")}
                </Button>
            </div>

            <div className="relative">
                <Search size={18} className="absolute left-4 top-1/2 -translate-y-1/2 text-[rgb(var(--text-secondary))]" />
                <input type="text" value={searchTerm} onChange={e => setSearchTerm(e.target.value)}
                    placeholder={t("contacts.search")}
                    className="w-full bg-white/5 border border-white/10 rounded-xl pl-11 pr-4 py-3 text-white" />
            </div>

            {filteredContacts.length === 0 ? (
                <Card className="p-8 text-center">
                    <Users size={48} className="mx-auto mb-4 text-[rgb(var(--text-secondary))] opacity-40" />
                    <p className="text-[rgb(var(--text-secondary))]">{t("contacts.noContacts")}</p>
                </Card>
            ) : (
                <div className="grid gap-3">
                    {filteredContacts.map(contact => (
                        <Card key={contact.id} className="p-4 flex items-center gap-4 group hover:border-[rgba(var(--accent-primary),0.3)] transition-all">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] flex items-center justify-center text-white font-bold text-sm">
                                {getInitials(contact.contact_name)}
                            </div>
                            <div className="flex-1 min-w-0">
                                <h3 className="text-white font-medium truncate">{contact.contact_name}</h3>
                                <p className="text-xs text-[rgb(var(--text-secondary))]">
                                    {t("contacts.accountId")}: #{contact.contact_account_id}
                                    {contact.contact_account_name && ` • ${contact.contact_account_name}`}
                                </p>
                                {contact.notes && (
                                    <p className="text-xs text-[rgb(var(--text-secondary))] mt-0.5 truncate">{contact.notes}</p>
                                )}
                            </div>
                            <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                {onQuickTransfer && (
                                    <button onClick={() => onQuickTransfer(contact.contact_account_id)}
                                        className="p-2 hover:bg-[rgba(var(--accent-primary),0.2)] rounded-lg transition-colors"
                                        title={t("contacts.quickTransfer")}>
                                        <Send size={14} className="text-[rgb(var(--accent-glow))]" />
                                    </button>
                                )}
                                <button onClick={() => openEdit(contact)}
                                    className="p-2 hover:bg-white/10 rounded-lg transition-colors">
                                    <Edit2 size={14} className="text-[rgb(var(--text-secondary))]" />
                                </button>
                                <button onClick={() => onRemoveContact(contact.id)}
                                    className="p-2 hover:bg-red-500/20 rounded-lg transition-colors">
                                    <Trash2 size={14} className="text-red-400" />
                                </button>
                            </div>
                        </Card>
                    ))}
                </div>
            )}

            {showAddModal && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("contacts.addContact")}</h3>
                            <button onClick={() => setShowAddModal(false)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("contacts.name")}</label>
                                <input type="text" value={contactName} onChange={e => setContactName(e.target.value)}
                                    placeholder={t("contacts.namePlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("contacts.accountId")}</label>
                                <input type="number" value={contactAccountId} onChange={e => setContactAccountId(e.target.value)}
                                    placeholder="12345"
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("contacts.notes")}</label>
                                <input type="text" value={notes} onChange={e => setNotes(e.target.value)}
                                    placeholder={t("contacts.notesPlaceholder")}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <Button onClick={handleAdd} className="w-full">{t("contacts.add")}</Button>
                        </div>
                    </Card>
                </div>
            )}

            {editingContact && (
                <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm">
                    <Card className="w-full max-w-md p-6 mx-4">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-bold text-white">{t("contacts.editContact")}</h3>
                            <button onClick={() => setEditingContact(null)} className="p-1 hover:bg-white/10 rounded-lg">
                                <X size={20} className="text-[rgb(var(--text-secondary))]" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("contacts.name")}</label>
                                <input type="text" value={contactName} onChange={e => setContactName(e.target.value)}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <div>
                                <label className="text-sm text-[rgb(var(--text-secondary))] mb-1 block">{t("contacts.notes")}</label>
                                <input type="text" value={notes} onChange={e => setNotes(e.target.value)}
                                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white" />
                            </div>
                            <Button onClick={handleUpdate} className="w-full">{t("contacts.save")}</Button>
                        </div>
                    </Card>
                </div>
            )}
        </div>
    )
}
