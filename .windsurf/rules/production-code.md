---
trigger: glob
globs: ["src/main/**/*.java"]
description: "Production code rule — TDD precondition + Spring Boot 4 conventions."
---

# Production code rule

When about to edit any file under `src/main/**`:

1. **Read** `.specs/<active-feature>/.tdd-state.json`.
2. **Verify** `tasks[<active-task>].phase` is `red`, `green`, `refactor`, or `simplify`, `red_at` is set, `red_failure_excerpt` is non-empty, AND the file appears in `files_in_scope`.
3. If verification fails, **stop** and tell the user: "No failing test for task `<task-id>`. Invoke `/build <task-id>` to write the test first."

Apply skills: `.windsurf/skills/spring-boot-4-conventions/SKILL.md`, `archunit-rules/SKILL.md`, `spring-security-baseline/SKILL.md`, `clarity-over-cleverness/SKILL.md`.

Hard convention: **package by feature/domain, not by layer**. Top-level packages are bounded contexts (e.g. `giftcard`, `order`), each with `api` (published) and `internal` (private) sub-packages. Never create top-level `controller`, `service`, `repository`, `model`, `dto`, or `util` packages.

Hard convention: **no Lombok** in any new code. Use Java records, explicit constructors, and `LoggerFactory.getLogger(...)` instead of `@Data`, `@Getter`, `@Setter`, `@Builder`, `@RequiredArgsConstructor`, `@Slf4j`, etc.
