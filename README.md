[![Pub Version](https://img.shields.io/pub/v/chatwoot_flutter_sdk?color=blueviolet)](https://pub.dev/packages/chatwoot_flutter_sdk)

# Chatwoot Flutter SDK

Integrate Chatwoot's real-time messaging capabilities into your Flutter app with ease. This comprehensive SDK provides both WebView-based widgets and native Flutter implementations for seamless customer support integration.

[Chatwoot](https://github.com/chatwoot/chatwoot) is an open-source customer engagement platform that helps you connect with your visitors and provide exceptional support in real time.

<img src="https://user-images.githubusercontent.com/22669874/225545427-bd3fe38c-d116-4286-b542-67b03a51e2d2.jpg" alt="chatwoot screenshot" height="560"/>

## ✨ Features

- 🚀 **Easy Integration** - Simple setup with WebView or native Flutter widgets
- 💬 **Real-time Messaging** - WebSocket-powered live chat
- 📱 **Cross Platform** - Works on iOS, Android, and other Flutter platforms
- 💾 **Offline Support** - Local message persistence with Hive
- 📎 **File Attachments** - Support for image and file sharing
- 🎨 **Customizable UI** - Build your own chat interface or use pre-built widgets
- 🔔 **Event Callbacks** - Handle typing indicators, message status, and more
- 🌍 **Internationalization** - Multi-language support

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  chatwoot_flutter_sdk: ^0.0.1
```

Or install via command line:

```bash
flutter pub add chatwoot_flutter_sdk
```

## 🚀 Quick Start

### Option 1: WebView Widget (Recommended for Quick Setup)

The easiest way to integrate Chatwoot is using the `ChatwootWidget`, which provides a full-featured chat interface in a WebView.

#### Setup:
1. Create a **Website Channel** in your Chatwoot dashboard ([Guide](https://www.chatwoot.com/docs/channels/website))
2. Get your `websiteToken` and `baseUrl`

```dart
import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ChatPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Customer Support')),
      body: ChatwootWidget(
        websiteToken: 'your-website-token-here',
        baseUrl: 'https://your-chatwoot-instance.com',
        user: ChatwootUser(
          identifier: 'user@example.com',
          name: 'John Doe',
          email: 'user@example.com',
        ),
        locale: 'en',
        onAttachFile: () async {
          // File picker implementation
          final result = await FilePicker.platform.pickFiles(
            allowMultiple: true,
            type: FileType.any,
          );
          return result?.paths.where((path) => path != null).cast<String>().toList() ?? [];
        },
        onLoadStarted: () => print('Chat loading...'),
        onLoadCompleted: () => print('Chat loaded!'),
      ),
    );
  }
}
```

That's it! Your chat widget is ready. 🎉


### Option 2: Native Flutter Implementation

For more control over the UI and advanced features, use `ChatwootClient` to build your own chat interface.

#### Setup:
1. Create an **API Channel** in your Chatwoot dashboard ([Guide](https://www.chatwoot.com/docs/product/channels/api/create-channel))
2. Get your `inboxIdentifier` and `baseUrl`

#### Example: Custom Chat Page

```dart
import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:flutter/material.dart';

class CustomChatPage extends StatefulWidget {
  @override
  _CustomChatPageState createState() => _CustomChatPageState();
}

class _CustomChatPageState extends State<CustomChatPage> {
  ChatwootClient? _client;
  final List<ChatwootMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      _client = await ChatwootClient.create(
        baseUrl: 'https://your-chatwoot-instance.com',
        inboxIdentifier: 'your-inbox-identifier',
        user: ChatwootUser(
          identifier: 'user@example.com',
          name: 'John Doe',
          email: 'user@example.com',
        ),
        enablePersistence: true,
        callbacks: ChatwootCallbacks(
          onWelcome: () => print('Chat connected! 🎉'),
          onMessageReceived: (message) {
            setState(() {
              _messages.add(message);
            });
          },
          onMessageSent: (message, echoId) => print('Message sent ✅'),
          onMessageDelivered: (message, echoId) => print('Message delivered ✅'),
          onConversationStartedTyping: () => print('Agent is typing...'),
          onConversationStoppedTyping: () => print('Agent stopped typing'),
          onError: (error) => print('Error: ${error.cause}'),
        ),
      );

      // Load previous messages
      _client?.loadMessages();
    } catch (error) {
      print('Failed to initialize chat: $error');
    }
  }

  void _sendMessage() {
    if (_controller.text.trim().isNotEmpty) {
      _client?.sendMessage(
        content: _controller.text.trim(),
        echoId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Custom Chat')),
      body: Column(
        children: [
          // Connection status
          Container(
            padding: EdgeInsets.all(8),
            color: _client != null ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                Icon(_client != null ? Icons.check_circle : Icons.error),
                SizedBox(width: 8),
                Text(_client != null ? 'Connected' : 'Connecting...'),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.messageType == 1;

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          message.content ?? '',
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _sendMessage,
                  child: Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _client?.dispose();
    _controller.dispose();
    super.dispose();
  }
}
```

## 📋 Widget Parameters

### ChatwootWidget Parameters

| Parameter        | Type                            | Required | Description                                    |
|------------------|---------------------------------|----------|------------------------------------------------|
| `websiteToken`   | `String`                        | ✅       | Website inbox channel token                   |
| `baseUrl`        | `String`                        | ✅       | Your Chatwoot instance URL                    |
| `user`           | `ChatwootUser`                  | ✅       | User information (email, name, etc.)          |
| `locale`         | `String`                        | ❌       | User locale (default: 'en')                   |
| `customAttributes` | `Map<String, dynamic>`        | ❌       | Additional customer information               |
| `onAttachFile`   | `Future<List<String>> Function()` | ❌       | File attachment handler                       |
| `onLoadStarted`  | `void Function()`               | ❌       | Widget load start callback                    |
| `onLoadProgress` | `void Function(int)`            | ❌       | Widget load progress callback                 |
| `onLoadCompleted` | `void Function()`              | ❌       | Widget load completed callback                |
| `closeWidget`    | `void Function()`               | ❌       | Widget close callback                         |

### ChatwootClient Parameters

| Parameter         | Type                | Required | Description                                   |
|-------------------|---------------------|----------|-----------------------------------------------|
| `baseUrl`         | `String`            | ✅       | Your Chatwoot instance URL                   |
| `inboxIdentifier` | `String`            | ✅       | API inbox identifier                         |
| `user`            | `ChatwootUser`      | ✅       | User information                             |
| `enablePersistence` | `bool`            | ❌       | Enable local data storage (default: true)   |
| `callbacks`       | `ChatwootCallbacks` | ❌       | Event callbacks                              |

## 🔔 Available Callbacks

The `ChatwootCallbacks` class provides handlers for various chat events:

```dart
ChatwootCallbacks(
  onWelcome: () => print('Welcome! Chat is ready 🎉'),
  onPing: () => print('Connection ping received'),
  onConfirmedSubscription: () => print('Successfully connected to chat'),
  onConversationStartedTyping: () => print('Agent is typing...'),
  onConversationStoppedTyping: () => print('Agent stopped typing'),
  onConversationIsOnline: () => print('Agent is online'),
  onConversationIsOffline: () => print('Agent is offline'),
  onMessageReceived: (message) => print('New message: ${message.content}'),
  onMessageSent: (message, echoId) => print('Message sent successfully'),
  onMessageDelivered: (message, echoId) => print('Message delivered'),
  onPersistedMessagesRetrieved: (messages) => print('Loaded ${messages.length} cached messages'),
  onMessagesRetrieved: (messages) => print('Loaded ${messages.length} messages from server'),
  onConversationResolved: () => print('Conversation resolved'),
  onError: (error) => print('Chat error: ${error.cause}'),
)
```

## 💾 Data Persistence

The SDK uses [Hive](https://pub.dev/packages/hive) for local storage, providing:

- **Offline Message Access**: View previous conversations without internet
- **Seamless Experience**: Continue conversations across app sessions
- **Automatic Sync**: Messages sync when connection is restored

```dart
// Enable persistence (default: true)
ChatwootClient.create(
  enablePersistence: true,
  // ... other parameters
);

// Clear local data
await client.clearClientData();  // Clear current user's data
await ChatwootClient.clearAllData();  // Clear all stored data
```

## 📚 Example App

Check out our comprehensive [example app](example/) that demonstrates:

- ✅ **WebView Chat Widget** - Full-featured chat interface
- ✅ **Custom Flutter Chat** - Native Flutter implementation using `flutter_chat_ui`
- ✅ **File Attachments** - Image and file sharing
- ✅ **Real-time Events** - Connection status, typing indicators
- ✅ **Persistence** - Offline message access
- ✅ **Error Handling** - Graceful error management

Run the example:
```bash
cd example
flutter run
```

## 🤝 Contributing

We welcome contributions! Please see our [Development Guide](doc/Develop.md) for details on:

- Setting up the development environment
- Running tests
- Submitting pull requests
- Code style guidelines

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 [Documentation](https://www.chatwoot.com/docs/)
- 💬 [Community Discussions](https://github.com/chatwoot/chatwoot/discussions)
- 🐛 [Bug Reports](https://github.com/chatwoot/chatwoot-flutter-sdk/issues)
- 📧 [Email Support](mailto:support@chatwoot.com)

---

Made with ❤️ by the [Chatwoot](https://www.chatwoot.com) team
