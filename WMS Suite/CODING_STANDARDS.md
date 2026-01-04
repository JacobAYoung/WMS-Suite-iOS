# WMS Suite - Coding Standards & Best Practices

**Last Updated:** January 3, 2026  
**Purpose:** Maintain code quality, consistency, and reliability across the project

---

## Table of Contents

1. [Architecture Standards](#architecture-standards)
2. [Async/Await & Concurrency](#asyncawait--concurrency)
3. [Error Handling](#error-handling)
4. [Core Data Best Practices](#core-data-best-practices)
5. [SwiftUI Patterns](#swiftui-patterns)
6. [Code Organization](#code-organization)
7. [Performance Guidelines](#performance-guidelines)
8. [Security & Data Integrity](#security--data-integrity)
9. [Testing Standards](#testing-standards)
10. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

---

## Architecture Standards

### MVVM Pattern (Mandatory)

**Always follow Model-View-ViewModel separation:**

✅ **CORRECT:**

```swift
// Model (Core Data Entity)
class InventoryItem: NSManagedObject {
    @NSManaged var name: String?
    @NSManaged var quantity: Int32
}

// ViewModel (Business Logic)
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    private let repository: InventoryRepositoryProtocol
    
    func fetchItems() {
        Task { @MainActor in
            do {
                items = try await repository.fetchAllItems()
            } catch {
                handleError(error)
            }
        }
    }
}

// View (SwiftUI)
struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    
    var body: some View {
        List(viewModel.items) { item in
            Text(item.name ?? "Unknown")
        }
        .onAppear {
            viewModel.fetchItems()
        }
    }
}
```

❌ **WRONG:**

```swift
// DON'T put business logic in views
struct InventoryView: View {
    @FetchRequest(entity: InventoryItem.entity(), sortDescriptors: [])
    var items: FetchedResults<InventoryItem>
    
    var body: some View {
        List(items) { item in
            Text(item.name ?? "Unknown")
        }
        .onAppear {
            // ❌ Business logic in view
            performComplexCalculations()
            updateDatabase()
        }
    }
}
```

### Repository Pattern

**Use repositories to abstract data access:**

```swift
protocol InventoryRepositoryProtocol {
    func fetchAllItems() async throws -> [InventoryItem]
    func save(_ item: InventoryItem) async throws
    func delete(_ item: InventoryItem) async throws
}

class InventoryRepository: InventoryRepositoryProtocol {
    private let context: NSManagedObjectContext
    
    func fetchAllItems() async throws -> [InventoryItem] {
        try await context.perform {
            let request = InventoryItem.fetchRequest()
            return try context.fetch(request)
        }
    }
}
```

**Benefits:**
- Testable (mock repositories for tests)
- Swappable data sources
- Single responsibility
- Cleaner ViewModels

---

## Async/Await & Concurrency

### Principle: Never Block the Main Thread

**Use async/await for all potentially blocking operations:**

✅ **CORRECT:**

```swift
// Core Data operations
Task { @MainActor in
    do {
        try await viewContext.perform {
            item.quantity += quantity
            try viewContext.save()
        }
        
        // UI updates happen on MainActor
        showSuccess = true
        
    } catch {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
```

```swift
// Network requests
func syncInventory() async throws {
    let data = try await URLSession.shared.data(from: url)
    let items = try JSONDecoder().decode([Item].self, from: data)
    
    await MainActor.run {
        self.items = items
    }
}
```

```swift
// File I/O
Task {
    let content = try await FileManager.default.contents(atPath: path)
    await processContent(content)
}
```

❌ **WRONG:**

```swift
// ❌ Blocking the main thread
func fetchData() {
    let data = try! Data(contentsOf: url) // Blocks UI!
    processData(data)
}

// ❌ Using old patterns
DispatchQueue.global().async {
    let result = expensiveOperation()
    DispatchQueue.main.async {
        self.updateUI(result)
    }
}
```

### Debouncing User Input

**Prevent UI lag from rapid user input:**

```swift
.onChange(of: searchText) { oldValue, newValue in
    Task { @MainActor in
        // Debounce with 300ms delay
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Check if value changed again during sleep
        guard searchText == newValue else { return }
        
        performSearch(newValue)
    }
}
```

### Camera & Scanner Operations

**Always use Task wrappers:**

```swift
.onAppear {
    Task {
        scannerManager.startScanning()
    }
}

.onDisappear {
    Task {
        scannerManager.stopScanning()
    }
}
```

### Progress Indicators

**Show loading states for async operations:**

```swift
@State private var isLoading = false

func loadData() {
    isLoading = true
    
    Task { @MainActor in
        defer { isLoading = false }
        
        do {
            items = try await repository.fetchItems()
        } catch {
            handleError(error)
        }
    }
}

// In view
.overlay {
    if isLoading {
        ProgressView("Loading...")
    }
}
```

---

## Error Handling

### Principle: Every Error Must Be Handled

**Never use `try!` or `try?` without justification:**

✅ **CORRECT:**

```swift
func saveItem() {
    Task { @MainActor in
        do {
            try await viewContext.perform {
                try viewContext.save()
            }
            
            successMessage = "Item saved successfully"
            showingSuccess = true
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
        } catch {
            // Specific error handling
            print("❌ Save failed: \(error.localizedDescription)")
            
            errorMessage = "Failed to save item: \(error.localizedDescription)"
            showingError = true
            
            // Error haptic
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
```

### User-Facing Error Messages

**Make errors actionable:**

```swift
enum InventoryError: LocalizedError {
    case insufficientStock(available: Int32, requested: Int32)
    case itemNotFound(code: String)
    case networkTimeout
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .insufficientStock(let available, let requested):
            return "Cannot remove \(requested) items. Only \(available) available."
        case .itemNotFound(let code):
            return "Item not found: \(code)\n\nPlease check the barcode and try again."
        case .networkTimeout:
            return "Connection timed out. Please check your internet and retry."
        case .permissionDenied:
            return "Camera access required. Please enable in Settings."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .insufficientStock:
            return "Adjust the quantity or check inventory levels."
        case .itemNotFound:
            return "Verify the barcode or add the item manually."
        case .networkTimeout:
            return "Retry or work offline."
        case .permissionDenied:
            return "Open Settings to grant permission."
        }
    }
}
```

### Alert Presentation

**Always show errors to users:**

```swift
@State private var showingError = false
@State private var errorMessage = ""

// Usage
catch {
    errorMessage = error.localizedDescription
    showingError = true
}

// In view
.alert("Error", isPresented: $showingError) {
    Button("OK", role: .cancel) { }
    Button("Retry") {
        retryOperation()
    }
} message: {
    Text(errorMessage)
}
```

### Validation Before Operations

**Validate early, fail fast:**

```swift
func pickItem() {
    // Validation
    guard let quantity = Int32(quantityToPick), quantity > 0 else {
        errorMessage = "Please enter a valid quantity"
        showingError = true
        return
    }
    
    guard quantity <= availableStock else {
        errorMessage = "Cannot pick \(quantity) items. Only \(availableStock) available."
        showingError = true
        return
    }
    
    // Only proceed if validation passes
    performPick(quantity)
}
```

---

## Core Data Best Practices

### Always Use `perform` for Background Operations

✅ **CORRECT:**

```swift
try await context.perform {
    let item = InventoryItem(context: context)
    item.name = "Product"
    item.quantity = 10
    try context.save()
}
```

❌ **WRONG:**

```swift
// ❌ Direct access without perform
let item = InventoryItem(context: context)
item.name = "Product"
try context.save()
```

### Check for Duplicates Before Creating

```swift
func createOrUpdate(qbItemId: String) async throws {
    try await context.perform {
        // Check if exists
        let fetchRequest = InventoryItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "quickbooksItemId == %@", qbItemId)
        fetchRequest.fetchLimit = 1
        
        let existing = try context.fetch(fetchRequest).first
        
        let item = existing ?? InventoryItem(context: context)
        
        // Update properties
        item.quickbooksItemId = qbItemId
        item.name = name
        
        try context.save()
    }
}
```

### Batch Updates for Performance

```swift
// For large datasets
let batchSize = 100

for (index, data) in largeDataset.enumerated() {
    processItem(data)
    
    // Save every 100 items
    if index % batchSize == 0 {
        try await context.perform {
            try context.save()
        }
    }
}

// Final save
try await context.perform {
    try context.save()
}
```

### Relationships & Deletion Rules

**Set proper deletion rules in Core Data model:**

- **Cascade:** Child deleted when parent deleted
- **Nullify:** Relationship set to nil
- **Deny:** Prevent deletion if relationship exists
- **No Action:** Manual handling required

---

## SwiftUI Patterns

### State Management

**Use appropriate property wrappers:**

```swift
// Simple view-local state
@State private var isExpanded = false

// Observed objects (ViewModels)
@ObservedObject var viewModel: InventoryViewModel

// Environment objects (app-wide state)
@EnvironmentObject var appState: AppState

// State objects (view owns the object)
@StateObject private var manager = ScannerManager()

// Environment values
@Environment(\.dismiss) private var dismiss
@Environment(\.managedObjectContext) private var viewContext

// Focus state
@FocusState private var isFieldFocused: Bool
```

### Avoid Massive Views

**Break down complex views:**

✅ **CORRECT:**

```swift
struct InventoryView: View {
    var body: some View {
        VStack {
            headerSection
            quickActionsBar
            inventoryList
        }
    }
    
    private var headerSection: some View {
        HStack {
            Text("Inventory")
            Spacer()
            refreshButton
        }
    }
    
    private var quickActionsBar: some View {
        QuickActionsBar(
            onQuickScan: { showingQuickScan = true },
            onPutAway: { showingPutAway = true },
            onTakeOut: { showingTakeOut = true },
            onPrintLabel: { showingBarcodeGenerator = true }
        )
    }
}
```

### Reusable Components

**Create components for repeated UI:**

```swift
// Reusable component
struct StockBadge: View {
    let quantity: Int32
    let minLevel: Int32
    
    var color: Color {
        quantity > minLevel ? .green : .red
    }
    
    var body: some View {
        Label("\(quantity)", systemImage: "cube.box")
            .foregroundColor(color)
    }
}

// Usage
StockBadge(quantity: item.quantity, minLevel: item.minStockLevel)
```

---

## Code Organization

### File Structure

```
WMS Suite/
├── Models/
│   ├── InventoryItem+Extensions.swift
│   ├── Sale+Extensions.swift
│   └── Customer+Extensions.swift
├── ViewModels/
│   ├── InventoryViewModel.swift
│   ├── OrdersViewModel.swift
│   └── CustomersViewModel.swift
├── Views/
│   ├── Inventory/
│   │   ├── InventoryView.swift
│   │   ├── ProductDetailView.swift
│   │   ├── PutAwayInventoryView.swift
│   │   └── TakeOutInventoryView.swift
│   ├── Orders/
│   │   ├── OrdersView.swift
│   │   ├── OrderDetailView.swift
│   │   └── PickItemSheet.swift
│   └── Components/
│       ├── QuickActionsBar.swift
│       ├── StockBadge.swift
│       └── LoadingOverlay.swift
├── Services/
│   ├── QuickBooksService.swift
│   ├── ShopifyService.swift
│   └── BarcodeService.swift
├── Repositories/
│   ├── InventoryRepository.swift
│   └── OrderRepository.swift
└── Utilities/
    ├── Extensions/
    ├── Helpers/
    └── Constants/
```

### Naming Conventions

```swift
// Classes/Structs: PascalCase
class InventoryViewModel { }
struct PickItemSheet { }

// Properties/Variables: camelCase
var currentItem: InventoryItem?
let totalQuantity: Int32

// Functions: camelCase with verb
func fetchItems() { }
func updateQuantity(_ quantity: Int32) { }

// Constants: camelCase or UPPER_SNAKE_CASE
let maxRetries = 3
let DEFAULT_PAGE_SIZE = 100

// Protocols: PascalCase with "Protocol" suffix or "-able"
protocol InventoryRepositoryProtocol { }
protocol Syncable { }

// Enums: PascalCase, cases camelCase
enum ScanMode {
    case camera
    case manual
}
```

### Comments & Documentation

```swift
// MARK: - Major Sections
// MARK: Section Headers

/// Documentation for public API
/// - Parameter item: The item to save
/// - Throws: `InventoryError` if validation fails
/// - Returns: The saved item ID
func saveItem(_ item: InventoryItem) async throws -> String {
    // Implementation comments for complex logic
    // ⚠️ Warning comments for important notes
    // TODO: Future improvements
    // FIXME: Known issues to address
}
```

---

## Performance Guidelines

### Avoid Premature Optimization

**Profile first, then optimize:**

1. Write clean, readable code first
2. Measure performance with Instruments
3. Optimize hot paths only
4. Re-measure to verify improvement

### Lazy Loading

```swift
// Load data only when needed
var body: some View {
    List(items) { item in
        ItemRow(item: item)
    }
    .task {
        // Only load when view appears
        await loadData()
    }
}
```

### Image Optimization

```swift
// Use proper image sizing
Image(uiImage: productImage)
    .resizable()
    .scaledToFit()
    .frame(width: 100, height: 100)
    .clipped()
```

### List Performance

```swift
// Use identifiable models
struct InventoryItem: Identifiable {
    let id: Int32
}

// Avoid ForEach with indices
ForEach(items) { item in
    ItemRow(item: item)
}
```

---

## Security & Data Integrity

### Input Validation

```swift
func updateQuantity(_ input: String) {
    // Validate input
    guard let quantity = Int32(input), quantity > 0 else {
        showError("Invalid quantity")
        return
    }
    
    guard quantity <= 10000 else {
        showError("Quantity too large")
        return
    }
    
    // Proceed with validated input
    item.quantity = quantity
}
```

### Secure Credentials Storage

```swift
// Use Keychain for sensitive data
import Security

func saveCredentials(token: String) {
    let data = token.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: "quickbooks_token",
        kSecValueData as String: data
    ]
    
    SecItemAdd(query as CFDictionary, nil)
}
```

### API Key Protection

```swift
// ❌ NEVER commit API keys to repo
let apiKey = "sk_live_12345" // DON'T DO THIS

// ✅ Use configuration files or environment
let apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
```

---

## Testing Standards

### Unit Tests with Swift Testing

```swift
import Testing

@Suite("Inventory Operations")
struct InventoryTests {
    
    @Test("Adding inventory increases quantity")
    func testAddInventory() async throws {
        let item = createTestItem(quantity: 10)
        
        item.quantity += 5
        
        #expect(item.quantity == 15)
    }
    
    @Test("Cannot remove more than available")
    func testInsufficientStock() async throws {
        let item = createTestItem(quantity: 5)
        
        let isValid = item.quantity >= 10
        
        #expect(isValid == false)
    }
    
    @Test("Search priority: SKU before UPC")
    func testSearchPriority() async throws {
        let items = [
            createTestItem(sku: "ABC", upc: "123"),
            createTestItem(sku: "XYZ", upc: "ABC")
        ]
        
        let result = searchItems(code: "ABC", in: items)
        
        // Should match SKU first
        #expect(result?.sku == "ABC")
    }
}
```

### Mock Objects

```swift
class MockInventoryRepository: InventoryRepositoryProtocol {
    var itemsToReturn: [InventoryItem] = []
    var shouldThrowError = false
    
    func fetchAllItems() async throws -> [InventoryItem] {
        if shouldThrowError {
            throw TestError.mockError
        }
        return itemsToReturn
    }
}
```

---

## Anti-Patterns to Avoid

### ❌ Force Unwrapping

```swift
// ❌ DON'T
let name = item.name!
let price = Double(priceString)!

// ✅ DO
let name = item.name ?? "Unknown"
guard let price = Double(priceString) else {
    showError("Invalid price")
    return
}
```

### ❌ Massive ViewModels

```swift
// ❌ DON'T create God objects
class MegaViewModel {
    // 2000 lines of code...
}

// ✅ DO split responsibilities
class InventoryViewModel { }
class OrderViewModel { }
class CustomerViewModel { }
```

### ❌ Magic Numbers

```swift
// ❌ DON'T
if quantity > 100 { }
sleep(0.3)

// ✅ DO
let maximumQuantityPerOrder = 100
if quantity > maximumQuantityPerOrder { }

let debounceDelay: UInt64 = 300_000_000 // 0.3 seconds in nanoseconds
try await Task.sleep(nanoseconds: debounceDelay)
```

### ❌ Pyramid of Doom

```swift
// ❌ DON'T
if let item = items.first {
    if let sku = item.sku {
        if let price = item.price {
            if price > 0 {
                processItem(sku, price)
            }
        }
    }
}

// ✅ DO use guard
guard let item = items.first,
      let sku = item.sku,
      let price = item.price,
      price > 0 else {
    return
}
processItem(sku, price)
```

### ❌ Stringly-Typed Code

```swift
// ❌ DON'T
let status = "needs_fulfillment"
if order.status == "needs_fulfillment" { }

// ✅ DO use enums
enum OrderStatus: String {
    case needsFulfillment
    case inTransit
    case delivered
}

let status: OrderStatus = .needsFulfillment
if order.status == .needsFulfillment { }
```

---

## Summary Checklist

Before submitting code, verify:

- [ ] **Architecture:** Follows MVVM pattern
- [ ] **Async:** All blocking operations use async/await
- [ ] **Errors:** Comprehensive try/catch with user-facing messages
- [ ] **Core Data:** Uses `perform` blocks for operations
- [ ] **State:** Proper use of @State, @ObservedObject, etc.
- [ ] **Performance:** No blocking operations on main thread
- [ ] **Validation:** Input validated before operations
- [ ] **Comments:** Complex logic is documented
- [ ] **Naming:** Follows Swift conventions
- [ ] **Tests:** Critical paths have test coverage
- [ ] **No Force Unwraps:** Uses optional binding or nil coalescing
- [ ] **No Magic Numbers:** Constants are named
- [ ] **Reusability:** Common UI extracted to components
- [ ] **Security:** No hardcoded credentials
- [ ] **User Feedback:** Loading states and error messages

---

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)

---

**Remember:** Clean code is not about cleverness, it's about clarity. Write code that your future self (and teammates) will thank you for.
