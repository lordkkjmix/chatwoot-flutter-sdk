# Chatwoot Flutter SDK Example

This example app demonstrates how to integrate the Chatwoot Flutter SDK into your application. It showcases all the main features and capabilities of the SDK.

## Features Demonstrated

### Core Features
- ✅ **Client Initialization** - Create and configure Chatwoot client instance
- ✅ **User Authentication** - Set up user details for conversations
- ✅ **Message Handling** - Send and receive messages
- ✅ **Real-time Events** - Handle websocket events and callbacks
- ✅ **Data Persistence** - Enable/disable local data storage

### UI Components
- ✅ **Chat Page** - Full-screen chat interface using ChatwootWidget
- ✅ **Custom Flutter Chat** - Pure Flutter chat UI with `flutter_chat_ui`
- ✅ **Chat Dialog** - Modal chat interface using ChatwootWidget
- ✅ **File Attachments** - File picker integration for chat attachments
- ✅ **Custom Callbacks** - Handle all Chatwoot events

### Actions & Operations
- ✅ **Send Messages** - Send text messages to agents
- ✅ **Load Messages** - Retrieve conversation history
- ✅ **File Attachments** - Pick and attach files to messages
- ✅ **Presence Updates** - Send user presence information
- ✅ **Data Management** - Clear client data
- ✅ **Connection Status** - Monitor connection state

## Setup Instructions

### 1. Update Configuration

Before running the example, update the configuration variables in `lib/main.dart`:

```dart
// Replace with your actual Chatwoot instance details
final String _baseUrl = 'https://your-chatwoot-instance.com';
final String _inboxIdentifier = 'your-inbox-identifier';
```

### 2. Get Dependencies

```bash
cd example
flutter pub get
```

### 3. Run the Example

```bash
flutter run
```

## Configuration Details

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `baseUrl` | Your Chatwoot instance URL | `https://app.chatwoot.com` |
| `inboxIdentifier` | Inbox identifier from Chatwoot dashboard | `abc123def456` |

### User Configuration

The example creates a test user with the following details:

```dart
ChatwootUser(
  identifier: 'user@example.com',
  name: 'Test User',
  email: 'user@example.com',
)
```

You can modify these values to match your testing requirements.

### File Picker Configuration

The example includes file attachment functionality using the `file_picker` package:

```dart
Future<List<String>> _androidFilePicker() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    type: FileType.any,
  );
  // Returns list of file paths for attachment
}
```

This is integrated with the ChatwootWidget:

```dart
ChatwootWidget(
  // ... other parameters
  onAttachFile: _androidFilePicker, // File picker integration
  onLoadStarted: () => /* handle load start */,
  onLoadCompleted: () => /* handle load complete */,
  onLoadProgress: (progress) => /* handle progress */,
)
```

### Custom Flutter Chat Implementation

The example includes a full Flutter chat page (`CustomChatPage`) that demonstrates:

- **Pure Flutter UI**: Built with `flutter_chat_ui` package for rich messaging interface
- **Real-time Integration**: Direct integration with Chatwoot SDK for live messaging
- **Message Types**: Support for text, images, and file attachments
- **Connection Status**: Visual indicators for connection health and agent presence
- **Typing Indicators**: Real-time typing status from agents
- **Message Status**: Delivery and read status indicators
- **File Attachments**: Integrated file picker for sending attachments

Key features of the custom implementation:

```dart
CustomChatPage(
  baseUrl: 'https://your-chatwoot-instance.com',
  inboxIdentifier: 'your-inbox-identifier',
  user: ChatwootUser(
    identifier: 'user@example.com',
    name: 'Test User',
    email: 'user@example.com',
  ),
  title: 'Custom Flutter Chat',
)
```

This demonstrates how to build a completely custom chat interface while leveraging all the Chatwoot SDK capabilities for real-time messaging, persistence, and agent communication.

## Features Overview

### Connection Status Card
- Shows current connection state
- Displays real-time status updates
- Visual indicators for connection health

### Action Buttons
- **Send Message**: Sends a test message to the conversation
- **Update Presence**: Notifies the server of user activity
- **Load Messages**: Retrieves conversation history
- **Clear Data**: Removes local conversation data

### UI Components
- **Open Chat Page**: Launches full-screen chat interface using ChatwootWidget
- **Custom Flutter Chat**: Full Flutter implementation with advanced chat UI
- **Open Chat Dialog**: Shows modal chat interface using ChatwootWidget

### File Attachment Features
- **File Picker Integration**: Uses `file_picker` package for selecting attachments
- **Multiple File Selection**: Supports selecting multiple files at once
- **Cross-platform Support**: Works on Android, iOS, and other platforms
- **Activity Logging**: Shows file selection events in the activity log

### Activity Log
- Real-time display of all SDK events
- Chronological list of actions and responses
- Useful for debugging and understanding SDK behavior

## Callback Events

The example demonstrates handling of all Chatwoot callback events:

- `onWelcome` - Welcome message received
- `onPing` - Ping event received
- `onConfirmedSubscription` - Connection established
- `onConversationStartedTyping` - Agent started typing
- `onConversationStoppedTyping` - Agent stopped typing
- `onPersistedMessagesRetrieved` - Local messages loaded
- `onMessagesRetrieved` - Remote messages loaded
- `onMessageReceived` - New message from agent
- `onMessageSent` - Message sent successfully
- `onMessageDelivered` - Message delivered confirmation
- `onConversationResolved` - Conversation closed
- `onError` - Error occurred

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Verify your `baseUrl` is correct and accessible
   - Check your `inboxIdentifier` is valid
   - Ensure your Chatwoot instance is running

2. **Messages Not Sending**
   - Confirm you're connected (check status indicator)
   - Verify the inbox is properly configured
   - Check for error messages in the activity log

3. **UI Components Not Loading**
   - Ensure all required parameters are provided
   - Check for any dependency issues

### Debug Mode

The activity log shows all SDK events in real-time. Use this to:
- Monitor connection status
- Track message flow
- Identify error conditions
- Understand SDK behavior

## Testing

The example includes widget tests that verify:
- App loads correctly
- All UI components are present
- Action buttons are displayed

Run tests with:
```bash
flutter test
```

## Next Steps

After running the example successfully:

1. **Customize the UI** - Modify the chat theme and appearance
2. **Add Custom Features** - Implement additional functionality
3. **Production Setup** - Configure for your production environment
4. **Error Handling** - Add robust error handling for your use case

## Support

For more information:
- [Chatwoot Documentation](https://www.chatwoot.com/docs/)
- [Flutter SDK GitHub Repository](https://github.com/chatwoot/chatwoot-flutter-sdk)
- [Chatwoot Community](https://github.com/chatwoot/chatwoot/discussions)
