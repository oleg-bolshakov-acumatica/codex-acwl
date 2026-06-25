# Acumatica Framework Architecture Rules

## 1. Core Principles

### 1.1 Target Environment
- .NET Framework 4.8
- C# 12.0
- Nullable reference types: disabled by default, enabled for new files

### 1.2 Fundamental Rules
1. Never use direct SQL. Use BQL or Fluent BQL exclusively.
2. Always work through PXCache for data operations.
3. Define field behavior through attributes, not imperative code.
4. Keep DACs, Graphs, and business logic separate.
5. Primary key fields must never change after insert.
6. Prefer platform mechanisms over custom implementations.
7. Prefer declarative over imperative logic for invariant behavior.
8. All logic must respect feature toggles and access rights.
9. Changes to fields, actions, statuses, workflows, projections, or selectors may affect API, OData, GI, import/export, and reports; check exposed surfaces when behavior changes.

This document defines framework-level architecture rules. For practical feature implementation patterns, data-path coverage, recalculation parity, and report/query tracing, see [FEATURE_IMPLEMENTATION_PATTERNS.md](FEATURE_IMPLEMENTATION_PATTERNS.md).

---

## 2. Data Access Classes (DACs)

### 2.1 Structure Requirements
```csharp
[Serializable]
[PXCacheName("Display Name")]
public class MyEntity : PXBqlTable, IBqlTable
{
    #region Keys
    public class PK : PrimaryKeyOf<MyEntity>.By<keyField>
    {
        public static MyEntity Find(PXGraph graph, int? keyField, PKFindOptions options = PKFindOptions.None)
            => FindBy(graph, keyField, options);
    }
    
    public static class FK
    {
        public class ParentEntity : Parent.PK.ForeignKeyOf<MyEntity>.By<parentID> { }
    }
    #endregion
    
    // Fields follow...
}
```

### 2.2 Field Definition Pattern
```csharp
#region FieldName
public abstract class fieldName : BqlType.Field<fieldName> { }

[PXDBType]
[PXUIField(DisplayName = "Field Name")]
public virtual Type FieldName { get; set; }
#endregion
```

**Rule**: Always use auto-implemented properties. Do not use explicit backing fields.

```csharp
// CORRECT - Auto-implemented property
[PXDBInt]
[PXUIField(DisplayName = "Project")]
public virtual int? ProjectID { get; set; }

// INCORRECT - Explicit backing field
protected int? _ProjectID;

[PXDBInt]
[PXUIField(DisplayName = "Project")]
public virtual int? ProjectID
{
    get => _ProjectID;
    set => _ProjectID = value;
}
```

This rule applies to all DACs and DAC extensions unless there is a strictly justified technical exception.

### 2.3 Mandatory System Fields
Every persistent DAC must include:
- `CompanyID` (handled by framework)
- `CreatedByID`, `CreatedByScreenID`, `CreatedDateTime`
- `LastModifiedByID`, `LastModifiedByScreenID`, `LastModifiedDateTime`
- `tstamp` (timestamp for concurrency)
- `NoteID` (for attachments/notes, when applicable)

### 2.4 DAC Extensions
**Rule**: For product-owned persistent fields in product DACs, prefer adding fields directly to the DAC that owns the table.

**Allowed uses**: DAC/cache extensions are acceptable when the base DAC cannot or should not be modified, when the local architecture already uses a feature-owned extension pattern, or for unbound, calculated, projection-specific, integration, compatibility, or customization fields.

Do not create a parallel DAC extension merely to keep an internal product change separate from the owning DAC.

```csharp
// INCORRECT
[PXCacheExtension(typeof(InventoryItem))]
public class InventoryItemExt : PXCacheExtension<InventoryItem> { }

// CORRECT - Add fields directly to DAC
public class InventoryItem : PXBqlTable, IBqlTable
{
    // Add new fields here
}
```

### 2.5 BQL Field Type Matching

**Rule**: BQL field classes must be strongly typed and must strictly correspond to the CLR types of their associated properties. This is a mandatory requirement for all DAC implementations.

#### 2.5.1 Type Correspondence Table

| CLR Property Type | BQL Field Class |
|-------------------|-----------------|
| `int?` | `BqlInt.Field<fieldName>` |
| `long?` | `BqlLong.Field<fieldName>` |
| `short?` | `BqlShort.Field<fieldName>` |
| `string` | `BqlString.Field<fieldName>` |
| `decimal?` | `BqlDecimal.Field<fieldName>` |
| `double?` | `BqlDouble.Field<fieldName>` |
| `float?` | `BqlFloat.Field<fieldName>` |
| `bool?` | `BqlBool.Field<fieldName>` |
| `DateTime?` | `BqlDateTime.Field<fieldName>` |
| `Guid?` | `BqlGuid.Field<fieldName>` |
| `byte[]` | `BqlByteArray.Field<fieldName>` |

#### 2.5.2 Correct Examples

```csharp
#region ProjectID
public abstract class projectID : BqlInt.Field<projectID> { }

[PXDBInt]
[PXUIField(DisplayName = "Project")]
public virtual int? ProjectID { get; set; }
#endregion

#region Description
public abstract class description : BqlString.Field<description> { }

[PXDBString(255, IsUnicode = true)]
[PXUIField(DisplayName = "Description")]
public virtual string Description { get; set; }
#endregion

#region Amount
public abstract class amount : BqlDecimal.Field<amount> { }

[PXDBDecimal(4)]
[PXUIField(DisplayName = "Amount")]
public virtual decimal? Amount { get; set; }
#endregion

#region IsActive
public abstract class isActive : BqlBool.Field<isActive> { }

[PXDBBool]
[PXDefault(true)]
[PXUIField(DisplayName = "Active")]
public virtual bool? IsActive { get; set; }
#endregion

#region CreatedDateTime
public abstract class createdDateTime : BqlDateTime.Field<createdDateTime> { }

[PXDBCreatedDateTime]
public virtual DateTime? CreatedDateTime { get; set; }
#endregion

#region NoteID
public abstract class noteID : BqlGuid.Field<noteID> { }

[PXNote]
public virtual Guid? NoteID { get; set; }
#endregion

#region Tstamp
public abstract class tstamp : BqlByteArray.Field<tstamp> { }

[PXDBTimestamp]
public virtual byte[] Tstamp { get; set; }
#endregion
```

#### 2.5.3 Incorrect Examples (Do Not Use)

```csharp
// INCORRECT - BqlString used for int? property
#region ProjectID
public abstract class projectID : BqlString.Field<projectID> { }  // WRONG!

[PXDBInt]
public virtual int? ProjectID { get; set; }
#endregion

// INCORRECT - BqlInt used for decimal? property
#region Amount
public abstract class amount : BqlInt.Field<amount> { }  // WRONG!

[PXDBDecimal(4)]
public virtual decimal? Amount { get; set; }
#endregion

// INCORRECT - BqlString used for bool? property
#region IsActive
public abstract class isActive : BqlString.Field<isActive> { }  // WRONG!

[PXDBBool]
public virtual bool? IsActive { get; set; }
#endregion

// INCORRECT - BqlString used for DateTime? property
#region DocDate
public abstract class docDate : BqlString.Field<docDate> { }  // WRONG!

[PXDBDate]
public virtual DateTime? DocDate { get; set; }
#endregion
```

#### 2.5.4 Why This Matters

1. **Compile-Time Safety**: Mismatched types can lead to runtime errors in BQL queries that would otherwise be caught at compile time.

2. **Query Correctness**: BQL uses the field class type to generate correct SQL. Type mismatches can cause:
   - Incorrect query results
   - SQL type conversion errors
   - Performance issues due to implicit conversions

3. **Fluent BQL Operations**: Type-specific operations (e.g., `IsGreater<>`, `Contains<>`) require correct BQL types to function properly.

4. **Framework Consistency**: The Acumatica framework relies on type information for caching, serialization, and data binding.

#### 2.5.5 Attribute to BQL Type Correlation

When defining fields, ensure the attribute type also aligns with the BQL field type:

| Attribute | Expected BQL Type | CLR Type |
|-----------|-------------------|----------|
| `[PXDBInt]`, `[PXDBIdentity]` | `BqlInt` | `int?` |
| `[PXDBLong]` | `BqlLong` | `long?` |
| `[PXDBShort]` | `BqlShort` | `short?` |
| `[PXDBString]` | `BqlString` | `string` |
| `[PXDBDecimal]`, `[PXDBCury]` | `BqlDecimal` | `decimal?` |
| `[PXDBDouble]` | `BqlDouble` | `double?` |
| `[PXDBFloat]` | `BqlFloat` | `float?` |
| `[PXDBBool]` | `BqlBool` | `bool?` |
| `[PXDBDate]`, `[PXDBDateAndTime]` | `BqlDateTime` | `DateTime?` |
| `[PXDBGuid]` | `BqlGuid` | `Guid?` |
| `[PXDBTimestamp]`, `[PXDBBinary]` | `BqlByteArray` | `byte[]` |

---

## 3. Relationships and Integrity

### 3.1 Foreign Key Definitions
Define relationships using the FK class pattern:
```csharp
public static class FK
{
    public class Order : SOOrder.PK.ForeignKeyOf<SOLine>.By<orderType, orderNbr> { }
    public class InventoryItem : IN.InventoryItem.PK.ForeignKeyOf<SOLine>.By<inventoryID> { }
}
```

### 3.2 Relationship Attributes
| Attribute | Purpose |
|-----------|---------|
| `[PXParent(typeof(FK.Parent))]` | Parent-child relationship with cascade delete |
| `[PXForeignReference(typeof(FK.Entity))]` | Referential integrity enforcement |
| `[PXDBDefault(typeof(Parent.field))]` | Cascade default values from parent |
| `[PXDBChildIdentity(typeof(Parent.identityField))]` | Link identity to parent's auto-number |

### 3.3 Usage in BQL
```csharp
// CORRECT - Use FK for joins and conditions
public SelectFrom<SOLine>
    .InnerJoin<InventoryItem>.On<SOLine.FK.InventoryItem>
    .Where<SOLine.FK.Order.SameAsCurrent>
    .View Lines;

// INCORRECT - Manual join conditions
public SelectFrom<SOLine>
    .InnerJoin<InventoryItem>.On<InventoryItem.inventoryID.IsEqual<SOLine.inventoryID>>
    .View Lines;
```

---

## 4. BQL Guidelines

### 4.1 Prefer Fluent BQL
**Rule**: Prefer Fluent BQL (`SelectFrom<>`, `SearchFor<>`) for new standalone queries.

When modifying legacy code with dense classic BQL, preserve the local query style if that keeps the change smaller, clearer, and less risky. Do not mix query styles inside a tightly related block without a concrete readability or safety benefit.

```csharp
// PREFERRED FOR NEW STANDALONE QUERIES
public SelectFrom<SOLine>
    .Where<SOLine.FK.Order.SameAsCurrent>
    .View Lines;

// ALLOWED WHEN PRESERVING LOCAL LEGACY STYLE IS SAFER
public PXSelect<SOLine,
    Where<SOLine.orderType, Equal<Current<SOOrder.orderType>>,
    And<SOLine.orderNbr, Equal<Current<SOOrder.orderNbr>>>>> Lines;
```

### 4.2 DAC Projections
Use `[PXProjection]` for reusable complex queries:
```csharp
[PXProjection(typeof(
    SelectFrom<BaseTable>
    .InnerJoin<JoinedTable>.On<...>
), Persistent = false)]
[PXHidden]
public class ProjectedDAC : PXBqlTable, IBqlTable
{
    [PXDBInt(IsKey = true, BqlField = typeof(BaseTable.keyField))]
    public virtual int? KeyField { get; set; }
    
    [PXDBCalced(typeof(Formula), typeof(decimal))]
    public virtual decimal? CalculatedField { get; set; }
}
```

**Rules:**
- Map every persisted projection field to its source with `BqlField`, unless it is explicitly calculated, scalar, or unbound.
- Define `IsKey` fields so they represent the real uniqueness of the projected row.
- Keep `Persistent = false` for read models. Use persistent projections only when insert, update, and delete behavior is intentionally designed and verified.
- Treat projection field and key changes as public read-model changes when the projection can feed inquiries, reports, APIs, or imports.

---

## 5. Graphs and Business Logic

### 5.1 Graph Structure
```csharp
public class MyGraph : PXGraph<MyGraph, PrimaryDAC>
{
    // Views
    public SelectFrom<PrimaryDAC>.View Document;
    public SelectFrom<DetailDAC>.Where<DetailDAC.FK.Document.SameAsCurrent>.View Details;
    
    // Actions
    public PXAction<PrimaryDAC> MyAction;
    
    // Event handlers
    protected virtual void _(Events.FieldUpdated<PrimaryDAC, PrimaryDAC.field> e) { }
    protected virtual void _(Events.RowSelected<PrimaryDAC> e) { }
}
```

### 5.2 Graph Extensions
**Rule**: Use abstract graph extensions instead of service classes for injectable functionality.

```csharp
// CORRECT
public abstract class DocumentProcessingExtension<TGraph, TDocument> : PXGraphExtension<TGraph>
    where TGraph : PXGraph
    where TDocument : class, IBqlTable, new()
{
    public static bool IsActive() => true;
    
    public virtual void ProcessDocument(TDocument doc)
    {
        // Full access to Base graph
    }
}

// INCORRECT
public class DocumentService : IDocumentService
{
    public void ProcessDocument(Document doc) { }
}
```

### 5.3 Method Visibility and Overrides
- Make all methods that may need customization `virtual`.
- Do not use `static` methods for business behavior that may need customization.
- Static methods are acceptable for pure utilities, constants, list attributes, BQL constants, and shared framework-neutral calculations that do not need graph state or customization hooks.
- Use `[PXOverride]` in extensions to override base graph methods.

### 5.4 PXOverride Requirements

`[PXOverride]` is used to override virtual methods of a Graph or Graph Extension from a higher-level Graph Extension.

#### 5.4.1 Base Method Requirements

A method can be overridden with `[PXOverride]` only if:
- It is `virtual`
- It is `public`, `protected`, or `protected internal`
- It is declared in a Graph or Graph Extension
- It is **not generic** (generic base methods are not supported)

#### 5.4.2 Override Method Rules

A `[PXOverride]` method:
- Must be `public`
- Must **not** be `virtual`, `abstract`, or `override`
- Must **not** be `static`
- Must be declared inside a Graph Extension
- Must have the **same name** as the base method
- Must have the **same return type** and parameters as the base method
- Must include **one additional delegate parameter**

#### 5.4.3 Delegate Parameter (Mandatory)

**Rule**: `[PXOverride]` methods without a delegate parameter are forbidden.

The delegate parameter:
- Must have a signature matching the base method exactly
- Must be named `base_<MethodName>` (e.g., `base_Add`)
- Allows calling the base implementation and ensures predictable execution order

Without the delegate parameter:
- Execution order becomes unpredictable
- Return values become unreliable when multiple overrides exist
- `IEnumerable<T>` return types may cause previous overrides not to execute
- `Task`/`Task<T>` return types may cause async execution bugs

#### 5.4.4 XML Documentation Requirement

Each `[PXOverride]` method must have a single-line XML comment referencing the overridden method:

```csharp
/// Overrides <seealso cref="FullGraphName.MethodName(type1, type2)"/>
```

Do not wrap in `<summary>`. Use the full method signature.

#### 5.4.5 Example

```csharp
public class MyGraph : PXGraph<MyGraph>
{
    public virtual int Add(int x, string y) 
        => x + Convert.ToInt32(y);
}

public class MyGraphExtension : PXGraphExtension<MyGraph>
{
    /// Overrides <seealso cref="MyGraph.Add(int, string)"/>
    [PXOverride]
    public int Add(int x, string y,
        Func<int, string, int> base_Add)
    {
        if (x < 10)
        {
            return x + Convert.ToInt32(y) * 2;
        }

        return base_Add(x, y);
    }
}
```

### 5.5 PXProtectedAccess

Use `[PXProtectedAccess]` only as a narrow extensibility bridge to an existing protected member when normal `virtual` methods, graph extension APIs, or `[PXOverride]` cannot express the customization point.

**Rules:**
- Keep the exposed protected surface minimal.
- Add XML documentation that references the original protected member.
- Do not expose mutable internal state merely for convenience.
- Prefer adding a proper virtual method or protected extension point when you control the base code.

---

## 6. Declarative Logic

### 6.1 When to Use Declarative
Use declarative patterns for behavior that is invariant across all graph contexts:

| Logic Type | Implementation |
|------------|----------------|
| Field defaults | `[PXDefault]`, `[PXFormula]` |
| Field validation (simple) | `[PXUIRequired]`, `[PXUIVerify]`, `[PXRestrictor]` |
| Calculated fields | `[PXFormula]`, `[PXDBCalced]`, `[PXDBScalar]` |
| Relationships | `[PXParent]`, `[PXForeignReference]`, `[PXDBDefault]` |
| Cross-field dependencies | `[PXFormula(typeof(Default<...>))]` |

### 6.2 When to Use Imperative
Use imperative patterns for graph-specific logic:

| Logic Type | Implementation |
|------------|----------------|
| Complex validation | `FieldVerifying` event handler |
| Graph workflow logic | Event handlers |
| UI state management | `RowSelected` (no DB queries) |
| Complex calculations | `FieldDefaulting`, `RowUpdated` |

### 6.3 Calculated Field Examples
```csharp
// Database-side calculation
[PXDBCalced(typeof(
    SOLine.orderQty.Multiply<SOLine.unitPrice>.Subtract<SOLine.discAmt>
), typeof(decimal))]
public virtual decimal? NetAmount { get; set; }

// Application-side formula
[PXFormula(typeof(Mult<SOLine.orderQty, SOLine.unitPrice>))]
public virtual decimal? ExtPrice { get; set; }
```

### 6.4 Attribute Modification

Use `CacheAttached` attribute modification carefully because it changes field behavior for the active graph context.

**Rules:**
- Prefer `PXMergeAttributes(Method = MergeMethod.Append)` or `Merge` over `Replace`.
- Use `PXRemoveBaseAttribute` only when the removed base behavior is explicitly replaced or no longer valid.
- Be especially careful with DB, defaulting, formula, selector, restrictor, note, searchable, and security-related attributes.
- After changing attributes, verify defaulting, validation, UI state, persistence, import/API behavior, and workflow/action availability affected by that field.

---

## 7. Workflow Extensions

### 7.1 Pattern
Use `_Workflow` graph extension pattern for entity state management:

```csharp
public class SOOrderEntry_Workflow : PXGraphExtension<SOOrderEntry>
{
    [PXWorkflowDependsOnType(typeof(SOSetup))]
    public sealed override void Configure(PXScreenConfiguration config) =>
        Configure(config.GetScreenConfigurationContext<SOOrderEntry, SOOrder>());

    protected static void Configure(WorkflowContext<SOOrderEntry, SOOrder> context)
    {
        var conditions = context.Conditions.GetPack<Conditions>();
        
        context.AddScreenConfigurationFor(screen => screen
            .StateIdentifierIs<SOOrder.status>()
            .AddDefaultFlow(flow => flow
                .WithFlowStates(states => { /* ... */ })
                .WithTransitions(transitions => { /* ... */ }))
            .WithActions(actions => { /* ... */ }));
    }
    
    public class Conditions : Condition.Pack
    {
        public Condition IsOnHold => GetOrCreate(b => b.FromBql<SOOrder.hold.IsEqual<True>>());
    }
}
```

### 7.2 Approval Workflow Layer
```csharp
public class SOOrderEntry_ApprovalWorkflow : PXGraphExtension<SOOrderEntry_Workflow, SOOrderEntry>
{
    public static bool IsActive() => 
        PXAccess.FeatureInstalled<FeaturesSet.approvalWorkflow>() && 
        SetupApproval.IsActive;
        
    [PXWorkflowDependsOnType(typeof(SOSetupApproval))]
    public sealed override void Configure(PXScreenConfiguration config) { /* ... */ }
}
```

### 7.3 Workflow and Server-Side Rules

Workflow controls screen state and action availability, but it must not be the only enforcement point for critical business rules.

**Rules:**
- Keep workflow action availability aligned with action implementation, validation, and persistence rules.
- Enforce critical state transitions and document invariants in server-side logic, not only through hidden or disabled UI actions.
- Treat persisted status values as data contracts. Do not change or reuse existing status codes with a different meaning without migration and compatibility analysis.

---

## 8. Feature Management

### 8.1 Feature Checking
```csharp
// Graph extension activation
public static bool IsActive() => 
    PXAccess.FeatureInstalled<FeaturesSet.inventory>();

// Combined feature check
public static bool IsActive() => 
    PXAccess.FeatureInstalled<FeaturesSet.inventory>() && 
    PXAccess.FeatureInstalled<FeaturesSet.warehouse>();
```

### 8.2 Setup-Based Activation
```csharp
private class FeatureActivation : IPrefetchable
{
    public static bool IsActive => 
        PXDatabase.GetSlot<FeatureActivation>(nameof(FeatureActivation), typeof(MySetup)).Enabled;

    private bool Enabled;

    void IPrefetchable.Prefetch()
    {
        using (PXDataRecord setup = PXDatabase.SelectSingle<MySetup>(
            new PXDataField<MySetup.enableFeature>()))
        {
            if (setup != null)
                Enabled = setup.GetBoolean(0) ?? false;
        }
    }
}
```

#### 8.2.1 Slot Lifetime

Choose slot lifetime intentionally.

- Use `PXContext.GetSlot` / `PXContext.SetSlot` for request-context state, temporary flags, and scoped coordination that must not outlive the current execution context.
- Use `PXDatabase.GetSlot` for persistent shared cache of read-mostly setup or reference data.
- Persistent slots must not store graph instances, current rows, mutable request state, or user-specific transient values.
- Persistent slot keys and dependent tables must cover every dimension that can change the cached value, such as setup tables, locale, feature state, tenant/company scope, or explicit parameters.
- Reset persistent slots only through an intentional invalidation path.

### 8.3 Field Visibility
```csharp
// Via FieldClass attribute
[PXDBInt]
[PXUIField(DisplayName = "Cost Code", FieldClass = nameof(FeaturesSet.costCodes))]
public virtual int? CostCodeID { get; set; }

// Dynamic visibility
protected virtual void _(Events.RowSelected<SOOrder> e)
{
    bool enabled = PXAccess.FeatureInstalled<FeaturesSet.projectAccounting>();
    PXUIFieldAttribute.SetVisible<SOOrder.projectID>(e.Cache, e.Row, enabled);
}
```

### 8.4 Feature Flag Rules
- Do not create new `FeaturesSet` entries without explicit justification.
- Reuse existing feature flags when possible.
- Use setup-based activation for minor functionality toggles.

---

## 9. Actions

### 9.1 Definition Pattern
```csharp
public PXAction<PrimaryDAC> MyAction;

[PXButton(CommitChanges = true)]
[PXUIField(DisplayName = "My Action", 
    MapEnableRights = PXCacheRights.Update,
    MapViewRights = PXCacheRights.Select)]
protected virtual IEnumerable myAction(PXAdapter adapter)
{
    // Implementation
    return adapter.Get();
}
```

### 9.2 Long-Running Operations
```csharp
PXLongOperation.StartOperation(this, () =>
{
    // Long-running code
});
```

**Rules:**
- Save pending changes before starting the operation when the operation depends on persisted state.
- Capture stable keys or immutable DTOs before the operation starts; do not rely on mutable cache rows inside the delegate.
- Create a fresh graph inside the operation for persistence, release, import, or processing work when graph state matters.
- Do not put UI-only logic in long operations.
- Make operations safe for retry where the process can be restarted after a partial failure.

---

## 10. Event Handlers

### 10.1 Modern Syntax
```csharp
protected virtual void _(Events.FieldUpdated<SOLine, SOLine.inventoryID> e)
{
    if (e.Row == null) return;
    // Handle field update
}

protected virtual void _(Events.RowSelected<SOOrder> e)
{
    if (e.Row == null) return;
    // UI state management only - no DB queries
}

protected virtual void _(Events.RowPersisting<SOOrder> e)
{
    if (e.Row == null || e.Operation == PXDBOperation.Delete) return;
    // Validation before save
}
```

### 10.2 Rules
- Always check for `null` row.
- Prefer `protected virtual` event handlers so behavior can be customized consistently through graph inheritance and extensions.
- `RowSelected`: UI state only, no database queries.
- `FieldVerifying`: Validation, can cancel with exception.
- `FieldUpdated`: Side effects from field changes.
- `RowPersisting`: Final validation before database write.
- Avoid long-running work and heavy computations in event handlers.
- Be cautious with `FieldDefaulting` and `RowPersisting`; invalid assumptions about cache state can lead to ignored fields or unexpected persisted values.
- Do not use `RowDeleting` or `RowDeleted` as the primary place for business logic. They should normally be limited to validation or cleanup tied directly to deletion.

### 10.3 Cache Value Changes

- Use `SetValueExt` when a programmatic field change must run verification, defaulting, formulas, dependencies, and `FieldUpdated` logic.
- Use `SetDefaultExt` when the field value should be recalculated through the field's defaulting pipeline.
- Direct property assignment is acceptable only for controlled initialization, internal calculations, or cases where field events are intentionally not needed.

---

## 11. File Placement Guidelines

### 11.1 Project Structure Overview

Acumatica follows a module-based organization where each functional area (AP, AR, CR, GL, PM, SO, etc.) has its own folder structure. Understanding this structure is critical for proper file placement.

```
PX.Objects/
`-- {Module}/                    # Module root (AP, AR, CR, GL, PM, SO, etc.)
    |-- {Module}MainGraph.cs     # Primary graphs (e.g., APInvoiceEntry.cs)
    |-- {Module}MainGraph_Workflow.cs  # Workflow configurations
    |-- DAC/                     # Data Access Classes
    |   |-- {DACName}.cs
    |   `-- Projections/         # DAC projections
    |-- Descriptor/              # Attributes, Messages, Constants
    |   |-- Attribute.cs         # Module-specific attributes
    |   |-- Messages.cs          # Localizable strings
    |   `-- Constants.cs         # Module constants
    `-- GraphExtensions/         # Graph extensions organized by base graph
        `-- {BaseGraph}Ext/
            `-- {ExtensionName}.cs
```

### 11.2 Graph Placement Rules

| Graph Type | Location | Naming Convention |
|------------|----------|-------------------|
| Primary Entry Graph | `PX.Objects/{Module}/` | `{Entity}Entry.cs` (e.g., `APInvoiceEntry.cs`) |
| Maintenance Graph | `PX.Objects/{Module}/` | `{Entity}Maint.cs` (e.g., `VendorMaint.cs`) |
| Process Graph | `PX.Objects/{Module}/` | `{Entity}Process.cs` (e.g., `APDocumentRelease.cs`) |
| Inquiry Graph | `PX.Objects/{Module}/` | `{Entity}Enq.cs` or `{Entity}Inquiry.cs` |
| Workflow Graph | `PX.Objects/{Module}/` | `{GraphName}_Workflow.cs` |
| Approval Workflow | `PX.Objects/{Module}/` | `{GraphName}_ApprovalWorkflow.cs` |

**Examples:**
```
PX.Objects/
`-- AP/
    |-- APInvoiceEntry.cs
    |-- APInvoiceEntry_Workflow.cs
    |-- APInvoiceEntry_ApprovalWorkflow.cs
    |-- APPaymentEntry.cs
    |-- VendorMaint.cs
    `-- APDocumentRelease.cs
```

### 11.3 Graph Extension Placement Rules

| Extension Type | Location | Naming Convention |
|----------------|----------|-------------------|
| Feature Extension | `{Module}/GraphExtensions/{BaseGraph}Ext/` | `{FeatureName}Ext.cs` |
| Cross-Module Extension | `{Module}/GraphExtensions/{SourceModule}{Graph}Ext/` | `{SourceModule}{Graph}Ext.cs` |
| Nested Extension (inside graph) | Same file as base graph | `public class {ExtName} : PXGraphExtension<BaseGraph>` |
| Activity Details | `{Module}/GraphExtensions/` | `{Graph}_ActivityDetailsExt.cs` |
| External Tax | `{Module}/GraphExtensions/` | `{Graph}ExternalTax.cs` |

**Rules:**
1. Extensions that extend graphs from the **same module** can be placed in the `GraphExtensions/` subfolder or nested inside the graph class.
2. Extensions that extend graphs from **different modules** should be in the extending module's `GraphExtensions/` folder.
3. Use nested classes for tightly coupled extensions that are always active with the base graph.

**Example - Same Module Extension:**
```
PX.Objects/PM/GraphExtensions/
|-- POOrderEntryExt.cs           # PM extending PO.POOrderEntry
|-- APInvoiceEntryExt.cs         # PM extending AP.APInvoiceEntry
`-- JournalEntryExt.cs           # PM extending GL.JournalEntry
```

**Example - Nested Extension (inside graph file):**
```csharp
// In VendorLocationMaint.cs
public class VendorLocationMaint : LocationMaint
{
    // Graph implementation...

    // Nested extension - always active with the graph
    public class LocationBAccountSharedContactOverrideGraphExt 
        : SharedChildOverrideGraphExt<VendorLocationMaint, LocationBAccountSharedContactOverrideGraphExt>
    {
        // Extension implementation
    }
}
```

### 11.4 DAC Placement Rules

| DAC Type | Location | Naming Convention |
|----------|----------|-------------------|
| Primary DAC | `{Module}/DAC/` | `{EntityName}.cs` |
| Projection DAC | `{Module}/DAC/Projections/` | `{Purpose}{Entity}.cs` |
| Standalone DAC | `{Module}/DAC/Standalone/` | `{EntityName}.cs` |
| Unbound/Filter DAC | `{Module}/DAC/Unbound/` | `{FilterName}Filter.cs` |
| Validation DAC | `{Module}/DAC/Validation/` | `{ValidationPurpose}.cs` |
| Report Parameters | `{Module}/DAC/ReportParameters/` | `{ReportName}Parameters.cs` |
| Lite/Simplified DAC | `{Module}/DAC/Lite/` | `{EntityName}.cs` |

**Rules:**
1. Place DACs in the module that owns the database table.
2. For DACs shared across modules, place in the module that creates/manages the data.
3. Projection DACs should reference the base DAC's module location.
4. Standalone DACs are used when you need a separate cache for the same table.

**Example:**
```
PX.Objects/PM/DAC/
|-- PMProject.cs                     # Primary DAC
|-- PMTask.cs
|-- Projections/
|   `-- PMProjectProjection.cs       # Read-only projection
|-- Standalone/
|   `-- PMProjectStandalone.cs       # Separate cache version
|-- Unbound/
|   `-- ProjectFilter.cs             # Filter DAC
|-- Lite/
|   `-- PMProject.cs                 # Simplified version
`-- ReportParameters/
    `-- ProjectReportParameters.cs   # Report parameters
```

### 11.5 Attribute Placement Rules

| Attribute Type | Location | Naming Convention |
|----------------|----------|-------------------|
| Module-specific Attribute | `{Module}/Descriptor/` or `{Module}/Attributes/` | `{Purpose}Attribute.cs` |
| Shared/Common Attribute | `Common/Attributes/` | `{Purpose}Attribute.cs` |
| Selector Attribute | `{Module}/Descriptor/` | `{Entity}SelectorAttribute.cs` |
| Tax Attribute | `TX/Descriptor/` | `{Purpose}TaxAttribute.cs` |
| Validation Attribute | `{Module}/Descriptor/` | `{Validation}Attribute.cs` |

**Rules:**
1. Attributes closely tied to a single module go in that module's `Descriptor/` folder.
2. Reusable attributes used across multiple modules go in `Common/Attributes/`.
3. Group related attributes in a single file when they share common functionality.

**Example:**
```
PX.Objects/SO/Descriptor/
|-- Attribute.cs                     # General module attributes
|-- SOSiteStatusLookup.cs            # Status lookup attribute
`-- Messages.cs                      # Module messages

PX.Objects/Common/Attributes/
|-- RetainagePercentAttribute.cs     # Shared attribute
`-- PXProviderTypeSelectorAttribute.cs
```

### 11.6 Messages Placement Rules

**Rule**: Each module should have a single `Messages.cs` file in its `Descriptor` folder containing all localizable strings.

| Messages Type | Location |
|---------------|----------|
| Module Messages | `{Module}/Descriptor/Messages.cs` |
| Feature-specific Messages | `{Module}/{Feature}/Descriptor/Messages.cs` |
| Shared Messages | `Common/Messages.cs` |

**Structure of Messages.cs:**
```csharp
namespace PX.Objects.{Module}
{
    [PXLocalizable(Messages.Prefix)]
    public static class Messages
    {
        public const string Prefix = "{MODULE}";
        
        // Cache names
        public const string {CacheName} = "Cache Display Name";
        
        // Field display names
        public const string {FieldDisplayName} = "Field Display Name";
        
        // Error messages
        public const string {ErrorCode} = "Error message text with {0} parameters.";
        
        // UI Labels
        public const string {LabelName} = "Label Text";
    }
}
```

- **Do not remove, replace, or modify existing user messages.**
- Preserve all previously defined messages and their behavior.
- Add new messages only when necessary to complete the task.
- Ensure new messages do not duplicate existing ones.


### 11.7 Constants and Enumerations Placement Rules

| Type | Location | Notes |
|------|----------|-------|
| Module Constants | `{Module}/Descriptor/Constants.cs` | Static values used within module |
| List Attributes | `{Module}/Descriptor/` | `{ListName}Attribute.cs` with nested constants |
| BQL Constants | Same file as DAC using them | Place near relevant fields |

**Example - List with Constants:**
```csharp
// In {Module}/Descriptor/{Status}Attribute.cs
public class OrderStatus
{
    public const string Open = "O";
    public const string Closed = "C";
    
    public class open : BqlString.Constant<open>
    {
        public open() : base(Open) { }
    }
    
    public class ListAttribute : PXStringListAttribute
    {
        public ListAttribute() : base(
            new[] { Open, Closed },
            new[] { "Open", "Closed" }) { }
    }
}
```

**Rules:**
- Persisted list values, document types, and status codes are data contracts.
- Do not change existing persisted constant values or reuse a value for a different meaning.
- Adding a new value requires checking workflow, selectors, reports, Generic Inquiries, import/export, API/OData exposure, and migration impact.

### 11.8 Feature Extension Organization

When adding feature-specific functionality, organize extensions by feature:

```
PX.Objects/{Module}/
`-- {FeatureName}/
    |-- GraphExtensions/
    |   `-- {Graph}{Feature}Ext.cs
    |-- CacheExtensions/
    |   `-- {DAC}{Feature}Ext.cs
    `-- Descriptor/
        `-- Messages.cs
```

**Example - Multiple Base Currencies Feature:**
```
PX.Objects/AP/MultipleBaseCurrencies/
|-- GraphExtensions/
|   |-- APInvoiceEntryMultipleBaseCurrencies.cs
|   `-- APPaymentEntryMultipleBaseCurrencies.cs
`-- CacheExtensions/
    `-- APInvoiceMultipleBaseCurrenciesRestriction.cs
```

### 11.9 Workflow and Actions Placement Rules

| Type | Location | Naming Convention |
|------|----------|-------------------|
| Primary Workflow | Same folder as graph | `{Graph}_Workflow.cs` |
| Approval Workflow | Same folder as graph | `{Graph}_ApprovalWorkflow.cs` |
| Workflow Extension | `{Module}/Workflows/` | `{Entity}Workflow.cs` |
| Shared Actions | `{Module}/` | Actions defined in graph |

**Example:**
```
PX.Objects/SO/
|-- SOOrderEntry.cs
|-- SOOrderEntry_Workflow.cs           # Base workflow (same folder)
`-- Workflow/
    `-- SalesOrder/                    # Complex workflow organization
        |-- WorkflowBase.cs
        |-- WorkflowSO.cs              # Order type specific
        `-- ScreenConfiguration.cs
```

### 11.10 Summary Table

| Artifact | Primary Location | Naming Pattern |
|----------|------------------|----------------|
| Graph | `{Module}/` | `{Entity}{Type}.cs` |
| Graph Extension | `{Module}/GraphExtensions/` | `{BaseGraph}{Feature}Ext.cs` |
| DAC | `{Module}/DAC/` | `{Entity}.cs` |
| DAC Extension | `{Module}/DAC/CacheExtensions/` | `{DAC}Ext.cs` |
| Attribute | `{Module}/Descriptor/` | `{Purpose}Attribute.cs` |
| Messages | `{Module}/Descriptor/Messages.cs` | N/A |
| Workflow | `{Module}/` | `{Graph}_Workflow.cs` |

---

## 12. Security

### 12.1 Cache Rights
```csharp
[PXUIField(DisplayName = "Action",
    MapEnableRights = PXCacheRights.Update,
    MapViewRights = PXCacheRights.Select)]
```

### 12.2 Row-Level Security
```csharp
public SelectFrom<Entity>
    .Where<Match<Current<AccessInfo.userName>>>
    .View Records;
```

### 12.3 Restriction Groups
```csharp
[PXDBGroupMask]
public virtual byte[] GroupMask { get; set; }
```

### 12.4 Enforcement Rules

- UI visibility and disabled fields are not authorization. Enforce critical restrictions in server-side validation, action logic, and query conditions.
- Apply access filters consistently to screens, inquiries, processing screens, reports, imports, and exposed data paths.
- Do not expose actions through inquiry, import, API, or workflow paths unless their server-side implementation checks the same business and access rules as the screen.

---

## 13. Database Model Synchronization

### 13.1 Mandatory Rule
When modifying DACs, update the corresponding `.sql` file in `DatabaseModel.sqlproj`.

### 13.2 SQL File Format
```sql
CREATE TABLE [TableName] (
    [CompanyID] INT NOT NULL,
    [KeyField] INT NOT NULL IDENTITY,
    [StringField] NVARCHAR(50) NULL,
    [BoolField] BIT NOT NULL DEFAULT ((0)),
    [DecimalField] DECIMAL(25,6) NULL,
    [DateField] DATETIME NULL,
    [CreatedByID] UNIQUEIDENTIFIER NOT NULL,
    [CreatedByScreenID] CHAR(8) NOT NULL,
    [CreatedDateTime] DATETIME NOT NULL,
    [LastModifiedByID] UNIQUEIDENTIFIER NOT NULL,
    [LastModifiedByScreenID] CHAR(8) NOT NULL,
    [LastModifiedDateTime] DATETIME NOT NULL,
    [tstamp] TIMESTAMP NOT NULL,

    CONSTRAINT [TableName_PK] PRIMARY KEY (
        [CompanyID] ASC,
        [KeyField] ASC
    ),

    CONSTRAINT [TableName_FK_RefTable] FOREIGN KEY (
        [CompanyID],
        [RefFieldID]
    ) REFERENCES [RefTable] (
        [CompanyID],
        [RefFieldID]
    )
);


GO
CREATE INDEX [TableName_IndexedField] ON [TableName] (
    [CompanyID] ASC,
    [IndexedField] ASC
);
```

### 13.3 DAC to SQL Mapping
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

### 13.4 SQL Naming Conventions
- Primary Key: `[TableName_PK]`
- Unique Constraint: `[TableName_ColumnName]`
- Foreign Key: `[TableName_FK_ReferencedTable]`
- Index: `[TableName_ColumnName]`

---

## 14. Performance Guidelines

### 14.1 Query Optimization
- Use `PXFieldScope` to limit selected columns.
- Use `SelectWindowed` or `ReadBranchRestrictedScope` for large datasets.
- Avoid database queries in `RowSelected` events.
- Use projections for complex read-only queries.

### 14.2 Caching
- Cache feature checks using `IPrefetchable`.
- Use `PXDatabase.GetSlot` for configuration data.
- Use request-context slots for transient state and persistent database slots only for stable shared definitions.

### 14.3 Bulk Operations
```csharp
using (new PXFieldScope(view.View, typeof(Field1), typeof(Field2)))
{
    foreach (var record in view.Select()) { }
}
```

---

## 15. Naming Conventions

### 15.1 DACs
- PascalCase, singular noun: `SOOrder`, `InventoryItem`
- Abstract field classes: camelCase matching property: `orderNbr`, `inventoryID`

### 15.2 Graphs
- PascalCase with suffix: `SOOrderEntry`, `InventoryItemMaint`
- Extensions: `{GraphName}_{Purpose}` (e.g., `SOOrderEntry_Workflow`)

### 15.3 Fields
- ID fields: `{Entity}ID` (e.g., `inventoryID`, `customerID`)
- Reference numbers: `{Entity}Nbr` (e.g., `orderNbr`, `refNbr`)
- Status fields: `status`
- Boolean fields: `is{Condition}` or descriptive (e.g., `isActive`, `hold`)

### 15.4 Views
- Primary: `Document`, `Documents`
- Details: `Details`, `Lines`, `Transactions`
- Lookups: `{Entity}Lookup`

---

## 16. Prohibited Patterns

| Pattern | Reason | Alternative |
|---------|--------|-------------|
| Direct SQL | Bypasses cache, security, customization | Use BQL/Fluent BQL |
| Unjustified DAC extensions for product-owned persistent fields | Fragments the data model | Add fields to the owning DAC, or use an allowed extension case from Section 2.4 |
| Static business behavior | Cannot be customized | Use virtual methods in graphs or graph extensions |
| New service classes with DI | Bypasses graph lifecycle | Use abstract graph extensions |
| Unnecessary classic BQL for new standalone queries | Less type-safe, harder to maintain | Prefer Fluent BQL |
| DB queries in RowSelected | Performance degradation | Cache data or use formulas |
| New FeaturesSet entries | Testing complexity, licensing coordination | Reuse existing features or use setup flags |
| Mismatched BQL field types | Runtime errors, incorrect queries, type conversion issues | Match BQL field type to CLR property type (see Section 2.5) |
| Explicit backing fields in DACs | Unnecessary complexity, inconsistent with framework patterns | Use auto-implemented properties (see Section 2.2) |
| PXOverride without delegate parameter | Unpredictable execution order, unreliable return values | Always include `base_<MethodName>` delegate (see Section 5.4) |
| Broad `PXProtectedAccess` usage | Exposes internals and creates fragile extension contracts | Use narrow protected bridges or proper virtual extension points |
| Replacing/removing base attributes without justification | Breaks defaulting, validation, selectors, persistence, or security | Use narrow attribute merges and preserve required base behavior |
| Capturing mutable cache rows in long operations | Uses stale or inconsistent graph state | Capture stable keys/DTOs and create a fresh graph when needed |
| UI-only enforcement of critical rules | Can be bypassed by import, API, GI actions, or processing paths | Enforce rules in server-side action and persistence logic |
| Request-specific data in persistent slots | Leaks mutable context across executions | Use `PXContext` slots or include all required dimensions in the persistent slot key |

---

## 17. Extension Development Checklist

1. [ ] Define `IsActive()` method with appropriate feature check.
2. [ ] Use `[PXWorkflowDependsOnType]` for workflow dependencies.
3. [ ] Make customization-relevant methods `virtual`.
4. [ ] Use `[PXOverride]` with delegate parameter for base graph method overrides.
5. [ ] Add XML documentation (`/// Overrides <seealso cref="..."/>`) to all `[PXOverride]` methods.
6. [ ] Respect cache rights in actions.
7. [ ] Update `DatabaseModel.sqlproj` for schema changes.
8. [ ] Use FK definitions for relationships.
9. [ ] Prefer declarative attributes over imperative code for invariant behavior.
10. [ ] Verify no static methods contain customizable business behavior.
11. [ ] Test with relevant features enabled and disabled.
12. [ ] Ensure BQL field class types match CLR property types (see Section 2.5).
13. [ ] Use auto-implemented properties in DACs unless a documented technical exception is required.
14. [ ] Check exposed API, OData, GI, import/export, and report surfaces when changing public fields, projections, actions, statuses, or selectors.
15. [ ] Use narrow attribute merges and justify any base attribute removal.
16. [ ] Capture stable keys or DTOs before long-running operations.
17. [ ] Choose request-context slots and persistent slots intentionally.
