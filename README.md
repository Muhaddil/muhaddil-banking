# 🏦 Sistema Bancario Muhaddil - Guía de Uso (README Creado con IA)

## 📋 Descripción

Sistema bancario completo para FiveM con múltiples cuentas, préstamos, transferencias y gestión de bancos privados.

## ✅ Instalación

### 1. Requisitos

- **ox_lib** - Para notificaciones y callbacks
- **oxmysql** - Para base de datos
- **ESX** o **QBCore** - Framework (detección automática)

### 2. Instalación

1. Coloca `muhaddil-banking` en tu carpeta `resources`
2. Añade `ensure muhaddil-banking` a tu `server.cfg`
3. La base de datos se crea automáticamente al iniciar

### 3. Configuración

Edita `config.lua` según tus necesidades:

- Framework (detecta automáticamente ESX/QBCore)
- Comando para abrir banco (default: `/banco`)
- Límites de cuentas, préstamos, etc.

## 🎮 Uso para Jugadores

### Abrir el Banco

- **Opción 1:** Acércate a cualquier ubicación de banco (verás un marcador azul)
- **Opción 2:** Usa el comando `/banco`

### Gestión de Cuentas

#### Primera Vez

Al abrir el banco por primera vez, se creará automáticamente una **"Cuenta Principal"** con $0 de balance.

#### Crear Más Cuentas

1. Haz clic en **"Nueva Cuenta"**
2. Ingresa un nombre descriptivo
3. Confirma
4. Límite: **5 cuentas por jugador**

#### Compartir Cuentas

1. Selecciona la cuenta que deseas compartir
2. Haz clic en **"Añadir Usuario"**
3. Ingresa el **ID del jugador** en el servidor
4. El usuario tendrá acceso completo a la cuenta
5. Límite: **5 usuarios compartidos por cuenta**

### Operaciones Bancarias

#### Depositar

1. Selecciona la cuenta
2. Haz clic en **"Depositar"**
3. Ingresa el monto (debe estar en efectivo)
4. Confirma

#### Retirar

1. Selecciona la cuenta
2. Haz clic en **"Retirar"**
3. Ingresa el monto (debe haber saldo suficiente)
4. Confirma

#### Transferir

1. Selecciona la cuenta origen
2. Haz clic en **"Transferir"**
3. Ingresa:
   - Monto a transferir
   - **ID de la cuenta destino** (número visible en cada cuenta)
4. Confirma

### Préstamos

#### Solicitar Préstamo

1. Ve a la pestaña **"Préstamos"**
2. Haz clic en **"Solicitar Préstamo"**
3. Configura:
   - **Monto:** $1,000 - $500,000
   - **Cuotas:** 1-12 meses
   - **Interés:** 5% fijo
4. Confirma
5. **Importante:** Solo puedes tener 1 préstamo activo a la vez

#### Pagar Préstamo

1. Ve a la pestaña **"Préstamos"**
2. Selecciona tu préstamo activo
3. Haz clic en **"Pagar Cuota"**
4. El monto se descontará de tu efectivo
5. Puedes pagar por partes o todo de una vez

### Comprar Bancos

#### Inversión

1. Ve a la pestaña **"Bancos"**
2. Haz clic en **"Comprar Ahora"**
3. Precio: **$1,000,000**
4. Límite: **3 bancos por jugador**

#### Beneficios

- Ganas **1% de comisión** en todas las transacciones de tu zona
- Ingresos pasivos
- Se registran en "Ganancias Totales"

## 👨‍💼 Comandos de Admin

### Ver Información

```bash
/bankadmin                    # Ver top 50 cuentas del servidor
/bankinfo [ID cuenta]         # Ver detalles de una cuenta específica
/bankloans                    # Ver todos los préstamos activos
```

### Gestión de Dinero

```bash
/bankaddmoney [ID cuenta] [monto]     # Añadir dinero a una cuenta
/bankremovemoney [ID cuenta] [monto]  # Remover dinero de una cuenta
```

### Gestión de Préstamos

```bash
/bankcancelloan [ID préstamo]   # Cancelar un préstamo
```

### Resetear

```bash
/bankreset [ID jugador]         # Elimina todas las cuentas y préstamos del jugador
```

## 🗺️ Ubicaciones de Bancos

Por defecto incluye 4 ubicaciones:

1. **Banco Central** - Legion Square
2. **Paleto Bay Bank** - Paleto Bay
3. **Great Ocean Highway** - West LS
4. **Pacific Standard Bank** - Alta

Puedes añadir más en `config.lua`.

## 🔧 Solución de Problemas

### No puedo abrir el banco

- Verifica que `ox_lib` esté iniciado
- Asegúrate de estar cerca de un banco (o usa `/banco`)
- Revisa la consola F8 para errores

### No se crean las cuentas

- Verifica que `oxmysql` esté funcionando
- Revisa la consola del servidor
- Asegúrate de que el recurso tenga permisos de base de datos

### Los préstamos no aparecen

- Espera unos segundos después de solicitar
- Cierra y abre el banco de nuevo
- Verifica con `/bankloans` que se haya creado

### Error de framework

- El sistema detecta automáticamente ESX o QBCore
- Si usas un framework custom, edita `config.lua`:
  ```lua
  Config.FrameWork = 'esx' -- o 'qb'
  ```

## 📊 Estadísticas

La pestaña **"Estadísticas"** muestra:

- **Balance Actual** de la cuenta seleccionada
- **Ingresos Totales** (últimos 7 días)
- **Gastos Totales** (últimos 7 días)
- **Gráfico** de actividad diaria

## 🔐 Seguridad

El sistema incluye:

- ✅ Validación de permisos en cada operación
- ✅ Verificación de saldo antes de transacciones
- ✅ Protección contra exploits
- ✅ Logging de todas las transacciones
- ✅ Límites configurables

## 🎯 Características Futuras (Opcionales)

En `config.lua` puedes habilitar sistemas opcionales (requieren implementación):

### ATMs (Cajeros Automáticos)

```lua
Config.ATMs.Enabled = true
```

- Retiros desde cajeros en el mapa
- Comisión por uso
- Límite de retiro

### Sistema de Tarjetas

```lua
Config.Cards.Enabled = true
```

- Tarjetas de débito físicas
- Límites diarios
- Requeridas para ATMs

### Sistema de Intereses

```lua
Config.Interest.Enabled = true
```

- Ganancias por ahorros
- 0.1% diario
- Balance mínimo de $10,000

### Sistema de Cheques

```lua
Config.Checks.Enabled = true
```

- Cheques físicos transferibles
- Expiran en 7 días
- Comisión por crear

## 📞 Soporte

Para reportar bugs o sugerencias, contacta al desarrollador.

---

**Versión:** 1.0.0  
**Autor:** Muhaddil  
**Licencia:** MIT
