let bankData = {
    accounts: [],
    transactions: [],
    loans: [],
    cards: [],
    cash: 0,
    maxAccounts: 5,
}

let currentTab = "accounts"
let selectedAccountId = null

function formatMoney(amount) {
    return (
        "$" +
        Number.parseFloat(amount)
            .toFixed(2)
            .replace(/\d(?=(\d{3})+\.)/g, "$&,")
    )
}

window.updateBankData = (data) => {
    bankData = { ...bankData, ...data }
    updateTotalBalance()
    renderCurrentTab()
}

function updateTotalBalance() {
    const total = bankData.accounts.reduce((sum, acc) => sum + Number.parseFloat(acc.balance || 0), 0)
    document.getElementById("total-balance").textContent = formatMoney(total)
}

document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => {
        const tabName = tab.dataset.tab
        switchTab(tabName)
    })
})

function switchTab(tabName) {
    currentTab = tabName

    document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"))
    document.querySelector(`[data-tab="${tabName}"]`).classList.add("active")

    document.querySelectorAll(".tab-content").forEach((tc) => tc.classList.remove("active"))
    document.getElementById(`${tabName}-tab`).classList.add("active")

    renderCurrentTab()
}

function renderCurrentTab() {
    switch (currentTab) {
        case "accounts":
            renderAccounts()
            break
        case "transactions":
            renderTransactions()
            break
        case "loans":
            renderLoans()
            break
    }
}

function renderAccounts() {
    const accountsList = document.getElementById("accounts-list")
    accountsList.innerHTML = ""

    if (!bankData.accounts || bankData.accounts.length === 0) {
        accountsList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">🏦</div>
                <div class="empty-state-text">No tienes cuentas bancarias<br>Crea tu primera cuenta para comenzar</div>
            </div>
        `
        return
    }

    bankData.accounts.forEach((account) => {
        const card = document.createElement("div")
        card.className = "account-card"
        if (selectedAccountId === account.id) {
            card.classList.add("selected")
        }

        card.innerHTML = `
            <div class="account-card-header">
                <span class="account-name">${account.account_name || "Mi Cuenta"}</span>
                ${account.isOwner === false ? '<span class="account-badge">Compartida</span>' : ""}
            </div>
            <div class="account-balance">${formatMoney(account.balance)}</div>
            <div class="account-id">ID: #${account.id}</div>
        `

        card.addEventListener("click", () => {
            if (selectedAccountId === account.id) {
                selectedAccountId = null
            } else {
                selectedAccountId = account.id
            }
            renderAccounts()
        })

        accountsList.appendChild(card)
    })

    if (selectedAccountId) {
        renderCardsForAccount(selectedAccountId)
    }
}

function renderCardsForAccount(accountId) {
    const accountsList = document.getElementById("accounts-list")

    const accountCards = (bankData.cards || []).filter((card) => card.account_id === accountId)

    const cardsSection = document.createElement("div")
    cardsSection.className = "cards-section"
    cardsSection.innerHTML = `
    <div class="cards-header">
      <h3>Tarjetas de esta cuenta</h3>
      <button class="btn-small" onclick="openNewCardModal(${accountId})">+ Nueva</button>
    </div>
    <div id="cards-list"></div>
  `

    accountsList.appendChild(cardsSection)

    const cardsList = cardsSection.querySelector("#cards-list")

    if (accountCards.length === 0) {
        cardsList.innerHTML = `
      <div class="empty-state-small">
        <div class="empty-state-text">No tienes tarjetas para esta cuenta</div>
      </div>
    `
        return
    }

    accountCards.forEach((card) => {
        const isBlocked = card.is_blocked === 1 || card.is_blocked === true
        const cardEl = document.createElement("div")
        cardEl.className = "card-item"
        if (isBlocked) cardEl.classList.add("blocked")

        const cardNumber = card.card_number || "0000000000000000"
        const maskedNumber = "**** **** **** " + cardNumber.slice(-4)

        cardEl.innerHTML = `
      <div class="card-visual">
        <div class="card-chip"></div>
        <div class="card-number">${maskedNumber}</div>
        <div class="card-status ${isBlocked ? "blocked" : "active"}">${isBlocked ? "🔒 Bloqueada" : "✓ Activa"}</div>
      </div>
      <div class="card-actions">
        <button class="btn-card ${isBlocked ? "btn-success" : "btn-warning"}" onclick="toggleCardBlock(${card.id}, ${!isBlocked})">
          ${isBlocked ? "Desbloquear" : "Bloquear"}
        </button>
        <button class="btn-card btn-danger" onclick="deleteCard(${card.id})">Eliminar</button>
      </div>
    `

        cardsList.appendChild(cardEl)
    })
}

function renderTransactions() {
    const transactionsList = document.getElementById("transactions-list")
    transactionsList.innerHTML = ""

    if (!bankData.transactions || bankData.transactions.length === 0) {
        transactionsList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">📊</div>
                <div class="empty-state-text">No hay transacciones recientes</div>
            </div>
        `
        return
    }

    bankData.transactions.slice(0, 20).forEach((transaction) => {
        const item = document.createElement("div")
        item.className = "transaction-item"

        const amount = Number.parseFloat(transaction.amount)
        const isPositive = amount >= 0

        item.innerHTML = `
            <div class="transaction-info">
                <div class="transaction-type">${transaction.description || transaction.type}</div>
                <div class="transaction-date">${new Date(transaction.created_at).toLocaleString("es-ES")}</div>
            </div>
            <div class="transaction-amount ${isPositive ? "positive" : "negative"}">
                ${isPositive ? "+" : ""}${formatMoney(amount)}
            </div>
        `
        transactionsList.appendChild(item)
    })
}

function renderLoans() {
    const loansList = document.getElementById("loans-list")
    loansList.innerHTML = ""

    if (!bankData.loans || bankData.loans.length === 0) {
        loansList.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">💰</div>
                <div class="empty-state-text">No tienes préstamos activos</div>
            </div>
        `
        return
    }

    bankData.loans.forEach((loan) => {
        const card = document.createElement("div")
        card.className = "loan-card"
        card.innerHTML = `
            <div class="loan-header">
                <span class="loan-id">Préstamo #${loan.id}</span>
                <span class="loan-status">Activo</span>
            </div>
            <div class="loan-details">
                <div class="loan-detail">
                    <span class="loan-detail-label">Monto Original:</span>
                    <span class="loan-detail-value">${formatMoney(loan.amount)}</span>
                </div>
                <div class="loan-detail">
                    <span class="loan-detail-label">Interés:</span>
                    <span class="loan-detail-value">${loan.interest_rate}%</span>
                </div>
                <div class="loan-detail">
                    <span class="loan-detail-label">Cuotas:</span>
                    <span class="loan-detail-value">${loan.installments}</span>
                </div>
            </div>
            <div class="loan-remaining">${formatMoney(loan.remaining)}</div>
            <div class="loan-actions">
                <button class="btn-small primary" onclick="payLoan(${loan.id})">Pagar Cuota</button>
            </div>
        `
        loansList.appendChild(card)
    })
}

function openModal(title, content) {
    const modal = document.getElementById("modal")
    document.getElementById("modal-title").textContent = title
    document.getElementById("modal-body").innerHTML = content
    modal.classList.add("active")
}

function closeModal() {
    document.getElementById("modal").classList.remove("active")
}

document.getElementById("modal-close").addEventListener("click", closeModal)
document.getElementById("modal").addEventListener("click", (e) => {
    if (e.target.id === "modal") closeModal()
})

document.getElementById("modal-backdrop").addEventListener("click", closeModal)

document.getElementById("btn-new-account").addEventListener("click", () => {
    if (bankData.accounts.length >= bankData.maxAccounts) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Límite alcanzado", content: `Máximo ${bankData.maxAccounts} cuentas` })
        }
        return
    }

    openModal(
        "Nueva Cuenta Bancaria",
        `
        <div class="form-group">
            <label class="form-label">Nombre de la cuenta</label>
            <input type="text" id="account-name" class="form-input" placeholder="Mi Cuenta Personal" />
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="createAccount()">Crear Cuenta</button>
        </div>
    `,
    )
})

window.createAccount = () => {
    const accountName = document.getElementById("account-name").value.trim()

    if (!accountName) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Error", content: "Ingresa un nombre válido" })
        }
        return
    }

    window.fetchNui("createAccountPhone", { accountName })
    closeModal()
}

document.getElementById("btn-transfer").addEventListener("click", () => {
    if (!bankData.accounts || bankData.accounts.length === 0) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Error", content: "No tienes cuentas bancarias" })
        }
        return
    }

    const accountOptions = bankData.accounts
        .map(
            (acc) =>
                `<option value="${acc.id}" ${selectedAccountId === acc.id ? "selected" : ""}>${acc.account_name} - ${formatMoney(acc.balance)}</option>`,
        )
        .join("")

    openModal(
        "Transferir Dinero",
        `
        <div class="form-group">
            <label class="form-label">Cuenta Origen</label>
            <select id="from-account" class="form-select">${accountOptions}</select>
        </div>
        <div class="form-group">
            <label class="form-label">ID Cuenta Destino</label>
            <input type="number" id="to-account" class="form-input" placeholder="123" />
        </div>
        <div class="form-group">
            <label class="form-label">Cantidad</label>
            <input type="number" id="transfer-amount" class="form-input" placeholder="1000.00" step="0.01" />
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="confirmTransfer()">Transferir</button>
        </div>
    `,
    )
})

window.confirmTransfer = () => {
    const fromAccountId = Number.parseInt(document.getElementById("from-account").value)
    const toAccountId = Number.parseInt(document.getElementById("to-account").value)
    const amount = Number.parseFloat(document.getElementById("transfer-amount").value)

    if (!toAccountId || !amount || amount <= 0) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Error", content: "Datos inválidos" })
        }
        return
    }

    window.fetchNui("transferPhone", { fromAccountId, toAccountId, amount })
    closeModal()
}

if (window.onSettingsChange) {
    window.onSettingsChange((settings) => {
        const theme = settings.display.theme
        document.getElementById("content").dataset.theme = theme
    })
}

if (window.getSettings) {
    window.getSettings().then((settings) => {
        const theme = settings.display.theme
        document.getElementById("content").dataset.theme = theme
    })
}

if (window.fetchNui) {
    window.fetchNui("getBankDataPhone").then((data) => {
        if (data) {
            window.updateBankData(data)
        }
    })
}

window.addEventListener("message", (e) => {
    const msg = e.data?.data
    if (!msg) return

    if (msg.type === "updateData") {
        window.updateBankData(msg.data)
    }
})

if (!window.sendNotification) {
    window.sendNotification = (notification) => {
    }
}

if (!window.fetchNui) {
    window.fetchNui = (action, data) => {
        return Promise.resolve({ accounts: [], transactions: [], loans: [], cards: [] })
    }
}

if (!window.onSettingsChange) {
    window.onSettingsChange = (callback) => {
    }
}

if (!window.getSettings) {
    window.getSettings = () => Promise.resolve({ display: { theme: "light" } })
}

window.openNewCardModal = (accountId) => {
    openModal(
        "Nueva Tarjeta",
        `
        <div class="form-group">
            <label class="form-label">PIN de 4 dígitos</label>
            <input type="password" id="card-pin" class="form-input" placeholder="0000" maxlength="4" pattern="[0-9]{4}" />
            <small>Recuerda este PIN, lo necesitarás para usar la tarjeta</small>
        </div>
        <div class="form-group">
            <label class="form-label">Confirmar PIN</label>
            <input type="password" id="card-pin-confirm" class="form-input" placeholder="0000" maxlength="4" pattern="[0-9]{4}" />
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="createCard(${accountId})">Crear Tarjeta ($500)</button>
        </div>
    `,
    )
}

// window.createCard = (accountId) => {
//     const pin = document.getElementById("card-pin").value
//     const pinConfirm = document.getElementById("card-pin-confirm").value

//     if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
//         if (window.sendNotification) {
//             window.sendNotification({ title: "Error", content: "El PIN debe ser de 4 dígitos numéricos" })
//         }
//         return
//     }

//     if (pin !== pinConfirm) {
//         if (window.sendNotification) {
//             window.sendNotification({ title: "Error", content: "Los PINs no coinciden" })
//         }
//         return
//     }

//     window.fetchNui("createCardPhone", { accountId, pin })
//     closeModal()
// }

window.toggleCardBlock = (cardId, block) => {
    const action = block ? "bloquear" : "desbloquear"
    openModal(
        `¿${block ? "Bloquear" : "Desbloquear"} tarjeta?`,
        `
        <p>¿Estás seguro que deseas ${action} esta tarjeta?</p>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="confirmToggleBlock(${cardId}, ${block})">Confirmar</button>
        </div>
    `,
    )
}

window.confirmToggleBlock = (cardId, block) => {
    window.fetchNui("toggleCardBlockPhone", { cardId, block })
    closeModal()
}

// window.deleteCard = (cardId) => {
//     openModal(
//         "¿Eliminar tarjeta?",
//         `
//         <p>Esta acción no se puede deshacer. ¿Estás seguro?</p>
//         <div class="modal-actions">
//             <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
//             <button class="btn-confirm btn-danger" onclick="confirmDeleteCard(${cardId})">Eliminar</button>
//         </div>
//     `,
//     )
// }

// window.confirmDeleteCard = (cardId) => {
//     window.fetchNui("deleteCardPhone", { cardId })
//     closeModal()
// }

document.getElementById("btn-request-loan").addEventListener("click", () => {
    openModal(
        "Solicitar Préstamo",
        `
        <div class="form-group">
            <label class="form-label">Monto del préstamo</label>
            <input type="number" id="loan-amount" class="form-input" placeholder="1000" min="1" />
        </div>
        <div class="form-group">
            <label class="form-label">Número de cuotas</label>
            <input type="number" id="loan-installments" class="form-input" placeholder="12" min="1" />
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="submitLoanRequest()">Solicitar</button>
        </div>
        `
    )
})

window.submitLoanRequest = () => {
    const amount = Number.parseFloat(document.getElementById("loan-amount").value)
    const installments = Number.parseInt(document.getElementById("loan-installments").value)

    if (!amount || amount <= 0 || !installments || installments <= 0) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Error", content: "Datos inválidos" })
        }
        return
    }

    if (window.fetchNui) {
        window.fetchNui("requestLoanPhone", { amount, installments }).then((res) => {
            closeModal()
        })
    } else {
        closeModal()
    }
}

window.payLoan = (loanId) => {
    openModal(
        "Pagar Préstamo",
        `
        <div class="form-group">
            <label class="form-label">Monto a pagar</label>
            <input type="number" id="pay-amount" class="form-input" placeholder="100" min="1" />
        </div>
        <div class="modal-actions">
            <button class="btn-cancel" onclick="closeModal()">Cancelar</button>
            <button class="btn-confirm" onclick="submitPayLoan(${loanId})">Pagar</button>
        </div>
        `
    )
}

window.submitPayLoan = (loanId) => {
    const amount = Number.parseFloat(document.getElementById("pay-amount").value)

    if (!amount || amount <= 0) {
        if (window.sendNotification) {
            window.sendNotification({ title: "Error", content: "Monto inválido" })
        }
        return
    }

    if (window.fetchNui) {
        window.fetchNui("payLoanPhone", { loanId, amount }).then((res) => {
            closeModal()
        })
    } else {
        closeModal()
    }
}
