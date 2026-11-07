import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var needsApproval = false
    @Published private(set) var error: String?
    private let service = SMAppService.mainApp

    init() { refresh() }

    func refresh() {
        enabled = service.status == .enabled
        needsApproval = service.status == .requiresApproval
    }

    func setEnabled(_ value: Bool) {
        error = nil
        do {
            if value {
                if service.status != .enabled { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try service.unregister()
            }
        } catch {
            self.error = "Couldn’t change Launch at Login. Use the installed copy of Kanta in Applications and check Login Items."
        }
        refresh()
    }

    func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
