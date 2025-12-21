import React from 'react';
import { Card } from './ui/Card';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';
import { TrendingUp, TrendingDown, DollarSign } from 'lucide-react';

interface StatsViewProps {
    data: any[];
    totalIncome: number;
    totalExpense: number;
    currentBalance: number;
}

export const StatsView: React.FC<StatsViewProps> = ({ data, totalIncome, totalExpense, currentBalance }) => {
    return (
        <div className="space-y-6 animate-in">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <Card className="bg-gradient-to-br from-gray-800 to-gray-900 border-white/5">
                    <div className="flex items-center gap-4">
                        <div className="p-3 bg-blue-500/20 rounded-xl text-blue-400">
                            <DollarSign size={24} />
                        </div>
                        <div>
                            <p className="text-gray-400 text-sm">Balance Actual</p>
                            <p className="text-2xl font-bold text-white">${currentBalance.toLocaleString()}</p>
                        </div>
                    </div>
                </Card>

                <Card className="bg-gradient-to-br from-gray-800 to-gray-900 border-white/5">
                    <div className="flex items-center gap-4">
                        <div className="p-3 bg-emerald-500/20 rounded-xl text-emerald-400">
                            <TrendingUp size={24} />
                        </div>
                        <div>
                            <p className="text-gray-400 text-sm">Ingresos Totales</p>
                            <p className="text-2xl font-bold text-white">${totalIncome.toLocaleString()}</p>
                        </div>
                    </div>
                </Card>

                <Card className="bg-gradient-to-br from-gray-800 to-gray-900 border-white/5">
                    <div className="flex items-center gap-4">
                        <div className="p-3 bg-red-500/20 rounded-xl text-red-400">
                            <TrendingDown size={24} />
                        </div>
                        <div>
                            <p className="text-gray-400 text-sm">Gastos Totales</p>
                            <p className="text-2xl font-bold text-white">${totalExpense.toLocaleString()}</p>
                        </div>
                    </div>
                </Card>
            </div>

            <Card title="Actividad Financiera" subtitle="Últimos 7 días">
                <div className="h-[400px] w-full mt-4">
                    <ResponsiveContainer width="100%" height="100%">
                        <BarChart data={data}>
                            <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.05)" vertical={false} />
                            <XAxis
                                dataKey="date"
                                stroke="#94a3b8"
                                fontSize={12}
                                tickLine={false}
                                axisLine={false}
                            />
                            <YAxis
                                stroke="#94a3b8"
                                fontSize={12}
                                tickLine={false}
                                axisLine={false}
                                tickFormatter={(value) => `$${value}`}
                            />
                            <Tooltip
                                contentStyle={{
                                    backgroundColor: '#1e293b',
                                    border: '1px solid rgba(255,255,255,0.1)',
                                    borderRadius: '12px',
                                    boxShadow: '0 10px 15px -3px rgba(0, 0, 0, 0.5)'
                                }}
                                cursor={{ fill: 'rgba(255,255,255,0.05)' }}
                            />
                            <Bar dataKey="income" name="Ingresos" fill="#10b981" radius={[4, 4, 0, 0]} />
                            <Bar dataKey="expense" name="Gastos" fill="#ef4444" radius={[4, 4, 0, 0]} />
                        </BarChart>
                    </ResponsiveContainer>
                </div>
            </Card>
        </div>
    );
};
