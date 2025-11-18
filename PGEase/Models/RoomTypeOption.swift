import Foundation

enum RoomTypeOption: String, CaseIterable, Identifiable {
    case single = "SINGLE"
    case twin = "TWIN"
    case triple = "TRIPLE"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .single:
            return "Single"
        case .twin:
            return "Twin Sharing"
        case .triple:
            return "Triple Sharing"
        }
    }
    
    static func from(_ value: String) -> RoomTypeOption {
        RoomTypeOption(rawValue: value.uppercased()) ?? .single
    }
}

