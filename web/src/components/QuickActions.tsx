"use client"

import type React from "react"
import { ArrowDownLeft, ArrowUpRight, Send, CreditCard } from "lucide-react"
import { useLocale } from "../hooks/useLocale"

interface QuickActionsProps {
    onAction: (action: "deposit" | "withdraw" | "transfer" | "createAccount") => void
    playerMoney?: number
}

export const QuickActions: React.FC<QuickActionsProps> = ({ onAction, playerMoney }) => {
    const { t } = useLocale()
    const balance = Number(playerMoney ?? 0)

    const actions = [
        {
            id: "deposit" as const,
            label: t("quickActions.deposit"),
            icon: ArrowDownLeft,
            gradient: "from-green-500 to-emerald-600",
        },
        {
            id: "withdraw" as const,
            label: t("quickActions.withdraw"),
            icon: ArrowUpRight,
            gradient: "from-orange-500 to-red-600",
        },
        { id: "transfer" as const, label: t("quickActions.transfer"), icon: Send, gradient: "from-blue-500 to-indigo-600" },
        {
            id: "createAccount" as const,
            label: t("quickActions.newAccount"),
            icon: CreditCard,
            gradient: "from-purple-500 to-pink-600",
        },
    ]

    return (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
            {actions.map((action) => (
                <button
                    key={action.id}
                    onClick={() => onAction(action.id)}
                    className={`group relative overflow-hidden p-4 rounded-xl bg-gradient-to-br ${action.gradient} hover:scale-105 active:scale-95 transition-all duration-300 shadow-lg hover:shadow-2xl`}
                >
                    <div className="absolute inset-0 bg-black/20 group-hover:bg-black/0 transition-colors duration-300" />
                    <div className="relative flex flex-col items-center gap-1">
                        <action.icon size={24} className="text-white" />
                        <span className="text-white text-sm font-medium">{action.label}</span>

                        {/* {action.id === "deposit" && (
                            <span className="text-xs text-white/80">
                                {t("quickActions.cashAvailable")}: ${balance.toLocaleString()}
                            </span>
                        )} */}
                    </div>
                </button>
            ))}
        </div>
    )
}
