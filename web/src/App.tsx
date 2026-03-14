"use client"

import React, { useState, useCallback, useEffect, Suspense, lazy } from "react"
import { fetchNui } from "./utils/fetchNui"
import { useNuiEvent } from "./hooks/useNuiEvent"
import toast, { Toaster } from "react-hot-toast"
import { ThemeProvider } from "./contexts/ThemeContext"
import { LocaleProvider } from "./contexts/LocaleContext"
import { QuickActions } from "./components/QuickActions"
import { useLocale } from "./hooks/useLocale"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "./components/ui/Select"

import { Sidebar } from "./components/Sidebar"
import { Dashboard } from "./components/Dashboard"
import { TransactionHistory } from "./components/TransactionHistory"
import { LoanManager } from "./components/LoanManager"
import { BankManager } from "./components/BankManager"
const StatsView = lazy(() => import("./components/StatsView"))
import { AtmInterface } from "./components/AtmInterface"
import { CardManager } from "./components/CardManager"
import { SavingsManager } from "./components/SavingsManager"
import { ContactManager } from "./components/ContactManager"
import { TransferRequests } from "./components/TransferRequests"
import { ScheduledTransfers } from "./components/ScheduledTransfers"
import { AdminPanel } from "./components/AdminPanel"

type DashboardAction =
  | "deposit"
  | "withdraw"
  | "transfer"
  | "createAccount"
  | "addSharedUser"
  | "removeSharedUser"
  | "deleteAccount"

interface Account {
  id: number
  owner: string
  account_name: string
  balance: string
  created_at: string
}

interface ATMData {
  cards?: Card[]
  accounts?: Account[]
  cash: number
}

interface Card {
  id: number
  account_id: number
  account_name: string
  card_number: string
  is_blocked: boolean | number
}

interface Transaction {
  id: number
  account_id: number
  type: string
  amount: string
  description: string
  created_at: string
}

interface Loan {
  id: number
  user_identifier: string
  amount: string
  remaining: string
  interest_rate: number
  installments: number
  status: string
  created_at: string
}

interface OwnedBank {
  id: number
  bank_id: string
  owner: string
  bank_name: string
  commission_rate: string
  total_earned: string
  pending_earnings?: string
  purchased_at: string
}

interface AvailableBank {
  id: string
  name: string
  price: number
}

interface AppData {
  accounts: Account[]
  sharedAccounts: Account[]
  transactions: Transaction[]
  loans: Loan[]
  loanPayments: Record<string, any[]>
  loanConfig: any
  creditScore: number
  ownedBanks: OwnedBank[]
  availableBanks?: AvailableBank[]
  savings: any[]
  savingsConfig: any
  contacts: any[]
  contactsConfig: any
  transferRequests: { incoming: any[]; outgoing: any[] }
  transferRequestsConfig: any
  scheduledTransfers: any[]
  scheduledTransfersConfig: any
  playerMoney: number
  maxAccounts?: number
  currentBank?: string
  currentBankId?: string
  currentBankType?: string
  currentBankCommissionRate?: number
  currentBankIsOwned?: boolean
  bankManagementEnabled?: boolean
  isAdmin?: boolean
}

interface ModalState {
  type:
  | "none"
  | "createAccount"
  | "transfer"
  | "loan"
  | "deposit"
  | "withdraw"
  | "addSharedUser"
  | "removeSharedUser"
  | "deleteAccount"
  isOpen: boolean
}

interface FormData {
  accountName: string
  transferAmount: string
  transferToAccount: string
  loanAmount: string
  loanInstallments: number
  depositAmount: string
  withdrawAmount: string
  targetId: string
}

interface ChartDataPoint {
  date: string
  income: number
  expense: number
}

interface AppContentProps {
  visible: boolean
  setVisible: (visible: boolean) => void
  data: AppData
  activeTab: string
  setActiveTab: (tab: string) => void
  selectedAccount: Account | null
  modalState: ModalState
  setModalState: (state: ModalState) => void
  formData: FormData
  setFormData: (data: FormData) => void
  submitAction: (action: string) => void
  getChartData: () => ChartDataPoint[]
  getTotalIncome: () => number
  getTotalExpense: () => number
  onSelectAccount: (id: number) => void
  isLoading: boolean
}

const LoadingOverlay: React.FC = () => {
  const { t } = useLocale()
  return (
    <div className="flex-1 flex items-center justify-center">
      <div className="flex flex-col items-center gap-5">
        <div className="relative w-20 h-20">
          <div className="absolute inset-0 rounded-full border-4 border-white/10" />
          <div className="absolute inset-0 rounded-full border-4 border-t-indigo-500 border-r-transparent border-b-transparent border-l-transparent animate-spin" />
          <div className="absolute inset-2 rounded-full border-4 border-t-transparent border-r-transparent border-b-indigo-300/50 border-l-transparent animate-spin [animation-direction:reverse] [animation-duration:600ms]" />
        </div>
        <div className="flex flex-col items-center gap-1">
          <p className="text-white font-semibold text-lg tracking-wide animate-pulse">
            {t("dashboard.loading_bank")}
          </p>
          <p className="text-white/40 text-sm">{t("dashboard.loading_bank_subtitle")}</p>
        </div>
      </div>
    </div>
  )
}

const AppContent: React.FC<AppContentProps> = ({
  visible,
  setVisible,
  data,
  activeTab,
  setActiveTab,
  selectedAccount,
  modalState,
  setModalState,
  formData,
  setFormData,
  submitAction,
  getChartData,
  getTotalIncome,
  getTotalExpense,
  onSelectAccount,
  isLoading,
}) => {
  const { t } = useLocale()
  const cashAvailable = data.playerMoney ?? 0

  useEffect(() => {
    if (activeTab === "banks" && !data.bankManagementEnabled) {
      setActiveTab("accounts")
    }
  }, [activeTab, data.bankManagementEnabled])

  const handleClose = useCallback(() => {
    setVisible(false)
    fetchNui("close")
  }, [])

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape" && visible) {
        handleClose()
      }
    }
    window.addEventListener("keydown", handleEscape)
    return () => window.removeEventListener("keydown", handleEscape)
  }, [visible, handleClose])

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/60 backdrop-blur-md p-4 md:p-8 animate-in">
      <Toaster
        position="top-right"
        toastOptions={{
          style: {
            background: "rgb(var(--bg-card))",
            color: "rgb(var(--text-primary))",
            border: "1px solid rgba(255,255,255,0.1)",
          },
        }}
      />

      <div className="w-full max-w-7xl h-[90vh] flex rounded-3xl overflow-hidden shadow-2xl relative animate-scale-in">
        <div className="absolute inset-0 bg-[rgb(var(--bg-primary))] z-0 transition-colors duration-300">
          <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-[rgba(var(--accent-primary),0.2)] via-[rgba(var(--accent-secondary),0.15)] to-transparent pointer-events-none" />
          <div className="absolute bottom-0 right-0 w-96 h-96 bg-[rgba(var(--accent-glow),0.1)] rounded-full blur-3xl" />
        </div>

        <div className="relative z-10 flex w-full h-full">
          <Sidebar
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            onClose={handleClose}
            currentBank={data.currentBank}
            currentBankType={data.currentBankType}
            bankManagementEnabled={data.bankManagementEnabled}
            isAdmin={data.isAdmin}
          />

          <main className="flex-1 p-4 md:p-8 overflow-y-auto custom-scrollbar flex flex-col">
            {isLoading ? (
              <LoadingOverlay />
            ) : (
              <>
                {activeTab === "accounts" && selectedAccount && (
                  <div className="mb-6 animate-slide-down">
                    <QuickActions
                      onAction={(action: "deposit" | "withdraw" | "transfer" | "createAccount") =>
                        setModalState({ type: action, isOpen: true })
                      }
                      playerMoney={data.playerMoney}
                    />
                  </div>
                )}

                {activeTab === "accounts" && (
                  <Dashboard
                    selectedAccount={selectedAccount}
                    accounts={data.accounts}
                    sharedAccounts={data.sharedAccounts}
                    onSelectAccount={onSelectAccount}
                    onAction={(action: DashboardAction) =>
                      setModalState({ type: action, isOpen: true })
                    }
                    maxAccounts={data.maxAccounts}
                    currentBank={data.currentBank}
                    currentBankType={data.currentBankType}
                    currentBankCommissionRate={data.currentBankCommissionRate}
                    playerMoney={data.playerMoney}
                  />
                )}

                {activeTab === "transactions" && (
                  <TransactionHistory
                    transactions={
                      selectedAccount ? data.transactions.filter((t) => t.account_id === selectedAccount.id) : []
                    }
                  />
                )}

                {activeTab === "loans" && (
                  <LoanManager
                    loans={data.loans}
                    onRequestLoan={() => setModalState({ type: "loan", isOpen: true })}
                    onPayLoan={(loanId, amount) => fetchNui("payLoan", { loanId, amount })}
                  />
                )}

                {activeTab === "stats" && (
                  <Suspense fallback={<div className="text-white">Loading stats...</div>}>
                    {selectedAccount ? (
                      <StatsView
                        data={getChartData()}
                        totalIncome={getTotalIncome()}
                        totalExpense={getTotalExpense()}
                        currentBalance={parseFloat(selectedAccount?.balance ?? "0")}
                      />
                    ) : (
                      <StatsView
                        data={[]}
                        totalIncome={0}
                        totalExpense={0}
                        currentBalance={0}
                      />
                    )}
                  </Suspense>
                )}

                {activeTab === "cards" && <CardManager accounts={data.accounts} />}

                {activeTab === "banks" && <BankManager ownedBanks={data.ownedBanks} availableBanks={data.availableBanks} />}

                {activeTab === "savings" && (
                  <SavingsManager
                    savings={data.savings}
                    accounts={data.accounts}
                    config={data.savingsConfig}
                    onCreateSavings={(d) => fetchNui("createSavings", d)}
                    onDepositSavings={(d) => fetchNui("depositSavings", d)}
                    onWithdrawSavings={(d) => fetchNui("withdrawSavings", d)}
                    onDeleteSavings={(id) => fetchNui("deleteSavings", { savingsId: id })}
                  />
                )}

                {activeTab === "contacts" && (
                  <ContactManager
                    contacts={data.contacts}
                    config={data.contactsConfig}
                    onAddContact={(d) => fetchNui("addContact", d)}
                    onUpdateContact={(d) => fetchNui("updateContact", d)}
                    onRemoveContact={(id) => fetchNui("removeContact", { contactId: id })}
                  />
                )}

                {activeTab === "requests" && (
                  <TransferRequests
                    incoming={data.transferRequests.incoming}
                    outgoing={data.transferRequests.outgoing}
                    accounts={data.accounts}
                    config={data.transferRequestsConfig}
                    onCreateRequest={(d) => fetchNui("createTransferRequest", d)}
                    onAcceptRequest={(d) => fetchNui("acceptTransferRequest", d)}
                    onRejectRequest={(id) => fetchNui("rejectTransferRequest", { requestId: id })}
                    onCancelRequest={(id) => fetchNui("cancelTransferRequest", { requestId: id })}
                  />
                )}

                {activeTab === "scheduled" && (
                  <ScheduledTransfers
                    transfers={data.scheduledTransfers}
                    accounts={data.accounts}
                    config={data.scheduledTransfersConfig}
                    onCreateTransfer={(d) => fetchNui("createScheduledTransfer", d)}
                    onUpdateTransfer={(d) => fetchNui("updateScheduledTransfer", d)}
                    onToggleTransfer={(id) => fetchNui("toggleScheduledTransfer", { transferId: id })}
                    onDeleteTransfer={(id) => fetchNui("deleteScheduledTransfer", { transferId: id })}
                  />
                )}

                {activeTab === "admin" && (
                  <AdminPanel onClose={() => setActiveTab("accounts")} />
                )}
              </>
            )}
          </main>
        </div>
      </div>

      {modalState.isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-md animate-in">
          <div className="bg-[rgb(var(--bg-card))] p-6 md:p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl animate-scale-in mx-4">
            <h3 className="text-xl font-bold text-white mb-6">
              {modalState.type === "deposit" && t("modals.deposit.title")}
              {modalState.type === "withdraw" && t("modals.withdraw.title")}
              {modalState.type === "transfer" && t("modals.transfer.title")}
              {modalState.type === "createAccount" && t("modals.createAccount.title")}
              {modalState.type === "loan" && t("modals.loan.title")}
              {modalState.type === "addSharedUser" && t("modals.addSharedUser.title")}
              {modalState.type === "removeSharedUser" && t("modals.removeSharedUser.title")}
              {modalState.type === "deleteAccount" && t("modals.deleteAccount.title")}
            </h3>

            <div className="space-y-4">
              {modalState.type === "createAccount" && (
                <input
                  type="text"
                  placeholder={t("modals.createAccount.placeholder")}
                  value={formData.accountName}
                  onChange={(e) => setFormData({ ...formData, accountName: e.target.value })}
                  className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                />
              )}

              {(modalState.type === "deposit" ||
                modalState.type === "withdraw" ||
                modalState.type === "transfer" ||
                modalState.type === "loan") && (
                  <>
                    {modalState.type === "deposit" && (
                      <p className="text-sm text-white/70 mb-2">
                        {t("quickActions.cashAvailable")}: ${cashAvailable.toLocaleString()}
                      </p>
                    )}

                    <input
                      type="number"
                      placeholder={t("modals.common.amount")}
                      value={
                        modalState.type === "deposit"
                          ? formData.depositAmount
                          : modalState.type === "withdraw"
                            ? formData.withdrawAmount
                            : modalState.type === "transfer"
                              ? formData.transferAmount
                              : formData.loanAmount
                      }
                      onChange={(e) => {
                        const val = e.target.value
                        if (modalState.type === "deposit") setFormData({ ...formData, depositAmount: val })
                        else if (modalState.type === "withdraw") setFormData({ ...formData, withdrawAmount: val })
                        else if (modalState.type === "transfer") setFormData({ ...formData, transferAmount: val })
                        else setFormData({ ...formData, loanAmount: val })
                      }}
                      className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                    />
                  </>
                )}

              {modalState.type === "transfer" && (
                <div className="space-y-3">
                  {data.contacts && data.contacts.length > 0 && (
                    <div className="relative">
                      <Select
                        onValueChange={(value: string) => {
                          if (value) setFormData({ ...formData, transferToAccount: value })
                        }}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder={t("contacts.select", "O selecciona un contacto...")} />
                        </SelectTrigger>
                        <SelectContent>
                          {data.contacts.map((contact) => (
                            <SelectItem key={contact.id} value={String(contact.contact_account_id)}>
                              {contact.contact_name} - #{contact.contact_account_id}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                      <div className="absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-white/50">
                        ▼
                      </div>
                    </div>
                  )}

                  <input
                    type="number"
                    placeholder={t("modals.transfer.toAccount")}
                    value={formData.transferToAccount}
                    onChange={(e) => setFormData({ ...formData, transferToAccount: e.target.value })}
                    className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                  />
                </div>
              )}

              {(modalState.type === "addSharedUser" || modalState.type === "removeSharedUser") && (
                <input
                  type="number"
                  placeholder={t("modals.common.userId")}
                  value={formData.targetId}
                  onChange={(e) => setFormData({ ...formData, targetId: e.target.value })}
                  className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                />
              )}

              {modalState.type === "deleteAccount" && (
                <p className="text-red-400">{t("modals.deleteAccount.confirm")}</p>
              )}

              {modalState.type === "loan" && (
                <div>
                  <label className="text-sm text-gray-400 mb-2 block">
                    {t("modals.loan.installments")}: {formData.loanInstallments}
                  </label>
                  <input
                    type="range"
                    min="1"
                    max="24"
                    value={formData.loanInstallments}
                    onChange={(e) => setFormData({ ...formData, loanInstallments: parseInt(e.target.value) })}
                    className="w-full"
                  />
                </div>
              )}

              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setModalState({ type: "none", isOpen: false })}
                  className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-all duration-200 hover:scale-105"
                >
                  {t("common.cancel")}
                </button>
                <button
                  onClick={() => submitAction(modalState.type)}
                  className={`flex-1 py-3 rounded-xl text-white transition-all duration-200 font-medium hover:scale-105 ${modalState.type === "deleteAccount"
                    ? "bg-gradient-to-r from-red-600 to-red-700 hover:from-red-700 hover:to-red-800 shadow-lg shadow-red-500/30"
                    : "bg-gradient-to-r from-indigo-600 to-indigo-700 hover:from-indigo-700 hover:to-indigo-800 shadow-lg shadow-indigo-500/30"
                    }`}
                >
                  {modalState.type === "deleteAccount" ? t("common.delete") : t("common.confirm")}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

const App = () => {
  const [visible, setVisible] = useState(false)
  const [isLoading, setIsLoading] = useState(true)
  const [data, setData] = useState<AppData>({
    accounts: [],
    sharedAccounts: [],
    transactions: [],
    loans: [],
    loanPayments: {},
    loanConfig: {},
    creditScore: 500,
    ownedBanks: [],
    availableBanks: [],
    savings: [],
    savingsConfig: { enabled: false, maxPerAccount: 3, interestRate: 0.02, minDeposit: 100, maxGoalAmount: 1000000 },
    contacts: [],
    contactsConfig: { enabled: false, maxContacts: 20 },
    transferRequests: { incoming: [], outgoing: [] },
    transferRequestsConfig: { enabled: false, maxPending: 10 },
    scheduledTransfers: [],
    scheduledTransfersConfig: { enabled: false, maxPerPlayer: 10, minAmount: 50, frequencies: ['daily', 'weekly', 'biweekly', 'monthly'] },
    playerMoney: 0,
    maxAccounts: undefined,
  })
  const [activeTab, setActiveTab] = useState("accounts")
  const [selectedAccountId, setSelectedAccountId] = useState<number | null>(null)

  const selectedAccount =
    selectedAccountId !== null
      ? [...data.accounts, ...data.sharedAccounts].find((acc) => acc.id === selectedAccountId) ?? null
      : null

  const [modalState, setModalState] = useState<ModalState>({ type: "none", isOpen: false })

  const [formData, setFormData] = useState<FormData>({
    accountName: "",
    transferAmount: "",
    transferToAccount: "",
    loanAmount: "",
    loanInstallments: 6,
    depositAmount: "",
    withdrawAmount: "",
    targetId: "",
  })

  useNuiEvent("setVisible", (event: boolean) => {
    if (event) {
      setIsLoading(true)
      setTimeout(() => setIsLoading(false), 3000)
    }
    setVisible(event)
  })

  useNuiEvent("setData", (event: any) => {
    const payload = event.data || {}
    const allAccounts: Account[] = (payload.accounts || []) as Account[]
    const ownedAccounts = allAccounts.filter((acc: any) => acc.isOwner === true)
    const sharedAccountsList = allAccounts.filter((acc: any) => acc.isOwner === false)

    const incomingCurrentBank = event.currentBank ?? payload.currentBank
    const incomingCurrentBankId = event.currentBankId ?? payload.currentBankId

    setData((prev) => ({
      accounts: ownedAccounts,
      sharedAccounts: sharedAccountsList,
      transactions: payload.transactions || [],
      loans: payload.loans || [],
      loanPayments: payload.loanPayments || {},
      loanConfig: payload.loanConfig || {},
      creditScore: payload.creditScore ?? prev.creditScore,
      ownedBanks: payload.ownedBanks || [],
      availableBanks: payload.availableBanks || [],
      savings: payload.savings || [],
      savingsConfig: payload.savingsConfig || prev.savingsConfig,
      contacts: payload.contacts || [],
      contactsConfig: payload.contactsConfig || prev.contactsConfig,
      transferRequests: payload.transferRequests || prev.transferRequests,
      transferRequestsConfig: payload.transferRequestsConfig || prev.transferRequestsConfig,
      scheduledTransfers: payload.scheduledTransfers || [],
      scheduledTransfersConfig: payload.scheduledTransfersConfig || prev.scheduledTransfersConfig,
      playerMoney: payload.cash ?? 0,
      maxAccounts: payload.maxAccounts,
      currentBank: incomingCurrentBank ?? prev.currentBank,
      currentBankId: incomingCurrentBankId ?? prev.currentBankId,
      currentBankType: event.currentBankType ?? payload.currentBankType ?? prev.currentBankType,
      currentBankCommissionRate: event.commissionRate ?? payload.comissionRate ?? prev.currentBankCommissionRate,
      bankManagementEnabled: event.bankManagementEnabled ?? payload.bankManagementEnabled ?? prev.bankManagementEnabled,
    }))

    setSelectedAccountId((currentId) => {
      if (allAccounts.length === 0) return null

      if (currentId === null) return allAccounts[0].id

      if (!allAccounts.some(acc => acc.id === currentId)) {
        return allAccounts[0].id
      }

      return currentId
    })

    setIsLoading(false)
  })

  useNuiEvent<{ type: string; message: string }>("notify", (event) => {
    if (event.type === "success") {
      toast.success(event.message)
    } else if (event.type === "error") {
      toast.error(event.message)
    } else {
      toast(event.message)
    }
  })

  const submitAction = (action: string) => {
    if (action === "createAccount") {
      if (!formData.accountName.trim()) return toast.error("Nombre requerido")
      fetchNui("createAccount", { accountName: formData.accountName })
    } else if (action === "deposit") {
      if (!selectedAccount || !formData.depositAmount) return toast.error("Monto inválido")
      fetchNui("deposit", {
        accountId: selectedAccount.id,
        amount: parseFloat(formData.depositAmount),
      })
    } else if (action === "withdraw") {
      if (!selectedAccount || !formData.withdrawAmount) return toast.error("Monto inválido")
      fetchNui("withdraw", {
        accountId: selectedAccount.id,
        amount: parseFloat(formData.withdrawAmount),
      })
    } else if (action === "transfer") {
      if (!selectedAccount || !formData.transferAmount || !formData.transferToAccount)
        return toast.error("Datos incompletos")
      fetchNui("transfer", {
        fromAccountId: selectedAccount.id,
        toAccountId: parseInt(formData.transferToAccount),
        amount: parseFloat(formData.transferAmount),
      })
    } else if (action === "loan") {
      if (!formData.loanAmount) return toast.error("Monto inválido")
      fetchNui("requestLoan", {
        amount: parseFloat(formData.loanAmount),
        installments: parseInt(formData.loanInstallments.toString()),
      })
    } else if (action === "addSharedUser") {
      if (!selectedAccount || !formData.targetId) return toast.error("ID de usuario requerido")
      fetchNui("addSharedUser", { accountId: selectedAccount.id, targetId: parseInt(formData.targetId) })
    } else if (action === "removeSharedUser") {
      if (!selectedAccount || !formData.targetId) return toast.error("ID de usuario requerido")
      fetchNui("removeSharedUser", { accountId: selectedAccount.id, targetId: parseInt(formData.targetId) })
    } else if (action === "deleteAccount") {
      if (!selectedAccount) return toast.error("Cuenta no seleccionada")
      fetchNui("deleteAccount", { accountId: selectedAccount.id })
    }

    setFormData({
      accountName: "",
      transferAmount: "",
      transferToAccount: "",
      loanAmount: "",
      loanInstallments: 6,
      depositAmount: "",
      withdrawAmount: "",
      targetId: "",
    })
    setModalState({ type: "none", isOpen: false })
  }

  const getChartData = (): ChartDataPoint[] => {
    if (!selectedAccount) return []
    const accountTransactions = data.transactions.filter((t) => t.account_id === selectedAccount.id)
    const groupedByDate: Record<string, ChartDataPoint> = {}

    accountTransactions.forEach((transaction) => {
      const date = new Date(transaction.created_at).toLocaleDateString()
      if (!groupedByDate[date]) {
        groupedByDate[date] = { date, income: 0, expense: 0 }
      }

      const parsedAmount = parseFloat(transaction.amount)
      const amount = Math.abs(parsedAmount)

      if (transaction.type === "deposit") {
        groupedByDate[date].income += amount
      } else {
        groupedByDate[date].expense += amount
      }
    })

    return Object.values(groupedByDate).slice(-7) as ChartDataPoint[]
  }

  const getTotalIncome = (): number => {
    if (!selectedAccount) return 0
    return data.transactions
      .filter((t) => t.account_id === selectedAccount.id && parseFloat(t.amount) > 0)
      .reduce((sum, t) => sum + parseFloat(t.amount), 0)
  }

  const getTotalExpense = (): number => {
    if (!selectedAccount) return 0
    return data.transactions
      .filter((t) => t.account_id === selectedAccount.id && parseFloat(t.amount) < 0)
      .reduce((sum, t) => sum + Math.abs(parseFloat(t.amount)), 0)
  }

  useNuiEvent("openAdminPanel", () => {
    setActiveTab("admin")
    setData((prev) => ({ ...prev, isAdmin: true }))
  })

  if (!visible) return null

  return (
    <LocaleProvider>
      <ThemeProvider>
        <AppContent
          visible={visible}
          setVisible={setVisible}
          data={data}
          activeTab={activeTab}
          setActiveTab={setActiveTab}
          selectedAccount={selectedAccount}
          modalState={modalState}
          setModalState={setModalState}
          formData={formData}
          setFormData={setFormData}
          submitAction={submitAction}
          getChartData={getChartData}
          getTotalIncome={getTotalIncome}
          getTotalExpense={getTotalExpense}
          onSelectAccount={(id) => setSelectedAccountId(id)}
          isLoading={isLoading}
        />
      </ThemeProvider>
    </LocaleProvider>
  )
}

const AppWithATM = () => {
  const [atmVisible, setAtmVisible] = useState(false)
  const [atmData, setAtmData] = useState<ATMData | null>(null)
  const [atmRequirePin, setAtmRequirePin] = useState(false)

  useNuiEvent("openATM", (event: any) => {
    setAtmData({
      cards: event.data.cards || [],
      accounts: event.data.accounts || [],
      cash: event.data.cash ?? 0,
    })
    setAtmRequirePin(event.requirePin ?? false)
    setAtmVisible(true)
  })

  useNuiEvent("closeATM", () => {
    setAtmVisible(false)
    setAtmData(null)
  })

  useNuiEvent("updateATMData", (event: any) => {
    if (atmVisible) {
      setAtmData({
        cards: event.data.cards || [],
        cash: event.data.cash ?? 0,
      })
    }
  })

  const handleATMClose = useCallback(() => {
    setAtmVisible(false)
    setAtmData(null)
    fetchNui("closeATM")
  }, [])

  const handleATMVerifyPin = async (pin: string, cardId: number, accountId: number): Promise<{ success: boolean; error?: string; accountData?: any }> => {
    return await fetchNui("atmVerifyPin", { pin, cardId, accountId })
  }

  const handleATMDeposit = (accountId: number, amount: number) => {
    fetchNui("atmDeposit", { accountId, amount })
  }

  const handleATMWithdraw = (accountId: number, amount: number) => {
    fetchNui("atmWithdraw", { accountId, amount })
  }

  const handleATMTransfer = (fromId: number, toId: number, amount: number) => {
    fetchNui("atmTransfer", { fromAccountId: fromId, toAccountId: toId, amount })
  }

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === "Escape" && atmVisible) {
        handleATMClose()
      }
    }
    window.addEventListener("keydown", handleEscape)
    return () => window.removeEventListener("keydown", handleEscape)
  }, [atmVisible, handleATMClose])

  return (
    <LocaleProvider>
      <ThemeProvider>
        {!atmVisible ? (
          <App />
        ) : (
          <AtmInterface
            data={{
              cards: atmData?.cards || [],
              accounts: atmData?.accounts || [],
              cash: atmData?.cash || 0,
            }}
            requirePin={atmRequirePin}
            onClose={handleATMClose}
            onDeposit={handleATMDeposit}
            onWithdraw={handleATMWithdraw}
            onTransfer={handleATMTransfer}
            onVerifyPin={handleATMVerifyPin}
          />
        )}
      </ThemeProvider>
    </LocaleProvider>
  )
}

export default AppWithATM