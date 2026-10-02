import Observation

enum RelayNavigationRoute: Hashable {
    case createRelayItem(RelayType)
    case editRelayItem(RelayItem)
    case settings
    case scan
}

@MainActor
@Observable
final class RelayNavigationStore {
    var path: [RelayNavigationRoute] = []

    func push(_ route: RelayNavigationRoute) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func pop(ifCurrent route: RelayNavigationRoute) {
        guard path.last == route else { return }
        path.removeLast()
    }
}
