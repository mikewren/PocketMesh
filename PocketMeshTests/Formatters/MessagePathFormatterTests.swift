import Foundation
import Testing
@testable import PocketMesh
@testable import PocketMeshServices

@Suite("MessagePathFormatter Tests")
struct MessagePathFormatterTests {
    // MARK: - Direct Path Tests

    @Test("pathLength 0 returns Direct")
    func directPathLengthZero() {
        let message = createMessage(pathLength: 0, pathNodes: nil)
        let result = MessagePathFormatter.format(message)
        #expect(result == L10n.Chats.Chats.Message.Path.direct)
    }

    @Test("pathLength 0xFF returns Direct")
    func directPathLengthMax() {
        let message = createMessage(pathLength: 0xFF, pathNodes: nil)
        let result = MessagePathFormatter.format(message)
        #expect(result == L10n.Chats.Chats.Message.Path.direct)
    }

    @Test("pathLength 1 with 0xFF destination marker returns Direct")
    func directWithDestinationMarker() {
        let message = createMessage(pathLength: 1, pathNodes: Data([0xFF]))
        let result = MessagePathFormatter.format(message)
        #expect(result == L10n.Chats.Chats.Message.Path.direct)
    }

    // MARK: - Path Nodes Tests

    @Test("Single node path formats correctly")
    func singleNode() {
        let message = createMessage(pathLength: 1, pathNodes: Data([0xA3]))
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3")
    }

    @Test("Three node path formats with commas")
    func threeNodes() {
        let message = createMessage(pathLength: 3, pathNodes: Data([0xA3, 0x7F, 0x42]))
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3,7F,42")
    }

    @Test("Four node path shows all nodes")
    func fourNodes() {
        let message = createMessage(pathLength: 4, pathNodes: Data([0xA3, 0x7F, 0x42, 0xB2]))
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3,7F,42,B2")
    }

    // MARK: - Truncation Tests

    @Test("Five node path truncates with ellipsis")
    func fiveNodesTruncated() {
        let message = createMessage(pathLength: 5, pathNodes: Data([0xA3, 0x7F, 0x42, 0xB2, 0xC1]))
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3,7F…B2,C1")
    }

    @Test("Eight node path truncates correctly")
    func eightNodesTruncated() {
        let message = createMessage(
            pathLength: 8,
            pathNodes: Data([0xA3, 0x7F, 0x42, 0xB2, 0xC1, 0xD4, 0xE5, 0xF6])
        )
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3,7F…E5,F6")
    }

    // MARK: - Fallback Tests

    @Test("Missing pathNodes falls back to hop count")
    func fallbackToHopCount() {
        let message = createMessage(pathLength: 3, pathNodes: nil)
        let result = MessagePathFormatter.format(message)
        #expect(result == L10n.Chats.Chats.Message.Path.hops(3))
    }

    // MARK: - Edge Case Tests

    @Test("pathLength doesn't match pathNodes count - shows actual nodes")
    func mismatchedPathData() {
        // pathLength says 5, but only 3 nodes in data - should show what we have
        let message = createMessage(pathLength: 5, pathNodes: Data([0xA3, 0x7F, 0x42]))
        let result = MessagePathFormatter.format(message)
        #expect(result == "A3,7F,42")
    }

    // MARK: - Helper

    private func createMessage(pathLength: UInt8, pathNodes: Data?) -> MessageDTO {
        let message = Message(
            deviceID: UUID(),
            contactID: UUID(),
            text: "Test",
            directionRawValue: MessageDirection.incoming.rawValue,
            statusRawValue: MessageStatus.delivered.rawValue,
            pathLength: pathLength,
            pathNodes: pathNodes
        )
        return MessageDTO(from: message)
    }
}
