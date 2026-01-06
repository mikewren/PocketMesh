import Testing
import Foundation
@testable import PocketMesh

@Suite("DemoModeManager Tests")
@MainActor
struct DemoModeManagerTests {

    // Clean up UserDefaults before and after tests
    init() {
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")
    }

    deinit {
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")
    }

    // MARK: - Singleton Pattern Tests

    @Test("shared returns the same instance")
    func testSingletonPattern() {
        let instance1 = DemoModeManager.shared
        let instance2 = DemoModeManager.shared
        #expect(instance1 === instance2)
    }

    // MARK: - Default Values Tests

    @Test("properties default to false for new instances")
    func testDefaultValues() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        let manager = DemoModeManager.shared
        #expect(manager.isUnlocked == false)
        #expect(manager.isEnabled == false)
    }

    // MARK: - unlock() Method Tests

    @Test("unlock sets both isUnlocked and isEnabled to true")
    func testUnlockSetsBothFlags() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        let manager = DemoModeManager.shared

        // Verify initial state
        #expect(manager.isUnlocked == false)
        #expect(manager.isEnabled == false)

        // Call unlock
        manager.unlock()

        // Verify both flags are set to true
        #expect(manager.isUnlocked == true)
        #expect(manager.isEnabled == true)
    }

    // MARK: - UserDefaults Persistence Tests

    @Test("UserDefaults persistence works for isUnlocked")
    func testUserDefaultsPersistenceForIsUnlocked() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        let manager = DemoModeManager.shared

        // Set isUnlocked to true
        manager.isUnlocked = true

        // Verify it's persisted in UserDefaults
        let persistedValue = UserDefaults.standard.bool(forKey: "isDemoModeUnlocked")
        #expect(persistedValue == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
    }

    @Test("UserDefaults persistence works for isEnabled")
    func testUserDefaultsPersistenceForIsEnabled() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        let manager = DemoModeManager.shared

        // Set isEnabled to true
        manager.isEnabled = true

        // Verify it's persisted in UserDefaults
        let persistedValue = UserDefaults.standard.bool(forKey: "isDemoModeEnabled")
        #expect(persistedValue == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")
    }

    @Test("unlock persists both values to UserDefaults")
    func testUnlockPersistsToUserDefaults() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        let manager = DemoModeManager.shared

        // Call unlock
        manager.unlock()

        // Verify both values are persisted in UserDefaults
        let unlockedValue = UserDefaults.standard.bool(forKey: "isDemoModeUnlocked")
        let enabledValue = UserDefaults.standard.bool(forKey: "isDemoModeEnabled")

        #expect(unlockedValue == true)
        #expect(enabledValue == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")
    }

    @Test("values persist across singleton access")
    func testPersistenceAcrossSingletonAccess() {
        // Clean UserDefaults to ensure fresh state
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")

        // Set values via UserDefaults directly
        UserDefaults.standard.set(true, forKey: "isDemoModeUnlocked")
        UserDefaults.standard.set(true, forKey: "isDemoModeEnabled")

        // Access singleton and verify it reads from UserDefaults
        let manager = DemoModeManager.shared
        #expect(manager.isUnlocked == true)
        #expect(manager.isEnabled == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "isDemoModeUnlocked")
        UserDefaults.standard.removeObject(forKey: "isDemoModeEnabled")
    }
}
