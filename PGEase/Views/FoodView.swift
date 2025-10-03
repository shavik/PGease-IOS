import SwiftUI

struct FoodView: View {
    @State private var selectedCategory = "Breakfast"
    @State private var searchText = ""
    
    let categories = ["Breakfast", "Lunch", "Dinner", "Snacks", "Beverages"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(categories, id: \.self) { category in
                            CategoryButton(
                                title: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                
                // Food Items List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(getFoodItems(), id: \.id) { item in
                            FoodItemCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Food Menu")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func getFoodItems() -> [FoodItem] {
        let allItems = [
            FoodItem(name: "Continental Breakfast", price: 8.99, category: "Breakfast", image: "sunrise"),
            FoodItem(name: "Pancakes", price: 6.99, category: "Breakfast", image: "pancake"),
            FoodItem(name: "Caesar Salad", price: 12.99, category: "Lunch", image: "leaf"),
            FoodItem(name: "Grilled Chicken", price: 15.99, category: "Lunch", image: "bird"),
            FoodItem(name: "Pasta Carbonara", price: 14.99, category: "Dinner", image: "fork"),
            FoodItem(name: "Fish & Chips", price: 16.99, category: "Dinner", image: "fish"),
            FoodItem(name: "Fresh Fruit", price: 4.99, category: "Snacks", image: "apple"),
            FoodItem(name: "Coffee", price: 3.99, category: "Beverages", image: "cup.and.saucer"),
            FoodItem(name: "Fresh Juice", price: 5.99, category: "Beverages", image: "drop")
        ]
        
        var filteredItems = allItems.filter { $0.category == selectedCategory }
        
        if !searchText.isEmpty {
            filteredItems = filteredItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return filteredItems
    }
}

struct FoodItem: Identifiable {
    let id = UUID()
    let name: String
    let price: Double
    let category: String
    let image: String
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search food items...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct FoodItemCard: View {
    let item: FoodItem
    @State private var isAdded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Food Image
            Image(systemName: item.image)
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            
            // Food Details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Price and Add Button
            VStack(alignment: .trailing, spacing: 8) {
                Text("$\(String(format: "%.2f", item.price))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isAdded.toggle()
                    }
                }) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                        .font(.title2)
                        .foregroundColor(isAdded ? .green : .blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    FoodView()
}
