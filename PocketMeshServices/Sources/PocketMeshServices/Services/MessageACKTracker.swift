import Foundation

/// Result of handling an ACK
public struct ACKResult: Sendable {
    public let messageID: UUID
    public let isFirstDelivery: Bool
    public let heardRepeats: Int
    public let roundTripMs: UInt32
}

/// Actor-isolated tracker for message acknowledgement tracking.
///
/// Provides a single source of truth for:
/// - Registering pending ACKs for outgoing messages
/// - Processing incoming ACKs and updating delivery status
/// - Tracking repeat counts ("heard repeats")
/// - Expiring unacknowledged messages
public actor MessageACKTracker {

    /// Pending ACK tracking entry
    private struct PendingACK {
        let messageID: UUID
        let ackCode: Data
        let sentAt: Date
        let timeout: TimeInterval
        var heardRepeats: Int = 0
        var isDelivered: Bool = false
        var deliveredAt: Date?

        var isExpired: Bool {
            !isDelivered && Date().timeIntervalSince(sentAt) > timeout
        }
    }

    /// Pending ACKs keyed by ACK code
    private var pendingAcks: [Data: PendingACK] = [:]

    /// Grace period for counting repeats after delivery
    private let repeatGracePeriod: TimeInterval

    public init(repeatGracePeriod: TimeInterval = 60.0) {
        self.repeatGracePeriod = repeatGracePeriod
    }

    /// Register a pending ACK for tracking.
    public func track(
        messageID: UUID,
        ackCode: Data,
        timeout: TimeInterval
    ) {
        pendingAcks[ackCode] = PendingACK(
            messageID: messageID,
            ackCode: ackCode,
            sentAt: Date(),
            timeout: timeout
        )
    }

    /// Check if an ACK code is being tracked.
    public func isTracking(ackCode: Data) -> Bool {
        pendingAcks[ackCode] != nil
    }

    /// Process an incoming ACK from the event stream.
    /// Returns nil if ACK code is not being tracked.
    public func handleACK(code: Data) -> ACKResult? {
        guard var pending = pendingAcks[code] else {
            return nil
        }

        let isFirstDelivery = !pending.isDelivered

        if isFirstDelivery {
            pending.isDelivered = true
            pending.heardRepeats = 1
            pending.deliveredAt = Date()
        } else {
            pending.heardRepeats += 1
        }

        pendingAcks[code] = pending

        let roundTripMs = UInt32(Date().timeIntervalSince(pending.sentAt) * 1000)

        return ACKResult(
            messageID: pending.messageID,
            isFirstDelivery: isFirstDelivery,
            heardRepeats: pending.heardRepeats,
            roundTripMs: roundTripMs
        )
    }

    /// Check and remove expired pending ACKs.
    /// Returns the message IDs that expired.
    public func checkExpired() -> [UUID] {
        let now = Date()
        var expiredIDs: [UUID] = []

        for (code, pending) in pendingAcks {
            // Skip delivered messages (they have a grace period for repeat tracking)
            if pending.isDelivered {
                continue
            }

            if now.timeIntervalSince(pending.sentAt) > pending.timeout {
                expiredIDs.append(pending.messageID)
                pendingAcks.removeValue(forKey: code)
            }
        }

        return expiredIDs
    }

    /// Remove delivered messages that have exceeded the grace period.
    public func cleanupDelivered() {
        let now = Date()

        for (code, pending) in pendingAcks {
            guard pending.isDelivered,
                  let deliveredAt = pending.deliveredAt,
                  now.timeIntervalSince(deliveredAt) > repeatGracePeriod else {
                continue
            }
            pendingAcks.removeValue(forKey: code)
        }
    }
}
