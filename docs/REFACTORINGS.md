# Acumatica-Specific Refactorings Catalog

## 1. How to Use This Catalog

This catalog serves as a machine-readable knowledge base for automated refactoring agents operating on Acumatica ERP codebases. Each refactoring type is assigned a unique identifier (REF-XXX) that agents MUST reference when executing or proposing transformations.

### Agent Usage Protocol

1. **Detection**: Use the "When to Apply (Symptoms)" section to programmatically identify code patterns requiring transformation
2. **Transformation**: Apply changes according to "Core Transformation (Target State)" rules
3. **Validation**: Verify changes meet all "Acceptance Criteria" before completion
4. **Risk Assessment**: Review "Risks / Side Effects" before proposing changes
5. **Cross-Reference**: Check "Related Acumatica Mechanisms" to ensure holistic understanding

### PR Review Usage

Detection signals are candidates for review, not automatic findings. In PR review, apply this catalog to the changed behavior and changed code first. Do not require broad cleanup of unrelated legacy code unless the legacy pattern directly causes the defect, makes the PR unsafe, or blocks the intended change.

Severity must follow user-visible, data, upgrade, security, performance, and maintainability risk. Style-only refactorings should not be escalated when the implementation is consistent with nearby legacy code and does not increase risk.

### Refactoring ID Format
- Pattern: `REF-XXX` where XXX is a three-digit number
- Categories use numeric prefixes: 0XX (Graph), 1XX (DAC), 2XX (BQL), 3XX (Events), 4XX (Cache), 5XX (LongOps), 6XX (UI), 7XX (Workflow), 8XX (Integration), 9XX (Security)

---

## 2. Glossary

| Term | Definition |
|------|------------|
| **BQL** | Business Query Language - Acumatica's type-safe query DSL |
| **Cache** | PXCache - in-memory data container managing DAC instances and change tracking |
| **DAC** | Data Access Class - typed representation of database tables |
| **Event Handler** | Graph method responding to framework lifecycle events |
| **Fluent BQL** | Modern BQL syntax using `SelectFrom<>` pattern |
| **Graph** | PXGraph - business logic container analogous to controller/service |
| **Graph Extension** | PXGraphExtension - modular extension mechanism for Graphs |
| **PXOverride** | Attribute enabling method override from Graph Extensions |
| **PXProtectedAccess** | Attribute enabling a Graph Extension bridge to selected protected members |
| **PXContext Slot** | Request-context storage for transient execution state |
| **PXDatabase Slot** | Persistent shared cache for read-mostly setup or reference data |
| **RowSelected** | Event fired when UI displays a row; UI state management only |
| **RowPersisting** | Event fired before database write; final validation point |
| **FieldUpdated** | Event fired after field value changes; side-effect handling |
| **FieldDefaulting** | Event fired to determine default value for a field |
| **FieldVerifying** | Event fired to validate proposed field value change |
| **SetValueExt** | Cache method triggering full event chain for field assignment |
| **SetValue** | Cache method for direct assignment bypassing events |
| **PXFormula** | Declarative field calculation attribute |
| **PXSelector** | Declarative lookup/dropdown configuration attribute |
| **PXParent** | Attribute defining parent-child cascade relationships |
| **PXForeignReference** | Attribute enforcing referential integrity |
| **IPrefetchable** | Interface for cached configuration data slots |
| **PXLongOperation** | Asynchronous background operation mechanism |
| **Workflow** | State machine configuration for document lifecycle |
| **IsActive()** | Graph Extension activation method controlling feature toggling |

---

## 3. Refactoring Catalog

### Category A: Graph & Extensions (REF-0XX)

---

### REF-001: Extract Business Logic to Graph Extension

**Description:**  
Monolithic Graphs containing unrelated functionality MUST be decomposed into focused Graph Extensions. Each extension SHOULD address a single feature concern and implement `IsActive()` for feature-gating.

**When to Apply (Symptoms):**
- Graph class exceeds 2000 lines of code
- Graph contains logic for multiple unrelated features
- Graph has methods that check feature flags inline
- Graph cannot be extended without modifying source
- Unit testing requires instantiating unrelated functionality
- Multiple developers frequently conflict on same Graph file

**Core Transformation (Target State):**
- Business logic MUST reside in `PXGraphExtension<TGraph>` classes
- Each extension MUST implement `public static bool IsActive()` method
- Extension MUST NOT duplicate base Graph views or actions without override
- Feature-specific logic MUST be isolated to single extension
- Extensions MUST use `[PXOverride]` with delegate parameter for method overrides

**Why It Matters in Acumatica:**
- Framework loads extensions dynamically based on IsActive() results
- Enables per-customer customization without source modification
- Upgrade-safe: extensions survive platform version changes
- Supports feature toggle architecture via PXAccess.FeatureInstalled
- Reduces merge conflicts in team development

**Risks / Side Effects:**
- Extension load order may affect behavior; validate with multiple extensions
- Static IsActive() evaluated once per session; dynamic toggling not supported
- Over-decomposition creates navigation complexity
- Extensions accessing private members require refactoring base Graph

**Acceptance Criteria:**
- Each Graph Extension addresses single functional concern
- All extensions implement IsActive() with explicit feature check
- No business logic remains in base Graph that belongs in extension
- All method overrides use [PXOverride] with delegate parameter
- Unit tests can instantiate extensions in isolation

**Related Acumatica Mechanisms:**
`PXGraphExtension<T>`, `IsActive()`, `[PXOverride]`, `PXAccess.FeatureInstalled<>`

**Common Anti-Patterns Nearby:**
- Feature flag checks scattered throughout Graph methods
- Large switch statements based on document type
- Service locator patterns instead of extension architecture
- Extensions without IsActive() method
- PXOverride without delegate parameter

---

### REF-002: Add Delegate Parameter to PXOverride Methods

**Description:**  
All `[PXOverride]` methods MUST include a delegate parameter (`base_MethodName`) to ensure predictable execution order and proper base method invocation when multiple extensions override the same method.

**When to Apply (Symptoms):**
- PXOverride method lacks delegate parameter
- Override method directly reimplements logic instead of calling base
- Multiple extensions override same method with unpredictable results
- IEnumerable return types from overrides not executing previous overrides
- Task/Task<T> return types causing async execution bugs

**Core Transformation (Target State):**
- Every `[PXOverride]` method MUST have delegate parameter as final parameter
- Delegate parameter MUST be named `base_<MethodName>`
- Delegate signature MUST exactly match base method signature
- Override MUST call delegate to invoke base implementation when appropriate
- XML comment MUST reference overridden method: `/// Overrides <seealso cref="..."/>`

**Why It Matters in Acumatica:**
- Framework chains multiple overrides via delegate invocation
- Without delegate, execution order becomes unpredictable
- Return values from prior overrides are lost without delegate chain
- Async methods may not complete properly without delegate invocation

**Risks / Side Effects:**
- Adding delegate to existing overrides may change behavior if base was not called
- Signature changes require updating all call sites
- Performance overhead of delegate invocation is negligible but measurable

**Acceptance Criteria:**
- All PXOverride methods have delegate parameter
- Delegate naming follows `base_<MethodName>` convention
- XML documentation references base method with seealso tag
- Override logic invokes delegate at appropriate point
- Multiple extension override chain executes correctly

**Related Acumatica Mechanisms:**
`[PXOverride]`, `PXGraphExtension`, delegate invocation chain

**Common Anti-Patterns Nearby:**
- Override methods that completely replace base logic unnecessarily
- Missing delegate invocation causing base logic bypass
- Generic base methods (not supported for override)
- Virtual methods in Graph not marked for extension

---

### REF-003: Convert Service Classes to Abstract Graph Extensions

**Description:**  
Injectable service classes containing business logic MUST be refactored to abstract Graph Extensions. This ensures access to Graph lifecycle, cache operations, and extension customization capabilities.

**When to Apply (Symptoms):**
- Service class receives PXGraph as constructor parameter
- Service class performs cache operations on passed Graph
- Service class contains business rules that should be customizable
- Service class duplicates logic available in Graph
- Dependency injection used where Graph Extension pattern applies

**Core Transformation (Target State):**
- Service classes MUST become `abstract class ServiceExt<TGraph> : PXGraphExtension<TGraph>`
- Service MUST access Graph via `Base` property instead of injected parameter
- Service MUST be concrete per-Graph implementation inheriting abstract extension
- Operations MUST use Graph's cache instances directly
- IsActive() MUST control extension activation

**Why It Matters in Acumatica:**
- Graph Extensions have full access to Graph lifecycle and events
- Cache operations within extension maintain proper change tracking
- Extensions can be further extended by customizations
- Avoids Graph instance management complexity

**Risks / Side Effects:**
- Requires per-Graph concrete extension classes
- Cannot share single extension instance across multiple Graph types
- Testing approach changes from mocking services to extension patterns

**Acceptance Criteria:**
- No service classes receive PXGraph as constructor parameter
- All business logic services converted to abstract Graph Extensions
- Concrete extensions exist for each supported Graph type
- Extensions access caches via Base.Caches pattern
- Services maintain customization extensibility

**Related Acumatica Mechanisms:**
`PXGraphExtension<T>`, `Base` property, abstract extension pattern

**Common Anti-Patterns Nearby:**
- Constructor injection of PXGraph instances
- Static utility methods receiving Graph parameters
- Service locator patterns for Graph-dependent services

---

### REF-004: Make Graph Methods Virtual for Extensibility

**Description:**  
Graph methods that may require customization MUST be declared `virtual` to enable `[PXOverride]` from Graph Extensions. Static methods MUST NOT contain business logic.

**When to Apply (Symptoms):**
- Graph method cannot be overridden from extension
- Customization requires copy-paste of entire method
- Protected or private non-virtual methods contain extensible logic
- Static methods contain business rules
- Method behavior cannot be modified without source change

**Core Transformation (Target State):**
- Methods containing business logic MUST be `public virtual` or `protected virtual`
- Static methods MUST be utility-only, containing no business rules
- Method granularity SHOULD allow override of specific behaviors
- Complex methods SHOULD be decomposed into smaller virtual methods

**Why It Matters in Acumatica:**
- PXOverride only works with virtual methods
- Non-virtual methods force complete reimplementation in customizations
- Static methods bypass Graph lifecycle and cannot be customized
- Proper virtuality enables surgical customization

**Risks / Side Effects:**
- Virtual dispatch has minor performance cost
- Excessive virtuality may complicate debugging
- Breaking existing overrides if signature changes

**Acceptance Criteria:**
- Business logic methods are virtual
- No static methods contain business rules
- Method documentation indicates extension points
- Existing customizations continue functioning

**Related Acumatica Mechanisms:**
`virtual` keyword, `[PXOverride]`, method decomposition patterns

**Common Anti-Patterns Nearby:**
- Sealed methods in base Graphs
- Business logic in static helper classes
- Private methods performing key calculations

---

### REF-005: Create Graph Instances via PXGraph.CreateInstance

**Description:**  
Graph instances MUST be created via `PXGraph.CreateInstance<TGraph>()` (or equivalent framework factory methods) instead of direct `new` instantiation. This guarantees correct framework initialization and Graph Extension activation.

**When to Apply (Symptoms):**
- Code uses `new SomeGraph()` or `new PXGraph()` for business operations
- Utility code creates Graphs directly without framework factory
- Graph Extensions do not initialize as expected
- Graph-level events/attributes behave inconsistently between UI and background code

**Core Transformation (Target State):**
- Replace `new SomeGraph()` with `PXGraph.CreateInstance<SomeGraph>()`
- For non-generic `PXGraph`, use a framework-supported creation pattern (prefer a concrete Graph)
- Keep Graph creation close to usage; do not cache Graph instances statically

**Why It Matters in Acumatica:**
- Graphs are framework-managed components (caches, extensions, context)
- Factory creation ensures extensions and initialization hooks run predictably
- Improves compatibility with platform upgrades and customization layering

**Risks / Side Effects:**
- May activate extensions that were previously skipped due to incorrect instantiation
- Can expose hidden bugs that relied on incomplete initialization

**Acceptance Criteria:**
- No direct `new` instantiation of Graphs in application code
- Graph Extensions are initialized consistently
- Behavior remains logically equivalent in UI and non-UI execution paths

**Related Acumatica Mechanisms:**
`PXGraph.CreateInstance<T>()`, Graph initialization pipeline, Graph Extensions

**Common Anti-Patterns Nearby:**
- `static` cached Graph instances
- Graph creation in static helper methods
- Calling Graph actions from non-UI code

---

### REF-006: Fix Data View Declaration Order to Prevent Duplicate Cache Instances

**Description:**  
Data view declarations in a Graph SHOULD be ordered to avoid creating multiple `PXCache` instances for DACs in the same inheritance hierarchy (base/derived), or unexpected cache reuse across DACs.

**When to Apply (Symptoms):**
- Graph contains multiple views for DACs that participate in inheritance (base + derived DACs)
- Observed duplication of cache instances or inconsistent cache behavior
- Event handlers do not trigger as expected due to unexpected cache selection
- UI grids show inconsistent state or duplicate/phantom rows

**Core Transformation (Target State):**
- Reorder view declarations so cache creation follows the intended DAC hierarchy
- Ensure base DAC views are declared before derived DAC views when both exist
- Re-test screen behavior (events, caches, UI) after reordering

**Why It Matters in Acumatica:**
- Cache instantiation is influenced by view declaration order
- Wrong order can lead to duplicate caches and non-obvious behavior
- Stable cache identity is critical for event sequencing and data integrity

**Risks / Side Effects:**
- View ordering changes can affect event subscription and cache lifecycle
- Requires regression testing on the target screen

**Acceptance Criteria:**
- Cache instances are consistent and match the intended DAC usage
- No regressions in UI behavior or event execution
- Data view behavior is stable across navigation and refresh

**Related Acumatica Mechanisms:**
`PXCache`, view declaration order, cache identity rules

**Common Anti-Patterns Nearby:**
- Mixing base and derived DAC views without considering cache impact
- Copy-pasted views that unintentionally change cache creation order

---

### REF-007: Reset PXView.StartRow When View Delegate Implements Paging

**Description:**  
When a data view delegate performs paging internally (e.g., windowed selects), it MUST reset `PXView.StartRow` to prevent double application of paging.

**When to Apply (Symptoms):**
- Data view has an `IEnumerable` delegate that uses windowed/paged selects
- Grid paging behaves incorrectly (missing rows, unstable page boundaries)
- Duplicate paging is observed (paging applied by both delegate and framework)

**Core Transformation (Target State):**
- If the delegate applies paging, reset `PXView.StartRow = 0` after the internal select
- Ensure `PXView.TotalRows` is set appropriately when required
- Return the correct slice of rows for the current page

**Why It Matters in Acumatica:**
- Framework paging relies on `PXView.StartRow` and related state
- Delegates that also page must coordinate with framework paging
- Prevents subtle UI data issues without changing business logic

**Risks / Side Effects:**
- Incorrect total row calculation may impact paging UI
- Requires verification on screens with large datasets

**Acceptance Criteria:**
- Grid paging returns stable and complete results
- No skipped or duplicated rows across pages
- Delegate logic remains logically equivalent

**Related Acumatica Mechanisms:**
`PXView.StartRow`, `PXView.TotalRows`, view delegates, windowed selects

**Common Anti-Patterns Nearby:**
- Manual paging without resetting `StartRow`
- Delegates returning partial results without setting totals

---

### REF-008: Implement Meaningful IsActive() for Graph Extensions

**Description:**  
Graph Extensions SHOULD implement `public static bool IsActive()` with a meaningful activation condition (feature gating). Always-on `IsActive()` returning `true` MUST be avoided unless explicitly justified.

**When to Apply (Symptoms):**
- Graph Extension lacks `IsActive()`
- `IsActive()` exists but always returns `true` without explanation
- Feature checks are scattered inside event handlers and actions
- Extensions load on every screen even when a feature is not installed

**Core Transformation (Target State):**
- Add `public static bool IsActive()` to Graph Extensions
- Gate activation via `PXAccess.FeatureInstalled<TFeature>()` and/or setup-driven conditions
- If the extension must always be active, document the rationale and keep `IsActive()` omitted (or justify suppression)

**Why It Matters in Acumatica:**
- Extensions are loaded dynamically; unnecessary activation increases runtime overhead
- Feature gating centralizes activation logic and improves maintainability
- Reduces risk of unintended behavior when features are disabled

**Risks / Side Effects:**
- Incorrect gating condition can hide functionality
- Requires testing in both feature-enabled and feature-disabled environments

**Acceptance Criteria:**
- Extensions that represent optional features are feature-gated via `IsActive()`
- No unneeded always-on extensions
- Behavior remains logically equivalent when feature is enabled

**Related Acumatica Mechanisms:**
`PXGraphExtension<T>`, `IsActive()`, `PXAccess.FeatureInstalled<>`

**Common Anti-Patterns Nearby:**
- Inline `FeatureInstalled` checks in many places
- One extension implementing multiple unrelated features

---

### REF-009: Remove Constructors from Graph Extensions - Use Initialize()

**Description:**  
Graph Extensions MUST NOT use instance constructors for initialization. Initialization logic MUST be moved to `Initialize()` to follow framework lifecycle and avoid subtle ordering issues.

**When to Apply (Symptoms):**
- `PXGraphExtension<>` defines an instance constructor
- Constructor performs subscriptions, view/action initialization, or state setup
- Initialization executes unexpectedly early or in the wrong context

**Core Transformation (Target State):**
- Remove instance constructors from Graph Extensions
- Move initialization code to `public override void Initialize()`
- Keep `Initialize()` logic side-effect free (no DB writes, no long ops)

**Why It Matters in Acumatica:**
- Framework controls extension instantiation and lifecycle
- `Initialize()` is the supported hook for extension initialization
- Prevents ordering-dependent bugs when multiple extensions exist

**Risks / Side Effects:**
- Initialization timing changes slightly; validate behavior
- Constructor side effects may have masked other issues

**Acceptance Criteria:**
- No instance constructors exist on Graph Extensions
- Initialization runs in `Initialize()` and behaves predictably
- No regressions when multiple extensions are present

**Related Acumatica Mechanisms:**
`PXGraphExtension.Initialize()`, extension lifecycle

**Common Anti-Patterns Nearby:**
- Initialization logic in field initializers
- DB queries in extension initialization

---

### REF-010: Eliminate Static Views, Actions, and Mutable State in Graphs and Extensions

**Description:**  
Graphs and Graph Extensions MUST NOT declare static views/actions or static mutable state. Static state can leak data between sessions and cause hard-to-debug concurrency issues.

**When to Apply (Symptoms):**
- `static PXSelect...` / `static SelectFrom...` views exist
- `static PXAction...` actions exist
- Static fields store per-user or per-request state
- Behavior differs between users or sessions (state leakage)

**Core Transformation (Target State):**
- Move static views/actions to instance members
- Replace static mutable state with instance state on the Graph/Extension
- For caching, use framework-supported patterns (slots, prefetch) instead of ad-hoc statics

**Why It Matters in Acumatica:**
- Graphs are per-request/per-session components
- Static mutable state breaks isolation and can corrupt behavior
- Improves thread safety and predictability

**Risks / Side Effects:**
- Some performance assumptions may change; validate performance
- Requires careful audit if static values were used as caches

**Acceptance Criteria:**
- No static views or actions in Graphs/Extensions
- No static mutable state used for request/session behavior
- Concurrent users do not affect each other's data/state

**Related Acumatica Mechanisms:**
Graph instance lifecycle, `IPrefetchable`, slots, caching patterns

**Common Anti-Patterns Nearby:**
- Static dictionaries keyed by user
- Static caches without invalidation

---

### REF-011: Harden PXOverride Method Declarations

**Description:**  
`[PXOverride]` methods MUST follow Acumatica override contract rules beyond just having a delegate parameter (see also REF-002). This includes correct visibility, non-virtual declaration, and correct delegate signature.

**When to Apply (Symptoms):**
- `[PXOverride]` method is `private`/`protected` instead of `public`
- `[PXOverride]` method is declared `virtual`
- Delegate parameter signature does not match the overridden method
- Missing or incorrect XML documentation for the overridden method

**Core Transformation (Target State):**
- `[PXOverride]` methods MUST be `public` and MUST NOT be `virtual`
- Delegate parameter MUST be the last parameter and MUST match base signature exactly
- Delegate parameter naming MUST follow `base_<MethodName>` convention (see REF-002)
- Add XML comment: `/// Overrides <seealso cref="..."/>` referencing the overridden method

**Why It Matters in Acumatica:**
- Framework relies on a strict override contract to chain multiple extensions
- Violations cause unpredictable execution order or broken override chains
- Documentation clarifies extension intent and supports maintainability

**Risks / Side Effects:**
- Signature changes may require updating existing code
- Fixing contract issues can surface previously hidden override ordering problems

**Acceptance Criteria:**
- All PXOverride methods meet the contract (public, non-virtual, correct delegate)
- Override chains execute predictably with multiple extensions
- Documentation references are present and accurate

**Related Acumatica Mechanisms:**
`[PXOverride]`, override delegate chaining, extension ordering

**Common Anti-Patterns Nearby:**
- Using `[PXOverride]` on methods that are not extension points
- Replacing base logic entirely without calling delegate

---

### REF-012: Make Custom Exception Types Serializable for LongOps and Distributed Execution

**Description:**  
Custom exception types used in Acumatica applications SHOULD be properly serializable. This is especially important for Long Operations and distributed/clustered environments where exceptions may cross app-domain/process boundaries.

**When to Apply (Symptoms):**
- Custom exception type derives from `Exception` but lacks serialization constructor
- Custom exception adds fields but does not serialize them
- Long operation or processing screen fails to report custom exceptions reliably

**Core Transformation (Target State):**
- Add serialization constructor: `protected MyException(SerializationInfo info, StreamingContext context) : base(info, context) { ... }`
- If custom fields exist, override `GetObjectData` to include them
- Keep exception state minimal and serializable

**Why It Matters in Acumatica:**
- Framework may serialize exception information for UI feedback and background processing
- Non-serializable exceptions can degrade error reporting and supportability

**Risks / Side Effects:**
- Must ensure added fields are serializable
- Incorrect serialization can lose diagnostic details

**Acceptance Criteria:**
- Custom exceptions are serializable and preserve relevant details
- Long operation error reporting remains correct

**Related Acumatica Mechanisms:**
`PXLongOperation`, processing screens, exception propagation

**Common Anti-Patterns Nearby:**
- Storing Graph/Cache references inside exceptions
- Exception fields holding non-serializable objects

---

### REF-013: Make Framework Entities Public for Extensibility

**Description:**  
Framework entities (Graphs, DACs, and Extensions) intended for use by the platform or other modules SHOULD be declared `public`. Non-public entities reduce extensibility and can break tooling expectations.

**When to Apply (Symptoms):**
- Graph/DAC/Extension declared as `internal` in application code
- Tooling or reflection-based mechanisms cannot locate types
- Customizations cannot reference core entities

**Core Transformation (Target State):**
- Make Graph classes `public`
- Make DAC classes `public`
- Make Graph Extensions and DAC Extensions `public`
- Keep internal-only helper types `internal` (do not over-expose utilities)

**Why It Matters in Acumatica:**
- Customization and extension model expects public types
- Reflection-based frameworks and analyzers assume public visibility
- Improves reuse and upgrade safety

**Risks / Side Effects:**
- Public API surface increases; follow naming and documentation conventions

**Acceptance Criteria:**
- All framework-facing entities are public
- Internal-only helper types remain internal
- Customizations can reference the required types

**Related Acumatica Mechanisms:**
Customization model, Graph/DAC discovery, analyzers

**Common Anti-Patterns Nearby:**
- Hiding core types behind internal visibility
- Using internal Graphs as screen entry points

---

---

### REF-014: Use PXGraph.CreateInstance for Graph Creation in Static and Utility Methods

**Priority:** High  
**Importance:** High

**Description:**  
Static helper methods and utility classes that create Graph instances MUST use `PXGraph.CreateInstance<T>()`. They MUST NOT silently create Graphs via `new` or cache Graph instances in static fields.

**When to Apply (Symptoms):**
- Static method creates a Graph via `new TGraph()`
- Static field stores a Graph instance for reuse
- Utility class hides Graph creation from callers
- Graph Extensions do not activate in utility-created Graphs

**Core Transformation (Target State):**
- Replace `new TGraph()` with `PXGraph.CreateInstance<TGraph>()` in all static/utility methods
- Do not store Graph instances in static fields
- Pass Graph context into utility methods when a caller already has one (see REF-207)

**Why It Matters in Acumatica:**
- Consistent with REF-005; static contexts are a frequent source of incorrect Graph creation
- Extensions, caches, and event handlers depend on factory-based creation
- Architecture rules (§5.3) explicitly prohibit static business logic methods

**Risks / Side Effects:**
- Same as REF-005; may activate previously skipped extensions

**Acceptance Criteria:**
- No `new TGraph()` in static or utility methods
- No static Graph caching
- Graph Extensions activate consistently

**Related Acumatica Mechanisms:**
`PXGraph.CreateInstance<T>()`, Graph initialization pipeline

**Common Anti-Patterns Nearby:**
- Singleton-pattern Graphs
- Lazy-initialized static Graphs

---

### REF-015: Keep PXProtectedAccess Bridges Narrow

**Priority:** Medium  
**Importance:** High

**Description:**  
`[PXProtectedAccess]` bridges SHOULD expose only the minimum protected members needed for a specific extension point. Prefer normal `virtual` methods, graph extension APIs, or `[PXOverride]` when the base code can provide a cleaner extension seam.

**When to Apply (Symptoms):**
- `[PXProtectedAccess]` exposes many protected members without clear need
- Protected bridge exposes mutable internal state for convenience
- Bridge has no XML documentation pointing to the original member
- New base code uses `PXProtectedAccess` instead of adding a proper virtual extension point

**Core Transformation (Target State):**
- Replace broad protected bridges with focused `virtual` methods where possible
- Keep only required `[PXProtectedAccess]` abstract members
- Add XML documentation referencing the original protected member
- Avoid exposing mutable caches, dictionaries, counters, or operation state unless no safer seam exists

**Why It Matters in Acumatica:**
- Protected access is a powerful compatibility tool but creates fragile extension contracts
- Broad exposure makes later refactoring harder and can couple unrelated extensions to internal state
- Documentation helps reviewers and customizers understand why the bridge exists

**Risks / Side Effects:**
- Removing a protected bridge can break dependent extensions
- Replacing with a virtual method may require updating extension call sites

**Acceptance Criteria:**
- Protected bridge surface is minimal and justified
- Each exposed member has XML documentation referencing the source member
- New base code prefers proper virtual extension points when available

**Related Acumatica Mechanisms:**
`[PXProtectedAccess]`, `PXGraphExtension<T>`, `[PXOverride]`, protected extension points

**Common Anti-Patterns Nearby:**
- Exposing complete internal helper state through protected access
- Using protected access to avoid designing a stable override method

### Category B: DAC & Attributes (REF-1XX)

---

### REF-101: Use Auto-Implemented Properties in DACs

**Description:**  
DAC field properties MUST use auto-implemented property syntax. Explicit backing fields are prohibited unless technically required and documented.

**When to Apply (Symptoms):**
- DAC property has explicit backing field (`protected int? _FieldName;`)
- Property getter/setter explicitly references backing field
- Backing field and property have inconsistent nullability
- Property contains logic beyond simple get/set

**Core Transformation (Target State):**
- All DAC properties MUST use `{ get; set; }` auto-implementation
- No explicit backing fields UNLESS documented technical exception exists
- Property logic MUST move to attributes or event handlers
- Calculated values MUST use `[PXFormula]` or unbound fields

**Why It Matters in Acumatica:**
- Framework expects consistent property patterns
- Explicit backing fields can cause serialization issues
- Attribute-based behavior is upgrade-safe
- Simplifies DAC maintenance and readability

**Risks / Side Effects:**
- Existing code referencing backing field directly requires update
- Some legacy patterns may require backing field (document with reason)
- Computed properties need conversion to formulas

**Acceptance Criteria:**
- No DAC has explicit backing fields without documented exception
- All properties use auto-implemented syntax
- Property logic moved to appropriate attributes
- DAC serialization functions correctly

**Related Acumatica Mechanisms:**
Auto-implemented properties, `[PXFormula]`, `[PXDBCalced]`

**Common Anti-Patterns Nearby:**
- Logic in property getters/setters
- Lazy initialization in properties
- Side effects in property access

---

### REF-102: Match BQL Field Type to CLR Property Type

**Description:**  
BQL field classes MUST use strongly typed base classes that correspond exactly to their associated CLR property types. Type mismatches cause runtime errors and incorrect query behavior.

**When to Apply (Symptoms):**
- BQL field class uses `BqlType.Field<>` not matching property type
- `BqlString.Field` used for `int?` property
- `BqlInt.Field` used for `decimal?` property
- Query results contain unexpected type conversion errors
- Fluent BQL operations fail type checking

**Core Transformation (Target State):**
- `int?` properties MUST use `BqlInt.Field<fieldName>`
- `string` properties MUST use `BqlString.Field<fieldName>`
- `decimal?` properties MUST use `BqlDecimal.Field<fieldName>`
- `bool?` properties MUST use `BqlBool.Field<fieldName>`
- `DateTime?` properties MUST use `BqlDateTime.Field<fieldName>`
- `Guid?` properties MUST use `BqlGuid.Field<fieldName>`
- `byte[]` properties MUST use `BqlByteArray.Field<fieldName>`

**Why It Matters in Acumatica:**
- BQL uses field class type for SQL generation
- Mismatched types cause implicit SQL conversions
- Type operations (comparisons, aggregates) require correct types
- Compile-time safety lost with mismatched types

**Risks / Side Effects:**
- Fixing types may reveal hidden bugs in existing queries
- Attribute changes may be required alongside type fixes
- Generated SQL may change affecting query plans

**Acceptance Criteria:**
- Every BQL field class matches its property CLR type
- Attribute type aligns with BQL field type
- No type mismatch compiler warnings
- Query behavior unchanged or explicitly improved

**Related Acumatica Mechanisms:**
`BqlInt`, `BqlString`, `BqlDecimal`, `BqlBool`, `BqlDateTime`, `BqlGuid`, `BqlByteArray`

**Common Anti-Patterns Nearby:**
- Copy-paste BQL field declarations without type adjustment
- Using `IBqlField` interface directly instead of typed classes
- Untyped `PX.Data.BQL.BqlType.Field<>` usage

---

### REF-103: Define Primary Keys and Foreign Keys in DACs

**Description:**  
Every persistent DAC MUST define a `PK` nested class for primary key and `FK` static class for foreign key relationships. This enables optimized lookups and enforces referential integrity.

**When to Apply (Symptoms):**
- DAC lacks nested `PK` class
- DAC lacks `FK` class with relationship definitions
- Joins manually specify field matching instead of using FK
- `PXSelector` relationships not mirrored in FK class
- Parent-child relationships lack `[PXParent]` attributes

**Core Transformation (Target State):**
- DAC MUST have `public class PK : PrimaryKeyOf<DAC>.By<keyField>` nested class
- DAC MUST have `public static class FK` with relationship classes
- FK classes MUST use `ParentDAC.PK.ForeignKeyOf<ChildDAC>.By<foreignKeyField>` pattern
- Joins SHOULD use `FK` definitions: `.InnerJoin<Related>.On<DAC.FK.Related>`
- Parent relationships MUST have `[PXParent(typeof(FK.Parent))]` attributes

**Why It Matters in Acumatica:**
- PK.Find() provides optimized single-record lookup
- FK definitions enable compile-time join validation
- Framework uses FK for cascade operations
- Referential integrity enforced declaratively

**Risks / Side Effects:**
- Adding keys to existing DACs may expose integrity violations
- Composite keys require careful field ordering
- FK enforcement may block deletes of referenced records

**Acceptance Criteria:**
- All persistent DACs have PK class with Find() method
- All relationships expressed in FK class
- Joins use FK-based syntax where applicable
- Parent-child relationships use [PXParent] with FK reference

**Related Acumatica Mechanisms:**
`PrimaryKeyOf<T>.By<>`, `ForeignKeyOf<T>.By<>`, `[PXParent]`, `[PXForeignReference]`, `[PXDBDefault]`

**Common Anti-Patterns Nearby:**
- Manual key lookup with PXSelect instead of PK.Find()
- Joins with explicit field comparisons
- Missing cascade delete for child records

---

### REF-104: Add Mandatory System Fields to Persistent DACs

**Description:**  
Every persistent DAC MUST include standard system fields for audit tracking, concurrency control, and note/attachment support.

**When to Apply (Symptoms):**
- DAC lacks `CreatedByID`, `CreatedDateTime` fields
- DAC lacks `LastModifiedByID`, `LastModifiedDateTime` fields
- DAC lacks `tstamp` field for concurrency
- DAC lacks `NoteID` for attachments (when applicable)
- Audit trail not functioning for entity

**Core Transformation (Target State):**
- DAC MUST have `CreatedByID` with `[PXDBCreatedByID]`
- DAC MUST have `CreatedByScreenID` with `[PXDBCreatedByScreenID]`
- DAC MUST have `CreatedDateTime` with `[PXDBCreatedDateTime]`
- DAC MUST have `LastModifiedByID` with `[PXDBLastModifiedByID]`
- DAC MUST have `LastModifiedByScreenID` with `[PXDBLastModifiedByScreenID]`
- DAC MUST have `LastModifiedDateTime` with `[PXDBLastModifiedDateTime]`
- DAC MUST have `tstamp` with `[PXDBTimestamp]`
- DAC SHOULD have `NoteID` with `[PXNote]` for note/attachment support

**Why It Matters in Acumatica:**
- Framework populates audit fields automatically
- Timestamp field prevents concurrent update conflicts
- NoteID enables attachment and activity linkage
- Compliance requirements often mandate audit trails

**Risks / Side Effects:**
- Adding fields requires database schema migration
- Existing records need default value population
- Timestamp field affects update concurrency behavior

**Acceptance Criteria:**
- All persistent DACs have complete audit field set
- Fields have correct framework attributes
- Database schema includes corresponding columns
- Audit trail populates correctly on CRUD operations

**Related Acumatica Mechanisms:**
`[PXDBCreatedByID]`, `[PXDBLastModifiedByID]`, `[PXDBTimestamp]`, `[PXNote]`

**Common Anti-Patterns Nearby:**
- Manual audit field population
- Missing timestamp causing silent overwrites
- NoteID without proper foreign key setup

---

### REF-105: Avoid Unjustified DAC Extensions for Product-Owned Persistent Fields

**Description:**  
For product-owned persistent fields in product DACs, prefer adding fields directly to the DAC that owns the table. DAC/cache extensions are acceptable when the base DAC cannot or should not be modified, when the local architecture already uses a feature-owned extension pattern, or for unbound, calculated, projection-specific, integration, compatibility, or customization fields.

**When to Apply (Symptoms):**
- New product-owned persistent field is added through `PXCacheExtension<T>` without a justified extension scenario
- Multiple extensions fragment single entity definition
- The extension has no clear feature, compatibility, projection, integration, or customization boundary
- Extension is used merely to avoid editing the owning DAC

**Core Transformation (Target State):**
- Product-owned persistent fields SHOULD be added directly to the owning DAC.
- Keep DAC/cache extensions for justified extension scenarios.
- Existing internal extensions SHOULD migrate only when the migration is in scope and does not break compatibility.
- Extension pattern documentation MUST clarify why the extension boundary exists.

**Why It Matters in Acumatica:**
- Extensions fragment data model understanding
- Performance overhead of extension loading
- Debugging complexity with split definitions
- Schema visualization tools may miss extension fields

**Risks / Side Effects:**
- Migration may break external customizations referencing extensions
- Requires coordination if multiple teams modify same DAC
- Field order in DAC may affect UI layout
- Removing a valid feature-owned or compatibility extension can increase coupling

**Acceptance Criteria:**
- New product-owned persistent fields live in the owning DAC unless an allowed extension scenario is documented
- Existing extensions are left in place unless changing them is in scope and safe
- Clear organizational policy on extension usage
- Third-party customization and compatibility workflows remain supported

**Related Acumatica Mechanisms:**
`PXCacheExtension<T>`, DAC field ordering, feature-owned extensions, compatibility extensions, schema management

**Common Anti-Patterns Nearby:**
- Extension per feature creating extension proliferation
- Extensions with no IsActive() equivalent control
- Circular dependencies between DAC and extensions

---

### REF-106: Make Bound DAC Fields Nullable

**Description:**  
Bound DAC fields MUST use nullable CLR types (`int?`, `bool?`, `decimal?`, `DateTime?`, etc.). Non-nullable CLR types in bound fields lead to incorrect defaulting and persistence behavior.

**When to Apply (Symptoms):**
- Persistent DAC contains `int`, `bool`, `decimal`, `DateTime` (non-nullable) properties
- Framework defaults or validation behaves unexpectedly
- Database NULL values are not represented correctly in caches

**Core Transformation (Target State):**
- Convert bound DAC fields to nullable types (`int?`, `bool?`, `decimal?`, `DateTime?`, `Guid?`)
- Keep non-nullable types only for unbound/calculated properties that never map to DB

**Why It Matters in Acumatica:**
- `PXCache` and DB mapping expect NULL-capable fields for bound columns
- Defaulting and event chains assume nullable semantics

**Risks / Side Effects:**
- Code consuming these properties may need null-safe handling
- Serialization and UI formatting may reveal previously hidden nullability issues

**Acceptance Criteria:**
- All bound DAC properties use nullable CLR types
- Persistence and UI behavior remains logically equivalent

**Related Acumatica Mechanisms:**
`PXCache`, bound vs unbound fields, persistence mapping

**Common Anti-Patterns Nearby:**
- Using `0`/`false` as a surrogate for NULL

---

### REF-107: Add Matching Type Attribute for List Attributes

**Description:**  
Fields using list attributes (e.g., `PXStringList`, `PXIntList`) MUST also have an appropriate type attribute (`PXString`/`PXDBString`, `PXInt`/`PXDBInt`, etc.).

**When to Apply (Symptoms):**
- Field has `PXStringList` but no `PXString`/`PXDBString`
- Field has `PXIntList` but no `PXInt`/`PXDBInt`
- UI dropdown behaves inconsistently or has incorrect formatting

**Core Transformation (Target State):**
- Add the correct type attribute matching the field CLR/DB type
- Ensure attribute order follows Acumatica conventions (DB/type before UI/list)

**Why It Matters in Acumatica:**
- Type attributes define DB mapping and UI formatting
- List attributes rely on a correct underlying type for consistent behavior

**Risks / Side Effects:**
- Incorrect type selection may change formatting or persistence behavior

**Acceptance Criteria:**
- Every list attribute has a matching type attribute on the same field

**Related Acumatica Mechanisms:**
`PXDBString`, `PXString`, `PXDBInt`, `PXInt`, `PXStringList`, `PXIntList`

**Common Anti-Patterns Nearby:**
- Adding list attributes by copy-paste without type attributes

---

### REF-108: Align Field Type Attributes with CLR Property Types

**Description:**  
Field type attributes (`PXDBInt`, `PXDBString`, `PXDBDecimal`, etc.) MUST match the CLR property type they decorate.

**When to Apply (Symptoms):**
- CLR property type and DB attribute type are inconsistent
- Runtime conversion errors or unexpected persisted values
- Fields display incorrectly in the UI

**Core Transformation (Target State):**
- Update type attributes to match the CLR property type (preferred)
- Alternatively, update the CLR property type to match the attribute (when the attribute is the source of truth)

**Why It Matters in Acumatica:**
- Type attributes drive SQL generation and cache behavior
- Mismatches cause implicit conversions and runtime failures

**Risks / Side Effects:**
- Fixing mismatches may change generated SQL and query plans

**Acceptance Criteria:**
- CLR type, BQL field type, and attribute type are consistent
- No runtime conversion errors

**Related Acumatica Mechanisms:**
`PXDB*` attributes, `PX*` unbound attributes, BQL field types

**Common Anti-Patterns Nearby:**
- Mixing `PXDBInt` with `string` properties

---

### REF-109: Remove Multiple Type Attributes and Conflicting Special Attributes

**Description:**  
A field MUST NOT have multiple competing type attributes (e.g., `PXDBInt` and `PXDBString`) or conflicting special attributes (`PXDBScalar` with `PXDBCalced`, etc.).

**When to Apply (Symptoms):**
- More than one `PXDB*`/`PX*` type attribute is present on a single field
- Special attribute combinations produce ambiguous behavior
- Analyzer warnings about duplicate/conflicting attributes

**Core Transformation (Target State):**
- Keep exactly one correct type attribute
- Keep only one of `PXDBScalar` / `PXDBCalced` when applicable
- Ensure resulting attribute stack matches intended persistence semantics

**Why It Matters in Acumatica:**
- Attribute stacks are executed in order; conflicting types cause undefined behavior
- Prevents subtle persistence and UI issues

**Risks / Side Effects:**
- Removing attributes may reveal reliance on incorrect behavior

**Acceptance Criteria:**
- Each field has a single unambiguous type definition
- Persistence/UI behavior remains logically equivalent

**Related Acumatica Mechanisms:**
Attribute stacking rules, `PXDBScalar`, `PXDBCalced`

**Common Anti-Patterns Nearby:**
- Copy-pasting attributes from unrelated fields

---

### REF-110: Make DAC BQL Field Nested Classes Public and Abstract

**Description:**  
DAC nested BQL field classes SHOULD be declared `public abstract` to match framework conventions and improve interoperability with Fluent BQL and analyzers.

**When to Apply (Symptoms):**
- Nested field classes are not `abstract`
- Nested field classes are `protected`/`internal` without justification
- Analyzer warnings about field class modifiers

**Core Transformation (Target State):**
- Declare nested field classes as `public abstract class fieldName : ... { }`
- Use typed field bases (`BqlInt.Field<>`, `BqlString.Field<>`, etc.) per REF-102

**Why It Matters in Acumatica:**
- Consistent field modifiers improve discoverability and tooling
- Aligns with framework expectations for BQL field identity

**Risks / Side Effects:**
- Visibility changes may expose field types to external assemblies (generally desired)

**Acceptance Criteria:**
- All nested BQL field classes follow `public abstract` convention

**Related Acumatica Mechanisms:**
BQL field classes, Fluent BQL (`SelectFrom<>`)

**Common Anti-Patterns Nearby:**
- `public class fieldName : IBqlField { }`

---

### REF-111: Remove Constructors from DACs and DAC Extensions

**Description:**  
DACs and DAC Extensions MUST NOT declare constructors. Defaulting and initialization logic MUST be expressed via attributes and event handlers.

**When to Apply (Symptoms):**
- DAC declares an instance constructor
- DAC Extension declares an instance constructor
- Constructor assigns default values to fields

**Core Transformation (Target State):**
- Remove constructors from DACs and DAC Extensions
- Move defaulting to `FieldDefaulting`, `RowInserting`, or declarative attributes (`PXDefault`, `PXFormula`)

**Why It Matters in Acumatica:**
- DAC instances are framework-managed; constructors are not a supported defaulting mechanism
- Constructor logic can conflict with cache defaulting and event chains

**Risks / Side Effects:**
- Defaulting behavior may change if constructor previously bypassed event chain

**Acceptance Criteria:**
- No constructors exist in DACs/DAC Extensions
- Default values are produced via supported mechanisms

**Related Acumatica Mechanisms:**
`FieldDefaulting`, `RowInserting`, `[PXDefault]`, `[PXFormula]`

**Common Anti-Patterns Nearby:**
- Setting defaults in constructors

---

### REF-112: Fix AutoNumber Field Type and Length

**Description:**  
Fields using `[AutoNumber]` MUST be `string`-typed and the field length MUST be sufficient for the numbering sequence.

**When to Apply (Symptoms):**
- `[AutoNumber]` is applied to a non-string field
- `PXDBString` length is shorter than possible generated numbers
- Number values are truncated or cause persistence errors

**Core Transformation (Target State):**
- Ensure the CLR property type is `string`
- Ensure `PXDBString(length)` is long enough for the numbering sequence format
- Keep UI formatting consistent with `PXUIField`

**Why It Matters in Acumatica:**
- Auto-numbering generates string keys
- Insufficient length causes truncation and data integrity issues

**Risks / Side Effects:**
- Increasing DB field length may require a DB schema update

**Acceptance Criteria:**
- Auto-numbered fields are `string` with sufficient length
- Generated numbers persist without truncation

**Related Acumatica Mechanisms:**
`[AutoNumber]`, numbering sequences, `PXDBString`

**Common Anti-Patterns Nearby:**
- Using `int` for document numbers

---

### REF-113: Normalize PK/FK/UK Structure and Naming in DACs

**Description:**  
Persistent DACs SHOULD define keys using standard nested class structure and naming conventions for `PK`, `FK`, and (when applicable) `UK` (unique keys). This improves readability, join safety, and automated refactoring.

**When to Apply (Symptoms):**
- PK/FK definitions exist but do not follow standard structure or naming
- Unique keys are implemented ad-hoc via selectors or queries only
- Joins do not use key-based patterns

**Core Transformation (Target State):**
- Keep `PK` as a single nested class using `PrimaryKeyOf<>.By<>`
- Keep `FK` as a `public static class FK` container
- Define unique keys via `UK` class/container when uniqueness is a stable business invariant
- Prefer FK-based join syntax where applicable

**Why It Matters in Acumatica:**
- Key definitions improve compile-time safety for joins
- Standard structure supports tools and automated agents
- Unique keys simplify lookups without changing business logic

**Risks / Side Effects:**
- Declaring unique keys may expose existing data quality issues

**Acceptance Criteria:**
- PK/FK/UK key structure follows conventions
- Codebase uses key-based joins where practical

**Related Acumatica Mechanisms:**
`PrimaryKeyOf<>`, `ForeignKeyOf<>`, key containers, FK-based joins

**Common Anti-Patterns Nearby:**
- Manual joins with field comparisons
- Repeated PXSelect lookups instead of key-based Find()

---

### REF-114: Strongly-Type BQL Constants for Fluent BQL Compatibility

**Description:**  
BQL constants SHOULD be expressed as strongly typed constants (`BqlString.Constant<>`, `BqlInt.Constant<>`, etc.) to support Fluent BQL and compile-time type safety.

**When to Apply (Symptoms):**
- Constants are declared using untyped/legacy patterns
- Fluent BQL requires explicit casts or produces analyzer warnings
- Constants are duplicated as literals in multiple queries

**Core Transformation (Target State):**
- Use strongly typed constant bases (`BqlString.Constant<>`, `BqlInt.Constant<>`, `BqlDecimal.Constant<>`, etc.)
- Centralize constants in a dedicated `Constants` class/namespace

**Why It Matters in Acumatica:**
- Strong typing improves query safety and refactorability
- Reduces duplication and accidental inconsistencies

**Risks / Side Effects:**
- Signature changes may require updating BQL expressions using the constants

**Acceptance Criteria:**
- Constants used in BQL are strongly typed
- Fluent BQL expressions compile cleanly

**Related Acumatica Mechanisms:**
BQL constants, Fluent BQL

**Common Anti-Patterns Nearby:**
- Magic literals embedded in BQL

---

### REF-115: Ensure Every DAC Is Either PXHidden or PXCacheName

**Description:**  
Every DAC MUST either be marked as `[PXHidden]` (technical/internal DAC) or provide a user-facing cache name via `[PXCacheName("...")]`.

**When to Apply (Symptoms):**
- DAC has no `[PXHidden]` and no `[PXCacheName]`
- UI displays an unfriendly DAC name
- Endpoint/schema consumers lack a meaningful entity name

**Core Transformation (Target State):**
- Add `[PXHidden]` for internal/technical DACs not meant for UI
- Add `[PXCacheName("...")]` for DACs shown in UI or exposed externally

**Why It Matters in Acumatica:**
- Cache names affect UI labels, traceability, and support experience
- Hidden DACs avoid accidental UI exposure

**Risks / Side Effects:**
- UI labels may change (usually improvement)

**Acceptance Criteria:**
- Every DAC is either hidden or has an explicit cache name

**Related Acumatica Mechanisms:**
`[PXHidden]`, `[PXCacheName]`

**Common Anti-Patterns Nearby:**
- Leaving DACs without naming/visibility intent

---

### REF-116: Add Unbound Type Attributes for PXDBCalced and PXDBScalar Fields

**Description:**  
Fields using `PXDBCalced` or `PXDBScalar` MUST include an unbound type attribute (`PXDecimal`, `PXDate`, `PXString`, etc.) to define the field type for cache/UI behavior.

**When to Apply (Symptoms):**
- `PXDBCalced`/`PXDBScalar` is present without a corresponding unbound type attribute
- UI formatting is incorrect for calculated/scalar fields
- Analyzer warnings about missing type attributes

**Core Transformation (Target State):**
- Add a matching unbound type attribute based on the calculated/scalar result type
- Keep the attribute stack consistent with the field's intended semantics

**Why It Matters in Acumatica:**
- Calculated/scalar fields still require a type definition for cache/UI
- Prevents ambiguous formatting and runtime issues

**Risks / Side Effects:**
- Incorrect chosen type can change formatting; verify results

**Acceptance Criteria:**
- All `PXDBCalced`/`PXDBScalar` fields have a matching unbound type attribute

**Related Acumatica Mechanisms:**
`PXDBCalced`, `PXDBScalar`, `PXDecimal`, `PXDate`, `PXString`

**Common Anti-Patterns Nearby:**
- Assuming SQL expression type is sufficient without a type attribute

---

### REF-117: Ensure NoteID Exists When PXDBLocalizableString Is Used

**Description:**  
If a DAC uses `PXDBLocalizableString`, it MUST contain a `NoteID` field to support localization infrastructure.

**When to Apply (Symptoms):**
- DAC has `PXDBLocalizableString` fields but no `NoteID`
- Localization features behave incorrectly or cannot persist localized values

**Core Transformation (Target State):**
- Add `NoteID` field with `[PXNote]` to the DAC
- Ensure the DAC is persistent and supports note infrastructure as intended

**Why It Matters in Acumatica:**
- Localization metadata relies on `NoteID` linkage
- Ensures consistent behavior across screens and endpoints

**Risks / Side Effects:**
- Adding NoteID requires DB schema update for persistent tables

**Acceptance Criteria:**
- DACs using `PXDBLocalizableString` have `NoteID`
- Localized values persist and display correctly

**Related Acumatica Mechanisms:**
`PXDBLocalizableString`, `[PXNote]`, note infrastructure

**Common Anti-Patterns Nearby:**
- Using localizable string attributes without note support

---

### REF-118: Ensure Every DAC Property Has a Corresponding BQL Field

**Description:**  
Each DAC property MUST have a corresponding nested BQL field class with the correct name and type. Missing or mismatched BQL fields break BQL queries, attributes, and tooling.

**When to Apply (Symptoms):**
- Property exists but nested BQL field class is missing
- BQL field class name does not match the property name
- Analyzer warnings about missing/incorrect BQL field declarations
- Queries fail or require string-based field references

**Core Transformation (Target State):**
- Add missing BQL nested classes for each DAC property
- Ensure naming matches the property (`public abstract class fieldName : ...`)
- Ensure BQL field type matches the CLR property type (see REF-102)

**Why It Matters in Acumatica:**
- BQL relies on nested field classes as canonical field identifiers
- Consistent declarations enable automated refactoring and compile-time safety

**Risks / Side Effects:**
- May reveal previously hidden query issues

**Acceptance Criteria:**
- Every DAC property has a matching BQL nested field class
- Names and types are consistent

**Related Acumatica Mechanisms:**
Nested BQL fields, BQL compilation, tooling

**Common Anti-Patterns Nearby:**
- Using `nameof(Field)` in BQL instead of nested classes

---

### REF-119: Fix Referenced Field Type and Size Mismatch Across DACs

**Description:**  
Fields that represent the same conceptual value across DACs (selectors, projections, joins, mapped fields) SHOULD have consistent types and sizes. Mismatches cause truncation, conversion, and join performance issues.

**When to Apply (Symptoms):**
- `PXDBString` length differs between referencing and referenced fields
- `PXDBInt` vs `PXDBLong` mismatches for keys
- Projection or mapped field type/size does not match the source DAC

**Core Transformation (Target State):**
- Align type attributes (`PXDB*`) with the source field
- Align string lengths to the source field length
- Align CLR property types accordingly

**Why It Matters in Acumatica:**
- Consistent field definitions prevent data loss and implicit conversions
- Join performance improves when types match

**Risks / Side Effects:**
- Schema changes may be required

**Acceptance Criteria:**
- Referencing and referenced field types/sizes are consistent
- No truncation or conversion warnings

**Related Acumatica Mechanisms:**
Selectors, projections, mapped fields, joins

**Common Anti-Patterns Nearby:**
- Declaring a short string for a long key field

---

### REF-120: Add XML Documentation for Public DACs and Extensions

**Description:**  
Public DACs and Extensions SHOULD provide XML documentation (or be explicitly excluded) to improve maintainability, schema readability, and tooling output.

**When to Apply (Symptoms):**
- Public DAC or DAC extension has no XML doc
- Projection/mapped fields lack `inheritdoc` or mapping documentation
- Tooling output (DAC reference) is incomplete or unclear

**Core Transformation (Target State):**
- Add `/// <summary>...</summary>` to DACs and important fields
- Use `inheritdoc` where fields are mapped from base DACs/projections
- If a DAC is not intended to be documented/exposed, consider `[PXHidden]`

**Why It Matters in Acumatica:**
- Improves developer experience and upgrade support
- Clarifies field intent and projection mappings

**Risks / Side Effects:**
- None (documentation-only)

**Acceptance Criteria:**
- Public DACs/extensions have meaningful XML documentation or are intentionally hidden

**Related Acumatica Mechanisms:**
DAC references, projections, mapping attributes

**Common Anti-Patterns Nearby:**
- Public types with no documentation

---

---

### REF-121: DAC Must Inherit PXBqlTable and IBqlTable

**Priority:** High  
**Importance:** Critical

**Description:**  
Every DAC MUST inherit from `PXBqlTable` and implement `IBqlTable`. DACs using legacy patterns (only `IBqlTable` without `PXBqlTable`) SHOULD be updated for Fluent BQL compatibility and framework consistency.

**When to Apply (Symptoms):**
- DAC declares only `: IBqlTable` without `PXBqlTable` base class
- Fluent BQL queries cannot reference the DAC
- Analyzer warnings about DAC base type

**Core Transformation (Target State):**
- Ensure DAC declaration follows: `public class MyDAC : PXBqlTable, IBqlTable`
- Keep existing attributes (`[Serializable]`, `[PXCacheName]`, etc.)

**Why It Matters in Acumatica:**
- `PXBqlTable` provides Fluent BQL integration
- Framework tooling and analyzers expect this base class
- Required for modern `SelectFrom<>` usage
- Architecture rules (§2.1) mandate this structure

**Risks / Side Effects:**
- Adding base class to legacy DACs is generally safe
- Very old DACs may have custom base classes that need review

**Acceptance Criteria:**
- All DACs inherit from `PXBqlTable` and implement `IBqlTable`

**Related Acumatica Mechanisms:**
`PXBqlTable`, `IBqlTable`, Fluent BQL

**Common Anti-Patterns Nearby:**
- Legacy DACs inheriting only `IBqlTable`

---

### REF-122: Ensure DACs Are Marked Serializable

**Priority:** Medium  
**Importance:** High

**Description:**  
DACs MUST be decorated with `[Serializable]` to support framework serialization requirements (session state, long operations, ViewState).

**When to Apply (Symptoms):**
- DAC lacks `[Serializable]` attribute
- Serialization failures in long operations or session state
- Analyzer warnings about missing serialization attribute

**Core Transformation (Target State):**
- Add `[Serializable]` attribute to all DAC classes
- Place `[Serializable]` before other class-level attributes per convention

**Why It Matters in Acumatica:**
- Framework serializes DAC instances for session state and long operations
- Missing attribute causes runtime serialization failures
- Architecture rules (§2.1) show `[Serializable]` as mandatory

**Risks / Side Effects:**
- None for compliant DACs

**Acceptance Criteria:**
- All DACs have `[Serializable]` attribute

**Related Acumatica Mechanisms:**
Session state, `PXLongOperation`, DAC serialization

**Common Anti-Patterns Nearby:**
- Missing `[Serializable]` on new DACs

---

### REF-123: Synchronize DAC Changes with DatabaseModel.sqlproj

**Priority:** High  
**Importance:** Critical

**Description:**  
When modifying persistent DACs (adding fields, changing types, adding keys), the corresponding `.sql` file in `DatabaseModel.sqlproj` MUST be updated to keep the DAC and database schema in sync.

**When to Apply (Symptoms):**
- New DAC field added without corresponding SQL column
- DAC field type changed but SQL column type unchanged
- Primary key or foreign key added to DAC but not to SQL schema
- Index requirements identified but not reflected in SQL
- Database migration script missing for DAC changes

**Core Transformation (Target State):**
- For each DAC field change, update the corresponding `CREATE TABLE` statement in `DatabaseModel.sqlproj`
- Follow SQL naming conventions:
  - Primary Key: `[TableName_PK]`
  - Unique Constraint: `[TableName_ColumnName]`
  - Foreign Key: `[TableName_FK_ReferencedTable]`
  - Index: `[TableName_ColumnName]`
- Match DAC attribute types to SQL types per correlation table:

| DAC Attribute | SQL Type |
|---------------|----------|
| `[PXDBIdentity]` | `INT NOT NULL IDENTITY` |
| `[PXDBInt]` | `INT NULL/NOT NULL` |
| `[PXDBString(30)]` | `NVARCHAR(30)` |
| `[PXDBString(1, IsFixed = true)]` | `CHAR(1)` |
| `[PXDBBool]` | `BIT` |
| `[PXDBDecimal(6)]` | `DECIMAL(25,6)` |
| `[PXDBDate]` | `DATETIME` |
| `[PXDBGuid]` | `UNIQUEIDENTIFIER` |
| `[PXDBTimestamp]` | `TIMESTAMP NOT NULL` |

**Why It Matters in Acumatica:**
- Schema drift causes deployment failures and data integrity issues
- DatabaseModel.sqlproj is the single source of truth for database schema
- Architecture rules (§14) make this a mandatory step
- Audit fields, timestamps, and keys all require SQL schema alignment

**Risks / Side Effects:**
- Forgetting SQL update causes runtime errors on fresh installs
- Column type mismatches cause silent data truncation or conversion errors

**Acceptance Criteria:**
- Every DAC field modification has a corresponding SQL file update
- SQL types match DAC attribute types per correlation table
- Naming conventions followed for constraints and indexes
- Schema compiles without errors

**Related Acumatica Mechanisms:**
`DatabaseModel.sqlproj`, DAC-to-SQL mapping, schema management

**Common Anti-Patterns Nearby:**
- Adding DAC fields without SQL schema updates
- Mismatched column types between DAC and SQL
- Missing indexes for frequently queried fields

---

### REF-124: Use Narrow Attribute Modification in CacheAttached

**Priority:** Medium  
**Importance:** High

**Description:**  
`CacheAttached` attribute modifications MUST preserve base field semantics unless the PR intentionally replaces them. Prefer narrow merges over broad replacement or removal of base attributes.

**When to Apply (Symptoms):**
- `PXMergeAttributes(Method = MergeMethod.Replace)` used without a clear reason
- `PXRemoveBaseAttribute` removes defaulting, formula, selector, restrictor, note, searchable, DB, or security-related behavior
- Field behavior differs across graphs after an attribute override
- Import/API, workflow, or persistence behavior changes unexpectedly after attribute modification

**Core Transformation (Target State):**
- Prefer `PXMergeAttributes(Method = MergeMethod.Append)` or `Merge`
- Remove base attributes only when the removed behavior is explicitly replaced or no longer valid
- Keep DB/type attributes, defaults, formulas, selectors, restrictors, notes, searchable attributes, and security behavior consistent with the intended field contract
- Add focused validation for defaulting, verification, UI state, persistence, import/API, and workflow/action availability affected by the field

**Why It Matters in Acumatica:**
- Attributes define framework behavior across UI, cache, persistence, import, and API paths
- Removing one base attribute can silently bypass validation, defaults, formulas, selectors, or access rules
- Narrow merges reduce regression risk and preserve customization compatibility

**Risks / Side Effects:**
- Preserving a base attribute may keep behavior that the feature intentionally needs to replace
- Removing an attribute may be valid but requires explicit validation of the replacement behavior

**Acceptance Criteria:**
- Attribute changes use the narrowest merge method that satisfies the requirement
- Any base attribute removal is justified by behavior, not convenience
- Affected field behavior is validated across UI, persistence, and non-UI entry paths

**Related Acumatica Mechanisms:**
`CacheAttached`, `PXMergeAttributes`, `PXRemoveBaseAttribute`, `PXCustomizeBaseAttribute`, field attributes

**Common Anti-Patterns Nearby:**
- Replacing all attributes to change only display metadata
- Removing `PXDefault`, `PXFormula`, `PXRestrictor`, or selector attributes without equivalent behavior

---

### REF-125: Preserve Persisted Status and List Constants

**Priority:** High  
**Importance:** High

**Description:**  
Persisted list values, document types, and status codes are data contracts. Existing persisted values MUST NOT be changed or reused with a different meaning without migration and compatibility analysis.

**When to Apply (Symptoms):**
- Existing `PXStringList` / `PXIntList` value changes
- A status or document type constant is reused with a new meaning
- New status/list value is added without workflow, selector, report, API, or migration review
- Display label changes hide a semantic change to persisted data

**Core Transformation (Target State):**
- Keep existing persisted constant values stable
- Add new values instead of reusing old values for new meanings
- Update workflow, selectors, reports, Generic Inquiries, import/export, API/OData exposure, and migration scripts when a new persisted value is introduced
- Document compatibility impact when changing a persisted value is unavoidable

**Why It Matters in Acumatica:**
- Persisted codes are stored in customer databases and used by workflows, reports, integrations, GIs, and imports
- Reusing or changing values can corrupt historical interpretation and break integrations
- Stable constants preserve upgrade compatibility

**Risks / Side Effects:**
- Adding a value can expand workflow and testing matrix
- Migration may be required for existing rows or external integrations

**Acceptance Criteria:**
- Existing persisted values remain stable
- New values include workflow and public-surface impact review
- Migration and compatibility plan exists for any unavoidable value change

**Related Acumatica Mechanisms:**
`PXStringListAttribute`, `PXIntListAttribute`, BQL constants, workflow statuses, document types

**Common Anti-Patterns Nearby:**
- Reusing an obsolete status code for a new lifecycle state
- Updating labels without checking downstream integrations and reports

### Category C: BQL & Data Access (REF-2XX)

---

### REF-201: Use Fluent BQL Instead of Classic BQL

**Description:**  
New code SHOULD use Fluent BQL (`SelectFrom<>`, `SearchFor<>`) wherever the expression can be represented clearly. Fluent BQL provides better type safety and readability. Existing classic BQL does not need to be rewritten solely for style.

**When to Apply (Symptoms):**
- New standalone query is introduced with classic `PXSelect<T, Where<...>>` syntax where Fluent BQL would be clear
- New search uses `Search<>` where `SearchFor<>` would be clear
- Join conditions manually specified with `And` chains
- Code mixes classic and Fluent BQL inside the same tightly related new block without a readability or safety reason

**Core Transformation (Target State):**
- New standalone views SHOULD use `SelectFrom<T>.Where<>.View` pattern
- New searches SHOULD use `SearchFor<>` syntax
- New joins SHOULD use `InnerJoin<T>.On<T.FK.Related>` pattern when FK definitions exist
- Parameters SHOULD use strongly-typed `.FromCurrent` syntax
- Preserve dense legacy classic BQL when rewriting it would broaden scope or reduce local consistency without reducing risk

**Why It Matters in Acumatica:**
- Fluent BQL provides compile-time type checking
- IDE support for autocomplete and refactoring
- FK-based joins catch relationship errors at compile time
- Cleaner, more maintainable query syntax

**Risks / Side Effects:**
- Large-scale conversion is time-consuming
- Some edge cases may not have Fluent equivalent
- Team must learn new syntax patterns
- Mechanical conversion can introduce regressions in mature legacy queries

**Acceptance Criteria:**
- New standalone queries use Fluent BQL where practical
- Existing classic BQL is not rewritten unless it is part of the changed behavior or materially improves safety/readability
- Migrated queries produce identical results
- Complex queries validate with integration tests
- Performance characteristics unchanged

**Related Acumatica Mechanisms:**
`SelectFrom<>`, `SearchFor<>`, `InnerJoin<>.On<>`, `.FromCurrent`, `.SameAsCurrent`

**Common Anti-Patterns Nearby:**
- Mixing classic and Fluent BQL in same file
- String-based field references
- Untyped parameter passing

---

### REF-202: Replace Direct SQL and Review Low-Level PXDatabase Mutations

**Description:**  
Native SQL and ad hoc database access MUST be replaced with BQL, Fluent BQL, or cache operations. `PXDatabase.Insert/Update/Delete` is a low-level framework mechanism: treat it as a review signal, not an automatic violation. It is acceptable only for documented infrastructure, upgrade/migration, integrity/rebuild, setup-slot, or carefully scoped bulk operations where bypassing cache/events is intentional.

**When to Apply (Symptoms):**
- Code executes raw SQL strings
- Code uses direct database providers or command text outside approved framework paths
- Code uses `PXDatabase.Insert`, `PXDatabase.Update`, or `PXDatabase.Delete` in normal document-entry or business-flow logic
- Code uses `PXDatabase.SelectSingle` for mutable per-document data where BQL/cache context is required
- Database changes not reflected in cache
- Events not firing for data modifications

**Core Transformation (Target State):**
- Raw SQL MUST be removed.
- Normal business data reads MUST use BQL views or `SelectFrom<>` queries.
- Normal inserts MUST use `cache.Insert(dac)` pattern.
- Normal updates MUST use `cache.Update(dac)` pattern.
- Normal deletes MUST use `cache.Delete(dac)` pattern.
- Batch operations SHOULD use `PXSelectBase.View.SelectMulti()` with cache operations
- Low-level `PXDatabase` mutations MUST be documented by purpose and scoped to rows that are safe to update without cache events.

**Why It Matters in Acumatica:**
- Cache operations trigger event handlers
- Security restrictions enforced through cache
- Customization overrides respected
- Audit trail populated correctly
- Transaction management coordinated

**Risks / Side Effects:**
- Performance characteristics may change
- Batch operations may need chunking
- Replacing legitimate rebuild or upgrade logic with cache operations can make processing too slow or change semantics
- Mixed direct and cache operations can leave stale cache state

**Acceptance Criteria:**
- No raw SQL or direct provider calls remain.
- Normal business data modifications go through appropriate cache.
- Any remaining `PXDatabase.Insert/Update/Delete` has an explicit low-level purpose and does not rely on cache events.
- Events fire correctly for data changes
- Security restrictions enforced

**Related Acumatica Mechanisms:**
`PXCache.Insert/Update/Delete`, BQL views, event handlers, `PXDatabase`, `PXTransactionScope`

**Common Anti-Patterns Nearby:**
- Raw SQL for "performance optimization"
- Bypassing validation via direct database access
- Mixed direct and cache operations in same transaction

---

### REF-203: Eliminate BQL Queries Inside Loops

**Description:**  
BQL queries executed inside loops create N+1 query patterns causing severe performance degradation. Queries MUST be moved outside loops and results cached or use batch retrieval patterns.

**When to Apply (Symptoms):**
- `PXSelect` or `SelectFrom` appears inside `foreach` loop
- `.Select()` called multiple times with different parameters
- Query in loop body retrieves single related record
- Database query count scales with data volume
- Performance degrades linearly with record count

**Core Transformation (Target State):**
- Related data MUST be fetched before loop via join or batch query
- Results MUST be indexed in dictionary for O(1) lookup
- Joins SHOULD be added to view definition when relationships exist
- `PXSelectReadonly` SHOULD be used for read-only batch fetches
- `PXFieldScope` SHOULD limit returned columns

**Why It Matters in Acumatica:**
- Each BQL query has round-trip overhead
- N+1 pattern multiplies database load
- User experience degrades with data growth
- Server resources exhausted under load

**Risks / Side Effects:**
- Batch query may retrieve unnecessary data
- Memory usage increases with prefetching
- Cache coherence must be considered

**Acceptance Criteria:**
- No queries inside loop bodies
- Related data prefetched and indexed
- Query count constant regardless of row count
- Performance tested with production data volumes

**Related Acumatica Mechanisms:**
Join optimization, `PXFieldScope`, `ReadBranchRestrictedScope`, dictionary caching

**Common Anti-Patterns Nearby:**
- Lazy loading patterns that execute queries on access
- Helper methods that hide query-per-call behavior
- LINQ queries that translate to multiple SQL statements

---

### REF-204: Use PXProjection for Complex Read-Only Queries

**Description:**  
Complex queries involving multiple joins, aggregations, or calculations that are read-only SHOULD use `[PXProjection]` DACs instead of inline BQL with projections.

**When to Apply (Symptoms):**
- Same complex query appears in multiple Graphs
- Query involves 3+ table joins
- Query includes aggregations or calculations
- Query results never modified
- Views duplicate query logic

**Core Transformation (Target State):**
- Create projection DAC with `[PXProjection(typeof(SelectFrom<>...), Persistent = false)]`
- Map fields using `[PXDBField(BqlField = typeof(BaseTable.field))]`
- Calculated fields use `[PXDBCalced]` attribute
- Views reference projection DAC instead of inline query
- Projection marked `[PXHidden]` if not user-facing

**Why It Matters in Acumatica:**
- Single definition of complex query logic
- Database-side calculation for aggregates
- Cleaner Graph view definitions
- Reusable across multiple screens

**Risks / Side Effects:**
- Projection DACs add to codebase size
- Changes to base tables require projection updates
- Overuse may fragment data model understanding

**Acceptance Criteria:**
- Complex read-only queries extracted to projections
- Projections properly marked non-persistent
- Original query logic matches projection results
- Projection reused across relevant Graphs

**Related Acumatica Mechanisms:**
`[PXProjection]`, `[PXDBCalced]`, `BqlField` mapping, `Persistent = false`

**Common Anti-Patterns Nearby:**
- Persistent projections for read-only data
- Projections without proper field mapping
- Multiple projections for same query

---

### REF-205: Use PXFieldScope for Large Data Retrieval

**Description:**  
When retrieving large datasets where only specific fields are needed, `PXFieldScope` MUST be used to limit database columns and reduce memory consumption.

**When to Apply (Symptoms):**
- Query retrieves full DAC but only uses few fields
- Memory consumption high during data processing
- Network latency between app and database servers
- Large BLOB or text fields retrieved unnecessarily
- Export/import operations process many records

**Core Transformation (Target State):**
- Wrap query iteration in `using (new PXFieldScope(view, typeof(Field1), typeof(Field2)))`
- Only required fields specified in scope
- Processed records not cached beyond scope
- Batch processing uses field scope consistently

**Why It Matters in Acumatica:**
- Reduces SQL SELECT column list
- Decreases network transfer volume
- Lowers memory allocation and GC pressure
- Improves throughput for bulk operations

**Risks / Side Effects:**
- Accessing fields not in scope returns default values
- Field scope affects all queries in block
- Must be used with read-only scenarios

**Acceptance Criteria:**
- Bulk operations use PXFieldScope
- Only required fields in scope definition
- Memory usage measurably reduced
- No unintended side effects from missing fields

**Related Acumatica Mechanisms:**
`PXFieldScope`, `PXSelectReadonly`, bulk processing patterns

**Common Anti-Patterns Nearby:**
- Full DAC retrieval for single field access
- Field scope with mutable operations
- Missing fields causing null reference errors

---

### REF-206: Fix BQL Select Argument Count for Required/Optional Parameters

**Description:**  
BQL query execution MUST pass the correct number of parameters matching `Required<>` and `Optional<>` placeholders. Parameter mismatches cause runtime errors and incorrect query results.

**When to Apply (Symptoms):**
- `Select()`/`SelectSingle()` called with the wrong argument count
- Query uses `Required<>` but caller passes fewer parameters
- Query uses `Optional<>` but caller passes parameters inconsistently
- Runtime exceptions related to BQL parameter binding

**Core Transformation (Target State):**
- Ensure the argument list matches the BQL placeholder list in both count and order
- Prefer named/local variables for parameters to improve readability
- Avoid passing unused dummy values for required parameters

**Why It Matters in Acumatica:**
- Parameter binding is positional
- Incorrect parameterization is a frequent source of production defects

**Risks / Side Effects:**
- Fixing parameter lists may reveal callers relying on accidental behavior

**Acceptance Criteria:**
- All BQL calls match their placeholder parameter lists
- Queries return the same logical result set

**Related Acumatica Mechanisms:**
`Required<>`, `Optional<>`, `PXSelect.Select`, `SelectFrom.Select`

**Common Anti-Patterns Nearby:**
- Passing `null` placeholders without understanding Required/Optional

---

### REF-207: Execute BQL Queries Within Graph Context and Avoid Hidden Graph Creation

**Description:**  
BQL queries SHOULD be executed using an explicit and correct Graph context. Query helpers MUST NOT silently create Graph instances without clear ownership, as this leads to unpredictable cache and extension behavior.

**When to Apply (Symptoms):**
- Static methods execute BQL and create a Graph internally
- Same query behaves differently depending on call site
- Security filters, extensions, or attributes apply inconsistently

**Core Transformation (Target State):**
- Pass a `PXGraph` (or a specific Graph type) into query helper methods
- Execute BQL using the provided Graph context
- If a new Graph is required, create it explicitly with `PXGraph.CreateInstance<>` and document ownership (see REF-005)

**Why It Matters in Acumatica:**
- Graph context affects caches, extensions, and row-level security
- Hidden Graph creation makes behavior non-local and hard to reason about

**Risks / Side Effects:**
- Signature changes may be required to pass Graph context

**Acceptance Criteria:**
- BQL helper methods have explicit Graph context
- Query results are stable and predictable

**Related Acumatica Mechanisms:**
`PXGraph`, `PXSelect`, `SelectFrom<>`, `Match<>`

**Common Anti-Patterns Nearby:**
- Static query helpers that instantiate Graphs internally

---

---

### REF-208: Use FK-Based Join Syntax Instead of Manual Field Comparisons

**Priority:** Medium  
**Importance:** High

**Description:**  
BQL joins SHOULD use FK-based syntax (`.InnerJoin<T>.On<DAC.FK.Related>`) instead of manual field comparison joins (`.On<T.field.IsEqual<U.field>>`). FK-based joins are compile-time validated and self-documenting.

**When to Apply (Symptoms):**
- Join conditions manually specify field equality: `.On<T.fieldA.IsEqual<U.fieldB>>`
- FK class exists on the DAC but joins do not reference it
- Composite key joins are error-prone due to manual field ordering
- Joins are inconsistent across views for the same relationship

**Core Transformation (Target State):**
- Replace manual join conditions with `.InnerJoin<T>.On<DAC.FK.Related>` (or `LeftJoin`, `CrossJoin`, etc.)
- Ensure FK class is defined on the child DAC (see REF-103)
- Use `.SameAsCurrent` for current-row filtering via FK

```csharp
// CORRECT - FK-based join
public SelectFrom<SOLine>
    .InnerJoin<InventoryItem>.On<SOLine.FK.InventoryItem>
    .Where<SOLine.FK.Order.SameAsCurrent>
    .View Lines;

// INCORRECT - Manual field comparison
public SelectFrom<SOLine>
    .InnerJoin<InventoryItem>.On<InventoryItem.inventoryID.IsEqual<SOLine.inventoryID>>
    .View Lines;
```

**Why It Matters in Acumatica:**
- Compile-time validation catches relationship errors
- Reduces copy-paste mistakes in composite key joins
- Self-documents the relationship intent
- Changes to key structure propagate automatically
- Architecture rules (§3.3) mandate FK-based join syntax

**Risks / Side Effects:**
- Requires FK definitions to exist (see REF-103)
- Some ad-hoc joins may not have FK equivalents (cross-module, analytical)

**Acceptance Criteria:**
- Joins use FK syntax where FK definitions exist
- Manual field-comparison joins remain only for ad-hoc/analytical cases
- Query results unchanged

**Related Acumatica Mechanisms:**
`FK` nested class, `ForeignKeyOf<>`, `InnerJoin<>.On<>`, `SameAsCurrent`

**Common Anti-Patterns Nearby:**
- Duplicate manual join conditions that drift from FK definition
- Forgetting a field in composite key joins

---

### REF-209: Use PXSelectReadonly for Read-Only Queries

**Priority:** Medium  
**Importance:** Medium

**Description:**  
Queries that retrieve data strictly for display, calculation, or export without intending to modify it SHOULD use `PXSelectReadonly<>` (or `SelectFrom<>.View.ReadOnly`) to signal read-only intent and enable framework optimizations.

**When to Apply (Symptoms):**
- View is used only for reading data but declared as mutable (`PXSelect<>`, `SelectFrom<>.View`)
- Records from the view are never inserted/updated/deleted through the view's cache
- Large data volumes retrieved for reporting or export

**Core Transformation (Target State):**
- Replace `PXSelect<>` with `PXSelectReadonly<>` for read-only ad-hoc queries
- Replace `SelectFrom<>.View` with `SelectFrom<>.View.ReadOnly` for read-only views
- Ensure no cache mutations are performed on records from these views

**Why It Matters in Acumatica:**
- Framework can optimize read-only queries (skip change tracking overhead)
- Signals intent clearly to maintainers and agents
- Reduces accidental cache pollution
- Architecture rules (§15.1) recommend this for query optimization

**Risks / Side Effects:**
- Records from read-only views should not be passed to cache.Update/Insert/Delete
- Verify no downstream code mutates records from the view

**Acceptance Criteria:**
- Read-only views use ReadOnly declaration
- No mutations on records from read-only views
- Query behavior unchanged

**Related Acumatica Mechanisms:**
`PXSelectReadonly<>`, `SelectFrom<>.View.ReadOnly`, cache optimization

**Common Anti-Patterns Nearby:**
- Mutable views used purely for display
- Fetching full DACs for read-only aggregation

---

### REF-210: Use SelectWindowed for Paginated or Batched Data Access

**Priority:** Medium  
**Importance:** Medium

**Description:**  
When processing large datasets in batches or implementing server-side pagination outside of view delegates, `SelectWindowed` SHOULD be used to limit the number of rows returned per round trip.

**When to Apply (Symptoms):**
- Processing screen iterates entire dataset in one Select call
- Memory usage spikes for large tables
- Timeout errors on large data volumes
- No pagination in background processing

**Core Transformation (Target State):**
- Use `view.SelectWindowed(startRow, maxRows, params)` for batched retrieval
- Process each batch before fetching the next
- Combine with `PXFieldScope` (REF-205) for optimal memory usage

**Why It Matters in Acumatica:**
- Limits memory footprint for large operations
- Prevents timeout on massive datasets
- Enables incremental progress reporting
- Architecture rules (§15.1) list `SelectWindowed` as a key optimization technique

**Risks / Side Effects:**
- Data may change between batches in long-running operations
- Requires careful handling of total row counts

**Acceptance Criteria:**
- Large-set processing uses windowed selects
- Memory usage remains stable across data volumes
- No timeouts on production-size datasets

**Related Acumatica Mechanisms:**
`SelectWindowed`, `PXFieldScope`, batch processing patterns

**Common Anti-Patterns Nearby:**
- Loading entire table into memory via Select()
- Unbounded queries in processing delegates

---

### REF-211: Validate PXProjection Field Mapping and Persistence Semantics

**Priority:** Medium  
**Importance:** High

**Description:**  
Projection DACs MUST map fields and keys deliberately. Every persisted projection field should have a correct `BqlField` mapping unless it is explicitly calculated, scalar, or unbound. Persistent projections require explicit write semantics.

**When to Apply (Symptoms):**
- Projection field lacks `BqlField` and is not calculated, scalar, or unbound
- `IsKey` fields do not represent the real uniqueness of the projected row
- Read model projection is marked `Persistent = true` without insert/update/delete design
- Projection field or key changes can affect inquiries, reports, API, OData, or imports

**Core Transformation (Target State):**
- Add correct `BqlField = typeof(SourceDAC.sourceField)` to mapped projection fields
- Define projection keys from the real unique row identity
- Keep `Persistent = false` for read models
- Use persistent projections only when write behavior is intentionally designed, tested, and documented
- Validate downstream read surfaces when projection shape changes

**Why It Matters in Acumatica:**
- Projection DACs are often reused as read models for inquiries, reports, selectors, processing screens, and API paths
- Incorrect keys create duplicate or unstable rows
- Missing mappings can break persistence, filtering, sorting, and metadata consumers

**Risks / Side Effects:**
- Changing projection keys can affect UI row identity and external consumers
- Making a projection persistent can introduce unintended writes to source tables

**Acceptance Criteria:**
- Projection fields have correct mapping or explicit calculated/unbound semantics
- Projection keys represent the row identity
- Persistent projections have verified write behavior
- Public read surfaces affected by the projection are checked

**Related Acumatica Mechanisms:**
`[PXProjection]`, `BqlField`, `PXDBCalced`, `PXDBScalar`, projection keys

**Common Anti-Patterns Nearby:**
- Projection DAC used as a mutable source of truth without persistence design
- Aggregated projection with insufficient key fields

### Category D: Events & Business Logic Placement (REF-3XX)

---

### REF-301: Move Business Logic Out of RowSelected

**Description:**  
`RowSelected` event handlers MUST be limited to UI and cache state management. Database queries, persistence, heavy calculations, and business data mutations MUST be moved to appropriate events, attributes, views, or processing logic.

**When to Apply (Symptoms):**
- `RowSelected` handler contains `PXSelect` or BQL queries
- `RowSelected` modifies field values via `SetValue`/`SetValueExt`
- `RowSelected` performs complex calculations
- `RowSelected` derives business state from unrelated caches or per-row lookup work
- Screen performance degrades when navigating records

**Core Transformation (Target State):**
- `RowSelected` SHOULD only adjust UI state and cache-level state that is safe to evaluate repeatedly
- Field defaults MUST use `[PXDefault]` or `FieldDefaulting` event
- Calculations MUST use `[PXFormula]` or `RowUpdated`/`FieldUpdated`
- Related data MUST be fetched via view joins, not per-row queries
- Business rules MUST be in `FieldUpdated`, `RowUpdated`, or `RowPersisting`

**Why It Matters in Acumatica:**
- RowSelected fires on every grid row display and navigation
- Queries in RowSelected cause severe performance issues
- Data modifications cause recursive event loops
- UI state should not depend on expensive operations

**Risks / Side Effects:**
- Moving logic may change when rules are evaluated
- Some UI state may depend on calculated values
- Requires careful analysis of business rule intent

**Acceptance Criteria:**
- RowSelected contains zero BQL queries
- RowSelected performs no data modifications
- Remaining logic is limited to UI/cache state and inexpensive checks
- Screen navigation performance acceptable

**Related Acumatica Mechanisms:**
`Events.RowSelected<T>`, `PXUIFieldAttribute`, `[PXFormula]`, `[PXDefault]`

**Common Anti-Patterns Nearby:**
- Calculating totals in RowSelected
- Loading related entity data per row
- Setting field values in RowSelected

---

### REF-302: Use Declarative Attributes for Invariant Field Behavior

**Description:**  
Field behaviors that are consistent across all Graph contexts MUST be implemented declaratively via attributes rather than imperatively in event handlers.

**When to Apply (Symptoms):**
- Same `FieldDefaulting` logic appears in multiple Graphs
- `FieldVerifying` duplicates validation across Graphs
- Calculated field logic repeated in multiple handlers
- Cross-field dependencies managed imperatively
- Default values hardcoded in event handlers

**Core Transformation (Target State):**
- Defaults MUST use `[PXDefault]` with appropriate source type
- Simple calculations MUST use `[PXFormula]`
- DB-side calculations MUST use `[PXDBCalced]`
- Required validation MUST use `[PXUIRequired]` or `[PXUIVerify]`
- Lookup restrictions MUST use `[PXRestrictor]`
- Cross-field defaults MUST use `[PXFormula(typeof(Default<...>))]`

**Why It Matters in Acumatica:**
- Attributes execute consistently across all contexts
- Reduces code duplication
- Behavior survives Graph Extensions
- Self-documenting DAC structure

**Risks / Side Effects:**
- Complex conditional logic may not fit attribute model
- Formula evaluation order matters for dependencies
- Some calculations require runtime context

**Acceptance Criteria:**
- Invariant behaviors use declarative attributes
- No duplicate logic across Graph event handlers
- DAC attributes document field behavior
- Graph-specific logic remains in handlers

**Related Acumatica Mechanisms:**
`[PXDefault]`, `[PXFormula]`, `[PXDBCalced]`, `[PXUIRequired]`, `[PXUIVerify]`, `[PXRestrictor]`

**Common Anti-Patterns Nearby:**
- Defaults set in multiple FieldDefaulting handlers
- Validation repeated across Graphs
- Calculated fields using event handlers instead of formulas

---

### REF-303: Use SetValueExt for Field Assignment with Event Chain

**Description:**  
When field assignment MUST trigger the full event chain (FieldVerifying, FieldUpdated, etc.), `SetValueExt` MUST be used instead of `SetValue` or direct property assignment.

**When to Apply (Symptoms):**
- Field assignment bypasses validation
- Dependent field updates not triggering
- Events expected but not firing
- Direct property assignment on DAC instances
- `SetValue` used where events are required

**Core Transformation (Target State):**
- Use `cache.SetValueExt<Field>(row, value)` when events required
- Use `cache.SetValue<Field>(row, value)` only when bypassing events intentional
- NEVER assign DAC properties directly when cache operations needed
- Document intent when using SetValue over SetValueExt

**Why It Matters in Acumatica:**
- SetValueExt raises FieldVerifying and FieldUpdated
- SetValue bypasses event chain
- Direct assignment bypasses cache entirely
- Dependent calculations require event chain

**Risks / Side Effects:**
- SetValueExt may trigger validation errors
- Recursive event loops possible with circular dependencies
- Performance overhead of event chain

**Acceptance Criteria:**
- All field assignments use appropriate method
- SetValue usage documented where intentional
- Event chains execute as expected
- No direct DAC property assignments in event handlers

**Related Acumatica Mechanisms:**
`PXCache.SetValueExt<T>`, `PXCache.SetValue<T>`, event chain, `FieldUpdated`

**Common Anti-Patterns Nearby:**
- Mixing SetValue and SetValueExt inconsistently
- Direct property assignment expecting cache tracking
- Recursive SetValueExt calls

---

### REF-304: Validate Data in RowPersisting, Not RowSelected

**Description:**  
Data validation that prevents database persistence MUST occur in `RowPersisting` event, not in `RowSelected`. RowSelected is for UI state only.

**When to Apply (Symptoms):**
- Validation errors raised in RowSelected
- Users cannot navigate away from invalid records
- Validation runs on every row display
- Database save permitted despite validation messages
- PXSetPropertyException thrown in RowSelected

**Core Transformation (Target State):**
- Final validation MUST occur in `RowPersisting` handler
- `PXSetPropertyException` with `PXErrorLevel.Error` for blocking errors
- Use `e.Cancel = true` for critical validation failures
- Warning-level validation may use `RowSelected` for display only
- Consider `[PXUIVerify]` for declarative validation

**Why It Matters in Acumatica:**
- RowPersisting executes immediately before database write
- Blocking validation in RowSelected harms user experience
- RowPersisting can cancel the persist operation
- Proper error level determines UI behavior

**Risks / Side Effects:**
- Late validation may frustrate users
- Consider early validation in FieldVerifying when appropriate
- RowPersisting fires per-row in batch operations

**Acceptance Criteria:**
- Blocking validation in RowPersisting only
- RowSelected contains no PXSetPropertyException with Error level
- Validation errors prevent persistence
- User experience acceptable for error discovery

**Related Acumatica Mechanisms:**
`Events.RowPersisting<T>`, `PXSetPropertyException`, `e.Cancel`, `[PXUIVerify]`

**Common Anti-Patterns Nearby:**
- Blocking validation in RowSelected
- Warning-level messages blocking persistence
- Validation scattered across multiple events

---

### REF-305: Check Row for Null in All Event Handlers

**Description:**  
Every event handler MUST check if `e.Row` (or equivalent row parameter) is null before processing. Null row indicates event fired without valid row context.

**When to Apply (Symptoms):**
- NullReferenceException in event handlers
- Handler assumes row always exists
- Handler crashes on new/empty forms
- Stack trace points to event handler row access

**Core Transformation (Target State):**
- First line of handler MUST be `if (e.Row == null) return;`
- Guard applies to RowSelected, RowUpdated, FieldUpdated, etc.
- Consider guard for RowPersisting based on operation type
- Pattern: `if (e.Row == null || e.Operation == PXDBOperation.Delete) return;`

**Why It Matters in Acumatica:**
- Framework fires events even with null row in some scenarios
- New record creation may have partial row state
- Grid operations may fire events without current row
- Defensive coding prevents runtime failures

**Risks / Side Effects:**
- Silent return may hide logic errors
- Ensure early return is appropriate for business logic

**Acceptance Criteria:**
- All event handlers have null row guard
- No NullReferenceException from event handlers
- Guard pattern consistent across codebase
- Documentation explains guard necessity

**Related Acumatica Mechanisms:**
Event handler patterns, `e.Row`, `e.Operation`, null propagation

**Common Anti-Patterns Nearby:**
- Immediate row access without null check
- Conditional null checks deeper in handler
- Different guard patterns across handlers

---

### REF-306: Convert Classic Named Event Handlers to Typed Generic Handlers

**Description:**  
Event handlers SHOULD use the typed generic handler syntax (`_(Events.FieldUpdated<...> e)`) instead of classic named handlers (`DAC_Field_EventName`). Typed handlers improve refactorability and reduce naming errors.

**When to Apply (Symptoms):**
- Event handlers are declared using classic naming conventions
- Refactoring DAC field names breaks handler binding
- Handlers are difficult to navigate and maintain

**Core Transformation (Target State):**
- Convert handlers to typed signatures:
  - `protected virtual void _(Events.RowSelected<DAC> e)`
  - `protected virtual void _(Events.FieldUpdated<DAC, DAC.field> e)`
- Keep logic unchanged; only change handler binding form

**Why It Matters in Acumatica:**
- Typed handlers are compile-time checked
- Handler binding is resilient to refactoring
- Improves readability and tooling support

**Risks / Side Effects:**
- Incorrect type parameters can break event binding; verify behavior

**Acceptance Criteria:**
- Converted handlers fire exactly as before
- No naming-based handlers remain where typed form is applicable

**Related Acumatica Mechanisms:**
Typed event syntax, `Events.*` classes

**Common Anti-Patterns Nearby:**
- Multiple handlers for the same event due to naming mistakes

---

### REF-307: Normalize Event Handler Modifiers to Protected Virtual

**Description:**  
Graph and Graph Extension event handlers SHOULD be declared `protected virtual` to follow framework conventions and enable safe customization layering.

**When to Apply (Symptoms):**
- Event handlers declared as `private`, `public`, or non-virtual
- Customizations cannot override or intercept behavior cleanly
- Inconsistent handler declarations across codebase

**Core Transformation (Target State):**
- Convert handler modifiers to `protected virtual`
- Keep method bodies unchanged

**Why It Matters in Acumatica:**
- Matches the standard extensibility model
- Improves predictability of override behavior

**Risks / Side Effects:**
- Minimal; mostly signature-level refactoring

**Acceptance Criteria:**
- Event handlers use `protected virtual` consistently

**Related Acumatica Mechanisms:**
Graph extensibility model, event pipeline

**Common Anti-Patterns Nearby:**
- `public` handlers used as API surface

---

### REF-308: Avoid Mutating DAC Instances in Forbidden Events

**Description:**  
DAC instances MUST NOT be mutated in event contexts where direct row mutation is forbidden or unsafe (e.g., `FieldDefaulting`, `FieldVerifying`, `RowSelected`). Use supported event patterns instead.

**When to Apply (Symptoms):**
- Code assigns `row.Field = ...` in `FieldDefaulting` or `FieldVerifying`
- Code mutates `e.Row` in `RowSelected`
- UI or persistence behavior becomes unstable due to forbidden mutations

**Core Transformation (Target State):**
- In `FieldDefaulting`, set `e.NewValue` instead of mutating the row
- In `FieldVerifying`, validate `e.NewValue` and throw/cancel appropriately
- In `RowSelected`, only configure UI state (see REF-601) and avoid data mutations
- Move data mutations to appropriate events (`FieldUpdated`, `RowInserting`, `RowUpdated`) using `SetValueExt` when required (see REF-303)

**Why It Matters in Acumatica:**
- The framework expects specific side effects per event type
- Violations lead to subtle cache inconsistencies and UI issues

**Risks / Side Effects:**
- Moving mutations may affect timing; validate side effects carefully

**Acceptance Criteria:**
- No forbidden row mutations remain in restricted events
- Business logic remains logically equivalent

**Related Acumatica Mechanisms:**
Event pipeline, `e.NewValue`, `SetValueExt`, UI-only RowSelected

**Common Anti-Patterns Nearby:**
- Fixing validation by "just setting" values in verifying/defaulting

---

### REF-309: Do Not Invoke PXActions from Event Handlers or View Delegates

**Description:**  
Event handlers and view delegates MUST NOT invoke `PXAction` handlers (directly or indirectly). Instead, extract reusable logic into a plain method and call it from both the action and the event if needed.

**When to Apply (Symptoms):**
- Code calls `SomeAction.Press()` or calls an action handler method from an event
- View delegates call actions to reuse behavior
- Side effects occur in unexpected lifecycle phases

**Core Transformation (Target State):**
- Extract action logic into a separate method (service-style method on Graph/Extension)
- Action handler calls the extracted method
- Event handler calls the extracted method only if it is valid in that event context
- Ensure action handlers still return `adapter.Get()` when required

**Why It Matters in Acumatica:**
- Actions are UI-triggered entry points with adapter semantics
- Calling actions from events breaks lifecycle assumptions and can cause recursion

**Risks / Side Effects:**
- Refactoring requires careful separation of UI concerns from business logic

**Acceptance Criteria:**
- No actions are invoked from event handlers or view delegates
- Logic is shared via extracted methods
- Behavior remains logically equivalent

**Related Acumatica Mechanisms:**
`PXAction<>`, `PXAdapter`, event pipeline

**Common Anti-Patterns Nearby:**
- Reusing actions as "methods" from within business logic

---

### REF-310: Throw PXSetupNotEnteredException Only in Allowed Contexts

**Description:**  
`PXSetupNotEnteredException` MUST be thrown only in contexts supported by the framework (typically `RowSelected` for UI screens). Throwing it in persistence or background contexts leads to unstable behavior and poor user experience.

**When to Apply (Symptoms):**
- `PXSetupNotEnteredException` thrown in `RowPersisting`, `FieldUpdating`, `RowUpdated`, long operations, or processing delegates
- Setup checks cause unexpected crashes during persistence
- Users see inconsistent setup prompts

**Core Transformation (Target State):**
- Move setup checks to `RowSelected` when possible
- In non-UI contexts, use alternative validation/error reporting patterns appropriate for the context
- Keep logic unchanged: the same prerequisite setup must be enforced

**Why It Matters in Acumatica:**
- Setup-not-entered is primarily a UI-driven guidance mechanism
- Persistence and background contexts require different error handling semantics

**Risks / Side Effects:**
- Setup checks may occur earlier (RowSelected) than before; validate UX

**Acceptance Criteria:**
- `PXSetupNotEnteredException` is only thrown in allowed contexts
- Setup prerequisites are still enforced consistently

**Related Acumatica Mechanisms:**
`PXSetup<>`, `PXSetupNotEnteredException`, `RowSelected`

**Common Anti-Patterns Nearby:**
- Throwing setup exceptions during persistence

---

---

### REF-311: Use FieldClass for Feature-Gated Field Visibility

**Priority:** Medium  
**Importance:** Medium

**Description:**  
DAC fields that should only be visible when a specific feature is installed SHOULD use the `FieldClass` property of `[PXUIField]` to declaratively control visibility, rather than imperative `SetVisible` calls in every Graph's `RowSelected`.

**When to Apply (Symptoms):**
- Multiple Graphs contain identical `PXUIFieldAttribute.SetVisible` calls gated by `PXAccess.FeatureInstalled<>`
- Feature-gated field visibility is inconsistent across screens
- New screens forget to add the feature check for field visibility

**Core Transformation (Target State):**
- Resolve the feature's `<Access FieldClass="...">` mapping in `Features.xml` and add the canonical token or constant to the `[PXUIField]` attribute
- Remove redundant `SetVisible` calls from `RowSelected` handlers that duplicate this logic

```csharp
// CORRECT - Declarative feature gating
[PXDBInt]
[PXUIField(DisplayName = "Cost Code", FieldClass = CostCodeAttribute.COSTCODE)]
public virtual int? CostCodeID { get; set; }

// INCORRECT - Imperative in every RowSelected
protected virtual void _(Events.RowSelected<SOOrder> e)
{
    bool hasCostCodes = PXAccess.FeatureInstalled<FeaturesSet.costCodes>();
    PXUIFieldAttribute.SetVisible<SOOrder.costCodeID>(e.Cache, e.Row, hasCostCodes);
}
```

**Why It Matters in Acumatica:**
- Eliminates duplicated visibility logic across all Graphs using the DAC
- Declarative approach is self-documenting and upgrade-safe
- Architecture rules (§8.3) show this as the preferred pattern
- Consistent with REF-302 (declarative over imperative)

**Risks / Side Effects:**
- `FieldClass` hides the field entirely when the feature is off; ensure this is the desired behavior
- A `FieldClass` token does not necessarily match the related `FeaturesSet` field name; verify the `Features.xml` mapping
- Cannot express complex multi-condition visibility this way (use `RowSelected` for those)

**Acceptance Criteria:**
- Feature-gated fields use the `FieldClass` token mapped by `Features.xml` where the condition is a single feature check
- Redundant `SetVisible` calls removed
- Visibility behavior unchanged

**Related Acumatica Mechanisms:**
`PXUIField.FieldClass`, `FeaturesSet`, `PXAccess.FeatureInstalled<>`

**Common Anti-Patterns Nearby:**
- Scattering the same `SetVisible` + `FeatureInstalled` in 10+ Graphs

---

### REF-312: Do Not Invoke PXAction.Press() from Event Handlers

**Priority:** High  
**Importance:** High

**Description:**  
Event handlers and view delegates MUST NOT invoke `PXAction` handlers by calling `.Press()` or similar methods. Instead, extract the reusable logic into a separate method and call it from both the action handler and the event handler.

This refactoring extends REF-309 with an explicit focus on the `.Press()` invocation pattern which is a common codebase anti-pattern.

**When to Apply (Symptoms):**
- Code calls `SomeAction.Press()` from inside an event handler or view delegate
- Code calls `Actions["actionName"].Press()` from event handlers
- Side effects occur in unexpected lifecycle phases
- Recursive action invocations observed

**Core Transformation (Target State):**
- Extract action business logic into a separate `protected virtual` method on the Graph/Extension
- Action handler calls the extracted method and returns `adapter.Get()`
- Event handler calls the extracted method directly (if valid in that event context)
- Do not invoke actions programmatically from events

**Why It Matters in Acumatica:**
- Actions have adapter semantics tied to UI lifecycle
- Calling `.Press()` from events breaks lifecycle assumptions and can cause recursion
- Extracted methods are independently testable and overridable

**Risks / Side Effects:**
- Requires careful separation of adapter-specific logic from business logic

**Acceptance Criteria:**
- No `.Press()` calls on actions from event handlers or view delegates
- Logic is shared via extracted methods
- Behavior remains logically equivalent

**Related Acumatica Mechanisms:**
`PXAction<>`, `PXAdapter`, event pipeline

**Common Anti-Patterns Nearby:**
- Using actions as reusable "methods" from business logic
- `Actions.PressSave()` in event handlers (see also REF-404)

### Category E: Cache & Persistence (REF-4XX)

---

### REF-401: Use Cache Operations Instead of Direct DAC Manipulation

**Description:**  
Data modifications MUST go through `PXCache` operations (Insert, Update, Delete) rather than direct DAC instance manipulation. Cache tracks changes and coordinates persistence.

**When to Apply (Symptoms):**
- DAC properties assigned directly without cache Update
- Changes not persisting to database
- RowUpdated events not firing
- Change tracking not reflecting modifications
- Dirty flag inconsistent with actual changes

**Core Transformation (Target State):**
- Create records via `cache.Insert(new DAC { ... })`
- Modify records via `cache.Update(existingDac)`
- Remove records via `cache.Delete(existingDac)`
- Always retrieve current record via `cache.Locate()` before update
- Use `PXCache<T>.CreateCopy()` before modifications if needed

**Why It Matters in Acumatica:**
- Cache manages change tracking for persistence
- Events fire only for cache-tracked changes
- Transaction rollback depends on cache state
- Audit trail requires cache operations

**Risks / Side Effects:**
- Update on non-cached record may Insert instead
- Multiple updates require careful Locate usage
- Cache holds references, not copies

**Acceptance Criteria:**
- All modifications use cache operations
- No direct DAC property assignments for persisted changes
- Events fire correctly for modifications
- Changes persist as expected

**Related Acumatica Mechanisms:**
`PXCache.Insert/Update/Delete`, `Locate()`, `CreateCopy()`, change tracking

**Common Anti-Patterns Nearby:**
- Modifying DAC without cache.Update
- Creating DAC without cache.Insert
- Mixing cached and uncached references

---

### REF-402: Use PXCache.CreateCopy Before Modifications

**Description:**  
When modifying a cached DAC instance, `PXCache<T>.CreateCopy()` SHOULD be used to avoid unintended side effects from shared references in cache.

**When to Apply (Symptoms):**
- Modifications affecting unintended records
- OldRow and NewRow showing same values in events
- Undo/cancel not reverting to original values
- Cache containing unexpected modifications
- Shared reference issues in loops

**Core Transformation (Target State):**
- Before modification: `var copy = PXCache<T>.CreateCopy(original);`
- Modify the copy, not original
- Update cache with modified copy: `cache.Update(copy)`
- Original reference remains unchanged
- Loop processing uses copies to avoid interference

**Why It Matters in Acumatica:**
- Cache stores object references, not copies
- Modifying cached object affects all references
- Event handlers see same object pre/post modification
- Proper copy semantics enable undo

**Risks / Side Effects:**
- Memory allocation for copies
- Must update with copy, not original
- Nested object references may still be shared

**Acceptance Criteria:**
- Modifications use CreateCopy pattern
- OldRow preserves original values in events
- No unintended side effects on other records
- Undo/cancel functions correctly

**Related Acumatica Mechanisms:**
`PXCache<T>.CreateCopy()`, object reference semantics, event OldRow/NewRow

**Common Anti-Patterns Nearby:**
- Direct modification of Current property
- Assuming cache clones objects
- Forgetting to Update with copy

---

### REF-403: Properly Use PXTransactionScope for Complex Operations

**Description:**  
Operations involving multiple Persist calls or external system interactions MUST properly use `PXTransactionScope` to ensure atomicity and proper rollback.

**When to Apply (Symptoms):**
- Partial data committed on error
- Multiple Persist calls without coordination
- External API calls between database operations
- Inconsistent state after exceptions
- Missing transaction rollback on failure

**Core Transformation (Target State):**
- Wrap related operations in `using (var ts = new PXTransactionScope())`
- Call `ts.Complete()` only when all operations succeed
- Do NOT catch exceptions inside scope without re-throw
- External calls SHOULD occur outside transaction when possible
- Consider compensation logic for non-transactional external systems

**Why It Matters in Acumatica:**
- Database operations need ACID guarantees
- Partial commits create data inconsistency
- Framework transaction management has specific scope rules
- External systems may not support rollback

**Risks / Side Effects:**
- Long-running transactions may cause lock contention
- Nested scopes have specific semantics
- Scope timeout may cause unexpected rollback

**Acceptance Criteria:**
- Related database operations within single scope
- Complete called only on full success
- Errors cause full rollback
- No partial state on exceptions

**Related Acumatica Mechanisms:**
`PXTransactionScope`, `Complete()`, transaction isolation, rollback behavior

**Common Anti-Patterns Nearby:**
- Missing Complete call
- Swallowing exceptions inside scope
- External API calls inside transaction
- Overly broad transaction scopes

---

### REF-404: Avoid Persist() in Event Handlers

**Description:**  
Calling `Persist()` or `Actions.PressSave()` from within event handlers creates recursive persistence and unpredictable behavior. Persistence MUST be triggered only from actions or Graph methods.

**When to Apply (Symptoms):**
- `Persist()` called from FieldUpdated or RowUpdated
- Recursive save operations
- Save triggered unexpectedly during data entry
- Stack overflow in persistence chain
- Unpredictable save behavior

**Core Transformation (Target State):**
- Event handlers MUST NOT call `Persist()` or `PressSave()`
- Related record creation SHOULD use views with persist on parent
- Immediate persistence requirements SHOULD use separate Graph
- Consider `PXLongOperation` for deferred processing
- Document why immediate save is required

**Why It Matters in Acumatica:**
- Persist triggers full persistence chain including events
- Recursive persistence causes stack overflow
- User loses control of save timing
- Transaction boundaries become unclear

**Risks / Side Effects:**
- Some business requirements may seem to need immediate save
- Requires architectural review for alternatives
- May need PXLongOperation for deferred processing

**Acceptance Criteria:**
- No Persist calls in event handlers
- Save triggered only by user action or explicit Graph method
- No recursive persistence scenarios
- Business requirements met via proper architecture

**Related Acumatica Mechanisms:**
`Actions.PressSave()`, `Persist()`, event handlers, `PXLongOperation`

**Common Anti-Patterns Nearby:**
- Auto-save on field change
- Creating related records via Persist in handler
- Trying to ensure immediate database consistency

---

---

### REF-405: Use Relationship Attributes for Parent-Child Cascade Operations

**Priority:** Medium  
**Importance:** High

**Description:**  
Parent-child DAC relationships MUST use declarative relationship attributes (`[PXParent]`, `[PXDBDefault]`, `[PXDBChildIdentity]`) rather than imperative code for cascade defaulting, delete, and identity linking.

**When to Apply (Symptoms):**
- Child record manually copies parent key in event handlers instead of using `[PXDBDefault]`
- Cascade delete implemented imperatively in `RowDeleting`/`RowDeleted` instead of `[PXParent]`
- Identity field linking done manually instead of `[PXDBChildIdentity]`
- Parent-child integrity not enforced declaratively

**Core Transformation (Target State):**
- Add `[PXParent(typeof(FK.ParentEntity))]` on the child DAC's foreign key field for cascade delete
- Add `[PXDBDefault(typeof(ParentDAC.keyField))]` for cascade defaulting of parent key values
- Add `[PXDBChildIdentity(typeof(ParentDAC.identityField))]` to link identity fields
- Ensure FK class exists on child DAC (see REF-103)

```csharp
// CORRECT - Declarative relationship
[PXDBInt]
[PXDBDefault(typeof(SOOrder.orderNbr))]
[PXParent(typeof(FK.Order))]
public virtual int? OrderNbr { get; set; }

// INCORRECT - Imperative cascade
protected virtual void _(Events.FieldDefaulting<SOLine, SOLine.orderNbr> e)
{
    e.NewValue = ((SOOrder)Document.Current)?.OrderNbr;
}
```

**Why It Matters in Acumatica:**
- Declarative attributes are enforced consistently regardless of Graph context
- Cascade operations survive Graph Extension changes
- Architecture rules (§3.2) mandate these attributes for relationships
- Reduces event handler clutter

**Risks / Side Effects:**
- Adding `[PXParent]` enables cascade delete which may not have been active before
- `[PXDBDefault]` behavior differs from `[PXDefault]` — it defaults from DB at persist time

**Acceptance Criteria:**
- Parent-child relationships use declarative attributes
- No imperative cascade logic in event handlers for standard parent-child patterns
- FK class defines the relationship (see REF-103)

**Related Acumatica Mechanisms:**
`[PXParent]`, `[PXDBDefault]`, `[PXDBChildIdentity]`, `[PXForeignReference]`, FK class

**Common Anti-Patterns Nearby:**
- Manual key copying in FieldDefaulting
- Manual cascade delete in RowDeleted

### Category F: Long Operations (REF-5XX)

---

### REF-501: Use PXLongOperation for Time-Consuming Processes

**Description:**  
Operations exceeding 30 seconds MUST use `PXLongOperation.StartOperation` to avoid request timeouts and provide user feedback via progress indication.

**When to Apply (Symptoms):**
- Request timeout errors on operations
- UI freezes during processing
- Browser connection drops
- No progress indication for lengthy operations
- Users repeatedly click buttons thinking nothing happened

**Core Transformation (Target State):**
- Wrap long operation in `PXLongOperation.StartOperation(this, () => { ... })`
- Use `PXProcessing<T>.SetInfo/SetWarning/SetError` for status
- Pass immutable data into operation lambda (no Graph references)
- Create new Graph inside operation for database access
- Consider chunking for very large operations

**Why It Matters in Acumatica:**
- HTTP requests have timeout limits
- Long operations run on background thread
- Framework provides progress tracking UI
- User can navigate away and return to check status

**Risks / Side Effects:**
- Cannot access caller Graph from operation
- Must create new Graph inside operation
- Session state may change during operation
- Error handling requires special patterns

**Acceptance Criteria:**
- Operations over 30s use PXLongOperation
- Progress indication visible to user
- Errors properly reported
- No timeout exceptions

**Related Acumatica Mechanisms:**
`PXLongOperation.StartOperation`, `PXProcessing<T>`, progress indication, background threads

**Common Anti-Patterns Nearby:**
- Graph reference captured in lambda
- Missing progress updates
- Swallowing exceptions in operation

---

### REF-502: Create New Graph Instance Inside Long Operation

**Description:**  
Long operations MUST create new Graph instances inside the operation lambda. The original Graph context is not valid in background thread.

**When to Apply (Symptoms):**
- Exceptions about Graph state in long operation
- Cache data stale or missing in operation
- Events not firing in background operation
- Cross-thread access exceptions
- Inconsistent data in operation results

**Core Transformation (Target State):**
- Extract data needed for operation BEFORE lambda
- Pass only primitive/immutable data into lambda
- Create `PXGraph.CreateInstance<TGraph>()` inside lambda
- Do NOT capture `this` (current Graph) in lambda
- Use new Graph's caches for all operations

**Why It Matters in Acumatica:**
- Original Graph bound to HTTP request thread
- Background thread needs independent Graph context
- Cache state must be fresh in operation
- Events must fire on new Graph's caches

**Risks / Side Effects:**
- Data may change between extraction and processing
- Must re-fetch data inside operation for currency
- Operation Graph is independent of UI state

**Acceptance Criteria:**
- No original Graph reference in operation lambda
- New Graph created inside operation
- Required data passed as parameters
- Operations complete successfully

**Related Acumatica Mechanisms:**
`PXGraph.CreateInstance<T>()`, lambda capture semantics, thread safety

**Common Anti-Patterns Nearby:**
- Capturing `this` in lambda
- Accessing caller Graph caches
- Passing mutable objects into lambda

---

### REF-503: Implement Proper Error Handling in Long Operations

**Description:**  
Long operations MUST implement proper error handling that surfaces exceptions to the user via `PXProcessing` status methods rather than silently failing.

**When to Apply (Symptoms):**
- Long operations fail silently
- Users see success when operation failed
- Exceptions logged but not displayed
- No way to see what records failed
- Operation status unclear after completion

**Core Transformation (Target State):**
- Use `PXProcessing<T>.SetError(index, exception)` for row failures
- Use `PXProcessing<T>.SetInfo(index, message)` for success
- Use `PXProcessing<T>.SetWarning(index, message)` for warnings
- Throw `PXOperationCompletedWithErrorException` for partial success
- Implement `try/catch` per record, not wrapping entire batch

**Why It Matters in Acumatica:**
- Users need feedback on operation results
- Partial failures require visibility into which items failed
- Exception details aid troubleshooting
- Framework provides standard status display

**Risks / Side Effects:**
- Per-item exception handling adds complexity
- Must decide continue-on-error vs. fail-fast
- Status storage consumes memory for large batches

**Acceptance Criteria:**
- All errors surface to user interface
- Per-record status visible
- Partial success clearly indicated
- Exception details available

**Related Acumatica Mechanisms:**
`PXProcessing<T>`, `SetError/SetInfo/SetWarning`, `PXOperationCompletedWithErrorException`

**Common Anti-Patterns Nearby:**
- Single try/catch around entire batch
- Silent exception swallowing
- Only logging, not displaying errors

---

### REF-504: Avoid Capturing PXAdapter, PXView, or Screen Graph State in LongOp and Processing Delegates

**Description:**  
Delegates used for Long Operations and processing screens MUST NOT capture `PXAdapter`, `PXView`, or UI-bound Graph state. Captures can cause unexpected synchronous execution, cross-thread access, and memory retention.

**When to Apply (Symptoms):**
- `PXLongOperation.StartOperation(this, () => ...)` lambda closes over `adapter`, `Base`, or UI state
- `PXProcessing.SetProcessDelegate` closes over screen Graph or adapter
- Long operation runs synchronously or behaves inconsistently

**Core Transformation (Target State):**
- Extract required primitive/immutable values before the delegate is created
- Pass only primitive keys/values into the delegate
- Create a new Graph instance inside the delegate (see REF-502)
- Do not reference `PXAdapter` or `PXView` inside background delegates

**Why It Matters in Acumatica:**
- UI objects are request-thread bound
- Background execution requires isolation from UI context
- Prevents subtle timing and threading bugs without changing business logic

**Risks / Side Effects:**
- Requires careful selection of what data is extracted vs re-queried inside the delegate

**Acceptance Criteria:**
- Delegates do not capture `PXAdapter`, `PXView`, or screen Graph instances
- Long operations execute asynchronously and reliably

**Related Acumatica Mechanisms:**
`PXLongOperation`, `PXProcessing`, lambda capture semantics, `PXGraph.CreateInstance<T>()`

**Common Anti-Patterns Nearby:**
- Passing `PXAdapter` into long operation delegates
- Closing over `this`/`Base` from a screen Graph

---

### REF-505: Use IEnumerable(PXAdapter) Action Signature for Actions Starting Long Operations

**Description:**  
Actions that start Long Operations SHOULD use the standard `IEnumerable` action signature with `PXAdapter` to ensure correct UI refresh and navigation behavior.

**When to Apply (Symptoms):**
- Action method returns `void` or does not accept `PXAdapter`
- After action completes, UI does not refresh or navigation behaves incorrectly
- Long operation results are not reflected on the screen

**Core Transformation (Target State):**
- Use action handler signature: `public virtual IEnumerable actionName(PXAdapter adapter)`
- Start long operation inside the handler
- Return `adapter.Get()` to preserve UI flow

**Why It Matters in Acumatica:**
- `PXAdapter` controls UI navigation and refresh
- Standard signature ensures consistent behavior across screens

**Risks / Side Effects:**
- Signature changes require updating action declarations and possible callers

**Acceptance Criteria:**
- Action handlers starting LongOps use `IEnumerable(PXAdapter)`
- UI refresh/navigation remains correct

**Related Acumatica Mechanisms:**
`PXAction<>`, `PXAdapter`, `PXLongOperation`

**Common Anti-Patterns Nearby:**
- `void` actions that start long operations

---

### Category G: UI Behavior (REF-6XX)

---

### REF-601: Use PXUIFieldAttribute Methods in RowSelected Only

**Description:**  
`PXUIFieldAttribute` methods (SetEnabled, SetVisible, SetRequired) SHOULD be called primarily in `RowSelected` events to manage UI state based on current row data.

**When to Apply (Symptoms):**
- UI state methods called from FieldUpdated
- SetEnabled called in constructor
- SetVisible scattered throughout Graph
- UI state not updating when row changes
- UI state dependent on stale conditions

**Core Transformation (Target State):**
- Centralize UI state logic in `RowSelected` handler
- Use `PXUIFieldAttribute.SetEnabled<Field>(cache, row, condition)`
- Evaluate conditions based on `e.Row` current state
- Actions' state managed in `RowSelected`
- Avoid UI state methods in other events unless necessary

**Why It Matters in Acumatica:**
- RowSelected fires when UI needs state
- Centralized logic easier to maintain
- UI state derives from current row values
- Other events don't guarantee UI refresh

**Risks / Side Effects:**
- Heavy RowSelected slows navigation
- Must not add queries to RowSelected (see REF-301)
- Conditional logic may become complex

**Acceptance Criteria:**
- UI state methods in RowSelected
- No SetEnabled/SetVisible in constructors
- UI state updates on row selection
- Performance acceptable

**Related Acumatica Mechanisms:**
`PXUIFieldAttribute.SetEnabled/SetVisible/SetRequired/SetReadOnly`, `RowSelected`

**Common Anti-Patterns Nearby:**
- UI state in field events
- Static UI state in constructor
- UI state based on queries

---

### REF-602: Use PXUIRequired Instead of Required Property

**Description:**  
Conditional required field validation MUST use `[PXUIRequired]` attribute or `PXDefaultAttribute.SetPersistingCheck` instead of hardcoding Required in `[PXUIField]`.

**When to Apply (Symptoms):**
- Required validation not conditional
- All rows require field even when not applicable
- Cannot make field conditionally required
- Validation errors on inapplicable records
- Required asterisk always shown

**Core Transformation (Target State):**
- Use `[PXUIRequired(typeof(condition))]` for declarative conditional
- Use `PXDefaultAttribute.SetPersistingCheck<Field>(cache, row, check)` for runtime
- Remove `Required = true` from `[PXUIField]` when conditional
- Condition expression uses BQL formula syntax

**Why It Matters in Acumatica:**
- Business rules often have conditional requirements
- Hard-coded required frustrates users
- Declarative attributes are self-documenting
- Runtime control enables complex scenarios

**Risks / Side Effects:**
- Condition evaluation adds overhead
- Complex conditions may need runtime approach
- Must test all condition branches

**Acceptance Criteria:**
- Conditional requirements use appropriate mechanism
- No false required errors
- UI shows required indicator correctly
- All business conditions covered

**Related Acumatica Mechanisms:**
`[PXUIRequired]`, `PXDefaultAttribute.SetPersistingCheck`, `PXPersistingCheck`

**Common Anti-Patterns Nearby:**
- Hard-coded Required = true
- Required check in RowPersisting instead of attribute
- Missing required indicator in UI

---

### REF-603: Use PXRestrictor for Selector Validation Messages

**Description:**  
Selector validation that rejects certain records MUST use `[PXRestrictor]` attribute to provide meaningful error messages. Default selector messages are cryptic.

**When to Apply (Symptoms):**
- Selector shows "value does not exist" for filtered records
- User cannot understand why value rejected
- Selector filter hides records but error message unclear
- FieldVerifying duplicates selector restrictions

**Core Transformation (Target State):**
- Add `[PXRestrictor(typeof(Where<condition>), "Message")]` to selector
- Message SHOULD explain why value is invalid
- Multiple restrictors for multiple conditions
- Restrictor conditions MUST match selector Where clause

**Why It Matters in Acumatica:**
- Users need actionable error messages
- Default "does not exist" misleads users
- Restrictors integrate with selector framework
- Avoids duplicate validation logic

**Risks / Side Effects:**
- Restrictor message overrides default
- Must keep restrictor in sync with selector Where
- Performance impact negligible

**Acceptance Criteria:**
- Selector restrictions have restrictors
- Error messages explain rejection reason
- No "does not exist" for restricted values
- Validation logic not duplicated

**Related Acumatica Mechanisms:**
`[PXRestrictor]`, `[PXSelector]`, Where clause, validation messages

**Common Anti-Patterns Nearby:**
- Selector without matching restrictor
- FieldVerifying duplicating selector validation
- Generic error messages

---

### REF-604: Ensure PXAction Handlers Have PXButton and PXUIField Attributes

**Description:**  
Action handlers SHOULD be decorated with `[PXButton]` and `[PXUIField]` to ensure consistent UI behavior, security, and tooling support.

**When to Apply (Symptoms):**
- A `PXAction<>` exists but its handler lacks `[PXButton]`
- A `PXAction<>` exists but its handler lacks `[PXUIField]`
- Action does not appear or behaves inconsistently in UI
- Analyzer warnings about action handler decoration

**Core Transformation (Target State):**
- Add `[PXButton]` to the action handler
- Add `[PXUIField(DisplayName = ...)]` to the action handler
- Keep action logic unchanged

**Why It Matters in Acumatica:**
- These attributes define UI integration and user interaction semantics
- Improves consistency across screens and modules

**Risks / Side Effects:**
- UI labels may change (usually improvement)

**Acceptance Criteria:**
- All PXAction handlers have the required UI/button attributes
- Actions display and execute consistently

**Related Acumatica Mechanisms:**
`PXAction<>`, `[PXButton]`, `[PXUIField]`

**Common Anti-Patterns Nearby:**
- Actions declared but not fully decorated

---

### REF-605: Extract Localizable Strings and Avoid Hardcoded UI Messages

**Description:**  
User-facing strings (exceptions, UI messages, validation messages) SHOULD be localized and centralized using `PXLocalizable` message containers. Hardcoded and concatenated strings reduce localization quality and supportability.

**When to Apply (Symptoms):**
- `throw new PXException("...")` uses hardcoded text
- `PXMessages.LocalizeFormat("...")` receives hardcoded or concatenated strings
- Messages are duplicated across multiple screens

**Core Transformation (Target State):**
- Create a `Messages` (or `Messages.<Feature>`) static class
- Define constants annotated with `[PXLocalizable]`
- Replace hardcoded strings with message constants and `PXMessages` helpers

**Why It Matters in Acumatica:**
- Platform supports localization and consistent messaging
- Centralized messages improve maintainability and upgrades

**Risks / Side Effects:**
- Message text may change slightly; verify user-facing wording

**Acceptance Criteria:**
- User-facing strings are centralized and localizable
- No new hardcoded strings appear in UI-facing code paths

**Related Acumatica Mechanisms:**
`[PXLocalizable]`, `PXMessages`, `PXException`

**Common Anti-Patterns Nearby:**
- String concatenation in exceptions
- Duplicated message text across modules

---

---

### REF-606: Add MapEnableRights and MapViewRights to Action PXUIField Attributes

**Priority:** Medium  
**Importance:** High

**Description:**  
`PXAction` handlers decorated with `[PXUIField]` SHOULD include `MapEnableRights` and `MapViewRights` properties to enforce proper security through cache rights. Missing rights mappings can leave actions accessible to unauthorized users.

**When to Apply (Symptoms):**
- `[PXUIField]` on an action handler lacks `MapEnableRights` / `MapViewRights`
- Action is visible/enabled for users who should not have access
- Security audit flags actions without rights mapping

**Core Transformation (Target State):**
- Add `MapEnableRights = PXCacheRights.Update` (or appropriate level) to `[PXUIField]`
- Add `MapViewRights = PXCacheRights.Select` (or appropriate level) to `[PXUIField]`
- Choose rights level based on the action's impact:
  - Read-only actions: `MapViewRights = PXCacheRights.Select`
  - Data-modifying actions: `MapEnableRights = PXCacheRights.Update`
  - Delete actions: `MapEnableRights = PXCacheRights.Delete`

```csharp
// CORRECT
[PXButton(CommitChanges = true)]
[PXUIField(DisplayName = "Release",
    MapEnableRights = PXCacheRights.Update,
    MapViewRights = PXCacheRights.Select)]
protected virtual IEnumerable release(PXAdapter adapter) { ... }

// INCORRECT - Missing rights mapping
[PXButton]
[PXUIField(DisplayName = "Release")]
protected virtual IEnumerable release(PXAdapter adapter) { ... }
```

**Why It Matters in Acumatica:**
- Security enforcement at the UI level prevents unauthorized operations
- Architecture rules (§13.1, §9.1) require rights mapping on actions
- Consistent with platform security model

**Risks / Side Effects:**
- Adding rights restrictions may hide actions from users who previously had access
- Verify role/rights configuration after adding mappings

**Acceptance Criteria:**
- All action `[PXUIField]` attributes include `MapEnableRights` and `MapViewRights`
- Rights levels match the action's operational impact
- Security behavior verified with multiple roles

**Related Acumatica Mechanisms:**
`PXCacheRights`, `MapEnableRights`, `MapViewRights`, `[PXUIField]`

**Common Anti-Patterns Nearby:**
- Actions without any rights mapping
- Overly permissive rights (e.g., Select for delete operations)

---

### REF-607: Use PXFormula and PXDBCalced Instead of Imperative Calculations in Event Handlers

**Priority:** Medium  
**Importance:** High

**Description:**  
Field calculations that follow a fixed formula regardless of Graph context SHOULD use `[PXFormula]` (application-side) or `[PXDBCalced]` (database-side) instead of imperative calculation code in event handlers. This is a specialization of the general principle in REF-302.

**When to Apply (Symptoms):**
- Same arithmetic expression repeated in `FieldUpdated`/`RowUpdated` handlers across multiple Graphs
- Calculated field value is a simple function of other fields on the same DAC (or parent DAC)
- Calculation is invariant — it does not depend on Graph context or user interaction

**Core Transformation (Target State):**
- For application-side calculations: use `[PXFormula(typeof(expression))]`
- For database-side calculations: use `[PXDBCalced(typeof(expression), typeof(resultType))]`
- Remove duplicated imperative calculation code from event handlers

```csharp
// CORRECT - Declarative formula
[PXFormula(typeof(Mult<SOLine.orderQty, SOLine.unitPrice>))]
[PXDBDecimal(4)]
public virtual decimal? ExtPrice { get; set; }

// CORRECT - Database-side calculation
[PXDBCalced(typeof(
    SOLine.orderQty.Multiply<SOLine.unitPrice>.Subtract<SOLine.discAmt>
), typeof(decimal))]
public virtual decimal? NetAmount { get; set; }

// INCORRECT - Imperative in every Graph
protected virtual void _(Events.FieldUpdated<SOLine, SOLine.orderQty> e)
{
    e.Row.ExtPrice = e.Row.OrderQty * e.Row.UnitPrice;
}
```

**Why It Matters in Acumatica:**
- Formulas execute consistently regardless of which Graph hosts the DAC
- Reduces code duplication and maintenance burden
- Architecture rules (§6.1, §6.3) mandate declarative patterns for invariant calculations
- PXDBCalced offloads computation to the database for read-heavy scenarios

**Risks / Side Effects:**
- Complex conditional calculations may not fit formula syntax
- Formula evaluation order matters for dependent fields
- PXDBCalced fields are read-only

**Acceptance Criteria:**
- Invariant calculations use `[PXFormula]` or `[PXDBCalced]`
- Imperative calculation code removed from event handlers
- Results match the imperative calculation

**Related Acumatica Mechanisms:**
`[PXFormula]`, `[PXDBCalced]`, `Mult<>`, `Add<>`, `Sub<>`, formula operators

**Common Anti-Patterns Nearby:**
- Copy-pasted arithmetic in multiple FieldUpdated handlers
- Calculated fields with no attribute relying entirely on event code

### Category H: Workflow (REF-7XX)

---

### REF-701: Use _Workflow Graph Extension Pattern for State Management

**Description:**  
Document state management MUST use the `{GraphName}_Workflow` graph extension pattern with `WorkflowContext` for defining states, transitions, and actions.

**When to Apply (Symptoms):**
- Status field managed via manual SetValue calls
- State transitions scattered throughout Graph
- No clear state machine definition
- Actions manually check/set status
- Workflow changes require code changes throughout Graph

**Core Transformation (Target State):**
- Create `{Graph}_Workflow : PXGraphExtension<{Graph}>` class
- Override `Configure(PXScreenConfiguration config)` method
- Use `context.AddScreenConfigurationFor(screen => ...)` for workflow
- Define states with `screen.StateIdentifierIs<status>()`
- Define transitions with `WithTransitions(...)`
- Actions bound to workflow via `WithActions(...)`

**Why It Matters in Acumatica:**
- Centralized state machine definition
- Visual workflow editor support
- Separation of workflow from business logic
- Declarative state management

**Risks / Side Effects:**
- Migration from imperative to declarative requires testing
- Complex workflows may have learning curve
- Actions must integrate with workflow

**Acceptance Criteria:**
- State management via _Workflow extension
- All transitions defined declaratively
- No manual status manipulation in Graph
- Workflow visible in designer

**Related Acumatica Mechanisms:**
`PXWorkflowDependsOnType`, `WorkflowContext<TGraph, TDoc>`, `StateIdentifierIs<>`, workflow designer

**Common Anti-Patterns Nearby:**
- Status SetValue in action handlers
- If/else chains checking status
- Missing workflow extension

---

### REF-702: Use Approval Workflow Layer for Approval Features

**Description:**  
Approval functionality MUST be implemented via `{Graph}_ApprovalWorkflow` extension layered on top of `{Graph}_Workflow`, with proper feature toggle checks.

**When to Apply (Symptoms):**
- Approval logic embedded in base workflow
- Approval transitions mixed with regular transitions
- No feature flag for approval functionality
- Cannot disable approvals without code change
- Approval states hardcoded

**Core Transformation (Target State):**
- Create `{Graph}_ApprovalWorkflow : PXGraphExtension<{Graph}_Workflow, {Graph}>`
- Implement `IsActive()` checking `FeaturesSet.approvalWorkflow`
- Add `[PXWorkflowDependsOnType(typeof({Setup}Approval))]`
- Layer approval states and transitions on base workflow
- Approval maps configured via setup tables

**Why It Matters in Acumatica:**
- Approvals are optional feature
- Base workflow functions without approvals
- Configuration-driven approval rules
- Proper feature toggle architecture

**Risks / Side Effects:**
- Layer order affects behavior
- Must test with and without feature enabled
- Approval setup tables required

**Acceptance Criteria:**
- Approval workflow in separate extension
- IsActive checks feature flag
- Base workflow functions without approvals
- Approval rules configurable

**Related Acumatica Mechanisms:**
`FeaturesSet.approvalWorkflow`, approval maps, `[PXWorkflowDependsOnType]`

**Common Anti-Patterns Nearby:**
- Approvals in base workflow
- Missing feature flag check
- Hardcoded approval logic

---

### REF-703: Define Workflow Conditions in Condition.Pack Class

**Description:**  
Workflow conditions MUST be defined in a nested `Conditions : Condition.Pack` class for reusability and clarity. Inline BQL conditions SHOULD be avoided.

**When to Apply (Symptoms):**
- Same condition BQL repeated across workflow
- Conditions defined inline in Configure method
- Condition logic difficult to understand
- Cannot reuse conditions across states/transitions

**Core Transformation (Target State):**
- Create `public class Conditions : Condition.Pack` nested in workflow
- Define conditions as `public Condition Name => GetOrCreate(b => b.FromBql<bql>());`
- Reference conditions from pack: `conditions.Name`
- Use meaningful condition names describing business rule

**Why It Matters in Acumatica:**
- Centralized condition definitions
- Self-documenting workflow
- Reusable across multiple transitions
- Easier maintenance and modification

**Risks / Side Effects:**
- Upfront organization required
- Must name conditions meaningfully
- Pack class adds structure

**Acceptance Criteria:**
- All conditions in Conditions pack
- No inline BQL in transitions
- Conditions named descriptively
- Reuse where applicable

**Related Acumatica Mechanisms:**
`Condition.Pack`, `GetOrCreate()`, `FromBql<>`, workflow configuration

**Common Anti-Patterns Nearby:**
- Inline condition BQL
- Duplicated conditions
- Cryptic condition names

---

### REF-704: Keep Workflow Availability Aligned with Server-Side Enforcement

**Priority:** High  
**Importance:** High

**Description:**  
Workflow state, transition, and action availability MUST stay aligned with action implementation, validation, and persistence logic. Workflow visibility or disabled actions must not be the only enforcement point for critical business rules.

**When to Apply (Symptoms):**
- Action is hidden or disabled in workflow but can still execute through non-UI paths
- Status transition is enforced only by workflow conditions
- Action implementation does not validate the same invariants as workflow availability
- Import/API/processing path can bypass the screen workflow state

**Core Transformation (Target State):**
- Keep workflow conditions and action implementation rules consistent
- Enforce critical state transitions and document invariants in server-side logic
- Validate action preconditions before persistence or release logic runs
- Add tests or manual validation for UI and non-UI invocation paths when applicable

**Why It Matters in Acumatica:**
- Workflow controls screen behavior, but business actions may be invoked through other framework paths
- Server-side validation protects imports, APIs, processing screens, and customizations
- Consistent enforcement prevents invalid persisted states

**Risks / Side Effects:**
- Duplicating complex conditions can drift if not centralized
- Server-side checks must avoid blocking legitimate background or import flows

**Acceptance Criteria:**
- Workflow availability and server-side validation express the same business invariant
- Invalid transitions cannot be persisted through non-UI paths
- Tests or validation cover the relevant invocation paths

**Related Acumatica Mechanisms:**
Workflow, `PXAction`, `RowPersisting`, action handlers, import/API execution paths

**Common Anti-Patterns Nearby:**
- Relying on disabled toolbar actions as the only guard
- Manually setting status without validating allowed transitions

---

### Category I: Integration (REF-8XX)

---

### REF-801: Choose Correct Slot Lifetime for Cached State

**Description:**  
Configuration and shared reference data accessed frequently across requests SHOULD use persistent `PXDatabase.GetSlot` / `IPrefetchable` slots rather than repeated database queries. Request-context state MUST use `PXContext` slots and must not be stored in persistent slots.

**When to Apply (Symptoms):**
- Same setup query executed repeatedly
- Configuration data read on every request
- `GetSlot` not used for static or read-mostly configuration
- Persistent `PXDatabase.GetSlot` stores graph instances, current rows, user-specific data, or mutable request state
- Temporary execution flags are stored in persistent slots instead of `PXContext`
- Performance degradation from config queries
- Feature flag checks hitting database

**Core Transformation (Target State):**
- Use `PXContext.GetSlot` / `PXContext.SetSlot` for request-context state and scoped coordination.
- Use `PXDatabase.GetSlot<Definition>(name, typeof(SetupTable))` for persistent shared cache of read-mostly setup or reference data.
- Create `private class Definition : IPrefetchable` when persistent slot data requires prefetching or parsing.
- Persistent slot keys and dependent tables MUST include every dimension that can change the cached value.
- Persistent slots MUST be invalidated through dependent tables or an intentional reset path.

**Why It Matters in Acumatica:**
- Configuration rarely changes
- Slot provides automatic invalidation
- Eliminates redundant queries
- Thread-safe access to cached data
- Wrong slot lifetime can leak request, user, tenant, or graph state across executions

**Risks / Side Effects:**
- Prefetch runs synchronously on first access
- Must use PXDatabase direct access, not Graph
- Invalidation based on table, not specific record, unless keying/reset logic accounts for it
- Missing dimensions in the slot key can serve stale or cross-context data

**Acceptance Criteria:**
- Static/read-mostly configuration uses persistent `PXDatabase.GetSlot`
- Temporary request state uses `PXContext` slots
- Persistent slots do not store graph instances, current rows, mutable request state, or user-specific transient values
- No repeated setup queries per request
- Persistent slot invalidates on table change or explicit reset path
- Performance improvement measurable

**Related Acumatica Mechanisms:**
`IPrefetchable`, `PXDatabase.GetSlot<T>`, `PXContext.GetSlot`, `PXContext.SetSlot`, `PXDataRecord`, slot invalidation

**Common Anti-Patterns Nearby:**
- PXSelect in slot Prefetch (not allowed)
- Missing table type for invalidation
- Over-caching dynamic data
- Request-specific data in persistent slots

---

### REF-802: Use Abstract Graph Extension for Shared Integration Logic

**Description:**  
Integration logic shared across multiple Graphs MUST use abstract generic Graph Extensions rather than service classes or static methods.

**When to Apply (Symptoms):**
- Same integration code copied to multiple Graphs
- Service classes instantiated per Graph
- Static methods require Graph parameter
- Cannot customize integration per Graph
- Integration not extension-aware

**Core Transformation (Target State):**
- Create `abstract class IntegrationExt<TGraph, TDoc> : PXGraphExtension<TGraph>`
- Define shared logic in abstract class
- Create concrete extensions for specific Graphs
- Override abstract members for Graph-specific behavior
- Use `IsActive()` for feature control

**Why It Matters in Acumatica:**
- Code reuse without duplication
- Graph-specific customization supported
- Proper extension chain for customizers
- Lifecycle managed by framework

**Risks / Side Effects:**
- Requires concrete extension per Graph
- Abstract class cannot be instantiated directly
- Type parameters add complexity

**Acceptance Criteria:**
- Shared logic in abstract extension
- Concrete extensions for each Graph
- No code duplication
- Extensions customizable

**Related Acumatica Mechanisms:**
Abstract generic extensions, `PXGraphExtension<T>`, type constraints

**Common Anti-Patterns Nearby:**
- Static helper classes for integration
- Service classes receiving Graph
- Copy-paste integration code

---

### REF-803: Check Public Surface Impact of Data and Action Changes

**Priority:** Medium  
**Importance:** High

**Description:**  
Changes to DAC fields, projections, selectors, actions, statuses, or workflow state can affect Contract-Based REST API, OData, Generic Inquiries, import/export scenarios, reports, and integrations. Treat this as a review guardrail when the changed object is exposed or likely reusable.

**When to Apply (Symptoms):**
- Public or screen-backed DAC field is added, removed, renamed, or changes type/meaning
- Projection or selector shape changes and may feed inquiry/report/API paths
- Action signature, availability, or server-side behavior changes
- Status/list value changes affect document lifecycle
- Local GI definitions, endpoint definitions, or reports show exposed usage

**Core Transformation (Target State):**
- Identify likely exposed surfaces for the changed object when the risk is material
- Preserve backward-compatible field names, types, keys, and values unless a breaking change is intentional
- Update or validate affected GI, OData, REST endpoint, import/export, and report contracts when in scope
- Document review limitations when exposed-surface evidence is unavailable

**Why It Matters in Acumatica:**
- DACs and projections often serve multiple UI, inquiry, report, API, and import paths
- A safe screen change can still break an integration or exposed inquiry metadata
- Early surface checks reduce upgrade and customer-integration regressions

**Risks / Side Effects:**
- Over-checking every internal field creates review noise
- Some exposed surfaces are tenant/customization-specific and cannot be fully proven from source alone

**Acceptance Criteria:**
- Material public-surface impact is checked or explicitly scoped out
- Breaking exposed contract changes have migration/compatibility notes
- Review findings separate confirmed exposed impact from possible exposure risk

**Related Acumatica Mechanisms:**
Contract-Based REST API, OData, Generic Inquiry, import/export scenarios, reports, screen actions

**Common Anti-Patterns Nearby:**
- Treating screen behavior as the only consumer of a DAC field
- Changing projection keys without checking inquiries or reports
- Changing action availability without checking API/import paths

---

### Category J: Security & Multi-Tenant (REF-9XX)

---

### REF-901: Use Match<> for Row-Level Security in Views

**Description:**  
Views containing security-sensitive data MUST include `Match<Current<AccessInfo.userName>>` or equivalent row-level security restrictions.

**When to Apply (Symptoms):**
- Users see data they shouldn't access
- View lacks security filtering
- Manual security checks in handlers
- Restriction groups not enforced
- Cross-branch data visible inappropriately

**Core Transformation (Target State):**
- Add `Where<Match<Current<AccessInfo.userName>>>` to view
- Use `MatchUser` or `MatchUserFor<TTable>` where available
- Combine with branch restriction: `ReadBranchRestrictedScope`
- Security restrictions apply at query level
- Respect `[PXDBGroupMask]` on DAC

**Why It Matters in Acumatica:**
- Security must be enforced at data layer
- UI hiding insufficient for security
- Compliance requirements mandate access control
- Multi-tenant architecture requires isolation

**Risks / Side Effects:**
- Performance impact of security joins
- Must test with multiple users/roles
- Over-restriction may hide required data

**Acceptance Criteria:**
- Security-sensitive views include Match
- Row-level security functions correctly
- Users only see permitted data
- Performance acceptable

**Related Acumatica Mechanisms:**
`Match<>`, `MatchUser`, `MatchUserFor<T>`, `[PXDBGroupMask]`, `PXReadBranchRestrictedScope`

**Common Anti-Patterns Nearby:**
- Security in UI only
- Manual row filtering in handlers
- Missing restriction group checks

---

### REF-902: Use PXAccess.FeatureInstalled for Feature Checks

**Description:**  
Feature flag checks MUST use `PXAccess.FeatureInstalled<FeaturesSet.feature>()` rather than direct database queries or custom implementations.

**When to Apply (Symptoms):**
- Feature checks query database directly
- Custom feature flag implementation
- Inconsistent feature checking patterns
- Feature state not cached
- FeaturesSet not used

**Core Transformation (Target State):**
- Use `PXAccess.FeatureInstalled<FeaturesSet.featureName>()`
- Combine checks: `&& PXAccess.FeatureInstalled<...>()`
- Use in `IsActive()` for extension activation
- Use in views for conditional field visibility
- Cache feature state where frequently accessed

**Why It Matters in Acumatica:**
- Centralized feature management
- License validation integrated
- Cached for performance
- Consistent across application

**Risks / Side Effects:**
- Feature state cached per session
- Cannot create new features without coordination
- Feature dependency chains possible

**Acceptance Criteria:**
- All feature checks use PXAccess.FeatureInstalled
- No custom feature implementations
- IsActive uses feature checks
- Feature behavior consistent

**Related Acumatica Mechanisms:**
`PXAccess.FeatureInstalled<T>`, `FeaturesSet`, feature licensing, `IsActive()`

**Common Anti-Patterns Nearby:**
- Direct CS.Features queries
- Boolean setup fields instead of features
- Feature checks in inappropriate places

---

### REF-903: Respect Branch Context in Data Operations

**Description:**  
Data operations MUST respect the current branch context using `PXAccess.GetBranchID()` or appropriate branch attributes on DACs.

**When to Apply (Symptoms):**
- Cross-branch data visible inappropriately
- Data created in wrong branch
- Branch-independent queries for branch-specific data
- Branch filtering manual and inconsistent
- PXReadBranchRestrictedScope not used

**Core Transformation (Target State):**
- Use `[PXDBDefault(typeof(AccessInfo.branchID))]` on BranchID field
- Use `PXReadBranchRestrictedScope` for cross-branch read operations
- Validate branch access in business logic
- Views include branch filtering where appropriate
- Respect `OrganizationID` for multi-company

**Why It Matters in Acumatica:**
- Multi-branch architecture requires isolation
- Financial data must not cross branches
- Audit compliance requires branch segregation
- User permissions tied to branches

**Risks / Side Effects:**
- Over-restriction may break legitimate cross-branch needs
- Branch hierarchy complexity
- Testing requires multiple branch setups

**Acceptance Criteria:**
- Branch context respected in operations
- Cross-branch access explicitly controlled
- Data isolated to appropriate branches
- Branch permissions enforced

**Related Acumatica Mechanisms:**
`PXAccess.GetBranchID()`, `[Branch]`, `PXReadBranchRestrictedScope`, `OrganizationID`

**Common Anti-Patterns Nearby:**
- Missing branch on DAC
- Ignoring branch in queries
- Hardcoded branch access

---

---

### REF-904: Do Not Create New FeaturesSet Entries Without Justification

**Priority:** Medium  
**Importance:** High

**Description:**  
New entries in `FeaturesSet` MUST NOT be created without explicit justification and coordination. Existing feature flags SHOULD be reused when possible. For minor functionality toggles, use setup-based activation instead.

**When to Apply (Symptoms):**
- Developer proposes adding a new `FeaturesSet` field for a minor toggle
- Existing feature flag already covers the desired gating condition
- Feature flag added without licensing coordination
- Setup table flag would be more appropriate

**Core Transformation (Target State):**
- Reuse existing `FeaturesSet` entries when the feature scope matches
- For minor toggles, use setup table flags with `IPrefetchable` activation (see REF-801)
- If a new `FeaturesSet` entry is truly needed, document:
  - Business justification
  - Licensing implications
  - Testing matrix (enabled/disabled combinations)

**Why It Matters in Acumatica:**
- Each `FeaturesSet` entry affects licensing, testing, and configuration complexity
- Feature proliferation increases the testing matrix exponentially
- Architecture rules (§8.4) explicitly restrict new feature flag creation
- Setup-based activation is simpler for internal toggles

**Risks / Side Effects:**
- Reusing a feature flag for unrelated logic can create unexpected coupling
- Setup-based flags lack the licensing integration of FeaturesSet

**Acceptance Criteria:**
- No new `FeaturesSet` entries without documented justification
- Minor toggles use setup-based activation
- Existing feature flags reused where scope matches

**Related Acumatica Mechanisms:**
`FeaturesSet`, `PXAccess.FeatureInstalled<>`, `IPrefetchable`, setup tables

**Common Anti-Patterns Nearby:**
- One feature flag per minor toggle
- Feature flags without testing in both enabled/disabled states

---

### REF-905: Do Not Enforce Security Through UI State Only

**Priority:** High  
**Importance:** Critical

**Description:**  
UI visibility, disabled fields, and workflow action availability are not authorization. Security-sensitive restrictions MUST be enforced in server-side validation, action logic, query filters, and persistence paths.

**When to Apply (Symptoms):**
- Field or action is hidden/disabled but server-side logic still accepts the operation
- Access restriction exists only in `RowSelected`
- Import, API, processing screen, or customization path can bypass UI checks
- Query exposes data and relies on UI filtering for security

**Core Transformation (Target State):**
- Enforce access restrictions in queries, action handlers, validation, and persistence logic
- Use `Match<>`, branch restrictions, group masks, and framework access mechanisms where applicable
- Keep UI visibility/enabled logic as presentation only
- Validate non-UI invocation paths when the action or field is exposed

**Why It Matters in Acumatica:**
- Users and integrations can reach business logic through paths other than the screen toolbar
- UI state is not a security boundary
- Server-side enforcement protects imports, APIs, GIs, processing screens, reports, and customizations

**Risks / Side Effects:**
- Server-side checks must account for legitimate automation and background processing contexts
- Over-restricting query filters can hide required operational data

**Acceptance Criteria:**
- Security-sensitive operations have server-side enforcement
- UI state mirrors server-side rules but does not replace them
- Non-UI paths cannot bypass the restriction

**Related Acumatica Mechanisms:**
`Match<>`, `[PXDBGroupMask]`, branch restrictions, `PXAction`, `RowPersisting`, access rights

**Common Anti-Patterns Nearby:**
- Security logic only in `RowSelected`
- Hidden action with no server-side precondition check
- Query returns sensitive data and relies on UI hiding

## 4. Quick Reference: Refactoring by Category

| Category | Refactoring IDs |
|----------|-----------------|
| **A. Graph & Extensions** | REF-001, REF-002, REF-003, REF-004, REF-005, REF-006, REF-007, REF-008, REF-009, REF-010, REF-011, REF-012, REF-013, REF-014, REF-015 |
| **B. DAC & Attributes** | REF-101, REF-102, REF-103, REF-104, REF-105, REF-106, REF-107, REF-108, REF-109, REF-110, REF-111, REF-112, REF-113, REF-114, REF-115, REF-116, REF-117, REF-118, REF-119, REF-120, REF-121, REF-122, REF-123, REF-124, REF-125 |
| **C. BQL & Data Access** | REF-201, REF-202, REF-203, REF-204, REF-205, REF-206, REF-207, REF-208, REF-209, REF-210, REF-211 |
| **D. Events & Business Logic** | REF-301, REF-302, REF-303, REF-304, REF-305, REF-306, REF-307, REF-308, REF-309, REF-310, REF-311, REF-312 |
| **E. Cache & Persistence** | REF-401, REF-402, REF-403, REF-404, REF-405 |
| **F. Long Operations** | REF-501, REF-502, REF-503, REF-504, REF-505 |
| **G. UI Behavior** | REF-601, REF-602, REF-603, REF-604, REF-605, REF-606, REF-607 |
| **H. Workflow** | REF-701, REF-702, REF-703, REF-704 |
| **I. Integration** | REF-801, REF-802, REF-803 |
| **J. Security & Multi-Tenant** | REF-901, REF-902, REF-903, REF-904, REF-905 |

---

## 5. Detection Signal Summary

For automated agent detection, the following code patterns indicate potential refactoring candidates:

| Signal Pattern | Potential Refactoring |
|---------------|----------------------|
| `Events.RowSelected` + `PXSelect/SelectFrom` | REF-301 |
| Raw SQL string / direct provider command | REF-202 |
| `PXDatabase.Insert/Update/Delete` in normal business flow | REF-202 (review context) |
| `foreach` + `.Select()` inside loop | REF-203 |
| `[PXOverride]` without delegate parameter | REF-002 |
| Broad `[PXProtectedAccess]` bridge | REF-015 |
| `protected int? _FieldName;` in DAC | REF-101 |
| New standalone `PXSelect<...>` where Fluent BQL is practical | REF-201 |
| `Persist()` inside event handler | REF-404 |
| `cache.SetValue` (not SetValueExt) | REF-303 (review) |
| Missing `if (e.Row == null) return;` | REF-305 |
| Graph > 2000 LOC without extensions | REF-001 |
| Product-owned persistent field added through unjustified `[PXCacheExtension]` | REF-105 |
| Missing PK/FK nested classes | REF-103 |
| Missing system audit fields | REF-104 |
| `PXMergeAttributes(Method = MergeMethod.Replace)` / `PXRemoveBaseAttribute` | REF-124 |
| Persisted status/list constant value changed or reused | REF-125 |
| Operations > 30s without PXLongOperation | REF-501 |
| `this` captured in long operation lambda | REF-502, REF-504 |
| SetEnabled outside RowSelected | REF-601 |
| Status SetValue without workflow | REF-701 |
| Workflow-only action/status enforcement | REF-704 |
| Repeated setup queries | REF-801 |
| Request/user-specific state in `PXDatabase.GetSlot` | REF-801 |
| DAC/projection/action/status change with exposed API/OData/GI/import/report use | REF-803 |
| Missing Match<> in sensitive views | REF-901 |
| Feature check not using PXAccess.FeatureInstalled | REF-902 |
| `new SomeGraph()` / `new PXGraph()` | REF-005 |
| Graph Extension constructor present | REF-009 |
| `static PXSelect` / `static PXAction` | REF-010 |
| `PXView.StartRow` used in view delegate | REF-007 |
| `PXSetupNotEnteredException` thrown outside RowSelected | REF-310 |
| `PXDBLocalizableString` without NoteID | REF-117 |
| `PXDBCalced`/`PXDBScalar` without unbound type attribute | REF-116 |
| `new SomeGraph()` in static method | REF-014 |
| `: IBqlTable` without `PXBqlTable` | REF-121 |
| DAC class without `[Serializable]` | REF-122 |
| DAC field added without SQL update | REF-123 |
| `.On<T.field.IsEqual<U.field>>` where FK exists | REF-208 |
| `SelectFrom<>.View` used read-only | REF-209 |
| `.Select()` on large dataset without windowing | REF-210 |
| `[PXProjection]` field without `BqlField` mapping | REF-211 |
| `Persistent = true` projection without write-semantics review | REF-211 |
| Repeated `SetVisible` + `FeatureInstalled` across Graphs | REF-311 |
| `SomeAction.Press()` inside event handler | REF-312 |
| Manual parent key copy in `FieldDefaulting` | REF-405 |
| `[PXUIField]` on action without `MapEnableRights` | REF-606 |
| Same arithmetic in multiple `FieldUpdated` handlers | REF-607 |
| New `FeaturesSet` field without justification | REF-904 |
| Security rule enforced only by UI hidden/disabled state | REF-905 |

---

*Document Version: 1.3*  
*Maintained as an Acumatica application-development review standard*
