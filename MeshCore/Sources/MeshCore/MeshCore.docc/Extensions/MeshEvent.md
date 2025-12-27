# ``MeshCore/MeshEvent``

@Metadata {
    @DocumentationExtension(mergeBehavior: append)
}

## Topics

### Connection Lifecycle

- ``connectionStateChanged(_:)``

### Command Responses

- ``ok(value:)``
- ``error(code:)``

### Device Information

- ``selfInfo(_:)``
- ``deviceInfo(_:)``
- ``battery(_:)``
- ``currentTime(_:)``
- ``customVars(_:)``
- ``channelInfo(_:)``
- ``statsCore(_:)``
- ``statsRadio(_:)``
- ``statsPackets(_:)``

### Contact Management

- ``contactsStart(count:)``
- ``contact(_:)``
- ``contactsEnd(lastModified:)``
- ``newContact(_:)``
- ``contactURI(_:)``

### Messaging

- ``messageSent(_:)``
- ``contactMessageReceived(_:)``
- ``channelMessageReceived(_:)``
- ``noMoreMessages``
- ``messagesWaiting``

### Network Events

- ``advertisement(publicKey:)``
- ``pathUpdate(publicKey:)``
- ``acknowledgement(code:)``
- ``traceData(_:)``
- ``pathResponse(_:)``

### Authentication

- ``loginSuccess(_:)``
- ``loginFailed(publicKeyPrefix:)``

### Binary Protocol

- ``statusResponse(_:)``
- ``telemetryResponse(_:)``
- ``binaryResponse(tag:data:)``
- ``mmaResponse(_:)``
- ``aclResponse(_:)``
- ``neighboursResponse(_:)``

### Cryptographic Signing

- ``signStart(maxLength:)``
- ``signature(_:)``
- ``disabled(reason:)``

### Raw Data

- ``rawData(_:)``
- ``logData(_:)``
- ``rxLogData(_:)``
- ``controlData(_:)``
- ``discoverResponse(_:)``
- ``privateKey(_:)``

### Diagnostics

- ``parseFailure(data:reason:)``
