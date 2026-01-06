# Heard Repeats Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Track and display channel message repeats heard by the companion radio, showing users how their messages propagate through the mesh.

**Architecture:** Content-based matching correlates RX log entries to sent messages using (channelIndex, senderTimestamp, text). MessageRepeat SwiftData model stores individual repeat observations with cascade delete from parent Message. HeardRepeatsService actor processes incoming RX log entries within a 10-second window.

**Tech Stack:** SwiftUI, SwiftData, Swift Concurrency (actors), OSLog

---

## Task 1: Add ChannelMessageFormat Parsing Utility

**Files:**
- Modify: `PocketMeshServices/Sources/PocketMeshServices/Models/ProtocolTypes.swift`

**Step 1: Add shared parsing utility**

Add at the end of ProtocolTypes.swift:

```swift
// MARK: - Channel Message Format

/// Utilities for parsing the "NodeName: MessageText" format used in channel messages.
/// The firmware prepends the sender's node name before encryption.
public enum ChannelMessageFormat {
    /// Parses "NodeName: MessageText" format from decrypted channel messages.
    /// - Parameter text: The full decrypted channel message text
    /// - Returns: Tuple of (senderName, messageText) or nil if format doesn't match
    public static func parse(_ text: String) -> (senderName: String, messageText: String)? {
        guard let colonIndex = text.firstIndex(of: ":"),
              colonIndex != text.startIndex else {
            return nil
        }

        let senderName = String(text[..<colonIndex])
        let afterColon = text.index(after: colonIndex)

        guard afterColon < text.endIndex else {
            return (senderName, "")
        }

        let messageText = String(text[afterColon...]).trimmingCharacters(in: .whitespaces)
        return (senderName, messageText)
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Models/ProtocolTypes.swift
git commit -m "feat: add ChannelMessageFormat parsing utility"
```

---

## Task 2: Create MessageRepeat SwiftData Model

**Files:**
- Create: `PocketMeshServices/Sources/PocketMeshServices/Models/MessageRepeat.swift`
- Modify: `PocketMeshServices/Sources/PocketMeshServices/Models/Message.swift` (add relationship)

**Step 1: Create the model file**

```swift
// PocketMeshServices/Sources/PocketMeshServices/Models/MessageRepeat.swift
import Foundation
import SwiftData

/// Represents a single heard repeat of a sent channel message.
/// Each repeat is an observation of the message being re-broadcast by a repeater.
@Model
public final class MessageRepeat {
    @Attribute(.unique)
    public var id: UUID

    /// The parent message (cascade delete when message is deleted)
    public var message: Message?

    /// The message ID (kept for queries, matches message.id)
    public var messageID: UUID

    /// When this repeat was received by the companion radio
    public var receivedAt: Date

    /// Repeater public key prefixes (1 byte per hop in the path)
    public var pathNodes: Data

    /// Signal-to-noise ratio in dB
    public var snr: Double?

    /// Received signal strength indicator in dBm
    public var rssi: Int?

    /// Link to RxLogEntry for raw packet details
    public var rxLogEntryID: UUID?

    public init(
        id: UUID = UUID(),
        message: Message? = nil,
        messageID: UUID,
        receivedAt: Date = Date(),
        pathNodes: Data,
        snr: Double? = nil,
        rssi: Int? = nil,
        rxLogEntryID: UUID? = nil
    ) {
        self.id = id
        self.message = message
        self.messageID = messageID
        self.receivedAt = receivedAt
        self.pathNodes = pathNodes
        self.snr = snr
        self.rssi = rssi
        self.rxLogEntryID = rxLogEntryID
    }
}

// MARK: - DTO

/// Sendable DTO for cross-actor transfer of MessageRepeat data.
public struct MessageRepeatDTO: Sendable, Identifiable, Equatable, Hashable {
    public let id: UUID
    public let messageID: UUID
    public let receivedAt: Date
    public let pathNodes: Data
    public let snr: Double?
    public let rssi: Int?
    public let rxLogEntryID: UUID?

    public init(from model: MessageRepeat) {
        self.id = model.id
        self.messageID = model.messageID
        self.receivedAt = model.receivedAt
        self.pathNodes = model.pathNodes
        self.snr = model.snr
        self.rssi = model.rssi
        self.rxLogEntryID = model.rxLogEntryID
    }

    public init(
        id: UUID = UUID(),
        messageID: UUID,
        receivedAt: Date,
        pathNodes: Data,
        snr: Double?,
        rssi: Int?,
        rxLogEntryID: UUID?
    ) {
        self.id = id
        self.messageID = messageID
        self.receivedAt = receivedAt
        self.pathNodes = pathNodes
        self.snr = snr
        self.rssi = rssi
        self.rxLogEntryID = rxLogEntryID
    }

    // MARK: - Computed Properties

    /// First repeater's public key prefix byte, or nil if direct
    public var repeaterByte: UInt8? {
        pathNodes.first
    }

    /// Repeater hash formatted as "0xAB"
    public var repeaterHashFormatted: String {
        guard let byte = repeaterByte else { return "0x00" }
        return String(format: "0x%02X", byte)
    }

    /// Path nodes as hex strings for display
    public var pathNodesHex: [String] {
        pathNodes.map { String(format: "%02X", $0) }
    }

    /// RSSI quality level (0.0 to 1.0)
    public var rssiLevel: Double {
        guard let rssi = rssi else { return 0 }
        // Map -120 dBm (weak) to -50 dBm (strong) → 0.0 to 1.0
        let clamped = max(-120, min(-50, rssi))
        return Double(clamped + 120) / 70.0
    }

    /// RSSI formatted for display
    public var rssiFormatted: String {
        guard let rssi = rssi else { return "—" }
        return "\(rssi) dBm"
    }

    /// SNR formatted for display
    public var snrFormatted: String {
        guard let snr = snr else { return "—" }
        return String(format: "%.1f dB", snr)
    }
}
```

**Step 2: Add inverse relationship to Message model**

In `Message.swift`, add the inverse relationship with cascade delete:

```swift
// Add to Message class properties
/// Heard repeats for this message (cascade delete)
@Relationship(deleteRule: .cascade, inverse: \MessageRepeat.message)
public var repeats: [MessageRepeat]?
```

**Step 3: Register model in schema**

Find the SwiftData schema registration (likely in `PocketMeshServices` or app target) and add `MessageRepeat.self` to the schema.

**Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Models/MessageRepeat.swift
git add PocketMeshServices/Sources/PocketMeshServices/Models/Message.swift
git commit -m "feat: add MessageRepeat SwiftData model with cascade delete relationship"
```

---

## Task 3: Add PersistenceStore Query Methods

**Files:**
- Modify: `PocketMeshServices/Sources/PocketMeshServices/Services/PersistenceStore.swift`

**Step 1: Add method to find sent channel messages for matching**

Add after the existing `updateMessageHeardRepeats` method (around line 713):

```swift
// MARK: - Heard Repeats

/// Finds a sent channel message matching the given criteria within a time window.
/// Used for correlating RX log entries to sent messages.
///
/// - Parameters:
///   - deviceID: The device that sent the message
///   - channelIndex: Channel the message was sent on
///   - timestamp: Sender timestamp from the message
///   - senderName: Sender name parsed from "Name: Text" format
///   - text: Message text (without sender prefix)
///   - withinSeconds: Time window to search (default 10 seconds)
/// - Returns: MessageDTO if found, nil otherwise
public func findSentChannelMessage(
    deviceID: UUID,
    channelIndex: UInt8,
    timestamp: UInt32,
    senderName: String,
    text: String,
    withinSeconds: Int = 10
) throws -> MessageDTO? {
    let targetDeviceID = deviceID
    let targetChannelIndex = channelIndex
    let targetTimestamp = timestamp
    let outgoingDirection = MessageDirection.outgoing.rawValue

    // Calculate time window
    let now = Date()
    let windowStart = now.addingTimeInterval(-TimeInterval(withinSeconds))
    let windowStartTimestamp = UInt32(windowStart.timeIntervalSince1970)

    let predicate = #Predicate<Message> { message in
        message.deviceID == targetDeviceID &&
        message.channelIndex == targetChannelIndex &&
        message.timestamp == targetTimestamp &&
        message.directionRawValue == outgoingDirection &&
        message.timestamp >= windowStartTimestamp
    }

    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1

    guard let message = try modelContext.fetch(descriptor).first else {
        return nil
    }

    // Verify sender name and text match
    // Channel messages are stored as just the text, sender name is device's node name
    guard message.text == text else {
        return nil
    }

    return MessageDTO(from: message)
}

/// Saves a new MessageRepeat entry.
public func saveMessageRepeat(_ dto: MessageRepeatDTO) throws {
    let repeat_ = MessageRepeat(
        id: dto.id,
        messageID: dto.messageID,
        receivedAt: dto.receivedAt,
        pathNodes: dto.pathNodes,
        snr: dto.snr,
        rssi: dto.rssi,
        rxLogEntryID: dto.rxLogEntryID
    )
    modelContext.insert(repeat_)
    try modelContext.save()
}

/// Fetches all repeats for a given message, sorted by receivedAt ascending.
public func fetchMessageRepeats(messageID: UUID) throws -> [MessageRepeatDTO] {
    let targetMessageID = messageID
    let predicate = #Predicate<MessageRepeat> { repeat_ in
        repeat_.messageID == targetMessageID
    }
    var descriptor = FetchDescriptor(
        predicate: predicate,
        sortBy: [SortDescriptor(\MessageRepeat.receivedAt, order: .forward)]
    )

    let results = try modelContext.fetch(descriptor)
    return results.map { MessageRepeatDTO(from: $0) }
}

/// Checks if a repeat already exists for the given RX log entry.
public func messageRepeatExists(rxLogEntryID: UUID) throws -> Bool {
    let targetID = rxLogEntryID
    let predicate = #Predicate<MessageRepeat> { repeat_ in
        repeat_.rxLogEntryID == targetID
    }
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1

    return try !modelContext.fetch(descriptor).isEmpty
}

/// Increments the heardRepeats count for a message and returns the new count.
public func incrementMessageHeardRepeats(id: UUID) throws -> Int {
    let targetID = id
    let predicate = #Predicate<Message> { message in message.id == targetID }
    var descriptor = FetchDescriptor(predicate: predicate)
    descriptor.fetchLimit = 1

    guard let message = try modelContext.fetch(descriptor).first else {
        return 0
    }

    message.heardRepeats += 1
    try modelContext.save()
    return message.heardRepeats
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Services/PersistenceStore.swift
git commit -m "feat: add PersistenceStore methods for heard repeats"
```

---

## Task 4: Create HeardRepeatsService Actor

**Files:**
- Create: `PocketMeshServices/Sources/PocketMeshServices/Services/HeardRepeatsService.swift`

**Step 1: Create the service file**

```swift
// PocketMeshServices/Sources/PocketMeshServices/Services/HeardRepeatsService.swift
import Foundation
import MeshCore
import OSLog

/// Service for correlating RX log entries to sent channel messages
/// and tracking "heard repeats" - evidence of message propagation through the mesh.
public actor HeardRepeatsService {
    private let persistenceStore: PersistenceStore
    private let logger = Logger(subsystem: "PocketMesh", category: "HeardRepeatsService")

    /// Device ID for the current session
    private var deviceID: UUID?

    /// Local node name for matching sender in decrypted messages
    private var localNodeName: String?

    public init(persistenceStore: PersistenceStore) {
        self.persistenceStore = persistenceStore
    }

    /// Configure the service with device context.
    public func configure(deviceID: UUID, localNodeName: String) {
        self.deviceID = deviceID
        self.localNodeName = localNodeName
        logger.debug("Configured with deviceID: \(deviceID), nodeName: \(localNodeName)")
    }

    /// Process an RX log entry to check if it's a repeat of a sent message.
    ///
    /// Called by RxLogService for each new entry. Only processes successfully
    /// decrypted channel messages within the 10-second matching window.
    ///
    /// - Parameter entry: The RX log entry to process
    /// - Returns: The updated heardRepeats count if a match was found, nil otherwise
    @discardableResult
    public func processForRepeats(_ entry: RxLogEntryDTO) async -> Int? {
        // Only process successfully decrypted channel messages
        guard entry.payloadType == .groupText,
              entry.decryptStatus == .success,
              let decodedText = entry.decodedText,
              let channelIndex = entry.channelHash,
              let senderTimestamp = entry.senderTimestamp,
              let deviceID = self.deviceID,
              let localNodeName = self.localNodeName else {
            return nil
        }

        // Parse "NodeName: MessageText" format using shared utility
        guard let (senderName, messageText) = ChannelMessageFormat.parse(decodedText) else {
            logger.debug("Failed to parse channel message text: \(decodedText.prefix(50))")
            return nil
        }

        // Only match messages from our own node
        guard senderName == localNodeName else {
            return nil
        }

        // Check for duplicate (already processed this RX entry)
        do {
            if try persistenceStore.messageRepeatExists(rxLogEntryID: entry.id) {
                logger.debug("Repeat already recorded for RX entry: \(entry.id)")
                return nil
            }
        } catch {
            logger.error("Failed to check for existing repeat: \(error.localizedDescription)")
            return nil
        }

        // Find matching sent message
        do {
            guard let message = try persistenceStore.findSentChannelMessage(
                deviceID: deviceID,
                channelIndex: channelIndex,
                timestamp: senderTimestamp,
                senderName: senderName,
                text: messageText,
                withinSeconds: 10
            ) else {
                return nil
            }

            // Create repeat entry
            let repeatDTO = MessageRepeatDTO(
                messageID: message.id,
                receivedAt: entry.receivedAt,
                pathNodes: entry.pathNodes,
                snr: entry.snr,
                rssi: entry.rssi,
                rxLogEntryID: entry.id
            )

            try persistenceStore.saveMessageRepeat(repeatDTO)

            // Increment and return new count
            let newCount = try persistenceStore.incrementMessageHeardRepeats(id: message.id)

            logger.info("Recorded repeat #\(newCount) for message \(message.id)")
            return newCount

        } catch {
            logger.error("Failed to process repeat: \(error.localizedDescription)")
            return nil
        }
    }

    /// Refresh repeats for a specific message by querying the RX log.
    /// Used when opening the Repeat Details sheet to catch any missed repeats.
    ///
    /// - Parameter messageID: The message to refresh repeats for
    /// - Returns: Array of repeat DTOs sorted by receivedAt
    public func refreshRepeats(for message: MessageDTO) async -> [MessageRepeatDTO] {
        // For on-demand refresh, we'd query RX log and create missing entries
        // For now, just return existing repeats from database
        do {
            return try persistenceStore.fetchMessageRepeats(messageID: message.id)
        } catch {
            logger.error("Failed to fetch repeats: \(error.localizedDescription)")
            return []
        }
    }

}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Services/HeardRepeatsService.swift
git commit -m "feat: add HeardRepeatsService actor for correlating repeats"
```

---

## Task 5: Integrate HeardRepeatsService with RxLogService

**Files:**
- Modify: `PocketMeshServices/Sources/PocketMeshServices/Services/RxLogService.swift`
- Modify: `PocketMeshServices/Sources/PocketMeshServices/ServiceContainer.swift`

**Step 1: Add HeardRepeatsService reference to RxLogService**

In `RxLogService.swift`, add property and setter:

```swift
// Add after other private properties (around line 17)
private var heardRepeatsService: HeardRepeatsService?

// Add setter method (after updateContacts method)
public func setHeardRepeatsService(_ service: HeardRepeatsService) {
    self.heardRepeatsService = service
}
```

**Step 2: Call HeardRepeatsService in process() method**

In `RxLogService.swift`, after the `yield()` call in `process()` (around line 164), add:

```swift
// Process for heard repeats (fire and forget - don't block stream)
if let heardRepeatsService = self.heardRepeatsService {
    Task {
        await heardRepeatsService.processForRepeats(dto)
    }
}
```

**Step 3: Register HeardRepeatsService in ServiceContainer**

In `ServiceContainer.swift`, add property and initialization:

```swift
// Add property (around line 38)
public let heardRepeatsService: HeardRepeatsService

// In init(), add creation (around line 135)
self.heardRepeatsService = HeardRepeatsService(persistenceStore: dataStore)

// In wireServices(), wire to RxLogService (around line 180)
await rxLogService.setHeardRepeatsService(heardRepeatsService)

// Configure with device info when available (in appropriate location)
// await heardRepeatsService.configure(deviceID: device.id, localNodeName: device.nodeName)
```

**Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Services/RxLogService.swift
git add PocketMeshServices/Sources/PocketMeshServices/ServiceContainer.swift
git commit -m "feat: integrate HeardRepeatsService with RxLogService"
```

---

## Task 6: Update UnifiedMessageBubble Status Text

**Files:**
- Modify: `PocketMesh/Views/Chats/Components/UnifiedMessageBubble.swift`

**Step 1: Update statusText to include repeat count**

Replace the `statusText` computed property (lines 258-273):

```swift
private var statusText: String {
    switch message.status {
    case .pending:
        return "Sending..."
    case .sending:
        return "Sending..."
    case .sent:
        return "Sent"
    case .delivered:
        if message.heardRepeats > 0 {
            let repeatText = message.heardRepeats == 1 ? "1 repeat" : "\(message.heardRepeats) repeats"
            return "Delivered • \(repeatText)"
        }
        return "Delivered"
    case .failed:
        return "Failed"
    case .retrying:
        return "Retrying..."
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMesh/Views/Chats/Components/UnifiedMessageBubble.swift
git commit -m "feat: show repeat count in message status text"
```

---

## Task 7: Add Context Menu Item for Heard Repeats

**Files:**
- Modify: `PocketMesh/Views/Chats/Components/UnifiedMessageBubble.swift`

**Step 1: Add state for showing repeat details sheet**

Add to UnifiedMessageBubble struct (around line 65):

```swift
@State private var showRepeatDetails = false
```

**Step 2: Add handler property for opening repeat details**

Add to init parameters and properties:

```swift
// Property
let onShowRepeatDetails: ((MessageDTO) -> Void)?

// Init parameter (add after onDelete)
onShowRepeatDetails: ((MessageDTO) -> Void)? = nil

// Init assignment
self.onShowRepeatDetails = onShowRepeatDetails
```

**Step 3: Update context menu to add Heard Repeats button**

In `contextMenuContent`, replace the outgoing message details section (lines 178-189):

```swift
// Outgoing message: Heard Repeats button + details
if message.isOutgoing {
    // Heard Repeats button (always visible for channel messages)
    if message.channelIndex != nil, let onShowRepeatDetails {
        Button {
            onShowRepeatDetails(message)
        } label: {
            Label(
                "\(message.heardRepeats) Heard Repeat\(message.heardRepeats == 1 ? "" : "s")",
                systemImage: "arrow.triangle.branch"
            )
        }
    }

    Text("Sent: \(message.date.formatted(date: .abbreviated, time: .shortened))")

    if let rtt = message.roundTripTime {
        Text("Round trip: \(rtt)ms")
    }
}
```

**Step 4: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add PocketMesh/Views/Chats/Components/UnifiedMessageBubble.swift
git commit -m "feat: add Heard Repeats context menu item"
```

---

## Task 8: Create RepeatRowView Component

**Files:**
- Create: `PocketMesh/Views/Chats/Components/RepeatRowView.swift`

**Step 1: Create the view file**

```swift
// PocketMesh/Views/Chats/Components/RepeatRowView.swift
import SwiftUI
import PocketMeshServices

/// Row displaying a single heard repeat with repeater info and signal quality.
struct RepeatRowView: View {
    let repeatEntry: MessageRepeatDTO
    let contacts: [ContactDTO]

    var body: some View {
        HStack(alignment: .top) {
            // Left side: Repeater name and hash
            VStack(alignment: .leading, spacing: 2) {
                Text(repeaterName)
                    .font(.body)

                Text(repeatEntry.repeaterHashFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }

            Spacer()

            // Right side: Signal bars and metrics
            VStack(alignment: .trailing, spacing: 2) {
                SignalBarsView(level: repeatEntry.rssiLevel)

                Text("RSSI \(repeatEntry.rssiFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("SNR \(repeatEntry.snrFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Repeat from \(repeaterName)")
        .accessibilityValue("RSSI \(repeatEntry.rssiFormatted), SNR \(repeatEntry.snrFormatted)")
    }

    // MARK: - Helpers

    /// Resolve repeater name from contacts or show placeholder
    private var repeaterName: String {
        guard let repeaterByte = repeatEntry.repeaterByte else {
            return "<unknown repeater>"
        }

        // Try to find contact with matching public key prefix
        if let contact = contacts.first(where: { contact in
            guard let firstByte = contact.publicKey.first else { return false }
            return firstByte == repeaterByte
        }) {
            return contact.displayName
        }

        return "<unknown repeater>"
    }
}

/// Signal strength bars visualization
struct SignalBarsView: View {
    let level: Double // 0.0 to 1.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
            }
        }
        .frame(height: 16, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Signal strength")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private func barHeight(for index: Int) -> CGFloat {
        CGFloat(6 + index * 3) // 6, 9, 12, 15
    }

    private func barColor(for index: Int) -> Color {
        let threshold = Double(index + 1) / 4.0
        return level >= threshold ? .green : .gray.opacity(0.3)
    }
}

#Preview {
    List {
        RepeatRowView(
            repeatEntry: MessageRepeatDTO(
                messageID: UUID(),
                receivedAt: Date(),
                pathNodes: Data([0xA3]),
                snr: 6.2,
                rssi: -85,
                rxLogEntryID: nil
            ),
            contacts: []
        )

        RepeatRowView(
            repeatEntry: MessageRepeatDTO(
                messageID: UUID(),
                receivedAt: Date(),
                pathNodes: Data([0x7F]),
                snr: 2.1,
                rssi: -102,
                rxLogEntryID: nil
            ),
            contacts: []
        )
    }
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMesh/Views/Chats/Components/RepeatRowView.swift
git commit -m "feat: add RepeatRowView component for repeat details"
```

---

## Task 9: Create RepeatDetailsSheet

**Files:**
- Create: `PocketMesh/Views/Chats/Components/RepeatDetailsSheet.swift`

**Step 1: Create the sheet view file**

```swift
// PocketMesh/Views/Chats/Components/RepeatDetailsSheet.swift
import SwiftUI
import PocketMeshServices

/// Sheet displaying detailed information about heard repeats for a message.
struct RepeatDetailsSheet: View {
    let message: MessageDTO
    let repeats: [MessageRepeatDTO]
    let contacts: [ContactDTO]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Summary section
                Section {
                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Repeats list or empty state
                if repeats.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No repeats yet",
                            systemImage: "arrow.triangle.branch",
                            description: Text("Repeats will appear here as your message propagates through the mesh")
                        )
                    }
                } else {
                    Section {
                        ForEach(repeats) { repeatEntry in
                            RepeatRowView(
                                repeatEntry: repeatEntry,
                                contacts: contacts
                            )
                        }
                    }
                }
            }
            .navigationTitle("Repeat Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var summaryText: String {
        let count = repeats.count
        if count == 0 {
            return "No repeats heard"
        } else if count == 1 {
            return "1 repeat heard"
        } else {
            return "\(count) repeats heard"
        }
    }
}

#Preview("With Repeats") {
    RepeatDetailsSheet(
        message: MessageDTO(
            id: UUID(),
            deviceID: UUID(),
            contactID: nil,
            channelIndex: 0,
            text: "Test message",
            timestamp: UInt32(Date().timeIntervalSince1970),
            createdAt: Date(),
            direction: .outgoing,
            status: .delivered,
            textType: .plain,
            ackCode: nil,
            pathLength: 0,
            snr: nil,
            senderKeyPrefix: nil,
            senderNodeName: nil,
            isRead: true,
            replyToID: nil,
            roundTripTime: nil,
            heardRepeats: 2,
            retryAttempt: 0,
            maxRetryAttempts: 0,
            deduplicationKey: nil
        ),
        repeats: [
            MessageRepeatDTO(
                messageID: UUID(),
                receivedAt: Date().addingTimeInterval(-5),
                pathNodes: Data([0xA3]),
                snr: 6.2,
                rssi: -85,
                rxLogEntryID: nil
            ),
            MessageRepeatDTO(
                messageID: UUID(),
                receivedAt: Date().addingTimeInterval(-3),
                pathNodes: Data([0x7F]),
                snr: 2.1,
                rssi: -102,
                rxLogEntryID: nil
            )
        ],
        contacts: []
    )
}

#Preview("Empty") {
    RepeatDetailsSheet(
        message: MessageDTO(
            id: UUID(),
            deviceID: UUID(),
            contactID: nil,
            channelIndex: 0,
            text: "Test message",
            timestamp: UInt32(Date().timeIntervalSince1970),
            createdAt: Date(),
            direction: .outgoing,
            status: .delivered,
            textType: .plain,
            ackCode: nil,
            pathLength: 0,
            snr: nil,
            senderKeyPrefix: nil,
            senderNodeName: nil,
            isRead: true,
            replyToID: nil,
            roundTripTime: nil,
            heardRepeats: 0,
            retryAttempt: 0,
            maxRetryAttempts: 0,
            deduplicationKey: nil
        ),
        repeats: [],
        contacts: []
    )
}
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMesh/Views/Chats/Components/RepeatDetailsSheet.swift
git commit -m "feat: add RepeatDetailsSheet for viewing repeat details"
```

---

## Task 10: Wire Up Sheet Presentation in Channel Chat View

**Files:**
- Modify: `PocketMesh/Views/Chats/ChannelChatView.swift` (or wherever channel messages are displayed)

**Step 1: Find the channel chat view file and add state**

Add state for selected message and sheet presentation:

```swift
@State private var selectedMessageForRepeats: MessageDTO?
```

**Step 2: Add sheet modifier**

Add after the view body:

```swift
.sheet(item: $selectedMessageForRepeats) { message in
    RepeatDetailsSheet(
        message: message,
        repeats: viewModel.fetchRepeats(for: message),
        contacts: contacts
    )
}
```

**Step 3: Pass handler to UnifiedMessageBubble**

When creating UnifiedMessageBubble instances, add:

```swift
onShowRepeatDetails: { message in
    selectedMessageForRepeats = message
}
```

**Step 4: Add fetchRepeats method to view model**

In the appropriate view model, add method to fetch repeats:

```swift
func fetchRepeats(for message: MessageDTO) -> [MessageRepeatDTO] {
    // Fetch from persistence store or HeardRepeatsService
    // This may need to be async with proper loading state
    return []
}
```

**Step 5: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add PocketMesh/Views/Chats/
git commit -m "feat: wire up RepeatDetailsSheet in channel chat view"
```

---

## Task 11: Configure HeardRepeatsService with Device Info

**Files:**
- Modify: `PocketMeshServices/Sources/PocketMeshServices/ServiceContainer.swift`

**Step 1: Find where device info becomes available and configure service**

In ServiceContainer, after device is loaded or connected:

```swift
// When device info is available (e.g., in connect flow or device setup)
await heardRepeatsService.configure(
    deviceID: device.id,
    localNodeName: device.nodeName ?? "Unknown"
)
```

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/ServiceContainer.swift
git commit -m "feat: configure HeardRepeatsService with device info"
```

---

## Task 12: Add Database Indexes for Performance

**Files:**
- Modify: `PocketMeshServices/Sources/PocketMeshServices/Models/Message.swift`

**Step 1: Add compound index to Message model**

SwiftData uses the `@Index` macro at model level, not `@Attribute(.indexed)`. Add the compound index for the heard repeats query pattern:

```swift
// Update the Message model declaration to add the index
@Model
@Index(\Message.deviceID, \Message.channelIndex, \Message.timestamp)
public final class Message {
    // ... existing properties
}
```

Note: This creates a compound index optimized for the `findSentChannelMessage` query which filters on `(deviceID, channelIndex, timestamp)`.

**Step 2: Build to verify compilation**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add PocketMeshServices/Sources/PocketMeshServices/Models/Message.swift
git commit -m "perf: add compound database index for heard repeats queries"
```

---

## Task 13: Add Unit Tests for HeardRepeatsService

**Files:**
- Create: `PocketMeshServices/Tests/PocketMeshServicesTests/Services/HeardRepeatsServiceTests.swift`

**Step 1: Create the test file**

```swift
// PocketMeshServices/Tests/PocketMeshServicesTests/Services/HeardRepeatsServiceTests.swift
import XCTest
@testable import PocketMeshServices

final class HeardRepeatsServiceTests: XCTestCase {

    // MARK: - ChannelMessageFormat.parse Tests

    func test_parse_validFormat_returnsSenderAndMessage() {
        let result = ChannelMessageFormat.parse("NodeName: Hello world")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.senderName, "NodeName")
        XCTAssertEqual(result?.messageText, "Hello world")
    }

    func test_parse_noColon_returnsNil() {
        let result = ChannelMessageFormat.parse("No colon here")

        XCTAssertNil(result)
    }

    func test_parse_colonAtStart_returnsNil() {
        let result = ChannelMessageFormat.parse(": Message without sender")

        XCTAssertNil(result)
    }

    func test_parse_emptyMessage_returnsEmptyText() {
        let result = ChannelMessageFormat.parse("Sender:")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.senderName, "Sender")
        XCTAssertEqual(result?.messageText, "")
    }

    func test_parse_messageWithColons_onlySplitsOnFirst() {
        let result = ChannelMessageFormat.parse("Sender: Time is 10:30:00")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.senderName, "Sender")
        XCTAssertEqual(result?.messageText, "Time is 10:30:00")
    }

    func test_parse_trimsWhitespaceFromMessage() {
        let result = ChannelMessageFormat.parse("Node:   Padded message   ")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.messageText, "Padded message")
    }

    func test_parse_senderWithSpaces_preservesSpaces() {
        let result = ChannelMessageFormat.parse("Node With Spaces: Message")

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.senderName, "Node With Spaces")
    }
}
```

**Step 2: Build and run tests**

Run: `xcodebuild test -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" -only-testing:PocketMeshServicesTests/HeardRepeatsServiceTests 2>&1 | xcsift`
Expected: All tests pass

**Step 3: Commit**

```bash
git add PocketMeshServices/Tests/PocketMeshServicesTests/Services/HeardRepeatsServiceTests.swift
git commit -m "test: add unit tests for ChannelMessageFormat parsing"
```

---

## Task 14: Final Integration Testing

**Step 1: Build full project**

Run: `xcodebuild build -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: BUILD SUCCEEDED

**Step 2: Run existing tests**

Run: `xcodebuild test -scheme PocketMesh -destination "platform=iOS Simulator,name=iPhone 16e" 2>&1 | xcsift`
Expected: All tests pass

**Step 3: Manual testing checklist**

- [ ] Send a channel message
- [ ] Verify "Delivered" status shows initially
- [ ] Wait for repeats (requires actual mesh network)
- [ ] Verify status updates to "Delivered • N repeats"
- [ ] Long-press message, verify "N Heard Repeats" menu item
- [ ] Tap menu item, verify sheet opens
- [ ] Verify empty state shows "No repeats yet" when no repeats
- [ ] Verify repeat rows show repeater info correctly

**Step 4: Final commit**

```bash
git add .
git commit -m "feat: complete heard repeats feature implementation"
```

---

## Summary

| Task | Component | Status |
|------|-----------|--------|
| 1 | ChannelMessageFormat parsing utility | ⬜ |
| 2 | MessageRepeat model + cascade delete | ⬜ |
| 3 | PersistenceStore queries | ⬜ |
| 4 | HeardRepeatsService actor | ⬜ |
| 5 | RxLogService integration | ⬜ |
| 6 | Status text update | ⬜ |
| 7 | Context menu item | ⬜ |
| 8 | RepeatRowView + accessibility | ⬜ |
| 9 | RepeatDetailsSheet | ⬜ |
| 10 | Sheet presentation wiring | ⬜ |
| 11 | Device configuration | ⬜ |
| 12 | Database compound index | ⬜ |
| 13 | Unit tests | ⬜ |
| 14 | Integration testing | ⬜ |
