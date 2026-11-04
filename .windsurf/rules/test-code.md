---
trigger: glob
globs: ["**/src/test/**/*.java"]
description: "Test code rule — JUnit 5, Testcontainers, traceability tagging."
---

# Test code rule

Apply `.windsurf/skills/junit5-testcontainers-patterns/SKILL.md` and `.windsurf/skills/requirements-traceability/SKILL.md`.

## Required

- Tests asserting an AC have BOTH `@Tag("AC-NNN")` and `@DisplayName("AC-NNN: …")`.
- Smallest scope wins: plain JUnit ≺ slice ≺ `@SpringBootTest`.
- Testcontainers IT (with `@ServiceConnection`) is mandatory when the project declares Testcontainers and the change touches a repo / DB-touching controller / migration / message broker.
- Image tags pinned (`postgres:17-alpine`).

## Forbidden

- `@Disabled` without `# DisabledReason: <link>` on the prior line.
- Removing assertions to make a test pass.
- `Thread.sleep` for sync (use Awaitility).
- Hard-coded host ports.
- Mocking the SUT.
- `@MockBean` (deprecated; use `@MockitoBean`).
