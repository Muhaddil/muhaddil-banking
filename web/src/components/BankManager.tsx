import React from 'react';
import { Card } from './ui/Card';
import { Button } from './ui/Button';
import { Building2, TrendingUp, DollarSign } from 'lucide-react';

interface OwnedBank {
    id: number;
    owner: string;
    bank_name: string;
    commission_rate: string;
    total_earned: string;
    purchased_at: string;
}

interface BankManagerProps {
    ownedBanks: OwnedBank[];
    onPurchaseBank: () => void;
}

export const BankManager: React.FC<BankManagerProps> = ({ ownedBanks, onPurchaseBank }) => {
    return (
        <div className="space-y-6 animate-in">
            <div className="relative overflow-hidden rounded-3xl bg-gradient-to-r from-amber-600 to-orange-600 p-8 shadow-2xl shadow-orange-500/20">
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -mr-16 -mt-16" />

                <div className="relative z-10 flex flex-col md:flex-row justify-between items-center gap-6">
                    <div>
                        <h2 className="text-3xl font-bold text-white mb-2">Invierte en el Futuro</h2>
                        <p className="text-orange-100 max-w-md">
                            Compra tu propia sucursal bancaria y gana comisiones por cada transacción realizada en tu zona.
                        </p>
                    </div>
                    <div className="bg-white/10 backdrop-blur-md p-6 rounded-2xl border border-white/20 text-center min-w-[200px]">
                        <p className="text-orange-100 text-sm mb-1">Precio de Inversión</p>
                        <p className="text-3xl font-bold text-white mb-4">$1,000,000</p>
                        <Button
                            onClick={onPurchaseBank}
                            className="w-full bg-white text-orange-600 hover:bg-orange-50 border-none"
                        >
                            Comprar Ahora
                        </Button>
                    </div>
                </div>
            </div>

            <h3 className="text-xl font-bold text-white mt-8 mb-4">Mis Sucursales</h3>

            <div className="grid gap-6">
                {ownedBanks.length === 0 ? (
                    <div className="text-center py-12 text-gray-500 bg-white/5 rounded-2xl border border-white/5">
                        No posees ninguna sucursal bancaria actualmente
                    </div>
                ) : (
                    ownedBanks.map(bank => (
                        <Card key={bank.id}>
                            <div className="flex items-center gap-6">
                                <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-gray-700 to-gray-800 flex items-center justify-center border border-white/10">
                                    <Building2 className="text-white" size={32} />
                                </div>

                                <div className="flex-1 grid grid-cols-1 md:grid-cols-3 gap-6">
                                    <div>
                                        <p className="text-gray-400 text-sm">Nombre del Banco</p>
                                        <p className="text-xl font-bold text-white">{bank.bank_name}</p>
                                    </div>

                                    <div className="flex items-center gap-3">
                                        <div className="p-2 bg-green-500/20 rounded-lg text-green-400">
                                            <TrendingUp size={20} />
                                        </div>
                                        <div>
                                            <p className="text-gray-400 text-sm">Comisión</p>
                                            <p className="text-white font-medium">{(parseFloat(bank.commission_rate) * 100).toFixed(2)}%</p>
                                        </div>
                                    </div>

                                    <div className="flex items-center gap-3">
                                        <div className="p-2 bg-yellow-500/20 rounded-lg text-yellow-400">
                                            <DollarSign size={20} />
                                        </div>
                                        <div>
                                            <p className="text-gray-400 text-sm">Ganancias Totales</p>
                                            <p className="text-white font-medium">${parseFloat(bank.total_earned).toLocaleString()}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </Card>
                    ))
                )}
            </div>
        </div>
    );
};
