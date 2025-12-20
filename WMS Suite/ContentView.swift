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
            // Products Tab
            InventoryView(viewModel: viewModel)
                .tabItem {
                    Label("Products", systemImage: "shippingbox.fill")
                }
                .tag(0)
            
            // Orders Tab
            OrdersView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Orders", systemImage: "list.bullet.rectangle")
                }
                .tag(1)
            
            // Customers Tab (NEW!)
            CustomersView()
                .environment(\.managedObjectContext, viewContext)
                .tabItem {
                    Label("Customers", systemImage: "person.2.fill")
                }
                .tag(2)
            
            // Tools Tab (NEW! - Consolidated utilities)
            ToolsView(viewModel: viewModel)
                .tabItem {
                    Label("Tools", systemImage: "wrench.and.screwdriver.fill")
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
