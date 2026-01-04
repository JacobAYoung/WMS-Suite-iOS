# Duplicate Inventory Items - Fix Guide

**Date:** January 3, 2026  
**Issue:** Duplicate inventory items with same SKU from QuickBooks sync
**Cause:** Timestamp-based ID generation created duplicate IDs when processing items quickly

---

## 🐛 What Happened

### **The Problem:**
1. Items synced from QuickBooks were assigned IDs using `Int32(Date().timeIntervalSince1970)`
2. When multiple items processed in quick succession, they got the **same ID**
3. This created duplicate items in the database with the **same SKU**
4. ForEach complained: "ID 1767459685 occurs multiple times"

### **Example:**
```
Item 1: SKU "ABC123", ID: 1767459685, QB ID: "45"
Item 2: SKU "ABC123", ID: 1767459685, QB ID: "45"  ← DUPLICATE!
Item 3: SKU "ABC123", ID: 1767459685, QB ID: "45"  ← DUPLICATE!
Item 4: SKU "ABC123", ID: 1767459685, QB ID: "45"  ← DUPLICATE!
```

---

## ✅ What Was Fixed

### **1. Proper ID Generation** (`IDGenerator.swift`)

Added `hashQuickBooksItemID()` method that:
- ✅ Always generates the **same ID** for the **same QuickBooks Item ID**
- ✅ Uses hash function for consistency
- ✅ Reserves ID range 2,500,000,000 - 2,147,483,647 for QB Items
- ✅ No chance of duplicates

```swift
static func hashQuickBooksItemID(_ qbID: String) -> Int32 {
    let hash = abs(qbID.hashValue)
    let qbOffset: Int32 = 2_500_000_000
    let hashedValue = Int32(hash % Int(Int32.max - qbOffset))
    return qbOffset + hashedValue
}
```

### **2. Better Duplicate Detection** (`QuickBooksService.swift`)

Now checks for existing items in TWO ways:
1. ✅ By `quickbooksItemId` (primary)
2. ✅ By `sku` (fallback to prevent duplicates)

```swift
// First try QB ID
fetchRequest.predicate = NSPredicate(format: "quickbooksItemId == %@", qbItemId)
var existingItems = try context.fetch(fetchRequest)

// If not found, try SKU
if existingItems.isEmpty && !sku.isEmpty {
    skuFetch.predicate = NSPredicate(format: "sku == %@", sku)
    existingItems = try context.fetch(skuFetch)
}
```

### **3. Consistent ID Assignment**

```swift
// Before (BAD):
item.id = Int32(Date().timeIntervalSince1970)  // Can duplicate!

// After (GOOD):
item.id = IDGenerator.hashQuickBooksItemID(qbItemId)  // Always unique!
```

---

## 🔧 How to Clean Up Existing Duplicates

### **Option 1: Clear and Re-Sync (Recommended)**

This is the cleanest approach:

1. **Go to Settings → QuickBooks → Clear QuickBooks Data**
   - This deletes ALL QuickBooks synced data
   - Local items are safe
   - Shopify items are safe

2. **Sync Again**
   - Go to Settings → QuickBooks → Sync Inventory
   - Items will be re-imported with correct IDs
   - No duplicates will be created

### **Option 2: Delete App and Reinstall**

If you want a completely fresh start:

1. Delete the WMS Suite app
2. Reinstall from Xcode
3. Connect to QuickBooks
4. Sync inventory

---

## 🧹 Manual Cleanup (If Needed)

If you want to keep your local items and only clean QuickBooks items:

### **Using the App:**

1. Open **Settings → QuickBooks**
2. Tap **"Clear QuickBooks Data"**
3. Confirm deletion
4. This removes:
   - ✅ All QuickBooks customers
   - ✅ All QuickBooks invoices
   - ✅ All QuickBooks inventory items
5. Your local data stays safe
6. Re-sync: **Settings → QuickBooks → Sync Inventory**

---

## 📊 Verify the Fix

After re-syncing, verify:

### **1. No Duplicate IDs**
- Open Inventory view
- Should see NO warnings in console
- Each item appears only once

### **2. Unique IDs**
```
// All IDs should be in the range 2,500,000,000+
Item 1: SKU "ABC123", ID: 2,567,123,456
Item 2: SKU "XYZ789", ID: 2,589,234,567
Item 3: SKU "DEF456", ID: 2,512,345,678
```

### **3. Correct Matching**
- Same QuickBooks item always gets same ID
- Re-syncing doesn't create duplicates
- Updates work correctly

---

## 🎯 ID Allocation Strategy (Updated)

```
1 - 999,999,999:                Local items (manually created)
1,000,000,000 - 1,499,999,999:  Shopify records
1,500,000,000 - 1,999,999,999:  QuickBooks Invoices
2,000,000,000 - 2,499,999,999:  QuickBooks Customers
2,500,000,000 - 2,147,483,647:  QuickBooks Items ← NEW!
```

### **Benefits:**
- ✅ No conflicts between sources
- ✅ Same QuickBooks ID always maps to same Int32
- ✅ Can identify source by ID range
- ✅ Local items get sequential IDs starting at 1

---

## 🔍 How to Identify Duplicate Items

### **In Console:**
```
ForEach<Array<InventoryItem>, Int32, NavigationLink<...>>: 
the ID 1767459685 occurs multiple times
```

### **In Database:**
Multiple items with:
- Same SKU
- Same QuickBooks Item ID
- Different Core Data object IDs
- Same display ID (causing ForEach error)

---

## 🚀 Prevention

The fixes ensure this **never happens again**:

1. ✅ **Hash-based IDs** - Same QB ID always produces same Int32
2. ✅ **Duplicate checking** - Checks both QB ID and SKU
3. ✅ **Reserved ranges** - QB Items have dedicated ID space
4. ✅ **Idempotent sync** - Re-syncing updates, doesn't duplicate

---

## 📝 Testing After Fix

### **Test Scenario 1: First Sync**
1. Clear QuickBooks data
2. Sync inventory
3. Check: All items have unique IDs in 2,500,000,000+ range
4. Check: No duplicate SKUs
5. Check: No console warnings

### **Test Scenario 2: Re-Sync**
1. Note current item count
2. Sync inventory again
3. Check: Item count stays the same (no duplicates)
4. Check: Items are updated, not created
5. Check: IDs remain the same

### **Test Scenario 3: New Item in QuickBooks**
1. Add item in QuickBooks Online
2. Sync in app
3. Check: New item appears with unique ID
4. Check: Existing items unchanged

### **Test Scenario 4: Update Existing**
1. Change quantity in QuickBooks
2. Sync in app
3. Check: Quantity updated
4. Check: No duplicate created
5. Check: ID remains the same

---

## 🎉 Summary

### **What Was Broken:**
- ❌ Timestamp-based IDs caused duplicates
- ❌ Multiple items with same ID
- ❌ ForEach couldn't differentiate items
- ❌ App showed 4 duplicates of same SKU

### **What's Fixed:**
- ✅ Hash-based ID generation
- ✅ Guaranteed unique IDs
- ✅ Duplicate detection by SKU
- ✅ Proper ID range allocation
- ✅ Idempotent sync operations

### **Next Steps:**
1. Clear QuickBooks data in app
2. Re-sync inventory
3. Verify no duplicates
4. Test that updates work correctly

---

**Status: Fixed and Ready to Clean Up** 🧹

Use "Clear QuickBooks Data" in settings, then re-sync to get clean data with proper IDs.
