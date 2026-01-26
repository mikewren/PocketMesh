import SwiftUI

/// Settings section for message display preferences
struct MessagesSettingsSection: View {
    @AppStorage("showIncomingRoutingInfo") private var showRoutingInfo = false

    var body: some View {
        Section {
            Toggle(L10n.Settings.Messages.showRoutingInfo, isOn: $showRoutingInfo)
        } header: {
            Text(L10n.Settings.Messages.header)
        } footer: {
            Text(L10n.Settings.Messages.showRoutingInfoFooter)
        }
    }
}

#Preview {
    Form {
        MessagesSettingsSection()
    }
}
