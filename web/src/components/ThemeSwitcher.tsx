"use client"

import type React from "react"
import { useState } from "react"
import { Palette, Check } from "lucide-react"
import { useTheme, type Theme } from "../contexts/ThemeContext"

export const ThemeSwitcher: React.FC = () => {
  const { theme, setTheme } = useTheme()
  const [isOpen, setIsOpen] = useState(false)

  const themes: { value: Theme; label: string; gradient: string }[] = [
    { value: "dark", label: "Oscuro", gradient: "linear-gradient(to bottom right, #475569, #1f2937)" },
    { value: "red", label: "Rojo", gradient: "linear-gradient(to bottom right, #ef4444, #e11d48)" },
    { value: "blue", label: "Azul", gradient: "linear-gradient(to bottom right, #3b82f6, #4f46e5)" },
    { value: "green", label: "Verde", gradient: "linear-gradient(to bottom right, #10b981, #0d9488)" },
    { value: "purple", label: "Púrpura", gradient: "linear-gradient(to bottom right, #8b5cf6, #ec4899)" },
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

      {/* Overlay */}
      <div
        onClick={() => setIsOpen(false)}
        className={`fixed inset-0 z-40 transition-opacity duration-200 ${
          isOpen ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none"
        }`}
      />

      {/* Dropdown animado */}
      <div
        className={`absolute right-0 top-full mt-2 w-56 
        bg-[rgb(var(--bg-card))] border border-white/10 
        rounded-xl shadow-2xl overflow-hidden z-50
        transform transition-all duration-200 ease-out
        ${
          isOpen
            ? "opacity-100 translate-y-0 scale-100 pointer-events-auto"
            : "opacity-0 -translate-y-2 scale-95 pointer-events-none"
        }`}
      >
        <div className="p-3 border-b border-white/5">
          <p className="text-white font-medium text-sm">
            Seleccionar Tema
          </p>
        </div>

        <div className="p-2 space-y-1">
          {themes.map(({ value, label, gradient }) => (
            <button
              key={value}
              onClick={() => {
                setTheme(value)
                setIsOpen(false)
              }}
              className={`w-full flex items-center gap-3 p-3 rounded-lg transition-all duration-200 ${
                theme === value
                  ? "bg-white/10 border border-white/20"
                  : "hover:bg-white/5"
              }`}
            >
              <div
                className="w-8 h-8 rounded-lg shadow-md"
                style={{ background: gradient }}
              />

              <span className="flex-1 text-left text-white text-sm">
                {label}
              </span>

              {theme === value && (
                <Check size={16} className="text-green-400" />
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  )
}