# QuickBooks Inventory Integration - Core Data Updates Required

**Date:** January 3, 2026  
**Purpose:** Document required Core Data model changes for QuickBooks inventory integration

---

## 📊 **Required Core Data Attributes for InventoryItem**

### **Add These Attributes to InventoryItem Entity:**

```
// QuickBooks Pricing (Decimal, Optional)
quickbooksCost              // Purchase cost from QB
quickbooksSellingPrice       // Selling price from QB

// QuickBooks Account References (String, Optional)
quickbooksIncomeAccountId    // Income account for sales
quickbooksExpenseAccountId   // COGS account  
quickbooksAssetAccountId     // Asset account for inventory

// Shopify Pricing (for comparison)
shopifyCost                  // Purchase cost from Shopify
shopifyPrice                 // Selling price from Shopify

// Local/Override Pricing
cost                         // Local cost (if different)
sellingPrice                 // Local selling price (if different)
```

---

## 🔧 **How to Add in Xcode:**

1. Open `WMS_Suite.xcdatamodeld` in Xcode
2. Select `InventoryItem` entity
3. Click `+` under Attributes section
4. Add each attribute with correct type:

### **QuickBooks Fields:**
- Name: `quickbooksCost`, Type: `Decimal`, Optional: ✓
- Name: `quickbooksSellingPrice`, Type: `Decimal`, Optional: ✓
- Name: `quickbooksIncomeAccountId`, Type: `String`, Optional: ✓
- Name: `quickbooksExpenseAccountId`, Type: `String`, Optional: ✓
- Name: `quickbooksAssetAccountId`, Type: `String`, Optional: ✓

### **Shopify Fields:**
- Name: `shopifyCost`, Type: `Decimal`, Optional: ✓
- Name: `shopifyPrice`, Type: `Decimal`, Optional: ✓

### **Local Fields:**
- Name: `cost`, Type: `Decimal`, Optional: ✓
- Name: `sellingPrice`, Type: `Decimal`, Optional: ✓

---

## ✅ **Verification:**

After adding fields:

1. **Clean Build Folder**: Cmd+Shift+K
2. **Rebuild**: Cmd+B
3. Core Data will automatically generate properties

---

## 📝 **What Each Field Does:**

### **QuickBooks Fields:**
- **quickbooksCost**: What you paid for the item (from QB)
- **quickbooksSellingPrice**: What you sell it for (from QB)
- **Account IDs**: Link to QB chart of accounts for proper accounting

### **Shopify Fields:**
- **shopifyCost**: Cost in Shopify (if different from QB)
- **shopifyPrice**: Selling price in Shopify

### **Local Fields:**
- **cost**: Your warehouse cost (may override QB/Shopify)
- **sellingPrice**: Your warehouse price (may override)

---

## 🎯 **Priority:**

**Implement these in order:**

1. ✅ QuickBooks pricing fields (quickbooksCost, quickbooksSellingPrice)
2. ✅ QuickBooks account IDs (for push updates)
3. ✅ Shopify pricing fields (for comparison)
4. ✅ Local override fields (cost, sellingPrice)

---

## 📱 **UI Impact:**

Once fields are added, ProductDetailView will show:

```
Pricing Information
├── QuickBooks
│   ├── Cost: $10.50
│   └── Selling Price: $19.99
├── Shopify  
│   ├── Cost: $10.50
│   └── Price: $19.99
└── Local (Override)
    ├── Cost: Custom if set
    └── Price: Custom if set
```

---

## ⚠️ **Important Notes:**

1. **All fields are Optional** - Item can exist without QB or Shopify data
2. **Decimal type** - For precise currency calculations
3. **No migrations needed** - Core Data handles adding optional fields automatically
4. **Existing data safe** - New fields will be nil for existing items

---

## 🚀 **After Adding Fields:**

The following will work automatically:
- ✅ QuickBooks inventory sync
- ✅ Push updates to QuickBooks
- ✅ Multi-source pricing display
- ✅ Source comparison in UI

---

## 🔄 **Current Implementation Status (January 3, 2026)**
### ✅ **Already Implemented (Using Extensions + UserDefaults):**

The code currently works WITHOUT Core Data changes by using computed properties in `InventoryItem+Extensions.swift`:

```swift
// These are COMPUTED PROPERTIES that store in UserDefaults
var quickbooksCost: Decimal { get/set }          // ✅ Working
var quickbooksPrice: Decimal? { get/set }        // ✅ Working
var shopifyPrice: Decimal? { get/set }           // ✅ Working
var cost: Decimal { get/set }                    // ✅ Working
var sellingPrice: Decimal? { get/set }           // ✅ Working
```

### ⚠️ **Partially Implemented (Needs Core Data Properties):**

The following are being SET directly on the InventoryItem in `QuickBooksService.swift`, which means they **should** be Core Data properties but might cause runtime errors:

```swift
// Line 794-797 in QuickBooksService.swift
item.quickbooksIncomeAccountId = incomeAcct     // ⚠️ May crash if not in Core Data
item.quickbooksExpenseAccountId = expenseAcct   // ⚠️ May crash if not in Core Data
item.quickbooksAssetAccountId = assetAcct       // ⚠️ May crash if not in Core Data
```

---

## 🎯 **Recommended Action:**

### **Option A: Quick Fix (No Core Data Changes)**
Comment out or remove the account ID storage code until Core Data is updated:

**In `QuickBooksService.swift` line ~792-800:**
```swift
// TODO: Add these to Core Data model first
// Store account references for future updates
// if let incomeAcct = incomeAccountRef?["value"] as? String {
//     item.quickbooksIncomeAccountId = incomeAcct
// }
// if let expenseAcct = expenseAccountRef?["value"] as? String {
//     item.quickbooksExpenseAccountId = expenseAcct
// }
// if let assetAcct = assetAccountRef?["value"] as? String {
//     item.quickbooksAssetAccountId = assetAcct
// }
```

**In `QuickBooksService.swift` line ~878-884:**
```swift
// Use service-level account IDs instead of item-level
if let incomeAccountId = incomeAccountId {  // Changed from item.quickbooksIncomeAccountId
    itemJson["IncomeAccountRef"] = ["value": incomeAccountId]
}
```

### **Option B: Proper Fix (Add to Core Data)**
1. Add the 3 account ID properties to Core Data (String, Optional)
2. Clean and rebuild
3. Code will work automatically

---

## 📊 **What's Safe to Use Right Now:**

✅ **These work perfectly** (via extensions):
- `item.cost` - Local/manual cost
- `item.quickbooksCost` - QB cost
- `item.sellingPrice` - Selling price (auto-prioritizes)
- `item.quickbooksPrice` - QB specific price
- `item.shopifyPrice` - Shopify specific price
- `item.priceSource` - Shows which source is used

⚠️ **These may crash** (not in Core Data yet):
- `item.quickbooksIncomeAccountId` - Income account
- `item.quickbooksExpenseAccountId` - COGS account
- `item.quickbooksAssetAccountId` - Asset account

---

## 🚨 **Test This Immediately:**

1. Run the app
2. Try to sync QuickBooks inventory
3. If it crashes on line ~794 with "unrecognized selector" → Option A needed
4. If it works → Core Data properties already exist!

---

**Status:** 
- ✅ Pricing integration working (via extensions)
- ⚠️ Account IDs need Core Data update OR code fix

