import 'package:flutter/material.dart';
import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action_data.dart';
import 'package:file_picker/file_picker.dart';
import 'custom_chat_page.dart';

void main() {
  runApp(const ChatwootExampleApp());
}

class ChatwootExampleApp extends StatelessWidget {
  const ChatwootExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatwoot SDK Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatwootHomePage(),
    );
  }
}

class ChatwootHomePage extends StatefulWidget {
  const ChatwootHomePage({super.key});

  @override
  State<ChatwootHomePage> createState() => _ChatwootHomePageState();
}

class _ChatwootHomePageState extends State<ChatwootHomePage> {
  ChatwootClient? _chatwootClient;
  bool _isConnected = false;
  String _status = 'Not connected';
  final List<String> _messages = [];

  // Demo configuration - Replace with your actual Chatwoot instance details
  final String _baseUrl = 'https://app.chatwoot.app';
  final String _inboxIdentifier = 'FJuAD272ZhPMDPmc4ciorqx7d4F';

  @override
  void initState() {
    super.initState();
    _initializeChatwoot();
  }

  void _initializeChatwoot() async {
    try {
      _chatwootClient = await ChatwootClient.create(
        baseUrl: _baseUrl,
        inboxIdentifier: _inboxIdentifier,
        user: ChatwootUser(
          identifier: 'user@example.com',
          name: 'Test User',
          email: 'user@example.com',
        ),
        enablePersistence: true,
        callbacks: ChatwootCallbacks(
          onWelcome: () {
            setState(() {
              _status = 'Welcome message received';
              _messages.add('📋 Welcome message received');
            });
          },
          onPing: () {
            setState(() {
              _status = 'Ping received';
              _messages.add('🏓 Ping received');
            });
          },
          onConfirmedSubscription: () {
            setState(() {
              _isConnected = true;
              _status = 'Connected to Chatwoot';
              _messages.add('✅ Connected to Chatwoot');
            });
          },
          onConversationStartedTyping: () {
            setState(() {
              _status = 'Agent is typing...';
              _messages.add('⌨️ Agent is typing...');
            });
          },
          onConversationStoppedTyping: () {
            setState(() {
              _status = 'Agent stopped typing';
              _messages.add('✋ Agent stopped typing');
            });
          },
          onPersistedMessagesRetrieved: (messages) {
            setState(() {
              _status = 'Loaded ${messages.length} persisted messages';
              _messages.add('📱 Loaded ${messages.length} persisted messages');
            });
          },
          onMessagesRetrieved: (messages) {
            setState(() {
              _status = 'Retrieved ${messages.length} messages';
              _messages.add('📬 Retrieved ${messages.length} messages');
            });
          },
          onMessageReceived: (message) {
            setState(() {
              _status = 'New message received';
              _messages.add('💬 Message: ${message.content}');
            });
          },
          onMessageSent: (message, echoId) {
            setState(() {
              _status = 'Message sent successfully';
              _messages.add('📤 Sent: ${message.content}');
            });
          },
          onMessageDelivered: (message, echoId) {
            setState(() {
              _status = 'Message delivered';
              _messages.add('✅ Delivered: ${message.content}');
            });
          },
          onConversationResolved: () {
            setState(() {
              _status = 'Conversation resolved';
              _messages.add('🎯 Conversation resolved');
            });
          },
          onError: (error) {
            setState(() {
              _status = 'Error: ${error.type}';
              _messages.add('❌ Error: ${error.toString()}');
            });
          },
        ),
      );

      setState(() {
        _status = 'Chatwoot client initialized';
        _messages.add('🚀 Chatwoot client initialized');
      });
    } catch (e) {
      setState(() {
        _status = 'Failed to initialize: $e';
        _messages.add('❌ Failed to initialize: $e');
      });
    }
  }

  void _sendMessage() {
    if (_chatwootClient != null && _isConnected) {
      _chatwootClient!.sendMessage(
        content: 'Hello from Flutter example app!',
        echoId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to Chatwoot')),
      );
    }
  }

  void _toggleTyping() {
    if (_chatwootClient != null && _isConnected) {
      _chatwootClient!.sendAction(ChatwootActionType.update_presence);
    }
  }

  void _openChatPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Chatwoot Chat')),
          body: ChatwootWidget(
            websiteToken: _inboxIdentifier,
            baseUrl: _baseUrl,
            user: ChatwootUser(
              identifier: 'user@example.com',
              name: 'Test User',
              email: 'user@example.com',
            ),
            locale: 'en',
            onAttachFile: _androidFilePicker,
            closeWidget: () {
              Navigator.pop(context);
            },
            onLoadStarted: () {
              setState(() {
                _messages.add('📱 Chat widget loading started');
              });
            },
            onLoadCompleted: () {
              setState(() {
                _messages.add('✅ Chat widget loaded successfully');
              });
            },
            onLoadProgress: (progress) {
              setState(() {
                _messages.add('⏳ Chat widget loading: $progress%');
              });
            },
          ),
        ),
      ),
    );
  }

  void _openCustomChatPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomChatPage(
          baseUrl: _baseUrl,
          inboxIdentifier: _inboxIdentifier,
          user: ChatwootUser(
            identifier: 'user@example.com',
            name: 'Test User',
            email: 'user@example.com',
          ),
          title: 'Custom Flutter Chat',
        ),
      ),
    );
  }

  void _openChatDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(
          height: 500,
          width: 400,
          child: Column(
            children: [
              AppBar(
                title: const Text('Chatwoot Support'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: ChatwootWidget(
                  websiteToken: _inboxIdentifier,
                  baseUrl: _baseUrl,
                  user: ChatwootUser(
                    identifier: 'user@example.com',
                    name: 'Test User',
                    email: 'user@example.com',
                  ),
                  locale: 'en',
                  onAttachFile: _androidFilePicker,
                  closeWidget: () => Navigator.of(context).pop(),
                  onLoadStarted: () {
                    setState(() {
                      _messages.add('📱 Dialog chat widget loading started');
                    });
                  },
                  onLoadCompleted: () {
                    setState(() {
                      _messages.add('✅ Dialog chat widget loaded successfully');
                    });
                  },
                  onLoadProgress: (progress) {
                    setState(() {
                      _messages.add('⏳ Dialog chat widget loading: $progress%');
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _loadMessages() {
    if (_chatwootClient != null) {
      _chatwootClient!.loadMessages();
    }
  }

  void _clearData() {
    if (_chatwootClient != null) {
      _chatwootClient!.clearClientData();
      setState(() {
        _messages.clear();
        _messages.add('🧹 Data cleared');
      });
    }
  }

  /// File picker implementation for chat attachments
  Future<List<String>> _androidFilePicker() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
        List<String> filePaths = result.paths
            .where((path) => path != null)
            .map((path) => path!)
            .toList();

        setState(() {
          _messages.add(
            '📎 Selected ${filePaths.length} file(s) for attachment',
          );
        });

        return filePaths;
      } else {
        setState(() {
          _messages.add('📎 File selection cancelled');
        });
        return [];
      }
    } catch (e) {
      setState(() {
        _messages.add('❌ Error selecting files: $e');
      });
      return [];
    }
  }

  @override
  void dispose() {
    _chatwootClient?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Chatwoot SDK Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle : Icons.error,
                          color: _isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_status)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Message'),
                ),
                ElevatedButton.icon(
                  onPressed: _toggleTyping,
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Update Presence'),
                ),
                ElevatedButton.icon(
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Load Messages'),
                ),
                ElevatedButton.icon(
                  onPressed: _clearData,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear Data'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _openChatPage,
                  icon: const Icon(Icons.chat),
                  label: const Text('Open Chat Page'),
                ),
                ElevatedButton.icon(
                  onPressed: _openCustomChatPage,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Custom Flutter Chat'),
                ),
                ElevatedButton.icon(
                  onPressed: _openChatDialog,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('Open Chat Dialog'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Activity Log',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: _messages.isEmpty
                    ? const Center(child: Text('No activity yet'))
                    : ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            dense: true,
                            title: Text(
                              _messages[_messages.length - 1 - index],
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initializeChatwoot,
        tooltip: 'Reconnect',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
