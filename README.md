# BankOS — Sistema Bancario Multitenant como Servicio

Plataforma bancaria multitenant en la nube construida íntegramente con **Dart** (Backend API REST v1) y **Flutter** (Aplicación Móvil), diseñada para que bancos pequeños, cooperativas de ahorro y fintechs emergentes operen como **tenants completamente aislados** con sus propios clientes, cuentas, divisas, tasas de cambio, comisiones y webhooks.

---

## Arquitectura del Repositorio

```text
BankOS/
├── backend/                     # API REST v1 en Dart (Shelf + PostgreSQL 16 + Redis 7)
│   ├── docker-compose.yml       # Levanta API + PostgreSQL + Redis + Webhook Sink en 1 comando
│   ├── Dockerfile               # Compilación nativa AOT multi-stage de Dart
│   ├── bin/
│   │   ├── server.dart          # Servidor HTTP principal (/api/v1/*)
│   │   └── webhook_sink.dart    # Receptor de webhooks para demostración en vivo (:8085)
│   ├── lib/src/
│   │   ├── cache/               # RedisCacheStore + InMemoryCacheStore
│   │   ├── db/                  # Esquema PostgreSQL, triggers de auditoría inmutable, seed demo
│   │   ├── middleware/          # CORS, X-Correlation-ID, logging estructurado, manejo de errores
│   │   ├── routes/              # Enrutador /api/v1/*
│   │   ├── security/            # JWT (tenant_id, user_id, role) y hashing salted HMAC-SHA256
│   │   └── services/            # Banking, Currency/FX, Idempotency (24h), RateLimiter, Webhooks
│   └── test/                    # Pruebas de integración end-to-end (dart test)
├── mobile/                      # Aplicación Móvil Flutter (Arquitectura MVVM + Repository)
│   ├── lib/
│   │   ├── data/                # API Client resiliente, almacenamiento seguro, repositorios
│   │   ├── domain/              # Modelos de dominio + OperationDraft (preserva llaves en reintentos)
│   │   └── ui/
│   │       ├── core/            # Tema fintech, formateadores, modal 2FA local (PIN + Biometría)
│   │       └── features/        # Auth por Tenant, Dashboard, Operaciones, Resumen Pre-Tx, Historial, Admin
│   └── test/                    # Pruebas de widgets y flujo completo de reintento idempotente
└── docs/
    ├── openapi.yaml             # Especificación OpenAPI 3.1 de la API v1
    └── BankOS.postman_collection.json  # Colección lista para importar en Postman / Thunder Client
```

---

## Características Implementadas

### 1. Backend Dart (`/api/v1`)
- **Gestión de Tenants y Aislamiento Estricto**: Alta de tenants (`POST /api/v1/tenants`), configuración independiente por institución (límite máximo por transacción, comisión fija o porcentual, moneda base, tabla estática de tasas de cambio y Webhook URL). Todas las consultas y mutaciones filtran estrictamente por el `tenant_id` del JWT verificado.
- **Autenticación, RBAC y Seguridad**:
  - JWT con claims `tenant_id`, `tenant_slug`, `user_id`, `email` y `role` (`administrador` | `cliente`).
  - **Rate Limiting Dual** en Redis por **dirección IP** y por **cuenta de usuario** en endpoints de autenticación y transacciones (`429 Too Many Requests` + `Retry-After`).
  - **Auditoría Inmutable**: Tabla `audit_logs` protegida a nivel de PostgreSQL mediante trigger `BEFORE UPDATE OR DELETE` que impide cualquier modificación o eliminación.
- **Cuentas Bancarias y Borrado Lógico (Soft Delete)**: `DELETE /api/v1/accounts/{id}` cambia el estado a `inactiva` o `bloqueada` sin borrar el registro físico; cualquier operación financiera sobre cuentas no activas es rechazada (`422 ACCOUNT_INACTIVE`).
- **Operaciones Financieras y Multimoneda**: Depósitos, retiros y transferencias internas ejecutadas atómicamente con bloqueo de filas `SELECT ... FOR UPDATE` en PostgreSQL, cálculo de comisión parametrizada y conversión multimoneda automática usando la tabla estática del tenant.
- **Idempotencia y Trazabilidad**:
  - Encabezado obligatorio `Idempotency-Key` (UUID) en depósitos, retiros y transferencias, vinculado estrictamente a `(tenant_id, user_id)` con expiración automática a las 24 horas en Redis + respaldo durable en PostgreSQL.
  - Replay exacto (mismo código HTTP y mismo cuerpo JSON con `X-Idempotency-Replayed: true`) si ya se procesó.
  - Respuesta inmediata `409 Conflict` (`TRANSACTION_IN_PROGRESS`) ante solicitudes concurrentes con la misma llave.
  - Propagación de `X-Correlation-ID` en logs estructurados JSON, webhooks y cabeceras HTTP de respuesta.
- **Webhooks Asíncronos**: Peticiones HTTP POST no bloqueantes firmadas con `X-BankOS-Signature` (HMAC-SHA256) y `X-Correlation-ID`.
- **Historial Paginado**: `GET /api/v1/transactions?page=1&limit=20&type=transfer&from_date=...&to_date=...`.

### 2. Aplicación Móvil Flutter
- **Ingreso por Tenant y Auto-Registro**: Requiere `tenant_slug` + credenciales (incluye accesos rápidos para probar ambos tenants en vivo), auto-onboarding de nuevas entidades bancarias (*"Registrar Nueva Institución"*) y persistencia segura de sesión con `flutter_secure_storage`.
- **Doble Factor Local (2FA)**: Modal de autorización con **PIN de 4 dígitos** (por defecto `1234`, configurable en la app) o **Biometría simulada** antes de confirmar retiros o transferencias.
- **Dashboard en Tiempo Real**: Saldos, divisas, estados de cuenta, reglas del tenant, accesos rápidos y filtro directo a movimientos por cuenta.
- **Flujos de Operación + Resumen Pre-Transacción**: Búsqueda de cuenta destino por identificador único y pantalla de resumen con desglose exacto (monto base, comisión, tasa de cambio, total a debitar, monto final en destino y monedas implicadas).
- **Reintento Transparente en Red**: `OperationDraft` fija el `Idempotency-Key` y `X-Correlation-ID` antes de enviar. Incluye reintento automático ante fallos transitorios, botón visible de reintento reutilizando exactamente las mismas llaves y un interruptor **"Simular pérdida de red (Demo Idempotencia)"** para demostrar el escenario en vivo.
- **Historial Visual y Auditoría Detallada**:
  - Filtros interactivos por tipo (`Todas`, `Depósitos`, `Retiros`, `Transferencias`), por cuenta bancaria y por **rango de fechas**.
  - Etiquetas y bordes de alto contraste para transacciones con **comisión** (ámbar) o **conversión de divisas FX** (violeta).
  - Hoja modal de **detalle completo de transacción** con desglose de montos, tasas y copiado rápido de `Idempotency-Key` y `X-Correlation-ID`.
- **Panel de Administración**: Disponible para rol `administrador` para modificar parámetros del tenant, dar de alta nuevos usuarios/clientes (`POST /api/v1/auth/register`), crear cuentas bancarias, aplicar borrado lógico y auditar logs inmutables.
- **Asistente de Demostración y Visor de Webhooks**: Acceso directo desde el AppBar a la **Guía interactiva de Demostración del Hackatón** y al **Visor en vivo de Webhooks** con firma HMAC para inspección en tiempo real sin salir de la app.

---

## Cómo Levantar el Proyecto

### 1. Levantar Backend completo con Docker Compose (1 solo comando)
```bash
cd backend
docker-compose up --build
```
Servicios disponibles:
- **BankOS API v1**: `http://localhost:8080/api/v1/health`
- **Webhook Receiver (Inspección en vivo)**: `http://localhost:8085/events`
- **PostgreSQL 16**: `localhost:5432` (`bankos` / `bankos_secret`)
- **Redis 7**: `localhost:6379`

> **Modo local rápido sin Docker** (opcional para desarrollo):
> ```bash
> cd backend
> dart pub get
> USE_IN_MEMORY=true dart run bin/server.dart
> ```

### 2. Ejecutar la Aplicación Móvil Flutter
```bash
cd mobile
flutter pub get
flutter run
```
- En **Emulador Android**, la app apunta por defecto a `http://10.0.2.2:8080`.
- En **Web / iOS Simulator / Desktop**, apunta por defecto a `http://localhost:8080`.
- Puedes cambiar la URL del backend directamente desde la pantalla de Login en *"Configurar URL del Backend"*.

### 3. Ejecutar Pruebas Automatizadas
```bash
# Backend (8 pruebas de integración: aislamiento, FX, idempotencia, 409, RBAC, soft delete, rate limit)
cd backend && dart test -r expanded

# Mobile (flujo completo login -> dashboard -> historial -> transferencia -> 2FA -> corte de red -> reintento idempotente)
cd mobile && flutter test -r expanded
```

---

## Credenciales Demo Pre-cargadas

El backend inicializa automáticamente dos instituciones completamente aisladas:

| Tenant (`slug`) | Configuración | Rol | Correo | Contraseña | Cuentas |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`banco-andes`** | Base `COP`, comisión `1.5%`, `USD→COP: 4000` | `administrador` | `admin@andes.bank` | `Admin123!` | Todas las de Andes |
| **`banco-andes`** | — | `cliente` | `ana@andes.bank` | `Cliente123!` | `AND-USD-1001` (`$5,000 USD`), `AND-COP-1002` (`$12,500,000 COP`) |
| **`banco-andes`** | — | `cliente` | `carlos@andes.bank` | `Cliente123!` | `AND-COP-2001` (`$3,200,000 COP`), `AND-EUR-2002` (`€1,500 EUR`) |
| **`cooperativa-sol`** | Base `USD`, comisión fija `$2.50`, `USD→COP: 4100` | `administrador` | `admin@sol.coop` | `Admin123!` | Todas las de Sol |
| **`cooperativa-sol`** | — | `cliente` | `maria@sol.coop` | `Cliente123!` | `SOL-USD-1001` (`$2,800 USD`) |
| **`cooperativa-sol`** | — | `cliente` | `pedro@sol.coop` | `Cliente123!` | `SOL-COP-2001` (`$4,000,000 COP`) |

> **PIN local 2FA por defecto en la app móvil**: `1234` (o botón de Biometría simulada).

---

## Guía de Demostración en Vivo (3 Escenarios Críticos)

### Escenario 1: Dos Tenants Operando en Paralelo sin Cruce de Datos
1. Inicia sesión en la app (o Postman) con **`banco-andes`** (`ana@andes.bank` / `Cliente123!`). Observa sus cuentas `AND-USD-1001` y `AND-COP-1002`.
2. Intenta buscar la cuenta **`SOL-USD-1001`** (de `cooperativa-sol`) desde la pestaña *Operar → Transferir*. El backend responde `404 ACCOUNT_NOT_FOUND` sin revelar su existencia.
3. Inicia sesión en otro dispositivo/ventana con **`cooperativa-sol`** (`maria@sol.coop` / `Cliente123!`). Observa sus propias reglas (comisión fija `$2.50 USD`, tasa `4100`) y aislamiento total de cuentas e historial.

### Escenario 2: Transferencia Interrumpida y Reintentada con la Misma `Idempotency-Key`
1. Como Ana (`banco-andes`), entra a **Operar → Transferir**: origen `AND-USD-1001`, destino `AND-COP-2001`, monto `100`.
2. En la pantalla de **Resumen Pre-Transacción**, activa el interruptor **"Simular pérdida de red (Demo Idempotencia)"**.
3. Pulsa **"Autorizar (2FA) y Confirmar"** e ingresa el PIN `1234` (o Biometría).
4. La petición llega al servidor y se procesa, pero la app simula pérdida de señal mostrando la tarjeta amarilla **"Conexión Interrumpida"** con la `Idempotency-Key` exacta.
5. Pulsa **"Reintentar con la misma Idempotency-Key"**. El servidor responde con `X-Idempotency-Replayed: true` y la app muestra la insignia **"Idempotencia verificada: respuesta recuperada SIN doble cobro"**. Verifica en el Dashboard que el saldo de Ana bajó **una sola vez** (`$5,000.00 → $4,898.50 USD`).

### Escenario 3: Transferencia Multimoneda con Tasa Estática, Comisión y Webhook
1. En la transferencia anterior (`100 USD` → cuenta destino en `COP`):
   - **Comisión parametrizada (`1.5%`)**: `$1.50 USD` → Total debitado a Ana: **`$101.50 USD`**.
   - **Tasa estática (`USD_COP = 4000`)**: Carlos recibe exactamente **`$400,000 COP`** (`$3,200,000 → $3,600,000 COP`).
2. Entra a la pestaña **Historial**: la transacción aparece destacada con etiquetas de contraste para **Comisión** (ámbar) y **Conversión FX** (violeta).
3. Consulta `GET http://localhost:8085/events` para evidenciar el evento **Webhook POST asíncrono** `transfer.completed` recibido con la firma HMAC y el mismo `X-Correlation-ID`.
