import SwiftUI

/// Orders View for VENDOR role
/// ✅ Automatically filters orders by current PG context
/// ✅ Reloads data when PG is switched
struct OrdersView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = OrdersViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading orders...")
                } else if viewModel.orders.isEmpty {
                    emptyStateView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Orders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.loadOrders(pgId: authManager.currentPgId) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                viewModel.loadOrders(pgId: authManager.currentPgId)
            }
            .onChange(of: authManager.currentPgId) { newPgId in
                // ✅ Reload orders when PG is switched
                viewModel.loadOrders(pgId: newPgId)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Orders List
    
    private var ordersList: some View {
        List {
            // Filter chips
            filterSection
            
            // Orders grouped by status
            ForEach(OrderStatus.allCases, id: \.self) { status in
                let filteredOrders = viewModel.orders.filter { $0.status == status }
                
                if !filteredOrders.isEmpty {
                    Section(header: sectionHeader(for: status)) {
                        ForEach(filteredOrders) { order in
                            OrderRow(order: order)
                                .onTapGesture {
                                    viewModel.selectedOrder = order
                                }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            viewModel.loadOrders(pgId: authManager.currentPgId)
        }
        .sheet(item: $viewModel.selectedOrder) { order in
            OrderDetailView(order: order)
        }
    }
    
    // MARK: - Filter Section
    
    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilterChipOrder(
                        title: "All",
                        isSelected: viewModel.selectedStatus == nil,
                        action: { viewModel.selectedStatus = nil }
                    )
                    
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        FilterChipOrder(
                            title: status.displayName,
                            isSelected: viewModel.selectedStatus == status,
                            action: { viewModel.selectedStatus = status }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Orders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("You don't have any orders for \(authManager.currentPgName)")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Refresh") {
                viewModel.loadOrders(pgId: authManager.currentPgId)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(for status: OrderStatus) -> some View {
        let count = viewModel.orders.filter { $0.status == status }.count
        
        return HStack {
            Text(status.displayName)
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

// MARK: - Order Row

struct OrderRow: View {
    let order: Order
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.orderNumber)")
                    .font(.headline)
                
                Spacer()
                
                statusBadge
            }
            
            Text(order.items.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Label(order.pgName, systemImage: "building.2")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(order.totalAmount, format: .currency(code: "INR"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label(order.deliveryDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(order.contactPerson, systemImage: "person")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusBadge: some View {
        Text(order.status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(order.status.color)
            .cornerRadius(8)
    }
}

// MARK: - Filter Chip

struct FilterChipOrder: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .cornerRadius(20)
        }
    }
}

// MARK: - Order Detail View

struct OrderDetailView: View {
    let order: Order
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Order Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Order #\(order.orderNumber)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text(order.status.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(order.status.color)
                                .cornerRadius(8)
                            
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // PG Details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery To")
                            .font(.headline)
                        
                        Label(order.pgName, systemImage: "building.2")
                        Label(order.address, systemImage: "mappin.and.ellipse")
                        Label(order.contactPerson, systemImage: "person")
                        Label(order.contactPhone, systemImage: "phone")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Items
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Items")
                            .font(.headline)
                        
                        ForEach(order.items, id: \.self) { item in
                            HStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(.blue)
                                Text(item)
                                Spacer()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Delivery Date
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Delivery Details")
                            .font(.headline)
                        
                        HStack {
                            Label("Delivery Date", systemImage: "calendar")
                            Spacer()
                            Text(order.deliveryDate.formatted(date: .long, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label("Total Amount", systemImage: "indianrupeesign.circle")
                            Spacer()
                            Text(order.totalAmount, format: .currency(code: "INR"))
                                .fontWeight(.semibold)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Actions
                    if order.status == .pending {
                        VStack(spacing: 12) {
                            Button(action: {}) {
                                Label("Mark as In Transit", systemImage: "shippingbox")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {}) {
                                Label("Cancel Order", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .foregroundColor(.red)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Order Details")
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

// MARK: - View Model

@MainActor
class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var showError = false
    @Published var selectedStatus: OrderStatus?
    @Published var selectedOrder: Order?
    
    private let apiManager = APIManager.shared
    
    func loadOrders(pgId: String?) {
        guard let pgId = pgId else {
            self.errorMessage = "No PG selected"
            self.showError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                // TODO: Replace with actual API call
                // let response = try await apiManager.getOrders(pgId: pgId)
                // self.orders = response.data
                
                // Mock data for now
                try await Task.sleep(nanoseconds: 1_000_000_000)
                self.orders = Order.mockOrders(for: pgId)
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

struct Order: Identifiable {
    let id: String
    let orderNumber: String
    let pgId: String
    let pgName: String
    let address: String
    let items: [String]
    let totalAmount: Double
    let status: OrderStatus
    let deliveryDate: Date
    let contactPerson: String
    let contactPhone: String
    
    static func mockOrders(for pgId: String) -> [Order] {
        [
            Order(
                id: "order_1",
                orderNumber: "ORD-2025-001",
                pgId: pgId,
                pgName: "Sunrise PG",
                address: "123 Main Street, Bangalore",
                items: ["10kg Rice", "5L Milk", "2kg Sugar"],
                totalAmount: 850.0,
                status: .pending,
                deliveryDate: Date().addingTimeInterval(86400),
                contactPerson: "Rajesh Kumar",
                contactPhone: "+91 98765 43210"
            ),
            Order(
                id: "order_2",
                orderNumber: "ORD-2025-002",
                pgId: pgId,
                pgName: "Sunrise PG",
                address: "123 Main Street, Bangalore",
                items: ["5kg Wheat Flour", "1kg Dal", "500g Tea"],
                totalAmount: 450.0,
                status: .inTransit,
                deliveryDate: Date(),
                contactPerson: "Rajesh Kumar",
                contactPhone: "+91 98765 43210"
            ),
            Order(
                id: "order_3",
                orderNumber: "ORD-2025-003",
                pgId: pgId,
                pgName: "Sunrise PG",
                address: "123 Main Street, Bangalore",
                items: ["2kg Potatoes", "1kg Onions", "500g Tomatoes"],
                totalAmount: 120.0,
                status: .delivered,
                deliveryDate: Date().addingTimeInterval(-86400),
                contactPerson: "Rajesh Kumar",
                contactPhone: "+91 98765 43210"
            ),
        ]
    }
}

enum OrderStatus: String, CaseIterable {
    case pending = "PENDING"
    case inTransit = "IN_TRANSIT"
    case delivered = "DELIVERED"
    case cancelled = "CANCELLED"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inTransit: return "In Transit"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .inTransit: return .blue
        case .delivered: return .green
        case .cancelled: return .red
        }
    }
}

// MARK: - Preview

struct OrdersView_Previews: PreviewProvider {
    static var previews: some View {
        OrdersView()
            .environmentObject(AuthManager())
    }
}

