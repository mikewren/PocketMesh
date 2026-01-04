import Testing
import Foundation
@testable import PocketMeshServices
@testable import MeshCore

@Suite("MessageService Tests")
struct MessageServiceTests {

    // MARK: - Test Constants

    private let testTimeout: TimeInterval = 30.0
    private let expiredTimeOffset: TimeInterval = -31.0
    private let validAckCode = Data([0x01, 0x02, 0x03, 0x04])
    private let expectedAckCodeUInt32: UInt32 = 0x04030201  // Little-endian
    private let shortAckCode = Data([0x01, 0x02])

    // MARK: - PendingAck Tests

    @Test("PendingAck isExpired returns false when within timeout")
    func pendingAckNotExpiredWithinTimeout() {
        let ack = PendingAck(
            messageID: UUID(),
            ackCode: validAckCode,
            sentAt: Date(),
            timeout: testTimeout
        )
        #expect(!ack.isExpired)
    }

    @Test("PendingAck isExpired returns true after timeout")
    func pendingAckExpiredAfterTimeout() {
        let ack = PendingAck(
            messageID: UUID(),
            ackCode: validAckCode,
            sentAt: Date().addingTimeInterval(expiredTimeOffset),
            timeout: testTimeout
        )
        #expect(ack.isExpired)
    }

    @Test("PendingAck isExpired returns false when delivered")
    func pendingAckNotExpiredWhenDelivered() {
        var ack = PendingAck(
            messageID: UUID(),
            ackCode: validAckCode,
            sentAt: Date().addingTimeInterval(expiredTimeOffset),
            timeout: testTimeout
        )
        ack.isDelivered = true
        #expect(!ack.isExpired)
    }

    @Test("PendingAck ackCodeUInt32 converts correctly")
    func pendingAckCodeConversion() {
        let ack = PendingAck(
            messageID: UUID(),
            ackCode: validAckCode,
            sentAt: Date(),
            timeout: testTimeout
        )
        #expect(ack.ackCodeUInt32 == expectedAckCodeUInt32)
    }

    @Test("PendingAck ackCodeUInt32 handles short data")
    func pendingAckCodeHandlesShortData() {
        let ack = PendingAck(
            messageID: UUID(),
            ackCode: shortAckCode,
            sentAt: Date(),
            timeout: testTimeout
        )
        #expect(ack.ackCodeUInt32 == 0)
    }

    // MARK: - MessageServiceConfig Tests

    @Test("MessageServiceConfig default values")
    func messageServiceConfigDefaults() {
        let config = MessageServiceConfig.default
        #expect(config.floodFallbackOnRetry == true)
        #expect(config.maxAttempts == 4)
        #expect(config.maxFloodAttempts == 2)
        #expect(config.floodAfter == 2)
        #expect(config.minTimeout == 0)
        #expect(config.triggerPathDiscoveryAfterFlood == true)
    }

    @Test("MessageServiceConfig custom values")
    func messageServiceConfigCustomValues() {
        let config = MessageServiceConfig(
            floodFallbackOnRetry: false,
            maxAttempts: 5,
            maxFloodAttempts: 3,
            floodAfter: 3,
            minTimeout: 10.0,
            triggerPathDiscoveryAfterFlood: false
        )
        #expect(config.floodFallbackOnRetry == false)
        #expect(config.maxAttempts == 5)
        #expect(config.maxFloodAttempts == 3)
        #expect(config.floodAfter == 3)
        #expect(config.minTimeout == 10.0)
        #expect(config.triggerPathDiscoveryAfterFlood == false)
    }

    // MARK: - Channel Message Integration Tests

    @Test("sendChannelMessage registers ACK for tracking")
    func sendChannelMessageRegistersAck() async throws {
        // Setup
        let mockSession = MockMeshCoreSession()
        let mockStore = MockPersistenceStore()
        let service = MessageService(session: mockSession, dataStore: mockStore)

        let deviceID = UUID()
        let channelIndex: UInt8 = 1

        // Create channel in store
        let channel = ChannelDTO(
            id: UUID(),
            deviceID: deviceID,
            index: channelIndex,
            name: "Test",
            secret: Data(repeating: 0, count: 16),
            isEnabled: true,
            lastMessageDate: nil,
            unreadCount: 0
        )
        try await mockStore.saveChannel(channel)

        // Act
        let messageID = try await service.sendChannelMessage(
            text: "Hello channel",
            channelIndex: channelIndex,
            deviceID: deviceID
        )

        // Assert - message was sent via session
        let invocations = await mockSession.sendChannelMessageInvocations
        #expect(invocations.count == 1)
        #expect(invocations.first?.channel == channelIndex)
        #expect(invocations.first?.text == "Hello channel")

        // Assert - message saved with .sent status
        let savedMessage = try await mockStore.fetchMessage(id: messageID)
        #expect(savedMessage != nil)
        #expect(savedMessage?.status == .sent)
    }
}
