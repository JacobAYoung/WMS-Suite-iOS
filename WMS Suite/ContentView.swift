import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: InventoryViewModel
    @State private var selectedTab = 0
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        let repo = InventoryRepository(context: context)
        let shopifyService = ShopifyService(storeUrl: "", accessToken: "")
        let quickbooksService = QuickBooksService(companyId: "", accessToken: "")
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
            InventoryView(viewModel: viewModel)
                .tabItem {
                    Label("Inventory", systemImage: "list.bullet.rectangle")
                }
                .tag(0)
            
            BarcodeView(viewModel: viewModel)
                .tabItem {
                    Label("Barcodes", systemImage: "barcode")
                }
                .tag(1)
            
            CountingView(viewModel: viewModel)
                .tabItem {
                    Label("AI Count", systemImage: "camera")
                }
                .tag(2)
            
            SettingsNavigationView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
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
