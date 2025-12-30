"use client"

import type React from "react"
import { createContext, useContext, useState, useEffect } from "react"

export type Theme = "dark" | "red" | "blue" | "green" | "purple"

interface ThemeContextType {
    theme: Theme
    setTheme: (theme: Theme) => void
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined)

export const useTheme = () => {
    const context = useContext(ThemeContext)
    if (!context) throw new Error("useTheme must be used within ThemeProvider")
    return context
}

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
    const [theme, setTheme] = useState<Theme>("dark")

    useEffect(() => {
        const savedTheme = localStorage.getItem("bank-theme") as Theme
        if (savedTheme) setTheme(savedTheme)
    }, [])

    useEffect(() => {
        localStorage.setItem("bank-theme", theme)
        document.documentElement.setAttribute("data-theme", theme)
    }, [theme])

    return <ThemeContext.Provider value={{ theme, setTheme }}>{children}</ThemeContext.Provider>
}
