import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: InventoryViewModel
    @State private var selectedTab = 0
    
    init() {
        let companyId = UserDefaults.standard.string(forKey: "quickbooksCompanyId") ?? ""
        let accessToken = UserDefaults.standard.string(forKey: "quickbooksAccessToken") ?? ""
        let context = PersistenceController.shared.container.viewContext
        let repo = InventoryRepository(context: context)
        let shopifyService = ShopifyService(
            storeUrl: UserDefaults.standard.string(forKey: "shopifyStoreUrl") ?? "",
            accessToken: UserDefaults.standard.string(forKey: "shopifyAccessToken") ?? ""
        )
        let quickbooksService = QuickBooksService(
            companyId: companyId,
            accessToken: accessToken,
            refreshToken: UserDefaults.standard.string(forKey: "quickbooksRefreshToken") ?? ""
        )
        let barcodeService = BarcodeService()
        _viewModel = StateObject(wrappedValue: InventoryViewModel(
            repository: repo,
            shopifyService: shopifyService,
            quickbooksService: quickbooksService,
            barcodeService: barcodeService
        ))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Products Tab (renamed from Inventory)
            InventoryView(viewModel: viewModel)
                .tabItem {
                    Label("Products", systemImage: "shippingbox.fill")
                }
                .tag(0)
            
            // Orders Tab (NEW)
            OrdersView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Orders", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
            
            // Barcodes Tab
            BarcodeView(viewModel: viewModel)
                .tabItem {
                    Label("Barcodes", systemImage: "barcode")
                }
                .tag(2)
            
            // AI Count Tab
            CountingView(viewModel: viewModel)
                .tabItem {
                    Label("AI Count", systemImage: "camera")
                }
                .tag(3)
            
            // Settings Tab
            SettingsNavigationView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(4)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
