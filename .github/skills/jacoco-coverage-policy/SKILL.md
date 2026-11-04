---
name: jacoco-coverage-policy
description: JaCoCo configuration and policy enforcement — 90% line+branch floor, 95% target, 95% on new code. Use when wiring JaCoCo into the Maven build or interpreting `jacoco.xml`.
when_to_use:
  - Phase 5/6 — coverage gate.
  - Brownfield onboarding — recording the existing baseline rather than failing the build day one.
authoritative_references:
  - https://www.jacoco.org/jacoco/trunk/doc/maven.html
---

# JaCoCo coverage policy

## Numbers (this toolkit's defaults)

| Metric | Hard floor | Target | New-code rule |
|---|---|---|---|
| Line coverage | 90% | 95–100% | 95% (new + changed lines only) |
| Branch coverage | 90% | 95–100% | 95% |

"Hard floor" = build fails. "Target" = aspirational; not enforced but tracked.
"New code" = lines added or modified vs `origin/main` (PR base).

## Maven config

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.12</version>
    <executions>
        <execution>
            <id>prepare</id>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>report</id>
            <phase>verify</phase>
            <goals><goal>report</goal></goals>
        </execution>
        <execution>
            <id>check</id>
            <phase>verify</phase>
            <goals><goal>check</goal></goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit><counter>LINE</counter><value>COVEREDRATIO</value><minimum>0.90</minimum></limit>
                            <limit><counter>BRANCH</counter><value>COVEREDRATIO</value><minimum>0.90</minimum></limit>
                        </limits>
                    </rule>
                    <rule>
                        <element>PACKAGE</element>
                        <limits>
                            <limit><counter>LINE</counter><value>COVEREDRATIO</value><minimum>0.85</minimum></limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

## Excludes (the only allowed)

- `**/*Application.class` (the `main` class)
- Generated code: `**/generated/**`, `**/openapi/**`
- DTOs that are pure records with no logic (when measuring branch coverage; line coverage stays)
- `**/config/**` is **not** excluded. Configuration is real code.

## Brownfield onboarding

If current coverage is below 90%:

1. Measure current values per package.
2. Write them into `.specs/_baseline.json`:

   ```json
   {
     "jacoco": {
       "overall_line": 0.74,
       "overall_branch": 0.62,
       "per_package": { "com.example.shop.checkout": { "line": 0.81, "branch": 0.70 } }
     }
   }
   ```

3. Set Maven thresholds to current values minus 1% (ratchet).
4. Each feature must improve the metric (or hold) for touched packages.
5. New code is held to 95% regardless of baseline.

## "New code at 95%"

The harness computes new-code coverage by intersecting the lines added or changed since `git merge-base origin/main HEAD` (including uncommitted and untracked files) with JaCoCo's `<line nr="N" mi="0" ci="3" mb="0" cb="2"/>` entries. A diff line with `ci > 0` is covered; one with `ci == 0` is uncovered; a diff line with no `<line>` entry is not executable and is ignored. Threshold: 95% (`NEW_CODE_THRESHOLD`).

This is implemented in `.github/scripts/check-new-code-coverage.sh`.

## Anti-patterns

- Excluding a class because it's "hard to test".
- `<excludes>**/*Service*</excludes>` — services are exactly what you must test.
- Treating coverage as the goal. It's a floor, not a target. Mutation testing is the real signal.
