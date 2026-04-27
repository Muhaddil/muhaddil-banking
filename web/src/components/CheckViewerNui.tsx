"use client"

import React from "react"
import { useLocale } from "../hooks/useLocale"

interface CheckViewerNuiProps {
  checkData: {
    check_code?: string
    amount?: string | number
    memo?: string
    issuer_name?: string
    expires_at?: string
  } | null
  isClosing?: boolean
  onClose: () => void
}

export const CheckViewerNui: React.FC<CheckViewerNuiProps> = ({ checkData, isClosing = false, onClose }) => {
  const { t } = useLocale()
  if (!checkData) return null

  const amount = Number(checkData.amount ?? 0)
  const formattedAmount = Number.isFinite(amount) ? amount.toLocaleString("es-ES") : "0"

  return (
    <div className={`fixed inset-0 z-[120] flex items-center justify-center bg-black/70 p-4 transition-opacity duration-200 ${isClosing ? "opacity-0" : "opacity-100"}`}>
      <div className="absolute inset-0 bg-gradient-to-b from-[rgba(var(--bg-primary),0.35)] via-[rgba(var(--bg-primary),0.65)] to-[rgba(var(--bg-primary),0.95)] pointer-events-none" />
      <div className={`relative w-full max-w-3xl rounded-3xl border border-[rgba(var(--accent-primary),0.35)] bg-[rgb(var(--bg-card))]/95 p-8 text-[rgb(var(--text-primary))] shadow-2xl z-10 transition-all duration-200 ${isClosing ? "opacity-0 scale-95 translate-y-2" : "opacity-100 scale-100 translate-y-0"}`}>
        <div className="absolute inset-0 rounded-3xl border border-white/10 pointer-events-none" />
        <div className="relative z-10">
          <div className="flex items-start justify-between gap-4">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.35em] text-[rgb(var(--accent-glow))]">{t("checksStandaloneViewer.badge")}</p>
              <h2 className="mt-1 text-4xl font-black tracking-wide text-white">{t("checksStandaloneViewer.title")}</h2>
            </div>
            <button
              onClick={onClose}
              className="rounded-xl bg-white/10 px-4 py-2 text-sm font-semibold text-white hover:bg-white/20"
            >
              {t("checksStandalone.common.close")}
            </button>
          </div>

          <div className="mt-8 grid grid-cols-1 gap-6 md:grid-cols-2">
            <div className="rounded-2xl bg-black/25 border border-white/10 p-5">
              <p className="text-xs uppercase tracking-[0.2em] text-[rgb(var(--text-muted))]">{t("checksStandaloneViewer.code")}</p>
              <p className="mt-2 text-2xl font-black tracking-wide">{checkData.check_code || "N/A"}</p>
            </div>

            <div className="rounded-2xl bg-black/25 border border-white/10 p-5">
              <p className="text-xs uppercase tracking-[0.2em] text-[rgb(var(--text-muted))]">{t("checksStandaloneViewer.amount")}</p>
              <p className="mt-2 text-3xl font-black text-emerald-400">${formattedAmount}</p>
            </div>

            <div className="rounded-2xl bg-black/25 border border-white/10 p-5">
              <p className="text-xs uppercase tracking-[0.2em] text-[rgb(var(--text-muted))]">{t("checksStandaloneViewer.issuer")}</p>
              <p className="mt-2 text-lg font-bold">{checkData.issuer_name || t("checksStandaloneViewer.unknownIssuer")}</p>
            </div>

            <div className="rounded-2xl bg-black/25 border border-white/10 p-5">
              <p className="text-xs uppercase tracking-[0.2em] text-[rgb(var(--text-muted))]">{t("checksStandaloneViewer.expiresAt")}</p>
              <p className="mt-2 text-lg font-bold">{checkData.expires_at || t("checksStandaloneViewer.noDate")}</p>
            </div>
          </div>

          <div className="mt-6 rounded-2xl bg-black/25 border border-white/10 p-5">
            <p className="text-xs uppercase tracking-[0.2em] text-[rgb(var(--text-muted))]">{t("checksStandaloneViewer.memo")}</p>
            <p className="mt-2 text-base font-medium">{checkData.memo && checkData.memo.length > 0 ? checkData.memo : t("checksStandaloneViewer.noMemo")}</p>
          </div>
        </div>
      </div>
    </div>
  )
}
