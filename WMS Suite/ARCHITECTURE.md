# WMS Suite - Architecture Documentation

**Last Updated:** January 3, 2026  
**Purpose:** Complete architectural overview for AI context and developer onboarding

---

## Table of Contents

1. [Inventory/Product Architecture](#inventoryproduct-architecture)
2. [Inventory Operations](#inventory-operations) *(NEW)*
3. [Orders/Sales Architecture](#orderssales-architecture)
4. [Order Picking & Fulfillment](#order-picking--fulfillment) *(NEW)*
5. [Barcode Tools](#barcode-tools) *(NEW)*
6. [Customer Architecture](#customer-architecture) *(Coming Soon)*
7. [Integration Architecture](#integration-architecture) *(Coming Soon)*
8. [Data Layer](#data-layer) *(Coming Soon)*

---

# Inventory/Product Architecture

## Overview

The inventory system manages products with multi-source synchronization (QuickBooks, Shopify), pricing management, and forecasting capabilities.

---

## Core Data Model

### **InventoryItem Entity**

**Core Data Properties:**
```swift
// Identity
id: Int32                           // Unique identifier (hash-based for QB/Shopify items)
sku: String?                        // Stock Keeping Unit
name: String?                       // Product name
itemDescription: String?            // Product description

// Inventory Management
quantity: Int32                     // Current stock quantity
minStockLevel: Int32                // Reorder point
location: String?                   // Warehouse location
barcode: String?                    // Barcode/UPC

// Dates
createdDate: Date?                  // When item was created
lastUpdated: Date?                  // Last modified date

// Integration IDs
shopifyProductId: String?           // Shopify product ID
shopifyVariantId: String?           // Shopify variant ID
quickbooksItemId: String?           // QuickBooks item ID
lastSyncedShopifyDate: Date?        // Last Shopify sync timestamp
lastSyncedQuickbooksDate: Date?     // Last QuickBooks sync timestamp

// Relationships
lineItems: Set<SaleLineItem>        // Related sale line items
```

---

## Extension-Based Pricing System

**File:** `InventoryItem+Extensions.swift`

All pricing is stored in **UserDefaults** via computed properties (not Core Data):

### **Pricing Properties:**

```swift
// QuickBooks Pricing
var quickbooksCost: Decimal         // Purchase cost from QB
    - Storage: UserDefaults key "item_{id}_qb_cost"
    - Get: Returns stored value or 0
    - Set: Stores in UserDefaults

var quickbooksPrice: Decimal?       // Selling price from QB
    - Storage: UserDefaults key "item_{id}_qb_price"
    - Get: Returns stored value or nil
    - Set: Stores in UserDefaults

// Shopify Pricing
var shopifyPrice: Decimal?          // Selling price from Shopify
    - Storage: UserDefaults key "item_{id}_shopify_price"
    - Get: Returns stored value or nil
    - Set: Stores in UserDefaults

// Local/Manual Pricing
var cost: Decimal                   // Manual cost override
    - Storage: UserDefaults key "item_{id}_cost"
    - Get: Returns QB cost if set, else manual cost, else 0
    - Set: Stores in UserDefaults

var sellingPrice: Decimal?          // Computed best selling price
    - Logic: Manual > Shopify > QuickBooks > nil
    - Smart prioritization based on what's set
    - Returns first available price source

// Helper Properties
var priceSource: String             // Shows which source is used
    - Returns: "Manual", "Shopify", "QuickBooks", or "Unknown"
```

### **Why UserDefaults?**

**Pros:**
- ✅ No Core Data migration required
- ✅ Simple implementation
- ✅ Works immediately
- ✅ Easy to update

**Cons:**
- ❌ Not queryable via Core Data predicates
- ❌ Not included in Core Data backups
- ❌ Slightly slower than Core Data for large datasets
- ❌ Can't create relationships based on price

**Future Consideration:** Migrate to Core Data properties for production use.

---

## Account ID Storage (Pending Implementation)

These properties are **referenced in code** but **not yet implemented**:

```swift
// ⚠️ NOT IN CORE DATA OR EXTENSIONS YET
var quickbooksIncomeAccountId: String?
var quickbooksExpenseAccountId: String?
var quickbooksAssetAccountId: String?
```

**Current Status:**
- Code in `QuickBooksService.swift` is **commented out** to prevent crashes
- Service uses **global account IDs** instead of per-item accounts
- **To implement:** Add to Core Data as optional String properties

---

## ID Generation Strategy

**File:** `IDGenerator.swift` (referenced but not seen)

### **Hash-Based IDs:**

```swift
// For QuickBooks items
IDGenerator.hashQuickBooksItemID(qbItemId: String) -> Int32
    - Same QB ID always produces same Int32
    - Prevents duplicate items on re-sync

// For QuickBooks customers
IDGenerator.hashQuickBooksCustomerID(qbCustomerId: String) -> Int32

// For QuickBooks invoices
IDGenerator.hashQuickBooksInvoiceID(qbInvoiceId: String) -> Int32
```

**Purpose:** Consistent ID generation for synced items across sessions.

---

## View Layer

### **ProductDetailView.swift**

Main product detail screen with comprehensive information display.

#### **Key Features:**

1. **Product Image Section**
   - Displays product image or placeholder

2. **Header Section**
   - Product name and SKU
   - Edit button to modify details

3. **Reorder Alert Section** (conditional)
   - Shows when stock below minimum
   - Provides reorder recommendations

4. **Product Info Section**
   - Quantity, location, barcode
   - Basic inventory information

5. **Inventory by Source Section**
   - Shows stock levels across services
   - QuickBooks vs Shopify comparison
   - Sync status indicators

6. **Pricing Section** ⭐ Key Section
   - Multi-source pricing display
   - Cost and selling price
   - Source attribution (QB/Shopify/Manual)
   - Edit button for pricing changes

7. **Tags & Notes Section**
   - Product categorization
   - Additional notes

8. **Action Buttons Section**
   - Push to QuickBooks
   - Push to Shopify
   - Add Sale
   - Delete Item

9. **Forecast Section**
   - Demand forecasting
   - Reorder recommendations

10. **Sales History Section**
    - Historical sales data
    - Source attribution

#### **State Management:**

```swift
@ObservedObject var viewModel: InventoryViewModel
let item: InventoryItem

// UI State
@State private var showingEditItem = false
@State private var showingAddSale = false
@State private var showingPushConfirmation = false
@State private var pushTarget: ItemSource?
@State private var showingForecastDetail = false
@State private var showingNotesTagsView = false
@State private var showingEditPricing = false

// Data State
@State private var salesHistory: [SalesHistoryDisplay] = []
@State private var quickForecast: ForecastResult?
@State private var reorderRecommendation: ReorderRecommendation?
@State private var refreshTrigger = UUID()

// Loading State
@State private var isLoadingSalesHistory = false
@State private var isPushingToService = false

// Performance Optimization: Cached Pricing
@State private var cachedCost: Decimal = 0
@State private var cachedSellingPrice: Decimal? = nil
@State private var cachedPriceSource: String? = nil
@State private var isPricingLoaded = false
```

#### **Performance Optimizations:**

1. **Cached Pricing Data**
   - Loads pricing once on view appear
   - Avoids repeated UserDefaults lookups
   - Improves scrolling performance

2. **Async Data Loading**
   - Uses `.task` modifier for async operations
   - Doesn't block UI thread
   - Smooth view presentation

3. **Refresh Trigger**
   - `UUID` based refresh system
   - Forces view rebuild after edits
   - Ensures UI stays in sync with data

4. **Loading States**
   - Separate flags for different operations
   - Contextual loading messages
   - Better user feedback

---

## PricingEditView (Referenced)

**File:** `PricingEditView.swift` (not fully viewed)

Allows editing of:
- Manual cost
- Manual selling price
- Override QuickBooks/Shopify pricing

Updates stored in UserDefaults via InventoryItem extensions.

---

## QuickBooks Integration

**File:** `QuickBooksService.swift`

### **Inventory Sync Methods:**

#### **1. Pull from QuickBooks:**

```swift
func syncInventory(
    context: NSManagedObjectContext,
    logMessage: @escaping (String) -> Void
) async throws
```

**Process:**
1. Fetches all pages of inventory items (Type='Inventory')
2. Paginated fetching (100 items per page)
3. Creates or updates local InventoryItem records
4. Stores pricing in UserDefaults via extensions
5. Updates sync timestamps

**Data Extracted:**
- Name, SKU, Description
- Quantity on hand
- Reorder point (mapped to minStockLevel)
- Unit price (selling price)
- Purchase cost
- Account references (if implemented)

#### **2. Push to QuickBooks:**

```swift
func pushInventoryItem(_ item: InventoryItem) async throws -> String
```

**Process:**
- Checks if item exists in QB (via quickbooksItemId)
- **CREATE** if new → calls `createInventoryItem()`
- **UPDATE** if exists → calls `updateInventoryItem()`
- Requires SyncToken for updates (fetched automatically)

**Data Sent:**
- Name, SKU, Description
- Quantity on hand
- Unit price (from sellingPrice)
- Purchase cost (from cost)
- Account references (Income, Expense, Asset)

#### **3. Fetch Single Item:**

```swift
private func fetchInventoryItem(qbItemId: String) async throws -> [String: Any]
```

Used to get SyncToken before updates.

---

### **Pagination System:**

All QuickBooks queries use pagination to handle large datasets:

```swift
// Query format
"SELECT * FROM Item WHERE Type = 'Inventory' AND Active = true 
 STARTPOSITION {position} MAXRESULTS {pageSize}"

// Typical flow
var currentPosition = 1
let pageSize = 100
while hasMorePages {
    let items = fetchPage(startPosition: currentPosition, maxResults: pageSize)
    if items.count < pageSize {
        hasMorePages = false
    } else {
        currentPosition += items.count
    }
    // Safety limit: 100 pages max (10,000 items)
}
```

---

### **Authentication & Token Refresh:**

```swift
private func makeAuthenticatedRequest(
    _ request: URLRequest,
    maxRetries: Int = 1
) async throws -> (Data, HTTPURLResponse)
```

**Features:**
- Proactive token refresh if expiring soon
- Automatic retry on 401 Unauthorized
- Token refresh via `QuickBooksTokenManager`
- Updates local accessToken after refresh

**Token Manager:** `QuickBooksTokenManager.shared`
- Checks if token should refresh
- Handles OAuth token refresh flow
- Updates stored credentials

---

## Shopify Integration

**File:** `ShopifyService.swift` (referenced but not fully viewed)

**Expected Features:**
- Pull inventory from Shopify
- Push inventory updates
- Price synchronization
- Similar pagination system as QB

**Integration Status:**
- Read permissions: ✅ Working
- Write permissions: Requires approval
- Checked via `UserDefaults.standard.bool(forKey: "shopify_canWriteInventory")`

---

## ViewModel Architecture

**File:** `InventoryViewModel.swift` (referenced but not viewed)

**Expected Structure:**
```swift
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem]
    @Published var filteredItems: [InventoryItem]
    @Published var searchText: String
    @Published var sortOption: SortOption
    @Published var filterOption: FilterOption
    
    func fetchItems()
    func addItem(_ item: InventoryItem)
    func updateItem(_ item: InventoryItem)
    func deleteItem(_ item: InventoryItem)
    func syncWithQuickBooks()
    func syncWithShopify()
    func pushToService(_ item: InventoryItem, target: ItemSource)
}
```

---

## Enumerations

### **ItemSource:**

```swift
enum ItemSource: String {
    case quickbooks = "QuickBooks"
    case shopify = "Shopify"
    case manual = "Manual"
}
```

Used for:
- Determining sync targets
- Displaying source labels in UI
- Push confirmation dialogs

---

## Supporting Types

### **SalesHistoryDisplay:**

```swift
struct SalesHistoryDisplay {
    let date: Date
    let quantity: Int
    let amount: Decimal
    let source: String
    let customerName: String?
}
```

### **ReorderRecommendation:**

```swift
struct ReorderRecommendation {
    let itemName: String
    let currentStock: Int
    let minStock: Int
    let recommendedOrderQuantity: Int
    let daysOfStockRemaining: Int?
}
```

### **ForecastResult:**

```swift
struct ForecastResult {
    let itemName: String
    let currentStock: Int
    let forecastedDemand: Int
    let recommendedReorder: Int
    let daysUntilStockout: Int?
    let confidence: String // "High", "Medium", "Low"
}
```

---

## Data Flow

### **Inventory Sync Flow (QuickBooks):**

```
User Triggers Sync
    ↓
QuickBooksService.syncInventory()
    ↓
Paginated API Calls (100 items per page)
    ↓
For Each Item:
    - Check if exists (by quickbooksItemId)
    - Create or Update InventoryItem
    - Set Core Data properties (name, sku, quantity, etc.)
    - Set pricing via extensions → UserDefaults
    - Set lastSyncedQuickbooksDate
    ↓
Save Core Data Context
    ↓
UI Refreshes
```

### **Inventory Push Flow (QuickBooks):**

```
User Taps "Push to QuickBooks"
    ↓
Confirmation Alert
    ↓
QuickBooksService.pushInventoryItem(item)
    ↓
Check if item.quickbooksItemId exists
    ↓
    ├─ YES → Update Flow
    │   ↓
    │   Fetch current item (get SyncToken)
    │   ↓
    │   Build update JSON with SyncToken
    │   ↓
    │   POST to QuickBooks API
    │
    └─ NO → Create Flow
        ↓
        Build create JSON
        ↓
        POST to QuickBooks API
        ↓
        Store returned itemId in quickbooksItemId
```

### **Pricing Display Flow:**

```
ProductDetailView loads
    ↓
.task { await loadDataAsync() }
    ↓
Load pricing from item extensions
    - item.cost → quickbooksCost or manual
    - item.sellingPrice → manual > shopify > QB
    - item.priceSource → "Manual", "Shopify", "QuickBooks"
    ↓
Cache in @State variables
    ↓
Display in pricingSection
    ↓
User taps "Edit"
    ↓
PricingEditView sheet
    ↓
User saves changes → Updates UserDefaults
    ↓
Sheet dismisses
    ↓
.onChange(of: showingEditPricing) triggers
    ↓
refreshTrigger = UUID()
    ↓
View rebuilds with new data
```

---

## Configuration Requirements

### **QuickBooks Setup:**

**Required in UserDefaults:**
```swift
"quickbooksCompanyId": String           // QB Company/Realm ID
"quickbooksAccessToken": String         // OAuth access token
"quickbooksRefreshToken": String        // OAuth refresh token
"quickbooksTokenExpiry": Date          // Token expiration time

// Optional: Account Configuration
"quickbooksIncomeAccountId": String     // Income account for sales
"quickbooksCOGSAccountId": String      // Cost of Goods Sold account
"quickbooksAssetAccountId": String     // Inventory Asset account
```

### **Shopify Setup:**

**Required in UserDefaults:**
```swift
"shopifyStoreUrl": String               // Store URL (e.g., "mystore.myshopify.com")
"shopifyAccessToken": String            // API access token
"shopify_canWriteInventory": Bool      // Write permission flag
```

---

## Error Handling

### **QuickBooksError:**

```swift
enum QuickBooksError: LocalizedError {
    case missingCredentials
    case missingAccountConfiguration
    case invalidResponse
    case httpError(statusCode: Int)
    case parseError
    case missingSyncToken
    
    var errorDescription: String? { ... }
}
```

**Common Errors:**
- `missingCredentials`: QB not configured in settings
- `missingAccountConfiguration`: Account IDs not set
- `httpError(401)`: Token expired → auto-refresh triggered
- `missingSyncToken`: Item modified elsewhere

---

## Testing Considerations

### **Inventory Sync Testing:**

- [ ] Sync creates new items correctly
- [ ] Sync updates existing items without duplicates
- [ ] Pricing stored correctly in UserDefaults
- [ ] Source labels display correctly
- [ ] Pagination handles >100 items
- [ ] Safety limit stops at 10,000 items

### **Inventory Push Testing:**

- [ ] Create new item in QB works
- [ ] Update existing item in QB works
- [ ] Pricing syncs correctly
- [ ] Account IDs use service defaults
- [ ] SyncToken fetched and used correctly
- [ ] Error handling for conflicts

### **UI Testing:**

- [ ] Pricing section shows all sources
- [ ] Edit pricing updates display immediately
- [ ] Push buttons disabled when not configured
- [ ] Loading states show during operations
- [ ] Refresh trigger updates view correctly

### **Performance Testing:**

- [ ] Large datasets (1000+ items) load smoothly
- [ ] Pricing cache improves scroll performance
- [ ] Async loading doesn't block UI
- [ ] Memory usage acceptable with many items

---

## Known Issues & Future Improvements

### **Current Limitations:**

1. **Account ID Storage Not Implemented**
   - Per-item account IDs not stored
   - Uses service-level defaults for all items
   - Code commented out to prevent crashes

2. **Pricing in UserDefaults**
   - Can't query by price range
   - Not included in Core Data backups
   - Consider migration to Core Data for production

3. **No Price History**
   - Only current prices stored
   - No historical price tracking
   - Could add related PriceHistory entity

4. **Limited Bulk Operations**
   - No bulk push/sync for selected items
   - No batch pricing updates
   - Could add checkbox selection system

### **Planned Enhancements:**

1. **Core Data Migration for Pricing**
   - Add Decimal properties to Core Data
   - Migrate from UserDefaults
   - Enable price-based queries

2. **Per-Item Account Configuration**
   - Add Core Data properties
   - Add UI for account selection
   - Enable per-item accounting in QB

3. **Price History Tracking**
   - New PriceHistory entity
   - Track changes over time
   - Visualize price trends

4. **Bulk Operations**
   - Multi-select mode
   - Batch sync/push
   - Batch pricing updates

5. **Image Management**
   - Store product images
   - Sync images from Shopify
   - Upload images to QuickBooks (if supported)

---

## File Structure

```
WMS Suite/
├── Models/
│   ├── WMS_Suite.xcdatamodeld           # Core Data model
│   └── InventoryItem+Extensions.swift   # Pricing extensions
│
├── Views/
│   ├── ProductDetailView.swift          # Main product view
│   ├── PricingEditView.swift           # Pricing editor
│   └── InventoryListView.swift         # Product list (referenced)
│
├── ViewModels/
│   └── InventoryViewModel.swift        # Inventory state management
│
├── Services/
│   ├── QuickBooksService.swift         # QB API integration
│   ├── ShopifyService.swift            # Shopify API integration
│   └── QuickBooksTokenManager.swift    # OAuth token management
│
├── Utilities/
│   └── IDGenerator.swift               # Consistent ID generation
│
└── Protocols/
    ├── QuickBooksServiceProtocol.swift # QB service interface
    └── InventoryRepositoryProtocol.swift # Inventory repo interface
```

---

## Quick Reference

### **Add New Product:**
1. User creates in UI (manual) OR
2. Syncs from QuickBooks/Shopify
3. Assigns unique ID (hash-based for synced items)
4. Stores in Core Data
5. Pricing stored in UserDefaults

### **Sync from QuickBooks:**
1. Navigate to Settings → QuickBooks
2. Tap "Sync Inventory"
3. Paginated fetch (100 per page)
4. Creates/updates items
5. Shows progress log

### **Push to QuickBooks:**
1. Open product detail
2. Tap "Push to QuickBooks"
3. Confirm action
4. Creates or updates in QB
5. Stores QB item ID

### **Edit Pricing:**
1. Open product detail
2. Tap "Edit" in pricing section
3. Modify cost/selling price
4. Save → Updates UserDefaults
5. View auto-refreshes

---

## Summary

The inventory architecture uses a **hybrid approach**:
- **Core Data** for core product information and relationships
- **UserDefaults** for pricing (via extensions) for simplicity
- **Hash-based IDs** for consistent synced item identification
- **Pagination** for handling large datasets
- **Auto-refresh** token management for seamless API access
- **Cached pricing** for optimal UI performance

This architecture balances **implementation speed** (UserDefaults pricing) with **data integrity** (Core Data core model) while providing **extensibility** for future enhancements (Core Data pricing migration, price history, etc.).

---

**Next Sections to Document:**
- Customer Architecture
- Sales Architecture  
- Integration Architecture (OAuth flows, webhooks)
- Data Layer (Core Data stack, repositories)
- UI Components (reusable views, modifiers)

---

*End of Inventory/Product Architecture Section*

---

# Inventory Operations

## Overview

The inventory operations system provides real-time stock management with barcode scanning support for receiving, removing, and viewing inventory. All operations automatically update stock levels and maintain transaction history.

---

## Put Away Inventory (Receiving)

**File:** `PutAwayInventoryView.swift`

Handles receiving inventory into stock with validation and tracking.

### **Features:**

- **Dual Scan Modes:**
  - Camera scanning (AVFoundation)
  - Manual entry (with Bluetooth scanner support)
  
- **Search Priority:** SKU → UPC → WebSKU

- **Stock Updates:** Automatic quantity increase

- **Activity History:** Recent put-away transactions

- **Haptic Feedback:** Success confirmation

### **Workflow:**

```
1. User selects scan mode (Camera or Manual)
2. Scans/enters product code
3. System searches inventory (SKU → UPC → WebSKU)
4. If found: Display item card with current stock
5. User enters quantity to add
6. Tap "Put Away" button
7. System updates: item.quantity += quantity
8. Core Data save with try/catch
9. Success feedback + haptic
10. Add to activity history
11. Reset for next scan
```

### **State Management:**

```swift
@State private var scanMode: ScanMode = .camera
@State private var scannedCode = ""
@State private var manualInput = ""
@State private var foundItem: InventoryItem?
@State private var quantityToAdd: String = "1"
@State private var putAwayHistory: [PutAwayRecord] = []

@StateObject private var scannerManager = BarcodeScannerManager()
@FocusState private var isQuantityFocused: Bool
```

### **Async Operations:**

- Camera start/stop wrapped in `Task { }` blocks
- Core Data saves use `try await viewContext.perform { }`
- Debounced input handling (100ms) prevents UI lag
- Non-blocking operations for smooth UX

---

## Take Out Inventory (Removal)

**File:** `TakeOutInventoryView.swift`

Handles inventory removal with reason tracking and stock validation.

### **Features:**

- **Dual Scan Modes:** Camera or Manual
- **Stock Validation:** Prevents over-removal
- **Removal Reasons:**
  - Order Fulfillment (Blue)
  - Damaged/Wastage (Red)
  - Transfer Out (Orange)
  - Sample/Demo (Purple)
  - Inventory Adjustment (Yellow)
  - Other (Gray)
- **Optional Notes:** Transaction context
- **Low Stock Warnings:** Alert when approaching minimum
- **Activity History:** Recent removals with reasons

### **Workflow:**

```
1. User selects scan mode
2. Scans/enters product code
3. System finds item
4. If out of stock: Show error, block action
5. If low stock: Show warning
6. User enters quantity to remove
7. System validates: quantity <= available
8. User selects removal reason
9. Optional: Add notes
10. Tap "Remove from Inventory"
11. System updates: item.quantity -= quantity
12. Transaction logged with reason
13. Core Data save
14. Success feedback + haptic
15. Add to activity history
```

### **Validation:**

```swift
private func isValidRemoval(item: InventoryItem) -> Bool {
    guard let quantity = Int32(quantityToRemove) else { return false }
    return quantity > 0 && quantity <= item.quantity
}
```

### **Transaction Logging:**

```swift
private func logTransaction(
    item: InventoryItem,
    quantity: Int32,
    reason: RemovalReason,
    notes: String
) {
    print("""
    📦 INVENTORY TAKEOUT:
    - Item: \(item.name ?? "Unknown")
    - Quantity: \(quantity)
    - Reason: \(reason.rawValue)
    - Notes: \(notes)
    - New Stock: \(item.quantity)
    - Timestamp: \(Date())
    """)
    // Future: Save to transaction log entity
}
```

---

## Quick Scan (View Only)

**File:** `QuickScanView.swift`

Quick barcode lookup for viewing product details without modifying stock.

### **Features:**

- Camera and Manual scan modes
- Search priority: SKU → UPC → WebSKU
- Auto-opens product detail on match
- Multiple results handling

---

## Quick Actions Bar

**File:** `QuickActionsBar.swift`

Prominent action bar on inventory screen for quick access to operations.

### **Actions:**

1. **Quick Scan** (Blue) - View product details
2. **Put Away** (Green) - Receive inventory
3. **Take Out** (Orange) - Remove inventory
4. **Print Labels** (Purple) - Generate barcodes

### **Platform Adaptive:**

- **iPhone:** 2x2 grid layout
- **iPad:** Horizontal row layout

### **Features:**

- Haptic feedback on tap
- Color-coded by action type
- Always visible (no hidden menu)
- Smooth scale animations

---

# Orders/Sales Architecture

## Overview

The orders/sales system manages the complete lifecycle of orders from multiple sources (Local, Shopify, QuickBooks), with fulfillment tracking, payment status, and line item management.

---

## Core Data Model

### **Sale Entity**

**Core Data Properties:**
```swift
// Identity
id: Int32                           // Unique identifier (hash-based for synced orders)
orderNumber: String?                // Display order number (e.g., "INV-1001")

// Dates
saleDate: Date?                     // Order/invoice date
createdDate: Date?                  // When record was created
dueDate: Date?                      // Payment due date

// Financial
subtotal: NSDecimalNumber?          // Subtotal before tax
taxAmount: NSDecimalNumber?         // Tax amount
totalAmount: NSDecimalNumber?       // Total amount (subtotal + tax)
amountPaid: NSDecimalNumber?        // Amount already paid
balance: NSDecimalNumber?           // Remaining balance (totalAmount - amountPaid)

// Order Details
terms: String?                      // Payment terms (e.g., "Net 30")
memo: String?                       // Private notes/memo

// Fulfillment Status (String stored)
fulfillmentStatus: String?          // "needs_fulfillment", "in_transit", "delivered", "unconfirmed"

// Flags
isPriority: Bool                    // Priority order flag
needsAttention: Bool                // Requires attention flag

// Integration IDs
quickbooksInvoiceId: String?        // QuickBooks invoice ID
shopifyOrderId: String?             // Shopify order ID
quickbooksSyncToken: String?        // QB sync token for updates
lastSyncedQuickbooksDate: Date?     // Last QB sync timestamp
lastSyncedShopifyDate: Date?        // Last Shopify sync timestamp

// Source Tracking
orderSource: String?                // "local", "shopify", "quickbooks"

// Relationships
customer: Customer?                 // Related customer (many-to-one)
lineItems: Set<SaleLineItem>        // Line items in this order (one-to-many)
```

---

### **SaleLineItem Entity**

**Core Data Properties:**
```swift
// Identity
id: Int32                           // Unique identifier

// Line Details
quantity: Int32                     // Quantity of items
unitPrice: NSDecimalNumber?         // Price per unit
lineTotal: NSDecimalNumber?         // Total for this line (quantity × unitPrice)

// Relationships
sale: Sale?                         // Parent sale (many-to-one)
item: InventoryItem?                // Related inventory item (many-to-one)
```

---

## Computed Properties & Extensions

**File:** `Sale+Extensions.swift` (referenced)

### **Fulfillment Status:**

```swift
// Enum conversion
var fulfillmentStatusEnum: OrderFulfillmentStatus? {
    guard let status = fulfillmentStatus else { return nil }
    return OrderFulfillmentStatus(rawValue: status)
}

// Status checks
var needsFulfillment: Bool {
    fulfillmentStatus == OrderFulfillmentStatus.needsFulfillment.rawValue
}

var isInTransit: Bool {
    fulfillmentStatus == OrderFulfillmentStatus.inTransit.rawValue
}

var isDelivered: Bool {
    fulfillmentStatus == OrderFulfillmentStatus.delivered.rawValue
}

var isUnconfirmed: Bool {
    fulfillmentStatus == OrderFulfillmentStatus.unconfirmed.rawValue
}
```

### **Source Tracking:**

```swift
// Enum conversion
var orderSource: OrderSource? {
    guard let source = orderSource else { return nil }
    return OrderSource(rawValue: source)
}

// Source checks
var isLocalOrder: Bool {
    orderSource == OrderSource.local.rawValue
}

var isShopifyOrder: Bool {
    orderSource == OrderSource.shopify.rawValue
}

var isQuickBooksOrder: Bool {
    orderSource == OrderSource.quickbooks.rawValue
}
```

### **Payment Status:**

```swift
var paymentStatusDisplayName: String {
    if let balance = balance?.doubleValue,
       let total = totalAmount?.doubleValue {
        if balance == 0 {
            return "Paid"
        } else if balance == total {
            return "Unpaid"
        } else {
            return "Partially Paid"
        }
    }
    return "Unknown"
}

var paymentStatusColor: Color {
    switch paymentStatusDisplayName {
    case "Paid": return .green
    case "Partially Paid": return .orange
    case "Unpaid": return .red
    default: return .gray
    }
}
```

### **Display Helpers:**

```swift
var formattedTotalAmount: String {
    guard let amount = totalAmount else { return "$0.00" }
    return amount.currencyFormatted
}

var formattedAmountPaid: String {
    guard let paid = amountPaid else { return "$0.00" }
    return paid.currencyFormatted
}

var formattedBalance: String {
    guard let bal = balance else { return "$0.00" }
    return bal.currencyFormatted
}

var hasCustomer: Bool {
    customer != nil
}

var hasMemo: Bool {
    memo != nil && !memo!.isEmpty
}

var hasFlagsSet: Bool {
    isPriority || needsAttention
}
```

### **QuickBooks Integration Helper:**

```swift
static func fetchByQuickBooksId(_ qbInvoiceId: String, context: NSManagedObjectContext) -> Sale? {
    let fetchRequest = NSFetchRequest<Sale>(entityName: "Sale")
    fetchRequest.predicate = NSPredicate(format: "quickbooksInvoiceId == %@", qbInvoiceId)
    fetchRequest.fetchLimit = 1
    return try? context.fetch(fetchRequest).first
}

func updateFromQuickBooksInvoice(
    qbInvoiceId: String,
    invoiceNumber: String,
    date: Date,
    subtotal: NSDecimalNumber,
    taxAmount: NSDecimalNumber,
    totalAmount: NSDecimalNumber,
    amountPaid: NSDecimalNumber,
    dueDate: Date?,
    terms: String?,
    memo: String?,
    syncToken: String?
) {
    self.quickbooksInvoiceId = qbInvoiceId
    self.orderNumber = invoiceNumber
    self.saleDate = date
    self.subtotal = subtotal
    self.taxAmount = taxAmount
    self.totalAmount = totalAmount
    self.amountPaid = amountPaid
    self.balance = NSDecimalNumber(decimal: totalAmount.decimalValue - amountPaid.decimalValue)
    self.dueDate = dueDate
    self.terms = terms
    self.memo = memo
    self.quickbooksSyncToken = syncToken
    self.orderSource = OrderSource.quickbooks.rawValue
    self.lastSyncedQuickbooksDate = Date()
    
    // Set fulfillment status based on payment
    if self.balance?.doubleValue == 0 {
        self.fulfillmentStatus = OrderFulfillmentStatus.delivered.rawValue
    } else if self.fulfillmentStatus == nil {
        self.fulfillmentStatus = OrderFulfillmentStatus.needsFulfillment.rawValue
    }
}
```

---

## Enumerations

### **OrderSource:**

**File:** `OrderSource.swift`

```swift
enum OrderSource: String, CaseIterable, Identifiable {
    case local = "local"
    case shopify = "shopify"
    case quickbooks = "quickbooks"
    
    var displayName: String
    var icon: String
    var color: Color
}
```

**Attributes:**
- `local`: Blue, iPhone icon - Orders created in the app
- `shopify`: Green, Cart icon - Orders from Shopify
- `quickbooks`: Orange, Book icon - Invoices from QuickBooks

---

### **OrderFulfillmentStatus:**

**File:** `OrderFulfillmentStatus.swift`

```swift
enum OrderFulfillmentStatus: String, CaseIterable, Identifiable {
    case needsFulfillment = "needs_fulfillment"
    case inTransit = "in_transit"
    case delivered = "delivered"
    case unconfirmed = "unconfirmed"
    
    var displayName: String
    var icon: String
    var color: Color
    var sortOrder: Int
}
```

**Status Lifecycle:**
1. **Needs Fulfillment** (Blue, Box icon) - Order created, ready to ship
2. **In Transit** (Orange, Truck icon) - Order shipped, in delivery
3. **Unconfirmed** (Yellow, Question mark) - Delivery status unknown
4. **Delivered** (Green, Checkmark seal) - Order completed

---

## View Layer

### **OrdersView.swift**

Main orders list view with filtering and organization.

#### **Key Features:**

1. **Source Filter Tabs**
   - All Orders
   - Local Only
   - Shopify Only
   - QuickBooks Only

2. **Status Filter Tabs**
   - All Statuses
   - Needs Fulfillment
   - In Transit
   - Unconfirmed
   - Delivered

3. **Organized Sections**
   - Priority Orders (always at top)
   - Needs Fulfillment Orders
   - In Transit Orders
   - Unconfirmed Orders
   - Delivered Orders

4. **Search Functionality**
   - Search by order number

5. **Pull to Refresh**
   - Syncs with QuickBooks/Shopify

#### **State Management:**

```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Sale.saleDate, ascending: false)],
    animation: .default
)
private var sales: FetchedResults<Sale>

@State private var searchText = ""
@State private var selectedSource: OrderSource? = nil
@State private var selectedStatus: OrderFulfillmentStatus? = nil
@State private var showingAddOrder = false
@State private var isRefreshing = false
@State private var refreshID = UUID()
```

#### **Filtering Logic:**

```swift
var filteredSales: [Sale] {
    var filtered = Array(sales)
    
    // Filter by source
    if let source = selectedSource {
        filtered = filtered.filter { $0.orderSource == source }
    }
    
    // Filter by status
    if let status = selectedStatus {
        filtered = filtered.filter { sale in
            if status == .needsFulfillment {
                return sale.needsFulfillment
            } else if status == .unconfirmed {
                return sale.isUnconfirmed
            } else {
                return sale.fulfillmentStatusEnum == status
            }
        }
    }
    
    // Filter by search text
    if !searchText.isEmpty {
        filtered = filtered.filter { sale in
            sale.orderNumber?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    return filtered
}
```

#### **Section Filtering:**

```swift
var priorityOrders: [Sale] {
    filteredSales.filter { $0.isPriority || $0.needsAttention }
}

var needsFulfillmentOrders: [Sale] {
    filteredSales.filter { $0.needsFulfillment && !$0.hasFlagsSet }
}

var inTransitOrders: [Sale] {
    filteredSales.filter { $0.isInTransit && !$0.isUnconfirmed && !$0.hasFlagsSet }
}

var unconfirmedOrders: [Sale] {
    filteredSales.filter { $0.isUnconfirmed && !$0.hasFlagsSet }
}

var deliveredOrders: [Sale] {
    filteredSales.filter { $0.isDelivered && !$0.hasFlagsSet }
}
```

---

### **InvoiceDetailView.swift**

Detailed view of a single order/invoice.

#### **Key Sections:**

1. **Invoice Header**
   - Payment status badge (Paid/Unpaid/Partially Paid)
   - Total amount (large display)
   - Invoice date and due date

2. **Customer Info Section**
   - Customer name
   - Contact information
   - Billing/shipping address

3. **Line Items Section**
   - List of items ordered
   - Quantity, unit price, line total
   - Links to inventory items

4. **Totals Section**
   - Subtotal
   - Tax amount
   - Total amount
   - Amount paid
   - Balance due

5. **Notes Section** (if present)
   - Memo/private notes

#### **Toolbar Actions:**

```swift
Menu {
    Button("Share") { /* Share functionality */ }
    Button("View in QuickBooks") { /* Open in QB */ }
}
```

---

### **OrderRow.swift**

**File:** `OrderRow.swift` (referenced)

Individual order row component for the orders list.

**Expected Display:**
- Order number
- Customer name
- Total amount
- Date
- Source icon/badge
- Fulfillment status icon
- Priority/attention flags

---

## QuickBooks Integration

### **Invoice Sync Methods:**

#### **1. Pull All Invoices:**

```swift
func syncInvoices(
    context: NSManagedObjectContext,
    logMessage: @escaping (String) -> Void
) async throws
```

**Process:**
1. Fetches all invoices with pagination (100 per page)
2. Query: `SELECT * FROM Invoice STARTPOSITION {pos} MAXRESULTS {max}`
3. Creates or updates local Sale records
4. Links to customers
5. Processes line items
6. Updates sync timestamps

**Data Extracted:**
- Invoice ID and Document Number
- Transaction Date and Due Date
- Total Amount, Balance, Tax
- Customer reference
- Sales terms
- Private notes (memo)
- Line items with quantities and prices

#### **2. Pull Single Invoice:**

```swift
func syncInvoice(qbInvoiceId: String, context: NSManagedObjectContext) async throws
```

Used for targeted sync of a specific invoice.

---

### **Invoice Processing:**

```swift
private func processInvoice(
    _ invoiceData: [String: Any],
    context: NSManagedObjectContext
) async throws -> (created: Bool, updated: Bool)
```

**Steps:**
1. Extract invoice data from QB JSON
2. Parse dates, amounts, customer reference
3. Calculate actual subtotal (total - tax)
4. Calculate amount paid (total - balance)
5. Check if invoice exists by QB ID
6. Create new Sale or update existing
7. Call `updateFromQuickBooksInvoice()` helper
8. Link to customer if found
9. Process line items
10. Save context

---

### **Line Items Processing:**

```swift
private func processInvoiceLineItems(
    _ lineItemsData: [[String: Any]],
    for sale: Sale,
    context: NSManagedObjectContext
) throws
```

**Process:**
1. Delete existing line items (clean slate)
2. Loop through QB line items
3. Filter for `SalesItemLineDetail` type
4. Create SaleLineItem entities
5. Extract quantity, unit price, line total
6. Link to InventoryItem if found by item name
7. Link to parent Sale

**Item Matching:**
- Searches for inventory item by name or SKU
- Falls back to unlinked line item if not found
- Allows manual linking later

---

## Data Flow

### **Invoice Sync Flow (QuickBooks → Local):**

```
User Triggers Sync (Orders Screen)
    ↓
QuickBooksService.syncInvoices()
    ↓
Paginated API Calls (100 invoices per page)
    ↓
For Each Invoice:
    ↓
    Extract Data from QB JSON
    ↓
    Check if Sale exists (by quickbooksInvoiceId)
    ↓
    ├─ Exists → Update existing Sale
    └─ New → Create Sale with hash-based ID
    ↓
    Set Core Data Properties:
    - Order number, dates
    - Financial amounts
    - Payment status
    - Source = "quickbooks"
    ↓
    Link to Customer (if found by QB ID)
    ↓
    Process Line Items:
    - Delete old line items
    - Create new line items
    - Link to inventory items
    ↓
    Set lastSyncedQuickbooksDate
    ↓
Save Core Data Context
    ↓
UI Refreshes with New/Updated Orders
```

---

### **Order Display Flow:**

```
OrdersView Loads
    ↓
@FetchRequest fetches all Sales
    ↓
Apply Filters:
    - Source filter (local/shopify/QB)
    - Status filter (fulfillment status)
    - Search text (order number)
    ↓
Organize into Sections:
    - Priority Orders (flagged)
    - Needs Fulfillment
    - In Transit
    - Unconfirmed
    - Delivered
    ↓
Display in Sectioned List
    ↓
User Taps Order
    ↓
Navigate to InvoiceDetailView
    ↓
Display Full Order Details:
    - Customer info
    - Line items
    - Totals
    - Payment status
```

---

### **Order Fulfillment Update Flow:**

```
User Opens Order Detail
    ↓
Change Fulfillment Status (Picker/Buttons)
    ↓
Update sale.fulfillmentStatus = newStatus.rawValue
    ↓
Save Core Data Context
    ↓
View Updates via @ObservedObject
    ↓
Orders List Updates Sections Automatically
```

---

### **Order Creation Flow (Local):**

```
User Taps "+" in Orders View
    ↓
Sheet Presents AddOrderView
    ↓
User Fills Order Details:
    - Select customer
    - Add line items
    - Set quantities/prices
    ↓
Calculate Totals:
    - Sum line totals for subtotal
    - Add tax if applicable
    - Calculate total
    ↓
Create Sale Entity:
    - Generate unique ID
    - Set orderSource = "local"
    - Set fulfillmentStatus = "needs_fulfillment"
    - Set dates
    - Link customer
    ↓
Create SaleLineItem Entities:
    - Link to Sale
    - Link to InventoryItems
    - Set quantities/prices
    ↓
Save Core Data Context
    ↓
Dismiss Sheet
    ↓
Orders List Updates with New Order
```

---

## ID Generation Strategy

### **Hash-Based IDs for Synced Orders:**

```swift
// For QuickBooks invoices
sale.id = IDGenerator.hashQuickBooksInvoiceID(qbInvoiceId)

// Ensures consistency:
// - Same QB invoice ID always produces same Int32
// - Prevents duplicate orders on re-sync
// - Allows safe re-syncing without data loss
```

---

## Charts & Analytics

**File:** `OrdersChartsView.swift` (referenced)

### **Expected Features:**

1. **Orders Over Time**
   - Line chart showing order volume by date
   - Segmented by source (Local/Shopify/QB)

2. **Revenue Over Time**
   - Bar/line chart showing total revenue
   - Trend analysis

3. **Fulfillment Status Breakdown**
   - Pie chart showing order distribution
   - By fulfillment status

4. **Top Customers**
   - Bar chart of revenue by customer
   - Linked customer analysis

5. **Payment Status Overview**
   - Paid vs Unpaid amounts
   - Outstanding balance tracking

---

## Supporting Views

### **InvoicesListView.swift**

**File:** `InvoicesListView.swift` (referenced)

Alternative view focused specifically on QuickBooks invoices.

**Expected Features:**
- Filter to show only QB orders
- Invoice-specific details
- QB sync button
- View in QuickBooks link

---

## Configuration Requirements

### **QuickBooks:**

Already covered in Inventory section, same credentials apply.

### **Shopify:**

Same as Inventory section, uses same API credentials.

---

## Error Handling

### **Invoice Sync Errors:**

```swift
// QuickBooksError cases apply:
case .missingCredentials       // QB not configured
case .invalidResponse          // Malformed API response
case .httpError(401)           // Token expired (auto-refresh)
case .parseError               // JSON parsing failed
```

**Handling:**
- Displays error message to user
- Logs error details
- Allows retry

### **Customer Linking Failures:**

If customer not found during invoice sync:
- Invoice still created
- Customer field left nil
- Can be manually linked later
- Shows "Unknown Customer" in UI

### **Item Linking Failures:**

If inventory item not found for line item:
- Line item still created
- item field left nil
- Shows item name from QB
- Can be manually linked later

---

## Testing Considerations

### **Invoice Sync Testing:**

- [ ] Sync creates new orders correctly
- [ ] Sync updates existing orders without duplicates
- [ ] Customer linking works when customer exists
- [ ] Customer missing doesn't block invoice creation
- [ ] Line items link to inventory correctly
- [ ] Payment status calculated correctly (Paid/Unpaid/Partial)
- [ ] Pagination handles >100 invoices
- [ ] Safety limit stops at 10,000 invoices

### **Filtering Testing:**

- [ ] Source filter shows correct orders
- [ ] Status filter shows correct orders
- [ ] Search finds orders by order number
- [ ] Combined filters work correctly
- [ ] Sections organize orders correctly
- [ ] Priority orders always show first

### **Display Testing:**

- [ ] Payment status colors correct
- [ ] Fulfillment status icons correct
- [ ] Source badges display correctly
- [ ] Amounts formatted as currency
- [ ] Dates display in correct format
- [ ] Customer info shows when linked

### **Performance Testing:**

- [ ] Large datasets (1000+ orders) load smoothly
- [ ] Filtering doesn't lag with many orders
- [ ] Sectioning performs well
- [ ] Detail view loads quickly
- [ ] Memory usage acceptable

---

## Known Issues & Future Improvements

### **Current Limitations:**

1. **No Shopify Order Sync**
   - Only QuickBooks invoices sync currently
   - Shopify integration planned
   - Manual order creation only for now

2. **No Invoice Creation/Editing**
   - Read-only from QuickBooks
   - Can't create invoices in QB from app
   - Can't edit invoice details

3. **Limited Fulfillment Tracking**
   - No shipping carrier integration
   - No tracking number support
   - Manual status updates only

4. **No Email/Print**
   - Can't email invoices to customers
   - No print/PDF generation
   - Share button placeholder

5. **No Payment Recording**
   - Can't record payments in app
   - Must update in QuickBooks
   - Syncs payment status only

### **Planned Enhancements:**

1. **Shopify Order Sync**
   - Pull orders from Shopify
   - Map to Sale entities
   - Include fulfillment data

2. **Push Orders to QuickBooks**
   - Create invoices from local orders
   - Update invoice details
   - Two-way sync

3. **Advanced Fulfillment**
   - Shipping carrier integration
   - Tracking number entry
   - Automatic status updates
   - Shipping label printing

4. **Payment Management**
   - Record payments in app
   - Push payments to QuickBooks
   - Payment history tracking

5. **PDF Generation**
   - Generate invoice PDFs
   - Email to customers
   - Print invoices

6. **Inventory Integration**
   - Auto-reduce stock on fulfillment
   - Low stock warnings for orders
   - Backorder management

7. **Order Analytics**
   - Revenue forecasting
   - Customer lifetime value
   - Product performance
   - Seasonal trends

---

## File Structure

```
WMS Suite/
├── Models/
│   ├── WMS_Suite.xcdatamodeld       # Core Data model
│   ├── Sale+Extensions.swift        # Sale computed properties
│   └── SaleLineItem+Extensions.swift # Line item helpers
│
├── Views/
│   ├── OrdersView.swift             # Main orders list
│   ├── InvoiceDetailView.swift     # Order detail view
│   ├── InvoicesListView.swift      # QB-specific invoices
│   ├── OrderRow.swift               # Order list row component
│   └── OrdersChartsView.swift       # Analytics charts
│
├── Services/
│   └── QuickBooksService.swift      # Invoice sync methods
│
├── Enums/
│   ├── OrderSource.swift            # Order source enum
│   └── OrderFulfillmentStatus.swift # Fulfillment status enum
│
└── Utilities/
    └── IDGenerator.swift            # Invoice ID hashing
```

---

## Quick Reference

### **Sync Invoices from QuickBooks:**
1. Navigate to Orders screen
2. Pull down to refresh OR
3. Tap refresh button in toolbar
4. Shows sync progress
5. Orders appear/update automatically

### **View Order Details:**
1. Tap order in list
2. Navigate to InvoiceDetailView
3. View customer, line items, totals
4. Access toolbar menu for actions

### **Filter Orders:**
1. Tap source filter tabs (All/Local/Shopify/QB)
2. Tap status filter tabs (All/Needs Fulfillment/etc.)
3. Use search bar for order number
4. Filters combine for precise results

### **Update Fulfillment Status:**
1. Open order detail (future)
2. Tap status picker/buttons
3. Select new status
4. Auto-saves to Core Data

### **Create Local Order:**
1. Tap "+" button
2. Fill order form
3. Add line items
4. Save
5. Order appears in list

---

## Summary

The orders/sales architecture provides:
- **Multi-source order management** (Local, Shopify, QuickBooks)
- **Comprehensive filtering and organization** by source and status
- **QuickBooks invoice sync** with pagination and line items
- **Customer linking** for relationship tracking
- **Payment status tracking** (Paid/Unpaid/Partially Paid)
- **Fulfillment workflow** (Needs Fulfillment → In Transit → Delivered)
- **Priority flagging** for important orders
- **Hash-based IDs** for consistent synced order identification

The architecture separates **read operations** (syncing from QuickBooks) from future **write operations** (creating/updating in QB), with a clear data model that supports both manual and synced orders.

---

**Next Sections to Document:**
- Customer Architecture (linking, sync, management)
- Integration Architecture (OAuth flows, webhooks, API details)
- Data Layer (Core Data stack, repositories, persistence)
- UI Components (reusable views, modifiers, theming)

---

*End of Orders/Sales Architecture Section*

---

# Order Picking & Fulfillment
## Overview

The order picking system integrates inventory management with order fulfillment, automatically deducting stock as items are picked, with support for partial picks and stock validation.

---

## Pick Item Sheet

**File:** `PickItemSheet.swift`

Interactive sheet for picking order line items with inventory deduction.

### **Features:**

- **Stock Status Display:**
  - Quantity needed vs available
  - Visual indicators (green/orange/red)
  - Sufficient/Insufficient/Out of stock warnings

- **Quantity Adjustment:**
  - +/- buttons for precise control
  - Direct keyboard entry
  - Quick pick buttons (Max, All, Half)

- **Stock Validation:**
  - Prevents over-picking
  - Real-time validation feedback
  - Blocks action when invalid

- **Partial Pick Support:**
  - Allows picking less than needed
  - Clear labeling when partial
  - Tracks remaining quantities

- **Automatic Inventory Deduction:**
  - Updates `item.quantity` on pick
  - Core Data save with error handling
  - Transaction logging

### **Workflow:**

```
1. User taps item in order pick list
2. Sheet opens with item details
3. Shows: Name, SKU, Qty Needed, Qty Available
4. Default quantity: min(needed, available)
5. User adjusts quantity if needed
6. System validates: quantity <= available
7. User taps "Pick & Deduct from Inventory"
8. Async operation:
   - item.quantity -= pickedQuantity
   - item.lastUpdated = Date()
   - viewContext.save()
9. Success: Haptic feedback + dismiss
10. Pick list updates with progress
```

### **State Management:**

```swift
let lineItem: SaleLineItem
let item: InventoryItem
let onPicked: (Int32) -> Void

@State private var quantityToPick: String
@State private var showingError = false
@State private var errorMessage = ""
@FocusState private var isQuantityFocused: Bool
```

### **Validation Logic:**

```swift
private var isValidPick: Bool {
    guard let qty = Int32(quantityToPick) else { return false }
    return qty > 0 && qty <= availableStock
}

private var isPartialPick: Bool {
    guard let qty = Int32(quantityToPick) else { return false }
    return qty < quantityNeeded
}
```

### **Async Pick Operation:**

```swift
private func pickItem() {
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
    
    Task { @MainActor in
        do {
            try await viewContext.perform {
                item.quantity -= quantity
                item.lastUpdated = Date()
                try viewContext.save()
            }
            
            // Log + haptic + callback + dismiss
            print("📦 ITEM PICKED: \(item.name ?? "")")
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            onPicked(quantity)
            dismiss()
            
        } catch {
            errorMessage = "Error updating inventory: \(error.localizedDescription)"
            showingError = true
        }
    }
}
```

---

## Order Pick List View

**File:** `OrderPickListView.swift`

Displays pickable items in an order with real-time progress tracking.

### **Features:**

- **Pick Progress Tracking:**
  - Tracks picked quantities per line item
  - Shows partial pick status
  - Visual progress indicators

- **Status Display:**
  - ✅ Green: Fully picked
  - 🔵 Blue: Partially picked
  - ⚪ Gray: Not picked
  - 🟠 Orange: Stock warning

- **Stock Warnings:**
  - Shows available quantity
  - Alerts when insufficient stock
  - Visual warning indicators

- **Interactive Rows:**
  - Tap item to open pick sheet
  - Shows picked vs needed quantities
  - Color-coded borders

### **State Management:**

```swift
@State private var pickedQuantities: [Int32: Int32] = [:] // lineItemId: pickedQty
@State private var showingPickSheet = false
@State private var selectedLineItem: SaleLineItem?
```

### **Progress Computation:**

```swift
var allItemsPicked: Bool {
    return lineItems.allSatisfy { lineItem in
        let picked = pickedQuantities[lineItem.id] ?? 0
        return picked >= lineItem.quantity
    }
}

var totalPicked: Int {
    lineItems.filter { lineItem in
        let picked = pickedQuantities[lineItem.id] ?? 0
        return picked >= lineItem.quantity
    }.count
}
```

### **Sheet Presentation:**

```swift
.sheet(isPresented: $showingPickSheet) {
    if let lineItem = selectedLineItem, let item = lineItem.item {
        NavigationView {
            PickItemSheet(lineItem: lineItem, item: item) { pickedQty in
                // Update picked quantity
                let currentPicked = pickedQuantities[lineItem.id] ?? 0
                pickedQuantities[lineItem.id] = currentPicked + pickedQty
            }
        }
    }
}
```

---

## Integration with Order Detail

**File:** `OrderDetailView.swift`

The pick list is automatically displayed in order detail views for orders that need fulfillment.

### **Conditional Display:**

```swift
// Show pick list if order needs fulfillment
if sale.needsFulfillment {
    OrderPickListView(sale: sale)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
}
```

---

# Barcode Tools

## Overview

Combined barcode scanning and generation tools for inventory management.

---

## Barcode Tools View

**File:** `BarcodeToolsView.swift`

Unified interface combining scanning and generating barcodes.

### **Features:**

- **Tab Interface:**
  - **Scan Tab:** Camera-based barcode scanner
  - **Generate Tab:** Barcode label creation

- **Segmented Control:** Easy switching between modes

### **Structure:**

```swift
struct BarcodeToolsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedTab: ToolTab = .scan
    
    enum ToolTab: String, CaseIterable {
        case scan = "Scan"
        case generate = "Generate"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            Picker("Tool", selection: $selectedTab) {
                ForEach(ToolTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content
            switch selectedTab {
            case .scan:
                BarcodeScannerView(viewModel: viewModel)
            case .generate:
                BarcodeView(viewModel: viewModel)
            }
        }
        .navigationTitle("Barcode Tools")
    }
}
```

---

## Barcode Scanner View

**File:** `BarcodeScannerView.swift`

Camera-based barcode scanner for product lookup.

### **Features:**

- AVFoundation camera integration
- Real-time barcode detection
- Search by barcode in inventory
- Auto-opens product detail on match

---

## Barcode Generator View

**File:** `BarcodeView.swift`

Generate and print barcode labels for products.

### **Features:**

- Code 128 barcode generation
- Print multiple copies
- Save/share barcode images
- iPad split-screen support

---

## Barcode Scanner Manager

**File:** `BarcodeScannerView.swift` (embedded class)

Manages AVFoundation camera session for barcode scanning.

### **Features:**

```swift
class BarcodeScannerManager: NSObject, ObservableObject {
    @Published var scannedCode: String?
    @Published var isAuthorized = false
    var hasScanned = false
    
    let session = AVCaptureSession()
    
    func checkAuthorization()
    func setupCaptureSession()
    func startScanning()
    func stopScanning()
    func resetScanner() // Resets state for next scan
}
```

### **Barcode Types Supported:**

- EAN-8
- EAN-13
- PDF417
- QR Code
- Code 128
- Code 39
- Code 93
- UPC-E

---

## Camera Preview View

**File:** `BarcodeScannerView.swift` (embedded struct)

UIViewRepresentable wrapper for camera preview.

```swift
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView
    func updateUIView(_ uiView: UIView, context: Context)
}
```

---

*End of New Features Documentation*



