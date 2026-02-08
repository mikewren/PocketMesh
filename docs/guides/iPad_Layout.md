# iPad Layout Guide

This guide describes how PocketMesh adapts its UI for iPad.

## Overview

PocketMesh uses a `TabView` (see `PocketMesh/ContentView.swift`) with five tabs:

- Chats (0)
- Nodes (1)
- Map (2)
- Tools (3)
- Settings (4)

Within each tab, the root view typically chooses between:

- `NavigationSplitView` when horizontal size class is `.regular` (common on iPad)
- `NavigationStack` when horizontal size class is `.compact` (iPhone, iPad in split view)

This keeps iPad navigation efficient without maintaining a separate iPad-only navigation model.

## Split View Pattern

In regular size class, split views follow a consistent pattern:

- Left column: list/selection
- Right column: detail content (or an empty placeholder until a selection exists)

Concrete implementations in this repo:

- Chats: `PocketMesh/Views/Chats/ChatsView.swift`
- Nodes: `PocketMesh/Views/Contacts/ContactsListView.swift`
- Tools: `PocketMesh/Views/Tools/ToolsView.swift`
- Settings: `PocketMesh/Views/Settings/SettingsView.swift`

The Map tab uses a single `NavigationStack` for all size classes:

- Map: `PocketMesh/Views/Map/MapView.swift`

## Testing

Use an iPad simulator destination when running from the command line:

```bash
xcodebuild test -project PocketMesh.xcodeproj \
  -scheme PocketMesh \
  -destination "platform=iOS Simulator,name=iPad Pro (13-inch)"
```

## Common Pitfalls

- Ensure app-wide state is accessed via `@Environment(\.appState)`.
- Avoid coupling selection state between tabs; each tab owns its own split-view selection.

## Further Reading

- [Development Guide](../Development.md)
- [Architecture Overview](../Architecture.md)
- [User Guide](../User_Guide.md)
