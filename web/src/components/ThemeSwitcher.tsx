"use client"

import type React from "react"
import { useState } from "react"
import { Palette, Check } from "lucide-react"
import { useTheme, type Theme } from "../contexts/ThemeContext"

export const ThemeSwitcher: React.FC = () => {
    const { theme, setTheme } = useTheme()
    const [isOpen, setIsOpen] = useState(false)

    const themes: { value: Theme; label: string; colors: string[] }[] = [
        { value: "dark", label: "Oscuro", colors: ["from-slate-600", "to-gray-800"] },
        // { value: "light", label: "Claro", colors: ["from-blue-200", "to-cyan-200"] },
        { value: "red", label: "Rojo", colors: ["from-red-500", "to-rose-600"] },
        { value: "blue", label: "Azul", colors: ["from-blue-500", "to-indigo-600"] },
        { value: "green", label: "Verde", colors: ["from-emerald-500", "to-teal-600"] },
        { value: "purple", label: "Púrpura", colors: ["from-purple-500", "to-pink-600"] },
    ]

    return (
        <div className="relative">
            <button
                onClick={() => setIsOpen(!isOpen)}
                className="p-3 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 transition-all duration-300 hover:scale-105"
                title="Cambiar tema"
            >
                <Palette size={20} className="text-white" />
            </button>

            {isOpen && (
                <>
                    <div className="fixed inset-0 z-40" onClick={() => setIsOpen(false)} />
                    <div className="absolute right-0 top-full mt-2 w-56 bg-[rgb(var(--bg-card))] border border-white/10 rounded-xl shadow-2xl overflow-hidden z-50 animate-slide-up">
                        <div className="p-3 border-b border-white/5">
                            <p className="text-white font-medium text-sm">Seleccionar Tema</p>
                        </div>
                        <div className="p-2 space-y-1">
                            {themes.map(({ value, label, colors }) => (
                                <button
                                    key={value}
                                    onClick={() => {
                                        setTheme(value)
                                        setIsOpen(false)
                                    }}
                                    className={`w-full flex items-center gap-3 p-3 rounded-lg transition-all duration-200 ${theme === value ? "bg-white/10 border border-white/20" : "hover:bg-white/5"
                                        }`}
                                >
                                    <div className={`w-8 h-8 rounded-lg bg-gradient-to-br ${colors.join(" ")} shadow-md`} />
                                    <span className="flex-1 text-left text-white text-sm">{label}</span>
                                    {theme === value && <Check size={16} className="text-green-400" />}
                                </button>
                            ))}
                        </div>
                    </div>
                </>
            )}
        </div>
    )
}
