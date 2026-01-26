import Foundation

/// Provides localized strings for notifications.
///
/// This protocol allows the app layer to inject localized strings into
/// PocketMeshServices without the service layer depending on L10n directly.
public protocol NotificationStringProvider: Sendable {
    /// Returns the notification title for a discovered contact of the given type.
    /// - Parameter type: The type of contact discovered
    /// - Returns: Localized notification title (e.g., "New Repeater Discovered")
    func discoveryNotificationTitle(for type: ContactType) -> String
}
