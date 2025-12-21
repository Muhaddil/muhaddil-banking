import { useState, useEffect, useCallback } from 'react';
import { fetchNui } from "./utils/fetchNui";
import { useNuiEvent } from "./hooks/useNuiEvent";
import { Toaster } from "react-hot-toast";
import toast from "react-hot-toast";

import { Sidebar } from './components/Sidebar';
import { Dashboard } from './components/Dashboard';
import { TransactionHistory } from './components/TransactionHistory';
import { LoanManager } from './components/LoanManager';
import { BankManager } from './components/BankManager';
import { StatsView } from './components/StatsView';

interface Account {
  id: number;
  owner: string;
  account_name: string;
  balance: string;
  created_at: string;
}

interface Transaction {
  id: number;
  account_id: number;
  type: string;
  amount: string;
  description: string;
  created_at: string;
}

interface Loan {
  id: number;
  user_identifier: string;
  amount: string;
  remaining: string;
  interest_rate: number;
  installments: number;
  status: string;
  created_at: string;
}

interface OwnedBank {
  id: number;
  owner: string;
  bank_name: string;
  commission_rate: string;
  total_earned: string;
  purchased_at: string;
}

interface BankData {
  accounts: Account[];
  sharedAccounts: Account[];
  transactions: Transaction[];
  loans: Loan[];
  ownedBanks: OwnedBank[];
  playerMoney: number;
}

const App = () => {
  const [visible, setVisible] = useState(false);
  const [data, setData] = useState<BankData>({
    accounts: [],
    sharedAccounts: [],
    transactions: [],
    loans: [],
    ownedBanks: [],
    playerMoney: 0
  });
  const [activeTab, setActiveTab] = useState('accounts');
  const [selectedAccount, setSelectedAccount] = useState<Account | null>(null);

  const [modalState, setModalState] = useState<{
    type: 'none' | 'createAccount' | 'transfer' | 'loan' | 'deposit' | 'withdraw';
    isOpen: boolean;
  }>({ type: 'none', isOpen: false });

  const [formData, setFormData] = useState({
    accountName: '',
    transferAmount: '',
    transferToAccount: '',
    loanAmount: '',
    loanInstallments: 6,
    depositAmount: '',
    withdrawAmount: ''
  });

  useNuiEvent('setVisible', (event: boolean) => {
    setVisible(event);
  });

  useNuiEvent('setData', (event: any) => {
    const allAccounts = event.data.accounts || [];
    const ownedAccounts = allAccounts.filter((acc: any) => acc.isOwner === true);
    const sharedAccountsList = allAccounts.filter((acc: any) => acc.isOwner === false);
    setData({
      accounts: ownedAccounts,
      sharedAccounts: sharedAccountsList,
      transactions: event.data.transactions || [],
      loans: event.data.loans || [],
      ownedBanks: event.data.ownedBanks || [],
      playerMoney: event.data.cash ?? 0
    });
    if (allAccounts.length > 0 && !selectedAccount) {
      setSelectedAccount(allAccounts[0]);
    }
  });

  useNuiEvent<{ type: string; message: string }>('notify', (event) => {
    if (event.type === 'success') {
      toast.success(event.message);
    } else if (event.type === 'error') {
      toast.error(event.message);
    } else {
      toast(event.message);
    }
  });

  const handleClose = useCallback(() => {
    setVisible(false);
    fetchNui('close');
  }, []);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && visible) {
        handleClose();
      }
    };

    window.addEventListener('keydown', handleEscape);
    return () => window.removeEventListener('keydown', handleEscape);
  }, [visible, handleClose]);

  const handleAction = (action: string) => {
    switch (action) {
      case 'deposit': setModalState({ type: 'deposit', isOpen: true }); break;
      case 'withdraw': setModalState({ type: 'withdraw', isOpen: true }); break;
      case 'transfer': setModalState({ type: 'transfer', isOpen: true }); break;
      case 'createAccount': setModalState({ type: 'createAccount', isOpen: true }); break;
    }
  };

  const submitAction = () => {
    const { type } = modalState;

    if (type === 'createAccount') {
      if (!formData.accountName.trim()) return toast.error('Nombre requerido');
      fetchNui('createAccount', { accountName: formData.accountName });
    }
    else if (type === 'deposit') {
      if (!selectedAccount || !formData.depositAmount) return toast.error('Monto inválido');
      fetchNui('deposit', { accountId: selectedAccount.id, amount: parseFloat(formData.depositAmount) });
    }
    else if (type === 'withdraw') {
      if (!selectedAccount || !formData.withdrawAmount) return toast.error('Monto inválido');
      fetchNui('withdraw', { accountId: selectedAccount.id, amount: parseFloat(formData.withdrawAmount) });
    }
    else if (type === 'transfer') {
      if (!selectedAccount || !formData.transferAmount || !formData.transferToAccount) return toast.error('Datos incompletos');
      fetchNui('transfer', {
        fromAccountId: selectedAccount.id,
        toAccountId: parseInt(formData.transferToAccount),
        amount: parseFloat(formData.transferAmount)
      });
    }
    else if (type === 'loan') {
      if (!formData.loanAmount) return toast.error('Monto inválido');
      fetchNui('requestLoan', {
        amount: parseFloat(formData.loanAmount),
        installments: parseInt(formData.loanInstallments.toString())
      });
    }

    setFormData({
      accountName: '',
      transferAmount: '',
      transferToAccount: '',
      loanAmount: '',
      loanInstallments: 6,
      depositAmount: '',
      withdrawAmount: ''
    });
    setModalState({ type: 'none', isOpen: false });
  };

  const getChartData = () => {
    if (!selectedAccount) return [];
    const accountTransactions = data.transactions.filter(t => t.account_id === selectedAccount.id);
    const groupedByDate = accountTransactions.reduce((acc: any, t) => {
      const date = new Date(t.created_at).toLocaleDateString();
      if (!acc[date]) acc[date] = { date, income: 0, expense: 0 };
      const amount = parseFloat(t.amount);
      if (amount > 0) acc[date].income += amount;
      else acc[date].expense += Math.abs(amount);
      return acc;
    }, {});
    return Object.values(groupedByDate).slice(-7);
  };

  const getTotalIncome = () => {
    if (!selectedAccount) return 0;
    return data.transactions
      .filter(t => t.account_id === selectedAccount.id && parseFloat(t.amount) > 0)
      .reduce((sum, t) => sum + parseFloat(t.amount), 0);
  };

  const getTotalExpense = () => {
    if (!selectedAccount) return 0;
    return data.transactions
      .filter(t => t.account_id === selectedAccount.id && parseFloat(t.amount) < 0)
      .reduce((sum, t) => sum + Math.abs(parseFloat(t.amount)), 0);
  };

  if (!visible) return null;

  return (
    <div className="fixed inset-0 flex items-center justify-center bg-black/50 backdrop-blur-sm p-8 animate-in">
      <Toaster
        position="top-right"
        toastOptions={{
          style: {
            background: "#1e293b",
            color: "#fff",
            border: "1px solid rgba(255,255,255,0.1)",
          },
        }}
      />

      <div className="w-full max-w-7xl h-[85vh] flex rounded-3xl overflow-hidden shadow-2xl relative">
        <div className="absolute inset-0 bg-[rgb(var(--bg-primary))] z-0">
          <div className="absolute top-0 left-0 w-full h-full bg-gradient-to-br from-indigo-900/20 via-purple-900/20 to-black pointer-events-none" />
        </div>

        <div className="relative z-10 flex w-full h-full">
          <Sidebar
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            onClose={handleClose}
          />

          <main className="flex-1 p-8 overflow-y-auto custom-scrollbar">
            {activeTab === 'accounts' && (
              <Dashboard
                selectedAccount={selectedAccount}
                accounts={data.accounts}
                sharedAccounts={data.sharedAccounts}
                onSelectAccount={(id) => {
                  const acc = [...data.accounts, ...data.sharedAccounts].find(a => a.id === id);
                  if (acc) setSelectedAccount(acc);
                }}
                onAction={handleAction}
              />
            )}

            {activeTab === 'transactions' && (
              <TransactionHistory
                transactions={selectedAccount
                  ? data.transactions.filter(t => t.account_id === selectedAccount.id)
                  : []
                }
              />
            )}

            {activeTab === 'loans' && (
              <LoanManager
                loans={data.loans}
                onRequestLoan={() => setModalState({ type: 'loan', isOpen: true })}
                onPayLoan={(loanId, amount) => fetchNui('payLoan', { loanId, amount })}
              />
            )}

            {activeTab === 'stats' && selectedAccount && (
              <StatsView
                data={getChartData()}
                totalIncome={getTotalIncome()}
                totalExpense={getTotalExpense()}
                currentBalance={parseFloat(selectedAccount.balance)}
              />
            )}

            {activeTab === 'banks' && (
              <BankManager
                ownedBanks={data.ownedBanks}
                onPurchaseBank={() => fetchNui('purchaseBank', { bankName: 'Mi Banco' })}
              />
            )}
          </main>
        </div>
      </div>

      {modalState.isOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm">
          <div className="bg-[rgb(var(--bg-card))] p-8 rounded-2xl w-full max-w-md border border-white/10 shadow-2xl animate-slide-up">
            <h3 className="text-xl font-bold text-white mb-6">
              {modalState.type === 'deposit' && 'Depositar Dinero'}
              {modalState.type === 'withdraw' && 'Retirar Dinero'}
              {modalState.type === 'transfer' && 'Transferir Dinero'}
              {modalState.type === 'createAccount' && 'Nueva Cuenta'}
              {modalState.type === 'loan' && 'Solicitar Préstamo'}
            </h3>

            <div className="space-y-4">
              {modalState.type === 'createAccount' && (
                <input
                  type="text"
                  placeholder="Nombre de la cuenta"
                  value={formData.accountName}
                  onChange={e => setFormData({ ...formData, accountName: e.target.value })}
                  className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                />
              )}

              {(modalState.type === 'deposit' || modalState.type === 'withdraw' || modalState.type === 'transfer' || modalState.type === 'loan') && (
                <input
                  type="number"
                  placeholder="Monto"
                  value={modalState.type === 'deposit' ? formData.depositAmount :
                    modalState.type === 'withdraw' ? formData.withdrawAmount :
                      modalState.type === 'transfer' ? formData.transferAmount :
                        formData.loanAmount}
                  onChange={e => {
                    const val = e.target.value;
                    if (modalState.type === 'deposit') setFormData({ ...formData, depositAmount: val });
                    else if (modalState.type === 'withdraw') setFormData({ ...formData, withdrawAmount: val });
                    else if (modalState.type === 'transfer') setFormData({ ...formData, transferAmount: val });
                    else setFormData({ ...formData, loanAmount: val });
                  }}
                  className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                />
              )}

              {modalState.type === 'transfer' && (
                <input
                  type="number"
                  placeholder="ID Cuenta Destino"
                  value={formData.transferToAccount}
                  onChange={e => setFormData({ ...formData, transferToAccount: e.target.value })}
                  className="w-full p-3 rounded-xl bg-black/20 border border-white/10 text-white focus:border-indigo-500 outline-none"
                />
              )}

              {modalState.type === 'loan' && (
                <div>
                  <label className="text-sm text-gray-400 mb-2 block">Cuotas: {formData.loanInstallments}</label>
                  <input
                    type="range"
                    min="1"
                    max="24"
                    value={formData.loanInstallments}
                    onChange={e => setFormData({ ...formData, loanInstallments: parseInt(e.target.value) })}
                    className="w-full"
                  />
                </div>
              )}

              <div className="flex gap-3 mt-6">
                <button
                  onClick={() => setModalState({ type: 'none', isOpen: false })}
                  className="flex-1 py-3 rounded-xl bg-white/5 hover:bg-white/10 text-white transition-colors"
                >
                  Cancelar
                </button>
                <button
                  onClick={submitAction}
                  className="flex-1 py-3 rounded-xl bg-indigo-600 hover:bg-indigo-700 text-white transition-colors font-medium"
                >
                  Confirmar
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;