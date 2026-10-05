import Observation

enum RelayNavigationRoute: Hashable {
    case createRelayItem(RelayType)
    case editRelayItem(RelayItem)
    case settings
    case scan

    func isSameDestination(as other: Self) -> Bool {
        switch (self, other) {
        case let (.createRelayItem(lhs), .createRelayItem(rhs)):
            lhs == rhs
        case let (.editRelayItem(lhs), .editRelayItem(rhs)):
            lhs.id == rhs.id
        case (.settings, .settings), (.scan, .scan):
            true
        default:
            false
        }
    }
}

@MainActor
@Observable
final class RelayNavigationStore {
    var path: [RelayNavigationRoute] = []

    func push(_ route: RelayNavigationRoute) {
        guard !path.contains(where: { $0.isSameDestination(as: route) }) else { return }
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func pop(ifCurrent route: RelayNavigationRoute) {
        guard path.last?.isSameDestination(as: route) == true else { return }
        path.removeLast()
    }
}
