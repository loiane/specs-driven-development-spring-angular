---
applyTo: "src/test/**/*.java"
description: "Test code guardrails — JUnit 5, Testcontainers, traceability tagging."
---

# Test code guardrails

You are editing test code under `src/test/**`.

## Required

- Every test method that asserts an AC must have BOTH `@Tag("AC-NNN")` AND `@DisplayName("AC-NNN: <description>")`.
- Use the smallest scope that covers the AC: plain JUnit ≺ slice (`@WebMvcTest`, `@DataJpaTest`) ≺ `@SpringBootTest`.
- When the project declares Testcontainers, integration tests for repositories / DB-touching controllers / migrations / message brokers are **mandatory**. Use `@ServiceConnection` (Spring Boot 3+/4 idiom).
- Pin Testcontainers image tags (`postgres:17-alpine`, never `postgres:latest`).

## Forbidden

- `@Disabled` without a `# DisabledReason: <ticket-or-ADR-link>` comment on the line above.
- Removing assertions to make a test pass.
- `Thread.sleep` for synchronization (use Awaitility).
- Hard-coded host ports.
- Mocking the SUT.
- Catching `Exception` and asserting nothing.
- `@MockBean` (deprecated — use `@MockitoBean` in Spring Boot 4).

## Naming

- Unit tests: `*Test.java` (Surefire).
- Integration tests: `*IT.java` (Failsafe + Testcontainers).
- Fixtures live in `src/test/java/.../testsupport/`.

Apply `.github/skills/junit5-testcontainers-patterns/SKILL.md` and `.github/skills/requirements-traceability/SKILL.md`.
