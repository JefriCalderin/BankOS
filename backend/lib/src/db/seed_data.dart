import 'package:uuid/uuid.dart';

import '../models/domain_models.dart';
import '../security/password_hasher.dart';
import 'bank_store.dart';

/// Seeds two completely isolated demo tenants for immediate live demonstration:
/// 1) `banco-andes` (Banco de los Andes - COP base, 1.5% transfer fee, FX rates)
/// 2) `cooperativa-sol` (Cooperativa Sol Financiero - USD base, $2.50 fixed fee)
Future<void> seedDemoTenants(
  BankStore store, {
  required String defaultWebhookUrl,
}) async {
  const uuid = Uuid();
  final now = DateTime.now().toUtc();

  // Tenant 1: Banco de los Andes
  if (await store.findTenantBySlug('banco-andes') == null) {
    final andesTenantId = uuid.v4();
    await store.createTenant(
      Tenant(
        id: andesTenantId,
        slug: 'banco-andes',
        name: 'Banco de los Andes',
        config: TenantConfig(
          maxTransactionLimit: 50000000,
          transferFeeType: FeeType.percentage,
          transferFeeValue: 1.5,
          baseCurrency: 'COP',
          exchangeRates: const {
            'USD_COP': 4000.0,
            'COP_USD': 0.00025,
            'EUR_COP': 4350.0,
            'COP_EUR': 0.00022989,
            'USD_EUR': 0.92,
            'EUR_USD': 1.087,
          },
          webhookUrl: defaultWebhookUrl,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final adminAndes = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: andesTenantId,
        email: 'admin@andes.bank',
        fullName: 'Laura Méndez (Admin Andes)',
        passwordHash: PasswordHasher.hash('Admin123!'),
        role: UserRole.administrador,
        isActive: true,
        createdAt: now,
      ),
    );

    final ana = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: andesTenantId,
        email: 'ana@andes.bank',
        fullName: 'Ana Sofía Gómez',
        passwordHash: PasswordHasher.hash('Cliente123!'),
        role: UserRole.cliente,
        isActive: true,
        createdAt: now,
      ),
    );

    final carlos = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: andesTenantId,
        email: 'carlos@andes.bank',
        fullName: 'Carlos Andrés Ruiz',
        passwordHash: PasswordHasher.hash('Cliente123!'),
        role: UserRole.cliente,
        isActive: true,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: andesTenantId,
        accountNumber: 'AND-USD-1001',
        ownerUserId: ana.id,
        ownerName: ana.fullName,
        balance: 5000.00,
        currency: 'USD',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: andesTenantId,
        accountNumber: 'AND-COP-1002',
        ownerUserId: ana.id,
        ownerName: ana.fullName,
        balance: 12500000.00,
        currency: 'COP',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: andesTenantId,
        accountNumber: 'AND-COP-2001',
        ownerUserId: carlos.id,
        ownerName: carlos.fullName,
        balance: 3200000.00,
        currency: 'COP',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: andesTenantId,
        accountNumber: 'AND-EUR-2002',
        ownerUserId: carlos.id,
        ownerName: carlos.fullName,
        balance: 1500.00,
        currency: 'EUR',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.appendAuditLog(
      AuditLog(
        id: uuid.v4(),
        tenantId: andesTenantId,
        actorUserId: adminAndes.id,
        actorEmail: adminAndes.email,
        action: 'TENANT_INITIALIZED',
        entityType: 'tenant',
        entityId: andesTenantId,
        newState: {'slug': 'banco-andes', 'seeded': true},
        correlationId: 'seed-banco-andes',
        createdAt: now,
      ),
    );
  }

  // Tenant 2: Cooperativa Sol Financiero
  if (await store.findTenantBySlug('cooperativa-sol') == null) {
    final solTenantId = uuid.v4();
    await store.createTenant(
      Tenant(
        id: solTenantId,
        slug: 'cooperativa-sol',
        name: 'Cooperativa Sol Financiero',
        config: TenantConfig(
          maxTransactionLimit: 10000,
          transferFeeType: FeeType.fixed,
          transferFeeValue: 2.50,
          baseCurrency: 'USD',
          exchangeRates: const {
            'USD_COP': 4100.0,
            'COP_USD': 0.0002439,
            'EUR_USD': 1.10,
            'USD_EUR': 0.9091,
          },
          webhookUrl: defaultWebhookUrl,
        ),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final adminSol = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: solTenantId,
        email: 'admin@sol.coop',
        fullName: 'Jorge Pardo (Admin Sol)',
        passwordHash: PasswordHasher.hash('Admin123!'),
        role: UserRole.administrador,
        isActive: true,
        createdAt: now,
      ),
    );

    final maria = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: solTenantId,
        email: 'maria@sol.coop',
        fullName: 'María Fernanda López',
        passwordHash: PasswordHasher.hash('Cliente123!'),
        role: UserRole.cliente,
        isActive: true,
        createdAt: now,
      ),
    );

    final pedro = await store.createUser(
      User(
        id: uuid.v4(),
        tenantId: solTenantId,
        email: 'pedro@sol.coop',
        fullName: 'Pedro Alejandro Díaz',
        passwordHash: PasswordHasher.hash('Cliente123!'),
        role: UserRole.cliente,
        isActive: true,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: solTenantId,
        accountNumber: 'SOL-USD-1001',
        ownerUserId: maria.id,
        ownerName: maria.fullName,
        balance: 2800.00,
        currency: 'USD',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.createAccount(
      BankAccount(
        id: uuid.v4(),
        tenantId: solTenantId,
        accountNumber: 'SOL-COP-2001',
        ownerUserId: pedro.id,
        ownerName: pedro.fullName,
        balance: 4000000.00,
        currency: 'COP',
        status: AccountStatus.activa,
        createdAt: now,
      ),
    );

    await store.appendAuditLog(
      AuditLog(
        id: uuid.v4(),
        tenantId: solTenantId,
        actorUserId: adminSol.id,
        actorEmail: adminSol.email,
        action: 'TENANT_INITIALIZED',
        entityType: 'tenant',
        entityId: solTenantId,
        newState: {'slug': 'cooperativa-sol', 'seeded': true},
        correlationId: 'seed-cooperativa-sol',
        createdAt: now,
      ),
    );
  }
}
