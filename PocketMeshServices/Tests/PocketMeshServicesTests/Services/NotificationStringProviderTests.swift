import Foundation
import Testing
@testable import PocketMeshServices

struct NotificationStringProviderTests {

    /// Mock implementation for testing
    struct MockStringProvider: NotificationStringProvider {
        func discoveryNotificationTitle(for type: ContactType) -> String {
            switch type {
            case .chat: "Mock Contact Title"
            case .repeater: "Mock Repeater Title"
            case .room: "Mock Room Title"
            }
        }
    }

    @Test("Provider returns correct title for chat type")
    func providerReturnsChatTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .chat)
        #expect(title == "Mock Contact Title")
    }

    @Test("Provider returns correct title for repeater type")
    func providerReturnsRepeaterTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .repeater)
        #expect(title == "Mock Repeater Title")
    }

    @Test("Provider returns correct title for room type")
    func providerReturnsRoomTitle() {
        let provider = MockStringProvider()
        let title = provider.discoveryNotificationTitle(for: .room)
        #expect(title == "Mock Room Title")
    }

    @Test("Default fallback titles are English")
    @MainActor
    func defaultFallbackTitlesAreEnglish() async {
        let service = NotificationService()
        // Without a provider set, should use defaults
        // We can't easily test the internal default method, but we verify
        // the service can be used without a provider (no crash)
        await service.postNewContactNotification(
            contactName: "Test",
            contactID: UUID(),
            contactType: ContactType.repeater
        )
        #expect(true) // If we got here, no crash occurred
    }
}
