"use client"

import React, { createContext, useContext, useState, useCallback, useEffect } from "react"
import { useNuiEvent } from "../hooks/useNuiEvent"

export type LocaleData = Record<string, any>

interface LocaleContextType {
  locale: string
  localeData: LocaleData
  setLocale: (locale: string) => void
  t: (key: string, ...args: any[]) => string
}

const LocaleContext = createContext<LocaleContextType | undefined>(undefined)

export const LocaleProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [locale, setLocaleState] = useState(() => localStorage.getItem("locale") || "es")
  const [localeData, setLocaleData] = useState<LocaleData>({})
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const loadLocale = async (localeName: string) => {
      setLoaded(false)
      try {
        const resourceName = (window as any).GetParentResourceName
          ? (window as any).GetParentResourceName()
          : 'muhaddil-banking'

        const response = await fetch(`https://cfx-nui-${resourceName}/locales/${localeName}.json`)
        const data = response.ok ? await response.json() : {}
        setLocaleData(data)
        localStorage.setItem("locale", localeName)
      } catch (error) {
        console.error("[LocaleProvider] Error loading locale:", error)
        setLocaleData({})
      } finally {
        setLoaded(true)
      }
    }

    loadLocale(locale)
  }, [locale])

  useNuiEvent<{ locale: string }>("setLocale", (data) => {
    if (data.locale && data.locale !== locale) {
      setLocaleState(data.locale)
    }
  })

  const setLocale = useCallback((newLocale: string) => {
    setLocaleState(newLocale)
  }, [])

  const t = useCallback(
    (key: string, vars?: Record<string, string | number> | any[]): string => {
      const keys = key.split(".")
      let text: any = localeData

      for (const k of keys) {
        text = text?.[k]
        if (text === undefined) {
          console.warn("[LocaleProvider] Translation key not found:", key)
          return key
        }
      }

      if (typeof text === "string") {
        if (Array.isArray(vars)) {
          vars.forEach(arg => {
            text = text.replace("%s", String(arg))
          })
        } else if (typeof vars === "object" && vars !== null) {
          Object.entries(vars).forEach(([k, v]) => {
            text = text.replace(new RegExp(`\\{${k}\\}`, "g"), String(v))
          })
        }
      }

      return typeof text === "string" ? text : key
    },
    [localeData]
  )

  return (
    <LocaleContext.Provider value={{ locale, localeData, setLocale, t }}>
      {loaded ? children : <div>Cargando idioma...</div>}
    </LocaleContext.Provider>
  )
}

export const useLocale = () => {
  const context = useContext(LocaleContext)
  if (!context) throw new Error("useLocale must be used within LocaleProvider")
  return context
}
