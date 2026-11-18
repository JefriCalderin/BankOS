# BankOS — Diseño Visual y Mapeo de Plantilla Figma

Este documento detalla la reestructuración y adaptación de la plantilla oficial de Figma a los requerimientos técnicos y de negocio de **BankOS**.

---

## 🎨 Archivo de Figma del Proyecto

* **Enlace al diseño:** [Figma Design File](https://www.figma.com/design/KDb53ZbS5iA5CmtBvpqHnI/Banking---E-Money-MBanking---E-Money-Management-App-%7CDigital-%7C-Finance-Mobile-Banking--Community-?node-id=0-1)
* **Pantallas agregadas directamente vía MCP:**
  1. `BankOS / 01 - Login Multitenant` (`node-id: 2008:9609`)
  2. `BankOS / 02 - Resumen Pre-Transacción` (`node-id: 2009:9609`)

---

## 📱 Mapeo de Pantallas y Requisitos

| Requisito BankOS | Componente en Figma | Implementación en Flutter (`mobile/`) |
| :--- | :--- | :--- |
| **Login Multitenant** | `BankOS / 01 - Login Multitenant` (Degradado superior + Card blanco curva 32) | `lib/ui/features/auth/views/login_view.dart` (Tenant slug, JWT claims, accesos directos demo) |
| **Dashboard Multicuenta** | `Home Page` + Tarjetas de balance multidivisa (COP, USD, EUR) | `lib/ui/features/dashboard/views/dashboard_view.dart` (Saldos en vivo, tarjetas dark gradient, soft delete) |
| **Resumen Pre-Transacción** ⚠️ | `BankOS / 02 - Resumen Pre-Transacción` | `lib/ui/features/operations/views/pre_transaction_summary_view.dart` (Monto base, comisión tenant, tasa estática y neto a recibir) |
| **2FA Local (PIN de 4 dígitos)** ⚠️ | `Security Authorization (PIN Keypad)` | `lib/ui/core/security_auth_dialog.dart` (PIN local configurable + biometría) |
| **Resiliencia de Red e Idempotencia** ⚠️ | `Transaction Status & Retry Panel` | `pre_transaction_summary_view.dart` (Simulación de caída de red + botón reintento con la misma `Idempotency-Key`) |
| **Alertas Visuales de Costo** ⚠️ | Badges de contraste en transacciones | `lib/ui/features/history/views/history_view.dart` (Badges ámbar de comisión y violeta de FX conversion) |

---

## 🖼️ Capturas de Referencia de Figma

Las capturas exportadas desde Figma se encuentran en esta carpeta:
* `home_page.png` — Dashboard y tarjetas principales
* `sign_in.png` — Inicio de sesión base
* `transfer_1.png` — Selección de destinatario
* `transfer_2.png` — Monto y cuenta a debitar
* `history.png` — Listado de transacciones
