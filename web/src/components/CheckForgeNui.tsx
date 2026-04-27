"use client"

import React, { useMemo, useState, useEffect } from "react"
import toast from "react-hot-toast"
import { fetchNui } from "../utils/fetchNui"
import { useLocale } from "../hooks/useLocale"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "./ui/Select"

interface CheckForgeNuiProps {
  visible: boolean
  isClosing?: boolean
  onClose: () => void
}

type PickerDate = { year: number; month: number; day: number } | null

export const CheckForgeNui: React.FC<CheckForgeNuiProps> = ({ visible, isClosing = false, onClose }) => {
  const { t } = useLocale()

  const getDefaultDate = () => {
    const d = new Date()
    d.setDate(d.getDate() + 7)
    return { year: d.getFullYear(), month: d.getMonth() + 1, day: d.getDate() }
  }

  const defaultDate = getDefaultDate()
  const defaultDateStr = `${defaultDate.year}-${String(defaultDate.month).padStart(2, "0")}-${String(defaultDate.day).padStart(2, "0")} 12:00:00`

  const [forgeData, setForgeData] = useState({
    checkCode: "",
    amount: "",
    issuerName: "",
    memo: "",
    expiresAt: defaultDateStr,
  })
  const [pickerOpen, setPickerOpen] = useState(false)

  const [entered, setEntered] = useState(false)
  useEffect(() => {
    if (visible) {
      const raf = requestAnimationFrame(() => setEntered(true))
      return () => cancelAnimationFrame(raf)
    } else {
      setEntered(false)
    }
  }, [visible])

  const now = new Date()
  const defaultMonth = new Date(defaultDate.year, defaultDate.month - 1, 1)
  const [currentMonth, setCurrentMonth] = useState(defaultMonth)
  const [pickedDate, setPickedDate] = useState<PickerDate>(defaultDate)
  const [pickedHour, setPickedHour] = useState<string>("12")
  const [pickedMinute, setPickedMinute] = useState<string>("00")

  const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate())

  const isPastDate = (year: number, month: number, day: number) =>
    new Date(year, month - 1, day) < todayMidnight

  const canSubmit = useMemo(() =>
    forgeData.checkCode.trim().length > 0 &&
    forgeData.amount.trim().length > 0 &&
    forgeData.issuerName.trim().length > 0,
    [forgeData]
  )

  if (!visible) return null

  const monthNames = [
    t("checksStandaloneForge.months.0"), t("checksStandaloneForge.months.1"), t("checksStandaloneForge.months.2"), t("checksStandaloneForge.months.3"),
    t("checksStandaloneForge.months.4"), t("checksStandaloneForge.months.5"), t("checksStandaloneForge.months.6"), t("checksStandaloneForge.months.7"),
    t("checksStandaloneForge.months.8"), t("checksStandaloneForge.months.9"), t("checksStandaloneForge.months.10"), t("checksStandaloneForge.months.11"),
  ]

  const weekdayNames = [
    t("checksStandaloneForge.weekdays.0"), t("checksStandaloneForge.weekdays.1"), t("checksStandaloneForge.weekdays.2"), t("checksStandaloneForge.weekdays.3"),
    t("checksStandaloneForge.weekdays.4"), t("checksStandaloneForge.weekdays.5"), t("checksStandaloneForge.weekdays.6"),
  ]

  const daysInMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0).getDate()
  const firstWeekday = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1).getDay()

  const applyPickedDate = (picked: PickerDate, hour: string, minute: string) => {
    if (!picked) {
      setForgeData((prev) => ({ ...prev, expiresAt: "" }))
      return
    }
    const expiresAt = `${picked.year}-${String(picked.month).padStart(2, "0")}-${String(picked.day).padStart(2, "0")} ${hour}:${minute}:00`
    setForgeData((prev) => ({ ...prev, expiresAt }))
  }

  const selectDay = (day: number) => {
    const year = currentMonth.getFullYear()
    const month = currentMonth.getMonth() + 1
    if (isPastDate(year, month, day)) return
    const picked = { year, month, day }
    setPickedDate(picked)
    applyPickedDate(picked, pickedHour, pickedMinute)
  }

  const clearDate = () => {
    setPickedDate(null)
    setPickedHour("12")
    setPickedMinute("00")
    setForgeData((prev) => ({ ...prev, expiresAt: "" }))
  }

  const moveMonth = (delta: number) => {
    const next = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + delta, 1)
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1)
    if (next < thisMonth) return
    setCurrentMonth(next)
  }

  const dateDisplay = pickedDate
    ? `${String(pickedDate.day).padStart(2, "0")}/${String(pickedDate.month).padStart(2, "0")}/${pickedDate.year} ${pickedHour}:${pickedMinute}`
    : t("checksStandaloneForge.datePlaceholder")

  const submit = () => {
    if (!canSubmit) {
      toast.error(t("checksStandaloneForge.validationRequired"))
      return
    }
    fetchNui("forgeCheck", {
      checkCode: forgeData.checkCode.toUpperCase(),
      amount: parseFloat(forgeData.amount),
      issuerName: forgeData.issuerName,
      memo: forgeData.memo,
      expiresAt: forgeData.expiresAt || undefined,
    })
    onClose()
  }

  const isPrevMonthDisabled = (() => {
    const thisMonth = new Date(now.getFullYear(), now.getMonth(), 1)
    const prevMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1, 1)
    return prevMonth < thisMonth
  })()

  const animCard = isClosing
    ? "opacity-0 scale-95 translate-y-2"
    : entered
      ? "opacity-100 scale-100 translate-y-0"
      : "opacity-0 scale-95 translate-y-4"

  const animBackdrop = isClosing ? "opacity-0" : entered ? "opacity-100" : "opacity-0"

  return (
    <div className={`fixed inset-0 z-[120] flex items-center justify-center bg-black/80 p-4 transition-opacity duration-200 ${animBackdrop}`}>
      <div className="absolute inset-0 bg-gradient-to-b from-[rgba(var(--bg-primary),0.2)] via-[rgba(var(--bg-primary),0.7)] to-[rgba(var(--bg-primary),0.95)] pointer-events-none" />

      <div className={`w-full max-w-2xl rounded-3xl border border-[rgba(var(--accent-primary),0.35)] bg-[rgb(var(--bg-card))] p-8 shadow-2xl relative z-10 transition-all duration-300 ease-out ${animCard}`}>

        <div className="mb-6 flex items-center justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.3em] text-rose-300">{t("checksStandaloneForge.badge")}</p>
            <h2 className="text-3xl font-black text-white">{t("checksStandaloneForge.title")}</h2>
          </div>
          <button onClick={onClose} className="rounded-xl bg-white/10 px-4 py-2 text-sm text-white hover:bg-white/20">
            {t("checksStandalone.common.close")}
          </button>
        </div>

        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <input
            type="text"
            placeholder={t("checksStandaloneForge.cloneCodePlaceholder")}
            value={forgeData.checkCode}
            onChange={(e) => setForgeData({ ...forgeData, checkCode: e.target.value.toUpperCase() })}
            className="rounded-xl border border-white/10 bg-black/20 p-3 text-white outline-none focus:border-rose-500"
          />
          <input
            type="number"
            placeholder={t("checksStandaloneForge.amountPlaceholder")}
            value={forgeData.amount}
            onChange={(e) => setForgeData({ ...forgeData, amount: e.target.value })}
            className="rounded-xl border border-white/10 bg-black/20 p-3 text-white outline-none focus:border-rose-500"
          />
          <input
            type="text"
            placeholder={t("checksStandaloneForge.issuerPlaceholder")}
            value={forgeData.issuerName}
            onChange={(e) => setForgeData({ ...forgeData, issuerName: e.target.value })}
            className="rounded-xl border border-white/10 bg-black/20 p-3 text-white outline-none focus:border-rose-500"
          />
          <button
            type="button"
            onClick={() => setPickerOpen((v) => !v)}
            className="rounded-xl border border-white/10 bg-black/20 p-3 text-left text-white outline-none hover:border-rose-400"
          >
            {dateDisplay}
          </button>
        </div>

        {pickerOpen && (
          <div className="mt-4 rounded-2xl border border-white/10 bg-black/35 p-4">
            <div className="mb-3 flex items-center justify-between">
              <button
                type="button"
                onClick={() => moveMonth(-1)}
                disabled={isPrevMonthDisabled}
                className="rounded-lg bg-white/10 px-3 py-1 text-white hover:bg-white/20 disabled:opacity-30 disabled:cursor-not-allowed"
              >
                {"<"}
              </button>
              <p className="font-semibold text-white">{monthNames[currentMonth.getMonth()]} {currentMonth.getFullYear()}</p>
              <button type="button" onClick={() => moveMonth(1)} className="rounded-lg bg-white/10 px-3 py-1 text-white hover:bg-white/20">{">"}</button>
            </div>

            <div className="mb-2 grid grid-cols-7 gap-1">
              {weekdayNames.map((day) => (
                <div key={day} className="text-center text-xs text-[rgb(var(--text-muted))]">{day}</div>
              ))}
            </div>

            <div className="grid grid-cols-7 gap-1">
              {Array.from({ length: firstWeekday }).map((_, idx) => (
                <div key={`empty-${idx}`} />
              ))}
              {Array.from({ length: daysInMonth }).map((_, idx) => {
                const day = idx + 1
                const year = currentMonth.getFullYear()
                const month = currentMonth.getMonth() + 1
                const past = isPastDate(year, month, day)
                const selected =
                  pickedDate &&
                  pickedDate.year === year &&
                  pickedDate.month === month &&
                  pickedDate.day === day
                return (
                  <button
                    type="button"
                    key={`day-${day}`}
                    onClick={() => selectDay(day)}
                    disabled={past}
                    className={`rounded-lg py-2 text-sm transition-colors ${past
                        ? "text-white/20 cursor-not-allowed bg-transparent"
                        : selected
                          ? "bg-rose-600 text-white"
                          : "bg-white/5 text-white hover:bg-white/15"
                      }`}
                  >
                    {day}
                  </button>
                )
              })}
            </div>

            <div className="mt-4 grid grid-cols-2 gap-3">
              <Select
                value={pickedHour}
                onValueChange={(next) => {
                  setPickedHour(next)
                  applyPickedDate(pickedDate, next, pickedMinute)
                }}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t("checksStandaloneForge.hour")} />
                </SelectTrigger>
                <SelectContent className="z-[200]">
                  {Array.from({ length: 24 }, (_, h) => {
                    const value = String(h).padStart(2, "0")
                    return (
                      <SelectItem key={value} value={value}>
                        {t("checksStandaloneForge.hour")} {value}
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>

              <Select
                value={pickedMinute}
                onValueChange={(next) => {
                  setPickedMinute(next)
                  applyPickedDate(pickedDate, pickedHour, next)
                }}
              >
                <SelectTrigger>
                  <SelectValue placeholder={t("checksStandaloneForge.minute")} />
                </SelectTrigger>
                <SelectContent className="z-[200]">
                  {Array.from({ length: 12 }, (_, i) => {
                    const value = String(i * 5).padStart(2, "0")
                    return (
                      <SelectItem key={value} value={value}>
                        {t("checksStandaloneForge.minute")} {value}
                      </SelectItem>
                    )
                  })}
                </SelectContent>
              </Select>
            </div>

            <div className="mt-3 flex justify-end">
              <button
                type="button"
                onClick={clearDate}
                className="rounded-lg bg-white/5 px-4 py-1.5 text-sm text-white/60 hover:bg-white/10 hover:text-white transition-colors"
              >
                {t("checksStandaloneForge.clearDate") ?? "Limpiar fecha"}
              </button>
            </div>
          </div>
        )}

        <textarea
          placeholder={t("checksStandaloneForge.memoPlaceholder")}
          value={forgeData.memo}
          onChange={(e) => setForgeData({ ...forgeData, memo: e.target.value })}
          className="mt-4 min-h-[90px] w-full rounded-xl border border-white/10 bg-black/20 p-3 text-white outline-none focus:border-rose-500"
        />

        <button
          onClick={submit}
          className="mt-6 w-full rounded-xl bg-gradient-to-r from-rose-600 to-red-700 py-3 font-semibold text-white transition hover:brightness-110"
        >
          {t("checksStandaloneForge.confirm")}
        </button>
      </div>
    </div>
  )
}