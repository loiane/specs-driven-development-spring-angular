---
name: flyway-or-liquibase-detection
description: Auto-detect the project's DB migration tool and follow its conventions. Never use both. Use when designing or writing a schema change.
when_to_use:
  - Phase 3 (Plan) — designing a migration as part of a feature.
  - Phase 4 (Build) — adding the migration script.
  - `/onboard` — recording the detected tool in the design baseline.
authoritative_references:
  - https://documentation.red-gate.com/flyway
  - https://docs.liquibase.com/concepts/changelogs/home.html
---

# Flyway or Liquibase detection

## Detection

`.github/scripts/detect-stack.sh` reports one of:

- `flyway` — `flyway-core` in `pom.xml` AND `src/main/resources/db/migration/` exists.
- `liquibase` — `liquibase-core` in `pom.xml` AND `src/main/resources/db/changelog/` exists.
- `none` — neither.
- `both` — **fatal**. Refuse to proceed; ask the user to remove one.

Record the result in `03-design.md` under `### Inputs from detect-stack.sh`.

## Flyway conventions

- File path: `src/main/resources/db/migration/V{version}__{description}.sql`
- Versioning: `V1__init.sql`, `V2__add_gift_card_table.sql`, `V3__add_index_gift_card_code.sql`
- One migration per logical change. Never edit a checked-in migration; add a new one.
- Repeatable migrations (views, functions): `R__view_active_orders.sql`.
- Forward-only by default. If a migration is destructive, the design must include a `## Rollback` section in `03-design.md`.

```sql
-- V12__add_gift_card_table.sql
CREATE TABLE gift_card (
    id          UUID PRIMARY KEY,
    code        VARCHAR(64) NOT NULL UNIQUE,
    balance     NUMERIC(12,2) NOT NULL CHECK (balance >= 0),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_gift_card_code ON gift_card(code);
```

## Liquibase conventions

- Master changelog: `src/main/resources/db/changelog/db.changelog-master.yaml`
- Per-feature changeset file: `db/changelog/changes/2026-04-18-gift-card.yaml`
- Include via `<include file="changes/2026-04-18-gift-card.yaml"/>`.
- Each changeset has `id`, `author`, and is **immutable** once merged.

```yaml
databaseChangeLog:
  - changeSet:
      id: gift-card-1
      author: spring-implementer
      changes:
        - createTable:
            tableName: gift_card
            columns:
              - column: { name: id, type: UUID, constraints: { primaryKey: true } }
              - column: { name: code, type: VARCHAR(64), constraints: { nullable: false, unique: true } }
              - column: { name: balance, type: NUMERIC(12,2), constraints: { nullable: false } }
              - column: { name: created_at, type: TIMESTAMPTZ, defaultValueComputed: now() }
```

## Tests

- Migrations run automatically inside the Testcontainers Postgres container at test boot.
- A dedicated `MigrationsIT` runs `flyway:info` (or `liquibase status`) at the latest version and asserts no pending migrations.

## Anti-patterns

- Editing a previously released migration → checksum mismatch → production breaks.
- Using `Flyway.repair()` in code paths.
- `DROP TABLE` without an ADR.
- Renaming a column with no two-step migration (add new → backfill → switch reads → switch writes → drop old).
- Two migration tools coexisting (`both` is fatal).
