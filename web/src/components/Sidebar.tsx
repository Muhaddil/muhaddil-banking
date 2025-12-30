"use client"

import type React from "react"
import { LayoutDashboard, CreditCard, History, Banknote, Building2, LogOut } from "lucide-react"
import { ThemeSwitcher } from "./ThemeSwitcher"
import { useLocale } from "../hooks/useLocale"

interface SidebarProps {
    activeTab: string
    setActiveTab: (tab: string) => void
    onClose: () => void
    currentBank?: string
    currentBankType?: string
    bankManagementEnabled?: boolean
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab, onClose, currentBank, currentBankType, bankManagementEnabled }) => {
    const { t } = useLocale()

    const bankTitle = currentBank && currentBank.trim() ? currentBank : t("sidebar.bankName")
    const bankSubtitle =
        currentBank && currentBank.trim()
            ? currentBankType === "state"
                ? t("dashboard.bankInfo.bankTypes.state")
                : currentBankType === "private"
                    ? t("dashboard.bankInfo.bankTypes.private")
                    : undefined
            : t("sidebar.bankSubtitle")

    const menuItems = [
        { id: "accounts", label: t("sidebar.accounts"), icon: <CreditCard size={20} /> },
        { id: "cards", label: t("sidebar.cards"), icon: <CreditCard size={20} /> },
        { id: "transactions", label: t("sidebar.transactions"), icon: <History size={20} /> },
        { id: "loans", label: t("sidebar.loans"), icon: <Banknote size={20} /> },
        { id: "stats", label: t("sidebar.stats"), icon: <LayoutDashboard size={20} /> },
        ...(bankManagementEnabled
            ? [{ id: "banks", label: t("sidebar.banks"), icon: <Building2 size={20} /> }]
            : []),
    ]

    return (
        <div className="w-72 glass-panel m-4 rounded-2xl flex flex-col border-r-0">
            <div className="p-6 md:p-8">
                <div className="flex items-center justify-between mb-8">
                    <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[rgb(var(--accent-primary))] to-[rgb(var(--accent-secondary))] flex items-center justify-center shadow-lg shadow-[rgba(var(--accent-glow),0.3)]">
                            <Building2 className="text-white" size={20} />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold text-white tracking-tight">{bankTitle}</h1>
                            {bankSubtitle ? (
                                <p className="text-xs text-[rgb(var(--text-secondary))]">{bankSubtitle}</p>
                            ) : null}
                        </div>
                    </div>
                    <ThemeSwitcher />
                </div>

                <nav className="space-y-2">
                    {menuItems.map((item) => (
                        <button
                            key={item.id}
                            onClick={() => setActiveTab(item.id)}
                            className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-xl transition-all duration-300 group ${activeTab === item.id
                                ? "bg-gradient-to-r from-[rgba(var(--accent-primary),0.2)] to-[rgba(var(--accent-secondary),0.2)] text-white border border-[rgba(var(--accent-primary),0.3)] shadow-lg shadow-[rgba(var(--accent-glow),0.1)]"
                                : "text-[rgb(var(--text-secondary))] hover:bg-white/5 hover:text-white"
                                }`}
                        >
                            <span
                                className={`${activeTab === item.id ? "text-[rgb(var(--accent-glow))]" : "text-current group-hover:text-white"
                                    } transition-colors`}
                            >
                                {item.icon}
                            </span>
                            <span className="font-medium">{item.label}</span>
                            {activeTab === item.id && (
                                <div className="ml-auto w-2 h-2 rounded-full bg-[rgb(var(--accent-glow))] shadow-[0_0_8px_rgb(var(--accent-glow))] animate-pulse" />
                            )}
                        </button>
                    ))}
                </nav>
            </div>

            <div className="mt-auto p-6 md:p-8 border-t border-white/5 space-y-2">
                <button
                    onClick={onClose}
                    className="w-full flex items-center gap-3 px-4 py-3.5 rounded-xl text-red-400 hover:bg-red-500/10 transition-all duration-300 hover:scale-105"
                >
                    <LogOut size={20} />
                    <span className="font-medium">{t("sidebar.close")}</span>
                </button>
            </div>
        </div>
    )
}
