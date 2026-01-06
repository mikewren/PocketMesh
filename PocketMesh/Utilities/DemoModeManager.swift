import SwiftUI
import os

private let logger = Logger(subsystem: "com.pocketmesh", category: "DemoMode")

@MainActor
@Observable
final class DemoModeManager {
    static let shared = DemoModeManager()

    @ObservationIgnored
    @AppStorage("isDemoModeUnlocked") var isUnlocked: Bool = false

    @ObservationIgnored
    @AppStorage("isDemoModeEnabled") var isEnabled: Bool = false

    private init() {}

    func unlock() {
        logger.info("Demo mode unlocked and enabled")
        isUnlocked = true
        isEnabled = true
    }
}
