# WMS Suite iOS - App Architecture & Setup Guide

**Last Updated:** January 1, 2026  
**Purpose:** Comprehensive guide to the app's architecture, data flow, and key components

---

## 📱 **App Overview**

**WMS Suite** is a comprehensive iOS warehouse management system with:
- ✅ Inventory tracking and management
- ✅ Barcode generation and scanning
- ✅ AI-powered item counting (Vision framework)
- ✅ Multi-platform integration (Shopify + QuickBooks)
- ✅ Order tracking and fulfillment
- ✅ Sales forecasting and analytics

---

## 🏗️ **Architecture Pattern: MVVM**

```
┌─────────────────────────────────────────────────┐
│                    Views                         │
│  (SwiftUI - User Interface)                     │
│  - ProductsView                                  │
│  - OrdersView                                    │
│  - QuickBooksSettingsView                       │
└──────────────┬──────────────────────────────────┘
               │ Binds to @Published properties
               ▼
┌─────────────────────────────────────────────────┐
│                View Models                       │
│  (ObservableObject - Business Logic)            │
│  - InventoryViewModel                           │
│  - OrdersViewModel                              │
│  - QuickBooksTokenManager                       │
└──────────────┬──────────────────────────────────┘
               │ Uses
               ▼
┌─────────────────────────────────────────────────┐
│                Services                          │
│  (API Communication & Business Logic)           │
│  - ShopifyService                               │
│  - QuickBooksService                            │
│  - BarcodeService                               │
└──────────────┬──────────────────────────────────┘
               │ Reads/Writes
               ▼
┌─────────────────────────────────────────────────┐
│              Repositories                        │
│  (Data Access Layer)                            │
│  - InventoryRepository                          │
│  - Core Data Context                            │
└──────────────┬──────────────────────────────────┘
               │ Persists to
               ▼
┌─────────────────────────────────────────────────┐
│              Data Models                         │
│  (Core Data Entities)                           │
│  - InventoryItem                                │
│  - Sale                                         │
│  - Customer                                     │
└─────────────────────────────────────────────────┘
```

---

## 📊 **Core Data Model**

### **Main Entities:**

#### **1. InventoryItem**
```swift
// Represents a product/SKU in the warehouse
Attributes:
- id: UUID
- sku: String                    // Warehouse SKU
- name: String                   // Product name
- itemDescription: String?       // Description
- upc: String?                   // Barcode/UPC
- webSKU: String?                // E-commerce SKU
- quantity: Int32                // Current stock
- minStockLevel: Int32           // Reorder point
- imageUrl: String?              // Product image
- shopifyProductId: String?      // Shopify sync ID
- quickbooksItemId: String?      // QuickBooks sync ID
- lastUpdated: Date              // Last modified
- lastSyncedShopifyDate: Date?   // Last Shopify sync
- lastSyncedQuickbooksDate: Date? // Last QB sync

Relationships:
- saleLineItems: [SaleLineItem]  // Sales history
```

#### **2. Sale**
```swift
// Represents an order/invoice
Attributes:
- id: UUID
- orderNumber: String
- saleDate: Date
- totalAmount: Decimal
- source: String                 // "manual", "shopify", "quickbooks"
- fulfillmentStatus: String      // "pending", "fulfilled", etc.
- trackingNumber: String?
- carrier: String?
- shippedDate: Date?
- deliveredDate: Date?
- lastTrackingUpdate: Date?
- isPriority: Bool              // Flag for urgent orders
- needsAttention: Bool          // Flag for issues
- quickbooksInvoiceId: String?  // QB sync ID
- paymentStatus: String?        // "paid", "unpaid", "partial"
- amountPaid: Decimal?
- dueDate: Date?

Relationships:
- lineItems: [SaleLineItem]     // Products in order
- notes: [OrderNote]            // Order notes
- customer: Customer?           // Linked customer
```

#### **3. Customer**
```swift
// Represents a customer (synced from QuickBooks)
Attributes:
- id: UUID
- name: String
- companyName: String?
- email: String?
- phone: String?
- billingAddress: String?
- shippingAddress: String?
- balance: Decimal?             // Outstanding balance
- quickbooksCustomerId: String? // QB sync ID
- lastSyncedQuickbooksDate: Date?

Relationships:
- sales: [Sale]                 // Purchase history
- customerNotes: [CustomerNote]  // Notes about customer
```

#### **4. SaleLineItem**
```swift
// Represents a product within an order
Attributes:
- id: UUID
- quantity: Int32
- unitPrice: Decimal
- lineTotal: Decimal

Relationships:
- item: InventoryItem           // Product reference
- sale: Sale                    // Parent order
```

---

## 🔄 **Data Flow Patterns**

### **1. QuickBooks Integration Flow**

```
User Actions → QuickBooks Settings View
                    ↓
              Token Manager
           (OAuth Authentication)
                    ↓
              Azure Function
          (Secure Token Exchange)
                    ↓
           QuickBooks OAuth API
                    ↓
              Access Granted
                    ↓
         Auto-Sync Manager Starts
                    ↓
    ┌───────────────┴───────────────┐
    ▼                               ▼
Customer Sync                  Invoice Sync
(QuickBooksService)           (QuickBooksService)
    │                               │
    ▼                               ▼
Core Data Context              Core Data Context
    │                               │
    ▼                               ▼
Customer Entities              Sale Entities
(quickbooksCustomerId set)    (source = "quickbooks")
```

### **2. Inventory Management Flow**

```
User Opens Products View
        ↓
InventoryViewModel.fetchItems()
        ↓
Background Core Data Fetch
        ↓
Update @Published items array
        ↓
SwiftUI View Updates
        ↓
User Sees Product List
```

### **3. Async Loading Pattern**

```
User Triggers Action
        ↓
Set isLoading = true
        ↓
Task.detached (Background Thread)
        ↓
Perform Heavy Work
  - Core Data fetch
  - Network request
  - Image processing
        ↓
MainActor.run (Main Thread)
        ↓
Update @Published properties
        ↓
Set isLoading = false
        ↓
SwiftUI View Updates
```

---

## 🔐 **Security Architecture**

### **QuickBooks OAuth:**

```
App (Client IDs only)
        ↓
QuickBooks OAuth Page
        ↓
User Authorizes
        ↓
harbordesksystems.com (Redirect)
        ↓
wmssuite://oauth-callback
        ↓
QuickBooksTokenManager
        ↓
Azure Function (Client Secrets stored here)
        ↓
QuickBooks Token Exchange API
        ↓
Access + Refresh Tokens
        ↓
iOS Keychain (Encrypted Storage)
```

**Key Security Features:**
- ✅ Client secrets NEVER in app code
- ✅ Tokens stored in iOS Keychain (encrypted)
- ✅ Azure Function acts as secure proxy
- ✅ Tokens auto-refresh before expiry
- ✅ HTTPS for all communications

---

## 📁 **File Organization**

```
WMS Suite/
├── Models/
│   ├── InventoryItem+Extensions.swift
│   ├── Sale+Extensions.swift
│   ├── Customer+quickbooks.swift
│   ├── QuickBooksAutoSyncManager.swift
│   └── Core Data model definitions
│
├── Views/
│   ├── ProductsView.swift
│   ├── ProductDetailView.swift
│   ├── OrdersView.swift
│   ├── SettingsView.swift
│   ├── QuickBooksSettingsView.swift
│   ├── ShopifySettingsView.swift
│   └── LoadingView.swift (Reusable component)
│
├── ViewModels/
│   ├── InventoryViewModel.swift
│   └── (ViewModels for each main view)
│
├── Services/
│   ├── QuickBooksService.swift
│   ├── QuickBooksTokenManager.swift
│   ├── ShopifyService.swift
│   ├── BarcodeService.swift
│   └── NetworkService.swift
│
├── Repositories/
│   ├── InventoryRepository.swift
│   └── PersistenceController.swift
│
├── Helpers/
│   ├── KeychainHelper.swift
│   └── Utility functions
│
└── Documentation/ (.md files)
    ├── QUICKBOOKS_OAUTH_OVERVIEW.md
    ├── QUICKBOOKS_SETUP_CHECKLIST.md
    ├── QUICKBOOKS_TESTING_GUIDE.md
    ├── ASYNC_BEST_PRACTICES.md
    └── APP_ARCHITECTURE.md (this file)
```

---

## 🔑 **Key Components Explained**

### **1. QuickBooksTokenManager**
**Purpose:** Manages OAuth authentication with QuickBooks  
**Features:**
- OAuth 2.0 flow with ASWebAuthenticationSession
- Automatic token refresh (every 30 min check)
- Secure token storage in Keychain
- Sandbox/Production environment switching
- Background token refresh

**Usage:**
```swift
let tokenManager = QuickBooksTokenManager.shared
if tokenManager.isAuthenticated {
    // User is connected to QuickBooks
}
```

### **2. QuickBooksAutoSyncManager**
**Purpose:** Automatic background syncing with QuickBooks  
**Features:**
- Syncs customers and invoices automatically
- Triggers on app launch and foreground
- Periodic sync every 4 hours
- Detects stale data (> 24 hours)
- Observable sync status

**Usage:**
```swift
let autoSync = QuickBooksAutoSyncManager.shared
autoSync.start() // Enable auto-sync
await autoSync.forceSync() // Manual sync
```

### **3. QuickBooksService**
**Purpose:** API communication with QuickBooks  
**Features:**
- Customer sync with pagination
- Invoice sync with pagination
- Automatic token refresh on 401
- Error handling and retry logic
- Sandbox/Production endpoints

**Usage:**
```swift
let service = QuickBooksService(
    companyId: companyId,
    accessToken: token,
    refreshToken: refreshToken
)
try await service.syncCustomers(context: context) { message in
    print(message)
}
```

### **4. InventoryViewModel**
**Purpose:** Manages inventory data and business logic  
**Features:**
- Core Data fetching and updates
- Shopify integration
- QuickBooks integration
- Sales forecasting
- Barcode generation
- Observable state for SwiftUI

**Usage:**
```swift
@ObservedObject var viewModel: InventoryViewModel
viewModel.items // Access inventory items
viewModel.fetchItems() // Reload data
```

### **5. KeychainHelper**
**Purpose:** Secure credential storage  
**Features:**
- Generic save/get/delete methods
- QuickBooks-specific convenience methods
- Async wrappers for background ops
- Secure iOS Keychain API

**Usage:**
```swift
KeychainHelper.shared.saveQBAccessToken(token)
let token = KeychainHelper.shared.getQBAccessToken()
```

### **6. LoadingView**
**Purpose:** Reusable loading overlay  
**Features:**
- Customizable message
- Blur background
- Progress indicator
- SwiftUI modifier

**Usage:**
```swift
SomeView()
    .loading(isLoading, message: "Syncing data...")
```

---

## 🔄 **Async/Await Patterns**

### **Standard Pattern:**
```swift
func performOperation() {
    isLoading = true
    
    Task {
        // Async work
        let result = await heavyOperation()
        
        // Update UI on main thread
        await MainActor.run {
            self.data = result
            self.isLoading = false
        }
    }
}
```

### **Core Data Background Pattern:**
```swift
func fetchData() async {
    let objectID = item.objectID // Get on main thread
    
    let result = await Task.detached(priority: .userInitiated) {
        let context = PersistenceController.shared
            .container.newBackgroundContext()
        
        return await context.perform {
            guard let backgroundItem = try? context
                .existingObject(with: objectID) else {
                return []
            }
            
            // Fetch on background context
            return performFetch(backgroundItem)
        }
    }.value
    
    await MainActor.run {
        self.items = result
    }
}
```

---

## 📱 **App Lifecycle Integration**

### **QuickBooks Auto-Sync Lifecycle:**

```
App Launch
    ↓
QuickBooksAutoSyncManager.init()
    ↓
Load last sync date from UserDefaults
    ↓
Register NotificationCenter observers:
  - UIApplication.didBecomeActiveNotification
  - UIApplication.willResignActiveNotification
    ↓
Check if authenticated
    ↓
If authenticated && data stale:
    Trigger sync
    ↓
Schedule periodic timer (4 hours)

---

App Enters Background
    ↓
willResignActiveNotification fires
    ↓
Cancel periodic timer
    ↓
(Save battery, prevent background work)

---

App Returns to Foreground
    ↓
didBecomeActiveNotification fires
    ↓
Check if data is stale (> 24 hours)
    ↓
If stale: Trigger sync
    ↓
Reschedule periodic timer
```

---

## 🎯 **Data Source Identification**

### **How We Track Data Origins:**

```swift
// Customers
if customer.quickbooksCustomerId != nil {
    // From QuickBooks
} else {
    // Local customer
}

// Orders/Sales
switch sale.source {
case "quickbooks":
    // From QuickBooks
case "shopify":
    // From Shopify
case "manual":
    // Created in app
default:
    // Unknown source
}
```

### **Safe Data Operations:**

```swift
// Delete only QuickBooks customers
let fetch = NSFetchRequest<Customer>(entityName: "Customer")
fetch.predicate = NSPredicate(
    format: "quickbooksCustomerId != nil"
)
let qbCustomers = try context.fetch(fetch)
qbCustomers.forEach { context.delete($0) }
// Local customers are safe!

// Delete only QuickBooks orders
let fetch = NSFetchRequest<Sale>(entityName: "Sale")
fetch.predicate = NSPredicate(
    format: "source == %@", "quickbooks"
)
let qbOrders = try context.fetch(fetch)
qbOrders.forEach { context.delete($0) }
// Local and Shopify orders are safe!
```

---

## 🧪 **Testing Strategy**

### **Unit Tests:**
- Core Data model logic
- ViewModel business logic
- Service API parsing
- Data transformations

### **Integration Tests:**
- QuickBooks OAuth flow
- Auto-sync functionality
- Data sync accuracy
- Token refresh

### **UI Tests:**
- Navigation flows
- Loading states
- Error handling
- Data display

---

## 🚀 **Performance Optimizations**

### **1. Background Core Data Operations**
All heavy Core Data operations use background contexts to avoid blocking UI

### **2. Pagination**
QuickBooks sync fetches data in pages (100 items at a time) to avoid memory issues

### **3. Caching**
- Cached pricing data in ProductDetailView
- Last sync date cached in UserDefaults
- Tokens cached in Keychain

### **4. Lazy Loading**
Lists load only visible items, fetch more as user scrolls

### **5. Debouncing**
Search fields debounce input to reduce Core Data queries

---

## 🔧 **Configuration**

### **UserDefaults Keys:**

```swift
// Shopify
"shopifyStoreUrl"
"shopifyAccessToken"

// QuickBooks
"quickbooksUseSandbox"              // Bool: Sandbox vs Production
"quickbooksAutoSyncEnabled"         // Bool: Auto-sync toggle
"quickbooksAutoSyncConfigured"      // Bool: First launch flag
"quickbooksLastSyncDate"            // Date: Last sync timestamp
```

### **Keychain Keys:**

```swift
// QuickBooks OAuth
"com.wmssuite.quickbooks.accessToken"    // Access token (1 hour TTL)
"com.wmssuite.quickbooks.refreshToken"   // Refresh token (100 days TTL)
"com.wmssuite.quickbooks.realmId"        // Company ID
"com.wmssuite.quickbooks.tokenExpiry"    // Expiry timestamp
```

---

## 📝 **Coding Standards**

### **File Organization:**
- ✅ One class/struct/view per file
- ✅ Descriptive file names
- ✅ Group related files in folders
- ✅ MARK comments for organization

### **Naming Conventions:**
- Views: `SomethingView.swift`
- ViewModels: `SomethingViewModel.swift`
- Services: `SomethingService.swift`
- Extensions: `Entity+Extensions.swift`

### **Error Handling:**
- ✅ All async operations wrapped in do-catch
- ✅ No force unwraps (!)
- ✅ Safe optional unwrapping (guard let, if let)
- ✅ User-friendly error messages
- ✅ Logging for debugging

### **Async Patterns:**
- ✅ Use async/await, not completion handlers
- ✅ Background contexts for Core Data
- ✅ MainActor for UI updates
- ✅ Task.detached for heavy work
- ✅ Loading states for all operations

---

## 🎓 **For New Developers**

### **Getting Started:**

1. **Read Documentation:**
   - Start with `QUICKBOOKS_OAUTH_OVERVIEW.md`
   - Read `ASYNC_BEST_PRACTICES.md`
   - Review `QUICKBOOKS_SETUP_CHECKLIST.md`

2. **Understand Core Components:**
   - `QuickBooksTokenManager` - OAuth
   - `QuickBooksAutoSyncManager` - Background sync
   - `InventoryViewModel` - Main business logic
   - `KeychainHelper` - Secure storage

3. **Follow Patterns:**
   - Copy existing ViewModels for new features
   - Use LoadingView for async operations
   - Follow MVVM architecture
   - Write comprehensive comments

4. **Test Thoroughly:**
   - Test with Sandbox mode first
   - Verify local data is never affected
   - Check loading states work
   - Test error scenarios

---

## 🆘 **Troubleshooting**

### **Common Issues:**

**QuickBooks OAuth not working:**
- Check URL scheme registered in Info.plist (`wmssuite://`)
- Verify website redirect is live
- Check Azure Function is running
- Verify Client IDs match QuickBooks app

**Core Data crashes:**
- Never pass managed objects between contexts
- Use `objectID` for cross-context references
- Always use background context for heavy ops
- Wrap all Core Data in do-catch

**UI blocking:**
- Check if operation is async
- Add loading indicators
- Move heavy work to background
- Use Task.detached for CPU-intensive work

---

## 📚 **Additional Resources**

- **Apple Documentation:**
  - Core Data Programming Guide
  - Concurrency (async/await)
  - Keychain Services
  - ASWebAuthenticationSession

- **QuickBooks Documentation:**
  - OAuth 2.0 Guide
  - API Reference
  - Sandbox Testing

- **Internal Documentation:**
  - All `.md` files in project
  - Code comments throughout
  - This architecture guide

---

## ✅ **Summary**

**WMS Suite** is a professional-grade warehouse management system using:
- **Architecture:** MVVM with SwiftUI
- **Data:** Core Data with background contexts
- **Async:** async/await throughout
- **Security:** Keychain + Azure for sensitive data
- **Integrations:** QuickBooks + Shopify
- **UX:** Loading states, error handling, smooth animations

**Well-documented, well-architected, production-ready!** 🚀

---

**Last Updated:** January 1, 2026  
**Version:** 1.0  
**Maintained By:** WMS Suite Development Team
