import SwiftUI

/// Inventory View for VENDOR role
/// ✅ Automatically filters inventory by current PG context
/// ✅ Reloads data when PG is switched
struct InventoryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = InventoryViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading inventory...")
                } else if viewModel.items.isEmpty {
                    emptyStateView
                } else {
                    inventoryList
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Category", selection: $viewModel.selectedCategory) {
                            Text("All Categories").tag(nil as InventoryCategory?)
                            ForEach(InventoryCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category as InventoryCategory?)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadInventory(pgId: authManager.currentPgId) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search items...")
            .onAppear {
                viewModel.loadInventory(pgId: authManager.currentPgId)
            }
            .onChange(of: authManager.currentPgId) { newPgId in
                // ✅ Reload inventory when PG is switched
                viewModel.loadInventory(pgId: newPgId)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Inventory List
    
    private var inventoryList: some View {
        List {
            // Summary cards
            summarySection
            
            // Low stock alert
            if !viewModel.lowStockItems.isEmpty {
                lowStockSection
            }
            
            // Inventory items by category
            ForEach(InventoryCategory.allCases, id: \.self) { category in
                let items = viewModel.filteredItems.filter { $0.category == category }
                
                if !items.isEmpty {
                    Section(header: categoryHeader(for: category)) {
                        ForEach(items) { item in
                            InventoryItemRow(item: item)
                                .onTapGesture {
                                    viewModel.selectedItem = item
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadInventory(pgId: authManager.currentPgId)
        }
        .sheet(item: $viewModel.selectedItem) { item in
            InventoryDetailView(item: item)
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    SummaryCard(
                        title: "Total Items",
                        value: String(viewModel.items.count),
                        icon: "cube.box",
                        color: .blue
                    )
                    
                    SummaryCard(
                        title: "Low Stock",
                        value: String(viewModel.lowStockItems.count),
                        icon: "exclamationmark.triangle",
                        color: .orange
                    )
                    
                    SummaryCard(
                        title: "Total Value",
                        value: "₹\(Int(viewModel.totalValue))",
                        icon: "indianrupeesign.circle",
                        color: .green
                    )
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Low Stock Section
    
    private var lowStockSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Low Stock Alert")
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                
                Text("\(String(viewModel.lowStockItems.count)) items need restocking")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.lowStockItems) { item in
                            LowStockChip(item: item)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.box")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Inventory")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No inventory items found for \(authManager.currentPgName)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                viewModel.loadInventory(pgId: authManager.currentPgId)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Category Header
    
    private func categoryHeader(for category: InventoryCategory) -> some View {
        let count = viewModel.filteredItems.filter { $0.category == category }.count
        
        return HStack {
            Label(category.displayName, systemImage: category.icon)
                .font(.headline)
            
            Spacer()
            
            Text(String(count))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
        }
    }
}

// MARK: - Inventory Item Row

struct InventoryItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item icon
            ZStack {
                Circle()
                    .fill(item.category.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: item.category.icon)
                    .foregroundColor(item.category.color)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Label("\(item.quantity) \(item.unit)", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label("₹\(Int(item.pricePerUnit))/\(item.unit)", systemImage: "indianrupeesign.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                stockBadge
                
                Text("₹\(Int(item.totalValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var stockBadge: some View {
        Group {
            if item.stockStatus == .low {
                Text("Low")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange)
                    .cornerRadius(6)
            } else if item.stockStatus == .out {
                Text("Out")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(width: 140)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Low Stock Chip

struct LowStockChip: View {
    let item: InventoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text("\(item.quantity) \(item.unit) left")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange, lineWidth: 1)
        )
    }
}

// MARK: - Inventory Detail View

struct InventoryDetailView: View {
    let item: InventoryItem
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Item Header
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(item.category.color.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: item.category.icon)
                                    .foregroundColor(item.category.color)
                                    .font(.system(size: 30))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(item.category.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Stock Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stock Information")
                            .font(.headline)
                        
                        InfoRow(label: "Current Stock", value: "\(item.quantity) \(item.unit)")
                        InfoRow(label: "Minimum Stock", value: "\(item.minimumQuantity) \(item.unit)")
                        InfoRow(label: "Status", value: item.stockStatus.displayName, valueColor: item.stockStatus.color)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Pricing
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pricing")
                            .font(.headline)
                        
                        InfoRow(label: "Price per \(item.unit)", value: "₹\(Int(item.pricePerUnit))")
                        InfoRow(label: "Total Value", value: "₹\(Int(item.totalValue))", valueColor: .green)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Supplier Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supplier")
                            .font(.headline)
                        
                        InfoRow(label: "Name", value: item.supplierName)
                        InfoRow(label: "Last Updated", value: item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Actions
                    if item.stockStatus == .low || item.stockStatus == .out {
                        Button(action: {}) {
                            Label("Restock Item", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - View Model

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var selectedCategory: InventoryCategory?
    @Published var selectedItem: InventoryItem?
    @Published var searchText = ""
    
    private let apiManager = APIManager.shared
    
    var filteredItems: [InventoryItem] {
        var filtered = items
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filtered
    }
    
    var lowStockItems: [InventoryItem] {
        items.filter { $0.stockStatus == .low || $0.stockStatus == .out }
    }
    
    var totalValue: Double {
        items.reduce(0) { $0 + $1.totalValue }
    }
    
    func loadInventory(pgId: String?) {
        guard let pgId = pgId else {
            self.errorMessage = "No PG selected"
            self.showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // TODO: Replace with actual API call
                // let response = try await apiManager.getInventory(pgId: pgId)
                // self.items = response.data
                
                // Mock data for now
                try await Task.sleep(nanoseconds: 1_000_000_000)
                self.items = InventoryItem.mockItems(for: pgId)
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
}

// MARK: - Models

struct InventoryItem: Identifiable {
    let id: String
    let pgId: String
    let name: String
    let category: InventoryCategory
    let quantity: Int
    let minimumQuantity: Int
    let unit: String
    let pricePerUnit: Double
    let supplierName: String
    let lastUpdated: Date
    
    var totalValue: Double {
        Double(quantity) * pricePerUnit
    }
    
    var stockStatus: StockStatus {
        if quantity == 0 {
            return .out
        } else if quantity <= minimumQuantity {
            return .low
        } else {
            return .good
        }
    }
    
    static func mockItems(for pgId: String) -> [InventoryItem] {
        [
            InventoryItem(
                id: "item_1",
                pgId: pgId,
                name: "Rice",
                category: .grains,
                quantity: 25,
                minimumQuantity: 20,
                unit: "kg",
                pricePerUnit: 45.0,
                supplierName: "Amit Supplies",
                lastUpdated: Date()
            ),
            InventoryItem(
                id: "item_2",
                pgId: pgId,
                name: "Milk",
                category: .dairy,
                quantity: 10,
                minimumQuantity: 15,
                unit: "L",
                pricePerUnit: 55.0,
                supplierName: "Amit Supplies",
                lastUpdated: Date()
            ),
            InventoryItem(
                id: "item_3",
                pgId: pgId,
                name: "Potatoes",
                category: .vegetables,
                quantity: 0,
                minimumQuantity: 10,
                unit: "kg",
                pricePerUnit: 30.0,
                supplierName: "Amit Supplies",
                lastUpdated: Date().addingTimeInterval(-86400)
            ),
            InventoryItem(
                id: "item_4",
                pgId: pgId,
                name: "Dal",
                category: .pulses,
                quantity: 15,
                minimumQuantity: 10,
                unit: "kg",
                pricePerUnit: 120.0,
                supplierName: "Amit Supplies",
                lastUpdated: Date()
            ),
            InventoryItem(
                id: "item_5",
                pgId: pgId,
                name: "Tea",
                category: .beverages,
                quantity: 5,
                minimumQuantity: 3,
                unit: "kg",
                pricePerUnit: 250.0,
                supplierName: "Amit Supplies",
                lastUpdated: Date()
            ),
        ]
    }
}

enum InventoryCategory: String, CaseIterable {
    case grains = "GRAINS"
    case dairy = "DAIRY"
    case vegetables = "VEGETABLES"
    case fruits = "FRUITS"
    case pulses = "PULSES"
    case spices = "SPICES"
    case beverages = "BEVERAGES"
    case other = "OTHER"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .grains: return "leaf.fill"
        case .dairy: return "drop.fill"
        case .vegetables: return "carrot.fill"
        case .fruits: return "apple.logo"
        case .pulses: return "circle.grid.2x2.fill"
        case .spices: return "sparkles"
        case .beverages: return "cup.and.saucer.fill"
        case .other: return "cube.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .grains: return .brown
        case .dairy: return .blue
        case .vegetables: return .green
        case .fruits: return .orange
        case .pulses: return .yellow
        case .spices: return .red
        case .beverages: return .purple
        case .other: return .gray
        }
    }
}

enum StockStatus {
    case good
    case low
    case out
    
    var displayName: String {
        switch self {
        case .good: return "Good Stock"
        case .low: return "Low Stock"
        case .out: return "Out of Stock"
        }
    }
    
    var color: Color {
        switch self {
        case .good: return .green
        case .low: return .orange
        case .out: return .red
        }
    }
}

// MARK: - Preview

struct InventoryView_Previews: PreviewProvider {
    static var previews: some View {
        InventoryView()
            .environmentObject(AuthManager())
    }
}

