import React from 'react';
import { Card } from './ui/Card';
import { Button } from './ui/Button';
import { Plus, AlertCircle } from 'lucide-react';

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

interface LoanManagerProps {
    loans: Loan[];
    onRequestLoan: () => void;
    onPayLoan: (loanId: number, amount: number) => void;
}

export const LoanManager: React.FC<LoanManagerProps> = ({ loans, onRequestLoan, onPayLoan }) => {
    return (
        <div className="space-y-6 animate-in">
            <div className="flex justify-between items-center">
                <div>
                    <h2 className="text-2xl font-bold text-white">Préstamos</h2>
                    <p className="text-gray-400">Gestiona tus deudas y créditos</p>
                </div>
                <Button onClick={onRequestLoan} icon={<Plus size={18} />}>
                    Solicitar Préstamo
                </Button>
            </div>

            <div className="grid gap-6">
                {loans.length === 0 ? (
                    <Card className="text-center py-12">
                        <div className="w-16 h-16 bg-gray-800 rounded-full flex items-center justify-center mx-auto mb-4">
                            <AlertCircle className="text-gray-500" size={32} />
                        </div>
                        <h3 className="text-xl font-medium text-white mb-2">No tienes préstamos activos</h3>
                        <p className="text-gray-400 mb-6">¿Necesitas dinero extra para tus proyectos?</p>
                        <Button onClick={onRequestLoan} variant="secondary">Solicitar ahora</Button>
                    </Card>
                ) : (
                    loans.map(loan => {
                        const amount = parseFloat(loan.amount);
                        const remaining = parseFloat(loan.remaining);
                        const totalWithInterest = amount * (1 + loan.interest_rate / 100);
                        const paid = totalWithInterest - remaining;
                        const progress = (paid / totalWithInterest) * 100;

                        return (
                            <Card key={loan.id} className="relative overflow-hidden">
                                <div className="flex flex-col md:flex-row justify-between gap-6 relative z-10">
                                    <div className="flex-1">
                                        <div className="flex items-center gap-3 mb-2">
                                            <h3 className="text-xl font-bold text-white">Préstamo #{loan.id}</h3>
                                            <span className="px-2 py-1 rounded-md bg-yellow-500/20 text-yellow-400 text-xs font-medium border border-yellow-500/20">
                                                Activo
                                            </span>
                                        </div>

                                        <div className="grid grid-cols-2 gap-4 mt-4">
                                            <div>
                                                <p className="text-gray-400 text-sm">Monto Original</p>
                                                <p className="text-white font-medium">${amount.toLocaleString()}</p>
                                            </div>
                                            <div>
                                                <p className="text-gray-400 text-sm">Interés</p>
                                                <p className="text-white font-medium">{loan.interest_rate}%</p>
                                            </div>
                                            <div>
                                                <p className="text-gray-400 text-sm">Cuotas</p>
                                                <p className="text-white font-medium">{loan.installments}</p>
                                            </div>
                                            <div>
                                                <p className="text-gray-400 text-sm">Fecha</p>
                                                <p className="text-white font-medium">{new Date(loan.created_at).toLocaleDateString()}</p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="flex-1 flex flex-col justify-center bg-black/20 p-6 rounded-xl border border-white/5">
                                        <div className="flex justify-between items-end mb-2">
                                            <div>
                                                <p className="text-gray-400 text-sm">Restante a pagar</p>
                                                <p className="text-3xl font-bold text-white">${remaining.toLocaleString()}</p>
                                            </div>
                                            <p className="text-gray-400 text-sm">{progress.toFixed(0)}% pagado</p>
                                        </div>

                                        <div className="h-3 bg-gray-700 rounded-full overflow-hidden mb-6">
                                            <div
                                                className="h-full bg-gradient-to-r from-indigo-500 to-purple-500 transition-all duration-500"
                                                style={{ width: `${progress}%` }}
                                            />
                                        </div>

                                        <Button
                                            onClick={() => onPayLoan(loan.id, remaining)}
                                            className="w-full"
                                        >
                                            Pagar Cuota
                                        </Button>
                                    </div>
                                </div>
                            </Card>
                        );
                    })
                )}
            </div>
        </div>
    );
};
