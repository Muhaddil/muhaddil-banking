import React from 'react';
import { Card } from './ui/Card';
import { ArrowUpRight, ArrowDownLeft } from 'lucide-react';

interface Transaction {
    id: number;
    account_id: number;
    type: string;
    amount: string;
    description: string;
    created_at: string;
}

interface TransactionHistoryProps {
    transactions: Transaction[];
}

export const TransactionHistory: React.FC<TransactionHistoryProps> = ({ transactions }) => {
    return (
        <div className="space-y-6 animate-in">
            <Card title="Historial de Transacciones" subtitle="Últimos movimientos de tu cuenta">
                <div className="space-y-4 mt-4">
                    {transactions.length === 0 ? (
                        <div className="text-center py-12 text-gray-500">
                            No hay transacciones recientes
                        </div>
                    ) : (
                        transactions.map((tx, i) => {
                            const amount = parseFloat(tx.amount);
                            const isIncome = amount > 0;

                            return (
                                <div
                                    key={i}
                                    className="flex items-center justify-between p-4 rounded-xl bg-white/5 hover:bg-white/10 transition-colors border border-white/5"
                                >
                                    <div className="flex items-center gap-4">
                                        <div className={`p-3 rounded-full ${isIncome ? 'bg-emerald-500/20 text-emerald-400' : 'bg-red-500/20 text-red-400'}`}>
                                            {isIncome ? <ArrowDownLeft size={20} /> : <ArrowUpRight size={20} />}
                                        </div>
                                        <div>
                                            <p className="text-white font-medium">{tx.description}</p>
                                            <p className="text-sm text-gray-400">{new Date(tx.created_at).toLocaleString()}</p>
                                        </div>
                                    </div>
                                    <div className="text-right">
                                        <p className={`font-bold text-lg ${isIncome ? 'text-emerald-400' : 'text-red-400'}`}>
                                            {isIncome ? '+' : ''}${Math.abs(amount).toLocaleString()}
                                        </p>
                                        <p className="text-xs text-gray-500 uppercase">{tx.type}</p>
                                    </div>
                                </div>
                            );
                        })
                    )}
                </div>
            </Card>
        </div>
    );
};
