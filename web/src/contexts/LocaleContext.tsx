"use client"

import type React from "react"
import { createContext, useContext, useState, useCallback, useEffect } from "react"
import { useNuiEvent } from "../hooks/useNuiEvent"

export type LocaleData = Record<string, string>

interface LocaleContextType {
  locale: string
  localeData: LocaleData
  setLocale: (locale: string) => void
  t: (key: string, ...args: any[]) => string
}

const LocaleContext = createContext<LocaleContextType | undefined>(undefined)

export const LocaleProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [locale, setLocaleState] = useState("es")
  const [localeData, setLocaleData] = useState<LocaleData>({})
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    const loadLocale = async (localeName: string) => {
      try {
        const resourceName = (window as any).GetParentResourceName 
          ? (window as any).GetParentResourceName() 
          : 'muhaddil-banking'
        
        const response = await fetch(`https://cfx-nui-${resourceName}/locales/${localeName}.json`)
        
        if (response.ok) {
          const data = await response.json()
          setLocaleData(data)
          setLoaded(true)
        } else {
          console.error(`[Giveaways] Error al cargar locale ${localeName}: ${response.status}`)
          setLocaleData({})
          setLoaded(true)
        }
      } catch (error) {
        console.error(`[Giveaways] Error al cargar locale ${localeName}:`, error)
        setLocaleData({})
        setLoaded(true)
      }
    }

    loadLocale(locale)
  }, [locale])

  useNuiEvent<{ locale: string }>("setLocale", (data) => {
    if (data.locale) {
      setLocaleState(data.locale)
    }
  })

  const setLocale = useCallback((newLocale: string) => {
    setLocaleState(newLocale)
  }, [])

  const t = useCallback(
    (key: string, ...args: any[]): string => {
      let text = localeData[key] || key

      if (args.length > 0) {
        args.forEach((arg) => {
          text = text.replace("%s", String(arg))
        })
      }

      return text
    },
    [localeData],
  )

  return (
    <LocaleContext.Provider value={{ locale, localeData, setLocale, t }}>
      {loaded && children}
    </LocaleContext.Provider>
  )
}

export const useLocale = () => {
  const context = useContext(LocaleContext)
  if (!context) {
    throw new Error("useLocale must be used within LocaleProvider")
  }
  return context
}