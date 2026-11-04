---
name: spring-boot-4-conventions
description: Spring Framework 7 / Spring Boot 4 idioms and defaults. Use when writing or reviewing controllers, services, configuration, HTTP clients, async/virtual-thread code, or anything touching Spring's programming model.
when_to_use:
  - Writing new Spring components (controllers, services, configuration).
  - Reviewing PRs against Spring 6.x patterns to bring them up to Spring 7 / Boot 4.
  - Choosing between RestTemplate / WebClient / RestClient / @HttpExchange.
  - Configuring virtual threads, AOT, or structured logging.
authoritative_references:
  - https://docs.spring.io/spring-boot/reference/index.html
  - https://docs.spring.io/spring-framework/reference/index.html
---

# Spring Framework 7 / Spring Boot 4 conventions

> Java 25 + Spring Framework 7 + Spring Boot 4. Prefer the most modern idiom unless an ADR explains otherwise.

## Defaults to apply

### Package layout — by feature, not by layer

Top-level packages are **bounded contexts / features**, not technical layers.
Inside a feature, split by visibility (`api` published, private impl hidden).
For the private impl sub-packages, apply the following rule:

- **One class of a given type** (single entity, single service, etc.) — keep it directly in the feature package (no sub-package).
- **Multiple classes of the same type** — use a typed sub-package within the feature:
  - `model/` — JPA entities
  - `repository/` — Spring Data repositories
  - `service/` — service classes / implementations
  - `service/` — service implementations
- **Inside `api/`** — keep the controller (or service interface) at the `api/` level; put all request/response DTO records in an `api/dto/` sub-package.

All classes in the feature's private sub-packages (`model`, `repository`, `service`, `internal`) must be `public` (cross-package visibility is required when code spans multiple sub-packages). Cross-feature access is still forbidden and enforced by ArchUnit — `public` here means "visible within this feature", not "part of the published API".

The `api/` sub-package is the **only** published surface. Other features depend only on `<feature>.api`.

```text
com.example.checkout
├── giftcard/                    # feature/domain — one package per bounded context
│   ├── api/                     # published surface: controller, service interfaces, events
│   │   ├── GiftCardController.java
│   │   ├── GiftCardRedemptionService.java
│   │   ├── GiftCardRedeemed.java
│   │   ├── dto/                 # request/response DTOs always in api/dto/
│   │   │   ├── RedeemCommand.java
│   │   │   └── GiftCardRedemptionResponse.java
│   │   └── exception/           # domain exceptions thrown by this feature's services
│   │       └── InsufficientBalanceException.java
│   ├── model/                   # entities (multiple → typed sub-package)
│   │   ├── GiftCardEntity.java
│   │   └── GiftCardTransactionEntity.java
│   ├── repository/              # repositories (multiple → typed sub-package)
│   │   ├── GiftCardRepository.java
│   │   └── GiftCardTransactionRepository.java
│   └── service/                 # service implementations (multiple → typed sub-package)
│       └── GiftCardRedemptionServiceImpl.java
├── order/                       # another feature
│   ├── api/
│   │   └── dto/                 # DTOs always in api/dto/
│   │       └── OrderSummaryResponse.java
│   └── service/                 # single service impl — sub-package still used for consistency
│       └── OrderService.java
└── shared/                      # cross-cutting: error envelope, security config, time
    └── exception/               # GlobalExceptionHandler (@RestControllerAdvice)
```

Forbidden layouts (do **not** create these at the application root level):

```text
com.example.checkout
├── controller/        ❌ by-layer at root
├── service/           ❌ by-layer at root
├── repository/        ❌ by-layer at root
└── model/             ❌ by-layer at root
```

The forbidden layouts are **top-level** by-layer packages. Typed sub-packages
(`model/`, `repository/`, `service/`) are allowed — and encouraged when there
are multiple classes — **inside** a feature/domain package.

Why:

- Features change together; layers don't. By-feature keeps the diff for one
  change inside one package.
- Typed sub-packages within a feature improve navigation when a bounded context
  grows beyond 4–5 private classes.
- ArchUnit enforces that no other feature reaches into `model/`, `repository/`,
  or `service/` sub-packages (see `archunit-rules`).
- It maps 1:1 to the module boundaries enforced by `archunit-rules`.

Cross-feature interaction:

- Other features depend only on `<feature>.api`.
- Prefer events (`ApplicationEventPublisher`) for fire-and-forget integration.
- Direct dependencies between features are explicit and asserted by ArchUnit
  (e.g. `order` may depend on `giftcard.api`, never the reverse).

### Dependency injection

- **Constructor injection only.** No field `@Autowired`. No setter injection except where Spring forces it (e.g., a pre-existing framework callback).
- One `final` field per dependency. Write the constructor explicitly — **Lombok is forbidden** (see *No Lombok* below).

```java
@Service
public class CheckoutService {
    private final OrderRepository orders;
    private final GiftCardClient giftCards;

    public CheckoutService(OrderRepository orders, GiftCardClient giftCards) {
        this.orders = orders;
        this.giftCards = giftCards;
    }
}
```

### HTTP clients

- **Outbound HTTP:** prefer **`@HttpExchange` declarative clients** built on `RestClient`. Use `WebClient` only when the call is genuinely reactive end-to-end.
- Do **not** use `RestTemplate` in new code.
- Each external API gets its own client interface in the `infra` package.

```java
@HttpExchange(url = "/cards", accept = "application/json")
public interface GiftCardClient {
    @GetExchange("/{code}")
    GiftCard fetch(@PathVariable String code);
}
```

### Web layer

- Controllers are `@RestController`. Return DTO records, not entities.
- Use Java `record` for request/response DTOs.
- Validate input at the controller boundary:
  - Annotate the controller class with `@Validated`.
  - Annotate every `@RequestBody` parameter with `@Valid`.
  - Annotate every `@PathVariable` and `@RequestParam` with the appropriate Bean Validation constraint (`@Positive`, `@NotBlank`, `@Max`, etc.).
  - Always add tests that exercise each constraint; a constraint with no test is untested behaviour.
- **Never use `Pageable` as a controller parameter.** `Pageable` is a Spring Data internal type; exposing it on the API surface leaks persistence concerns, makes parameters implicit to callers, and prevents OpenAPI tooling from generating correct query-param docs. Instead:
  - Declare explicit `@RequestParam` fields (`page`, `size`, sort params).
  - Apply Bean Validation constraints directly (`@PositiveOrZero`, `@Positive`, `@Max(100)`).
  - Construct `PageRequest.of(page, size)` inside the method and pass it to the service.

  ```java
  @GetMapping
  FooPageResponse list(
      @RequestParam(defaultValue = "0") @PositiveOrZero int page,
      @RequestParam(defaultValue = "25") @Positive @Max(100) int size) {
    return fooService.getPage(PageRequest.of(page, size));
  }
  ```

- **Avoid `ResponseEntity<T>` as a return type** unless varying the HTTP status code at runtime is unavoidable. For the common cases:
  - **Add a response header** (e.g. `ETag`, `Location`) → inject `HttpServletResponse` and call `response.setHeader(...)`, then return the DTO directly.
  - **201 Created with Location** → use `@ResponseStatus(HttpStatus.CREATED)` on the method + set the `Location` header via `HttpServletResponse`.
  - `ResponseEntity` is acceptable only in handlers that need to conditionally vary the status (e.g. `304 Not Modified` based on `If-None-Match`).
- Map exceptions via `@RestControllerAdvice` to a single, documented error envelope.

```java
// in <feature>/api/dto/
public record ApplyGiftCardRequest(@NotBlank String code, @Min(0) int orderTotalCents) {}
public record ApplyGiftCardResponse(int redeemedCents, int newOrderTotalCents) {}
```

### Persistence

- Spring Data JPA is the default. Use `@Query` for non-trivial reads; never rely on derived queries longer than three predicates.
- Always paginate list endpoints (`Pageable`). Reject unbounded queries.
- Use `@ServiceConnection` with Testcontainers in tests instead of `application-test.yml` overrides.
- **Use `Instant` for audit timestamps** (`created_at`, `updated_at`), not `LocalDateTime`. `Instant` is an absolute UTC point in time; `LocalDateTime` is ambiguous across DST transitions and timezone changes. Hibernate 6 maps `Instant` to `DATETIME`/`TIMESTAMP` columns using UTC normalization — no schema change required.

### Virtual threads

- Spring Boot 4 enables virtual threads for the web server by default. Keep it on. Do not introduce custom `Executor`s that pin to platform threads without measuring.

### Configuration

- One `@ConfigurationProperties` record per bounded module. Validate with `@Validated`.
- No `@Value` for grouped settings. Use `@Value` only for ad-hoc single primitives.

```java
@ConfigurationProperties("app.giftcard")
@Validated
public record GiftCardProperties(@NotBlank String baseUrl, @Min(1) int timeoutMs) {}
```

### Observability

- Structured logging via `Logger` + key/value pairs (Boot 4 native `StructuredLoggingFormatter`).
- Metrics via `MeterRegistry`; one counter per business outcome (`gift_card.redeemed`, `gift_card.rejected`).

### AOT-friendly

- No reflection on application code.
- Beans are `@Component`, `@Service`, etc. at compile time. No runtime registration.
- Anything dynamic is registered via a `RuntimeHintsRegistrar` and noted in the design doc.

## Anti-patterns to flag in review

- Field injection (`@Autowired` on a field).
- Lombok in any form (`@Data`, `@Getter`, `@Setter`, `@Builder`, `@RequiredArgsConstructor`, `@Slf4j`, `@SneakyThrows`, etc.) — see *No Lombok* below.
- Top-level packages named `controller`, `service`, `repository`, `model`, `dto`, `util` (by-layer layout at the application root) — use feature/domain packages instead (see *Package layout*). Note: `model/`, `repository/`, and `service/` sub-packages *within* a feature package are allowed when there are multiple classes of that type.
- `RestTemplate` in new code.
- Returning entities from controllers.
- Untyped `Map<String, Object>` request/response bodies.
- Catching `Exception` then rethrowing `RuntimeException` with no message.
- `@SpringBootTest` for code that a slice test (`@WebMvcTest`, `@DataJpaTest`) can cover.
- `Pageable` as a controller method parameter — use explicit `@RequestParam` fields instead (see *Web layer*).
- `ResponseEntity<T>` as a return type when a simpler alternative exists (see *Web layer*).
- Controller input constraints (`@Positive`, `@Max`, `@Valid`, etc.) without corresponding tests — every constraint must have at least one test that fires it. (`FooService` interface in `api` + `FooServiceImpl` class in `internal`) when there is only one implementation and no other feature depends on the interface. The `api` package is the published cross-feature surface; an interface that nothing outside the feature uses does not belong there and defeats the ArchUnit `internal` guard. Use a concrete `@Service` class named `FooService` directly in `internal`. Reserve an `api`-package interface only when another feature's code must depend on it (e.g. a port for inversion of control across bounded contexts).
- `status().isUnprocessableEntity()` in `MockMvc` tests — deprecated and removed in Spring MVC Test 7.0; use `status().is(422)` instead.
- `new MappingJackson2HttpMessageConverter()` passed to `standaloneSetup(...).setMessageConverters(...)` — `MappingJackson2HttpMessageConverter` is removed in Spring 7; drop the `.setMessageConverters()` call entirely (`standaloneSetup` auto-registers Jackson).
- **Fully-qualified type names (FQNs) inline in method signatures or bodies** — never write `jakarta.servlet.http.HttpServletResponse response` or `throws java.io.IOException` directly in code; always add the proper `import` statement at the top of the file and use the simple class name. FQNs in code bypass IDE navigation, break Spotless/google-java-format style checks, and make code harder to read.

## Java 25 features to use freely

- Records and sealed types for DTOs and domain.
- Pattern matching for `switch`.
- Virtual threads (default).
- Sequenced collections.

## No Lombok

Lombok is **forbidden** in new code, including new modules added to brownfield repos.

Why:

- Java 25 records, accessors, and concise constructors cover the legitimate use cases.
- Lombok is a compile-time bytecode rewriter that interferes with AOT, code coverage, mutation testing, and static analysis.
- It hides constructor signatures, which makes constructor-injection review harder.

Replacements:

| Lombok | Use instead |
|---|---|
| `@Data`, `@Value`, `@Builder` on a DTO | Java `record` (with a static factory or compact constructor for validation) |
| `@Getter` / `@Setter` | Plain accessors; for immutable types, the record's auto-generated accessors |
| `@RequiredArgsConstructor` / `@AllArgsConstructor` | Write the constructor explicitly (one-time cost; clarifies dependency graph) |
| `@Slf4j` | `private static final Logger log = LoggerFactory.getLogger(MyClass.class);` |
| `@SneakyThrows` | Declare the checked exception or wrap it explicitly with a meaningful message |
| `@EqualsAndHashCode`, `@ToString` | Records get these for free; for non-records, write them or use `Objects.equals` / `Objects.hash` |

Enforcement:

- The `pom.xml` must not declare `org.projectlombok:lombok` as a dependency in new modules.
- Add an ArchUnit rule (see `archunit-rules` skill): `noClasses().should().dependOnClassesThat().resideInAPackage("lombok..")`.
- `spring-code-reviewer` flags any Lombok import as a **must-fix**.
