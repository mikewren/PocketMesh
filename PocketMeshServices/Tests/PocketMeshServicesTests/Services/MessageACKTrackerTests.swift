import Testing
import Foundation
@testable import PocketMeshServices

@Suite("MessageACKTracker Tests")
struct MessageACKTrackerTests {

    private let validAckCode = Data([0x01, 0x02, 0x03, 0x04])

    @Test("track registers pending ACK")
    func trackRegistersPendingAck() async {
        let tracker = MessageACKTracker()
        let messageID = UUID()

        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: 30.0
        )

        let isTracking = await tracker.isTracking(ackCode: validAckCode)
        #expect(isTracking)
    }

    @Test("handleACK marks message as delivered on first ACK")
    func handleACKMarksDelivered() async {
        let tracker = MessageACKTracker()
        let messageID = UUID()

        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: 30.0
        )

        let result = await tracker.handleACK(code: validAckCode)

        #expect(result?.messageID == messageID)
        #expect(result?.isFirstDelivery == true)
        #expect(result?.heardRepeats == 1)
    }

    @Test("handleACK increments heardRepeats on subsequent ACKs")
    func handleACKIncrementsRepeats() async {
        let tracker = MessageACKTracker()
        let messageID = UUID()

        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: 30.0
        )

        // First ACK
        let first = await tracker.handleACK(code: validAckCode)
        #expect(first?.heardRepeats == 1)
        #expect(first?.isFirstDelivery == true)

        // Second ACK (repeat)
        let second = await tracker.handleACK(code: validAckCode)
        #expect(second?.heardRepeats == 2)
        #expect(second?.isFirstDelivery == false)

        // Third ACK (repeat)
        let third = await tracker.handleACK(code: validAckCode)
        #expect(third?.heardRepeats == 3)
        #expect(third?.isFirstDelivery == false)
    }

    @Test("handleACK returns nil for unknown ACK code")
    func handleACKReturnsNilForUnknown() async {
        let tracker = MessageACKTracker()
        let unknownCode = Data([0xFF, 0xFF, 0xFF, 0xFF])

        let result = await tracker.handleACK(code: unknownCode)

        #expect(result == nil)
    }

    @Test("checkExpired returns expired message IDs")
    func checkExpiredReturnsExpiredIDs() async {
        let tracker = MessageACKTracker()
        let messageID = UUID()

        // Track with already-expired timestamp (negative timeout trick)
        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: -1.0  // Already expired
        )

        let expired = await tracker.checkExpired()

        #expect(expired.count == 1)
        #expect(expired.first == messageID)
    }

    @Test("checkExpired does not expire delivered messages")
    func checkExpiredSkipsDelivered() async {
        let tracker = MessageACKTracker()
        let messageID = UUID()

        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: -1.0  // Would be expired if not delivered
        )

        // Deliver it
        _ = await tracker.handleACK(code: validAckCode)

        let expired = await tracker.checkExpired()

        #expect(expired.isEmpty)
    }

    @Test("cleanupDelivered removes delivered messages after grace period")
    func cleanupDeliveredRemovesAfterGrace() async throws {
        let tracker = MessageACKTracker(repeatGracePeriod: 0.1)  // 100ms for testing
        let messageID = UUID()

        await tracker.track(
            messageID: messageID,
            ackCode: validAckCode,
            timeout: 30.0
        )

        // Deliver it
        _ = await tracker.handleACK(code: validAckCode)

        // Wait for grace period
        try await Task.sleep(for: .milliseconds(150))

        await tracker.cleanupDelivered()

        let isTracking = await tracker.isTracking(ackCode: validAckCode)
        #expect(!isTracking)
    }
}
