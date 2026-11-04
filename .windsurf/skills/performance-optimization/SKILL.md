---
name: performance-optimization
description: Spring Boot 4 / JVM performance work — measure first, then fix. Profiling (async-profiler, JFR, JMH), Micrometer, common Spring antipatterns (N+1, unbounded lists, HikariCP sizing, virtual-thread pinning), caching, GC, and SLO-driven work. Used by `/plan` for risk callouts and by `/review` to flag perf regressions.
when_to_use:
  - Phase 3 (Plan) — when the design touches a hot path, a new query, a new external call, or anything with a stated SLO.
  - Phase 4 (Build) — when a task explicitly targets a performance fix or optimization.
  - Phase 7 (Review) — to flag N+1 queries, unbounded results, virtual-thread pinning, missing pagination, or other antipatterns in the diff.
  - On-demand — user asks "is this fast enough?", "why is this slow?", or "tune the connection pool".
authoritative_references:
  - https://docs.spring.io/spring-boot/reference/index.html
  - https://docs.oracle.com/en/java/javase/25/
  - .windsurf/skills/spring-boot-4-conventions/SKILL.md
  - .windsurf/skills/spring-code-review-rubric/SKILL.md (section 10)
---

# Performance optimization (Spring Boot 4 / JVM)

## Rule zero: measure first

> No optimization without a profile or a benchmark. "It feels slow" is a hypothesis, not a finding.

If a PR labeled `perf` lands without a profile artifact, a JMH result, a flame graph, or a before/after metric screenshot, **request changes**. The artifact path goes in the PR description and in `05-implementation-log.md`.

Acceptable evidence:

- async-profiler flame graph (CPU or alloc) saved as SVG/HTML.
- JDK Flight Recorder recording (`.jfr`) with the relevant view captured.
- JMH benchmark output (`*.json` from `-rf json`) with before/after.
- Micrometer histogram screenshots (p50/p95/p99) from before and after.
- Database `EXPLAIN ANALYZE` output for the query in question.

## SLO-first, not optimization-first

Every perf claim is tied to a Service Level Objective. If there is no stated SLO, the work has no exit criterion — write the SLO first.

Template (the user fills the blanks; **never invent the numbers**):

```text
Endpoint:        <method> <path>
p50 latency:     ___ ms   (current: ___ ms)
p95 latency:     ___ ms   (current: ___ ms)
p99 latency:     ___ ms   (current: ___ ms)
Throughput:      ___ rps  (current: ___ rps)
Error budget:    ___ %    (window: ___ )
Measurement:     <Micrometer metric name + dashboard link>
```

If the user has not committed to numbers, file a `Q-NNN` in `01-spec.md` or `03-design.md` and halt.

## Tools

| Tool | Use for | Notes |
|---|---|---|
| **async-profiler** | CPU and allocation flame graphs in production-like envs | `-e cpu` or `-e alloc`; safe in prod (sample-based) |
| **JFR + JDK Mission Control** | Always-on low-overhead recording; method profiling, allocation, GC, locks | Enable with `-XX:StartFlightRecording=...` |
| **JMH** | Microbenchmarks for hot loops, parsers, serialization, comparator/equality changes | Fork ≥ 2, warmup ≥ 5, measure ≥ 5; run on the deploy hardware class |
| **Micrometer + Spring Boot Actuator** | Production metrics (latency histograms, throughput, error rate) | Use `Timer` with `publishPercentileHistogram(true)`; **not** `Counter` for latency |
| **`EXPLAIN ANALYZE`** | Real query plan with row counts, buffers, timing | PostgreSQL: `EXPLAIN (ANALYZE, BUFFERS, VERBOSE) ...` |
| **`-Djdk.tracePinnedThreads=full`** | Detect virtual-thread pinning during dev/test | Enable in test profiles when investigating throughput regressions |
| **`-Xlog:gc*`** or JFR GC events | GC pause analysis | Look at p99 pause, not average |

## Antipatterns to scan for in review

### Data access

- **N+1 queries.** Entity navigation inside a loop or stream. Fix with `JOIN FETCH`, an entity graph, or a projection DTO query.
- **Unbounded list endpoints.** Any `List<T>` return type from a controller without `Pageable`. Pagination is mandatory; reject the diff.
- **Long-held `@Transactional` on read paths.** A read transaction wrapping an HTTP boundary call holds a connection. Move I/O outside the transaction.
- **Eager fetch by default.** `FetchType.EAGER` on associations forces every query to load the world. Default to `LAZY`; load explicitly.
- **Derived queries with > 3 predicates.** Spring Data parses them at startup but they hide intent and rarely use the right index. Use `@Query`.
- **No `setFetchSize` on streaming reads.** A `Stream<T>` query that materializes all rows defeats streaming. Set fetch size; iterate; close.

### Connection pool (HikariCP)

Size the pool with the formula:

```text
connections = ((core_count * 2) + effective_spindle_count)
```

For most cloud Postgres instances on SSD, `effective_spindle_count = 1`. Start with `maximumPoolSize = (cores * 2) + 1`, **never** the Hikari default of 10 in production without measuring. Verify saturation with the Actuator `hikaricp` metrics (`active`, `pending`, `usage`).

### Virtual threads (Boot 4 default-on)

- **Pinning via `synchronized`.** `synchronized` blocks holding I/O pin the carrier thread. Replace with `ReentrantLock` for any block that does I/O. Detect with `-Djdk.tracePinnedThreads=full`.
- **Large `ThreadLocal` state.** Virtual threads are cheap, so there can be millions. A `ThreadLocal<byte[]>` of 1 MB × 1M threads = 1 TB. Use scoped values (`ScopedValue`) or pool the buffer explicitly.
- **Custom `Executor` that pins to platform threads.** Don't introduce one without an ADR and a measurement showing virtual threads were the bottleneck.

### Caching

- **Cache the result, not the input.** Key on the inputs that affect the result; do not cache by request object identity.
- **TTL is mandatory.** No infinite-TTL caches in production code. State the TTL in the bean configuration.
- **Stampede protection.** Use `Caffeine` with `refreshAfterWrite` plus `AsyncLoadingCache`, or a single-flight wrapper. Without it, a TTL expiry hits the origin N times concurrently.
- **Two-tier cache (local + Redis).** Local for hot keys (microseconds), Redis for shared invalidation. Never invalidate Redis without invalidating local — use a pub/sub or short local TTL.
- **Cache size cap.** Bound `maximumSize` (Caffeine) or `maxmemory` (Redis); without a cap a cache becomes a leak.

### Payload + serialization

- **Stream large responses.** Don't materialize a 100 MB list into memory; use `StreamingResponseBody` or `ResponseBodyEmitter`.
- **Compress text responses.** Enable `server.compression.enabled=true` for `application/json`, `text/*` over a threshold (e.g. 1 KiB).
- **Avoid round-tripping JSON through `Map<String, Object>`.** It allocates per-field; use records or a typed DTO.
- **Don't log full payloads at INFO.** Logs are an allocation hot path; large payloads at INFO will dominate p99.

### GC and heap

- **Pick the collector for the workload.** Throughput-bound batch: G1. Latency-bound services with > 4 GB heap: ZGC. Generational ZGC is the default to consider on Java 25.
- **Container memory awareness.** `-XX:+UseContainerSupport` is on by default; verify with `java -Xlog:os+container=trace`. Set `-XX:MaxRAMPercentage` rather than `-Xmx` so pod resizes are honored.
- **Allocation rate, not heap size, is the GC driver.** Use JFR `Allocation in new TLAB` to find the allocator. Common offenders: per-request `ObjectMapper`, `String.format` in hot paths, autoboxing in stream pipelines.

### HTTP clients

- **Connection pool sized for the dependency.** `RestClient`/`@HttpExchange` over Apache HttpClient: set `maxTotal` and `maxPerRoute`; don't accept defaults.
- **Timeouts on every external call.** Connect, read, write, and request timeouts. Spring Boot 4 defaults are bounded but verify per client.
- **Circuit breaker on flaky dependencies.** Resilience4j with bulkhead. The breaker's open-state timeout must be shorter than the upstream's timeout.

## Cross-cutting checks for `/review`

When reviewing a diff, ask:

1. Does any controller method return `List<T>` without pagination? → blocker.
2. Does any service iterate an entity collection and call a method that triggers a query? → likely N+1; major.
3. Did Hikari `maximumPoolSize` change without a measurement? → request the profile.
4. Did the diff add `synchronized` around an I/O call? → request switch to `ReentrantLock`.
5. Did the diff add a `@Cacheable` without a TTL or a size cap? → blocker.
6. Did the diff add an external HTTP call without explicit timeouts? → blocker.
7. Does any new metric use `Counter` for a duration? → request a `Timer` with histogram.

## Before/after evidence

Every perf change appends to `05-implementation-log.md`:

```text
### T-NNN — perf

Hypothesis: <what we expected to improve>
Before:     <metric snapshot or JMH result, with units>
Change:     <what was changed, in one paragraph>
After:      <same metric, same workload, with units>
Evidence:   <path/url to flame graph, JFR file, or JMH JSON>
SLO impact: <p95 latency moved from ___ ms to ___ ms, error budget unchanged>
```

A perf change without this block fails review.

## Anti-rationalizations

| Excuse | Counter |
|---|---|
| "I know this loop is hot, let me micro-optimize." | Profile first. The hot loop is rarely where the time goes. |
| "Caffeine has a sensible default, no need to tune." | Default `maximumSize = unbounded` is a leak. Set the cap. |
| "Virtual threads make pool sizing irrelevant." | DB connection pools are still bounded. Sizing matters more, not less, because virtual threads make starvation cheaper to hit. |
| "JMH is overkill for this small change." | A 100 ns regression × 10k rps = 1 second/sec wasted. JMH is the cheapest way to know. |
| "Pagination breaks the UI." | The UI breaks because the dataset grew. Pagination is the fix; coordinate with frontend. |
| "We'll add metrics later." | If it's not measured it's not optimized. Add the `Timer` in the same PR. |

## Verification (before claiming the work is done)

- [ ] An SLO is written down with concrete numbers.
- [ ] A measurement artifact (profile, JFR, JMH, dashboard screenshot, EXPLAIN) is linked.
- [ ] A before/after delta is recorded in `05-implementation-log.md`.
- [ ] The change is gated by a feature flag if it is risky or behavior-altering.
- [ ] No new antipattern from the lists above was introduced.
- [ ] The review rubric Section 10 (Performance) checks all pass.
