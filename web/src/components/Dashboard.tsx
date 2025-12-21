import React from 'react';
import { Card } from './ui/Card';
import { Button } from './ui/Button';
import { ArrowUpRight, ArrowDownLeft, Plus, Wallet, Send, UserPlus, UserMinus, Trash2 } from 'lucide-react';

interface Account {
    id: number;
    owner: string;
    account_name: string;
    balance: string;
    created_at: string;
}

interface DashboardProps {
    selectedAccount: Account | null;
    accounts: Account[];
    sharedAccounts: Account[];
    onSelectAccount: (id: number) => void;
    onAction: (action: string) => void;
}

export const Dashboard: React.FC<DashboardProps> = ({
    selectedAccount,
    accounts,
    sharedAccounts,
    onSelectAccount,
    onAction
}) => {
    if (!selectedAccount && accounts.length === 0 && sharedAccounts.length === 0) {
        return (
            <div className="flex items-center justify-center h-full">
                <div className="text-center max-w-md">
                    <h3 className="text-2xl font-bold text-white mb-2">¡Bienvenido al Banco!</h3>
                    <p className="text-gray-400 mb-6">Aún no tienes cuentas bancarias. Crea tu primera cuenta para comenzar.</p>
                    <Button onClick={() => onAction('createAccount')} className="mx-auto">
                        Crear Mi Primera Cuenta
                    </Button>
                </div>
            </div>
        );
    }

    if (!selectedAccount) return null;

    const isOwner = accounts.some(acc => acc.id === selectedAccount.id);

    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-indigo-600 via-purple-600 to-pink-600 p-8 shadow-2xl shadow-indigo-500/20">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />
                <div className="absolute bottom-0 left-0 w-64 h-64 bg-black/10 rounded-full blur-3xl -ml-16 -mb-16" />

                <div className="relative z-10">
                    <div className="flex justify-between items-start mb-8">
                        <div>
                            <p className="text-indigo-100 font-medium mb-1">Balance Total</p>
                            <h2 className="text-5xl font-bold text-white tracking-tight">
                                ${parseFloat(selectedAccount.balance).toLocaleString()}
                            </h2>
                        </div>
                        <div className="bg-white/20 backdrop-blur-md px-4 py-2 rounded-lg border border-white/10">
                            <span className="text-white font-medium">{selectedAccount.account_name}</span>
                        </div>
                    </div>

                    <div className="flex gap-4">
                        <Button
                            onClick={() => onAction('deposit')}
                            className="bg-white text-indigo-600 hover:bg-indigo-50 border-none shadow-lg shadow-black/10"
                            icon={<ArrowDownLeft size={18} />}
                        >
                            Depositar
                        </Button>
                        <Button
                            onClick={() => onAction('withdraw')}
                            className="bg-indigo-800/50 text-white hover:bg-indigo-800/70 border border-white/10"
                            icon={<ArrowUpRight size={18} />}
                        >
                            Retirar
                        </Button>
                        <Button
                            onClick={() => onAction('transfer')}
                            className="bg-indigo-800/50 text-white hover:bg-indigo-800/70 border border-white/10"
                            icon={<Send size={18} />}
                        >
                            Transferir
                        </Button>
                    </div>

                    {isOwner && (
                        <div className="flex gap-4 mt-4 pt-4 border-t border-white/10">
                            <Button
                                onClick={() => onAction('addSharedUser')}
                                className="bg-indigo-800/30 text-indigo-200 hover:bg-indigo-800/50 border border-white/5"
                                icon={<UserPlus size={18} />}
                            >
                                Añadir Usuario
                            </Button>
                            <Button
                                onClick={() => onAction('removeSharedUser')}
                                className="bg-indigo-800/30 text-indigo-200 hover:bg-indigo-800/50 border border-white/5"
                                icon={<UserMinus size={18} />}
                            >
                                Eliminar Usuario
                            </Button>
                            <Button
                                onClick={() => onAction('deleteAccount')}
                                className="bg-red-500/20 text-red-200 hover:bg-red-500/30 border border-red-500/20 ml-auto"
                                icon={<Trash2 size={18} />}
                            >
                                Eliminar Cuenta
                            </Button>
                        </div>
                    )}
                </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <Card title="Tus Cuentas" className="h-full">
                    <div className="space-y-3 mt-2">
                        {accounts.map(acc => (
                            <div
                                key={acc.id}
                                onClick={() => onSelectAccount(acc.id)}
                                className={`p-4 rounded-xl cursor-pointer transition-all duration-200 border ${selectedAccount.id === acc.id
                                    ? 'bg-white/10 border-indigo-500/50 shadow-lg shadow-indigo-500/10'
                                    : 'bg-white/5 border-white/5 hover:bg-white/10 hover:border-white/10'
                                    }`}
                            >
                                <div className="flex justify-between items-center">
                                    <div className="flex items-center gap-3">
                                        <div className={`p-2 rounded-lg ${selectedAccount.id === acc.id ? 'bg-indigo-500' : 'bg-gray-700'}`}>
                                            <Wallet size={18} className="text-white" />
                                        </div>
                                        <div>
                                            <p className="text-white font-medium">{acc.account_name}</p>
                                            <p className="text-xs text-gray-400">**** {acc.id}</p>
                                        </div>
                                    </div>
                                    <p className="text-white font-bold">${parseFloat(acc.balance).toLocaleString()}</p>
                                </div>
                            </div>
                        ))}

                        <Button
                            variant="secondary"
                            className="w-full mt-4 border-dashed border-white/20 hover:border-indigo-500/50 hover:text-indigo-400"
                            icon={<Plus size={18} />}
                            onClick={() => onAction('createAccount')}
                        >
                            Nueva Cuenta
                        </Button>
                    </div>
                </Card>

                {sharedAccounts.length > 0 && (
                    <Card title="Cuentas Compartidas" className="h-full">
                        <div className="space-y-3 mt-2">
                            {sharedAccounts.map(acc => (
                                <div
                                    key={acc.id}
                                    onClick={() => onSelectAccount(acc.id)}
                                    className={`p-4 rounded-xl cursor-pointer transition-all duration-200 border ${selectedAccount.id === acc.id
                                        ? 'bg-white/10 border-purple-500/50 shadow-lg shadow-purple-500/10'
                                        : 'bg-white/5 border-white/5 hover:bg-white/10 hover:border-white/10'
                                        }`}
                                >
                                    <div className="flex justify-between items-center">
                                        <div className="flex items-center gap-3">
                                            <div className={`p-2 rounded-lg ${selectedAccount.id === acc.id ? 'bg-purple-500' : 'bg-gray-700'}`}>
                                                <Wallet size={18} className="text-white" />
                                            </div>
                                            <div>
                                                <p className="text-white font-medium">{acc.account_name}</p>
                                                <p className="text-xs text-gray-400">Compartida</p>
                                            </div>
                                        </div>
                                        <p className="text-white font-bold">${parseFloat(acc.balance).toLocaleString()}</p>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </Card>
                )}
            </div>
        </div>
    );
};
