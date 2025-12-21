"use client"

import { useLocale as useLocaleContext } from "../contexts/LocaleContext"

export type LocaleData = Record<string, string>

export const useLocale = () => {
  return useLocaleContext()
}
