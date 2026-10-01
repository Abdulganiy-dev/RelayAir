import Foundation

enum CustomFieldEditorMode: Equatable, Identifiable {
    case adding
    case editing(UUID)

    var id: String {
        switch self {
        case .adding: "adding"
        case .editing(let id): id.uuidString
        }
    }
}
