import React from 'react';
import { LayoutDashboard, CreditCard, History, Banknote, Building2, LogOut } from 'lucide-react';

interface SidebarProps {
    activeTab: string;
    setActiveTab: (tab: string) => void;
    onClose: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab, onClose }) => {
    const menuItems = [
        { id: 'accounts', label: 'Cuentas', icon: <CreditCard size={20} /> },
        { id: 'transactions', label: 'Transacciones', icon: <History size={20} /> },
        { id: 'loans', label: 'Préstamos', icon: <Banknote size={20} /> },
        { id: 'stats', label: 'Estadísticas', icon: <LayoutDashboard size={20} /> },
        { id: 'banks', label: 'Mis Bancos', icon: <Building2 size={20} /> },
    ];

    return (
        <div className="w-72 glass-panel m-4 rounded-2xl flex flex-col border-r-0">
            <div className="p-8">
                <div className="flex items-center gap-3 mb-8">
                    <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shadow-lg shadow-indigo-500/30">
                        <Building2 className="text-white" size={20} />
                    </div>
                    <div>
                        <h1 className="text-xl font-bold text-white tracking-tight">Banco</h1>
                        <p className="text-xs text-[rgb(var(--text-secondary))]">Nacional</p>
                    </div>
                </div>

                <nav className="space-y-2">
                    {menuItems.map((item) => (
                        <button
                            key={item.id}
                            onClick={() => setActiveTab(item.id)}
                            className={`w-full flex items-center gap-3 px-4 py-3.5 rounded-xl transition-all duration-300 group ${activeTab === item.id
                                    ? 'bg-gradient-to-r from-[rgba(var(--accent-primary),0.15)] to-[rgba(var(--accent-secondary),0.15)] text-white border border-[rgba(var(--accent-primary),0.2)]'
                                    : 'text-[rgb(var(--text-secondary))] hover:bg-white/5 hover:text-white'
                                }`}
                        >
                            <span className={`${activeTab === item.id ? 'text-[rgb(var(--accent-glow))]' : 'text-current group-hover:text-white'} transition-colors`}>
                                {item.icon}
                            </span>
                            <span className="font-medium">{item.label}</span>
                            {activeTab === item.id && (
                                <div className="ml-auto w-1.5 h-1.5 rounded-full bg-[rgb(var(--accent-glow))] shadow-[0_0_8px_rgb(var(--accent-glow))]" />
                            )}
                        </button>
                    ))}
                </nav>
            </div>

            <div className="mt-auto p-8 border-t border-white/5">
                <button
                    onClick={onClose}
                    className="w-full flex items-center gap-3 px-4 py-3.5 rounded-xl text-red-400 hover:bg-red-500/10 transition-all duration-300"
                >
                    <LogOut size={20} />
                    <span className="font-medium">Cerrar</span>
                </button>
            </div>
        </div>
    );
};
