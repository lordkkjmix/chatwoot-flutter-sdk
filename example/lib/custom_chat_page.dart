import 'dart:io';

import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';

/// A fully custom Flutter chat page implementation using Chatwoot SDK
/// This demonstrates how to build a complete chat interface using pure Flutter widgets
/// and integrating with the Chatwoot real-time messaging system
class CustomChatPage extends StatefulWidget {
  final String baseUrl;
  final String inboxIdentifier;
  final ChatwootUser user;
  final String title;

  const CustomChatPage({
    super.key,
    required this.baseUrl,
    required this.inboxIdentifier,
    required this.user,
    this.title = 'Chat',
  });

  @override
  State<CustomChatPage> createState() => _CustomChatPageState();
}

class _CustomChatPageState extends State<CustomChatPage> {
  ChatwootClient? _chatwootClient;
  final List<types.Message> _messages = [];
  bool _isConnected = false;
  bool _isTyping = false;
  bool _isAgentOnline = false;
  String _connectionStatus = 'Connecting...';
  final TextEditingController _controller = TextEditingController();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;

  // Create a user for the chat interface
  late final types.User _user;
  late final types.User _agent;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _initializeUsers();
    _controller.dispose();
    _initializeChatwoot();
    _initRecorder();
  }

  void _initializeUsers() {
    _user = types.User(
      id: widget.user.identifier ?? 'user',
      firstName: widget.user.name?.split(' ').first,
      lastName: widget.user.name?.split(' ').skip(1).join(' '),
      imageUrl: widget.user.avatarUrl,
    );

    _agent = const types.User(
      id: 'agent',
      firstName: 'Support',
      lastName: 'Agent',
    );
  }

  // helper para pedir permisos
  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.camera.request();
    await Permission.storage.request();
    await Permission.photos.request();
    await Permission.phone.request();
  }

  void _initializeChatwoot() async {
    try {
      _chatwootClient = await ChatwootClient.create(
        baseUrl: widget.baseUrl,
        inboxIdentifier: widget.inboxIdentifier,
        user: widget.user,
        enablePersistence: true,
        callbacks: ChatwootCallbacks(
          onWelcome: () {
            setState(() {
              _connectionStatus = 'Connected';
            });
          },
          onConfirmedSubscription: () {
            setState(() {
              _isConnected = true;
              _connectionStatus = 'Connected';
            });
            _loadMessages();
          },
          onConversationStartedTyping: () {
            setState(() {
              _isTyping = true;
            });
          },
          onConversationStoppedTyping: () {
            setState(() {
              _isTyping = false;
            });
          },
          onConversationIsOnline: () {
            setState(() {
              _isAgentOnline = true;
            });
          },
          onConversationIsOffline: () {
            setState(() {
              _isAgentOnline = false;
            });
          },
          onMessageReceived: (message) {
            print('>>>>>>>>>>>> onMessageReceived');
            _addMessage(_convertChatwootMessageToType(message, _agent));
          },
          onMessageSent: (message, echoId) {
            // Message already added when sending
          },
          onMessageDelivered: (message, echoId) {
            print('>>>>>>>>>>>> onMessageDelivered');
            _updateMessageStatus(echoId, types.Status.delivered);
          },
          onPersistedMessagesRetrieved: (messages) {
            _loadPersistedMessages(messages);
          },
          onMessagesRetrieved: (messages) {
            _loadRemoteMessages(messages);
          },
          onError: (error) {
            setState(() {
              _connectionStatus = 'Error: ${error.type}';
            });
            _showErrorSnackBar('Error: ${error.toString()}');
          },
          onConversationResolved: () {

          },
        ),
      );
    } catch (e) {
      setState(() {
        _connectionStatus = 'Failed to connect';
      });
      _showErrorSnackBar('Failed to initialize chat: $e');
    }
  }

  void _loadMessages() {
    _chatwootClient?.loadMessages();
  }

  void _loadPersistedMessages(List<ChatwootMessage> messages) {
    setState(() {
      final convertedMessages = messages
          .map((msg) => _convertChatwootMessageToType(
              msg, msg.messageType == 1 ? _user : _agent))
          .toList();
      _messages.insertAll(0, convertedMessages.reversed);
    });
  }

  void _loadRemoteMessages(List<ChatwootMessage> messages) {
    setState(() {
      _messages.clear();
      final convertedMessages = messages
          .map((msg) => _convertChatwootMessageToType(
              msg, msg.messageType == 1 ? _user : _agent))
          .toList();
      _messages.addAll(convertedMessages.reversed);
    });
  }

  types.Message _convertChatwootMessageToType(ChatwootMessage chatwootMessage, types.User author) {
    // Handle different message types
    if (chatwootMessage.attachments?.isNotEmpty == true) {
      final attachment = chatwootMessage.attachments!.first;
      print('>>>>>>>>>>>> $attachment');
      //print('>>>>>>>>>>>> ${attachment.file_type}');
      if (attachment is Map<String, dynamic>) {
        print('>>>>>>>>>>>> ${attachment['file_type']}');

        final fileType = attachment['file_type']?.toString();
        final dataUrl = attachment['data_url']?.toString();
        if (fileType != null && fileType == 'image') { //!.startsWith('image/')
          return types.ImageMessage(
            author: author,
            createdAt: DateTime
                .parse(chatwootMessage.createdAt)
                .millisecondsSinceEpoch,
            id: chatwootMessage.id.toString(),
            name: dataUrl
                ?.split('/')
                .last ?? 'image',
            size: fileType?.length.toDouble() ?? 0,
            uri: dataUrl ?? '',
          );
        } else {
          if (fileType != null && fileType == 'audio') {
            print('>>>>>>>>>>>> Ingreso audios jkkjsdkjsajkd ');
            return types.AudioMessage(
              author: author,
              createdAt: DateTime
                  .parse(chatwootMessage.createdAt)
                  .millisecondsSinceEpoch,
              id: chatwootMessage.id.toString(),
              name: dataUrl
                  ?.split('/')
                  .last ?? 'audio',
              size: fileType?.length.toDouble() ?? 0,
              uri: dataUrl ?? '',
              duration: Duration(seconds: 10),
            );
          } else {
            return types.FileMessage(
              author: author,
              createdAt: DateTime
                  .parse(chatwootMessage.createdAt)
                  .millisecondsSinceEpoch,
              id: chatwootMessage.id.toString(),
              name: dataUrl
                  ?.split('/')
                  .last ?? 'file',
              size: fileType?.length.toDouble() ?? 0,
              uri: dataUrl ?? '',
            );
          }
        }
      }
    }

    // Default to text message
    return types.TextMessage(
      author: author,
      createdAt: DateTime.parse(chatwootMessage.createdAt).millisecondsSinceEpoch,
      id: chatwootMessage.id.toString(),
      text: chatwootMessage.content ?? '',
    );
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _updateMessageStatus(String messageId, types.Status status) {
    setState(() {
      final index = _messages.indexWhere((msg) => msg.id == messageId);
      if (index != -1) {
        final message = _messages[index];
        if (message is types.TextMessage) {
          _messages[index] = message.copyWith(status: status);
        }
      }
    });
  }

  void _handleSendPressed(types.PartialText message) {
    if (_chatwootClient == null || !_isConnected) {
      _showErrorSnackBar('Not connected to chat service');
      return;
    }

    final echoId = const Uuid().v4();
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: echoId,
      text: message.text,
      status: types.Status.sending,
    );

    _addMessage(textMessage);

    // Send message through Chatwoot client
    _chatwootClient!.sendMessage(
      content: message.text,
      echoId: echoId,
    );

    // Update presence
    _chatwootClient!.sendAction(ChatwootActionType.update_presence);
  }

  void _handleAttachmentPressed() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        String filePath = result.files.single.path!;
        String fileName = result.files.single.name;
        final fileTemp = result.files.first;

        // Detectar tipo MIME
        final mimeType = lookupMimeType(filePath) ?? '';
        print('Tipo MIME detectado: $mimeType');

        // Determinar tipo de archivo según MIME
        String fileType;
        if (mimeType.startsWith('image/')) {
          fileType = 'image';
        } else if (mimeType.startsWith('audio/')) {
          fileType = 'audio';
        } else if (mimeType.startsWith('video/')) {
          fileType = 'video';
        } else {
          fileType = 'file';
        }

        print('Tipo clasificado: $fileType');

        // Convert the file to base64
        List<int> fileBytes = await File(filePath).readAsBytes();

        //convert filepath into uri
        final tempUri = (await getTemporaryDirectory()).uri.resolve(fileName);
        final file = await File.fromUri(tempUri).create(recursive: true);
        //convert file in bytes
        final resultPath = await file.writeAsBytes(fileBytes, flush: true);

        print('>>>>>>>>>>>>> $file');

        final echoId = const Uuid().v4();

        // return [file.uri.toString()];

        // Aquí puedes actuar según el tipo
        switch (fileType) {
          case 'image':
          // Mostrar vista previa o enviarlo como imagen
          //final file = result.files.first;
            final fileMessage = types.ImageMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              name: fileName,
              size: fileTemp.size,
              uri: resultPath.uri.toString(),
            );
            _chatwootClient!.sendMessageMedia(content: "Imagen", echoId: echoId, media: resultPath);
            _addMessage(fileMessage);
            break;
          case 'audio':
          // Enviar al API o mostrar reproductor
          //final file = result.files.first;
            final fileMessage = types.AudioMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              name: fileName,
              size: fileTemp.size,
              uri: resultPath.uri.toString(),
              duration: Duration(seconds: 10)
            );
            //_chatwootClient!.sendMessageAudio(content: "Audio", echoId: echoId, fileAudio: resultPath);
            _addMessage(fileMessage);
            break;
          default:
          //final file = result.files.first;
            final fileMessage = types.FileMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: const Uuid().v4(),
              name: fileName,
              size: fileTemp.size,
              uri: resultPath.uri.toString(),
            );
            _chatwootClient!.sendMessageMedia(content: "Video", echoId: echoId, media: resultPath);
            _addMessage(fileMessage);
            break;
        }


        //final file = result.files.first;
        /*final fileMessage = types.FileMessage(
          author: _user,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: const Uuid().v4(),
          name: fileName,
          size: fileTemp.size,
          uri: resultPath.uri.toString(),
        );

        _addMessage(fileMessage);*/


        // Send message through Chatwoot client
        /* _chatwootClient!.sendMessage(
            content: "https://images.unsplash.com/photo-1689308271305-58e75832289b?fm=jpg&q=60&w=3000&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1yZWxhdGVkfDE0fHx8ZW58MHx8fHx8",
            echoId: echoId,
          );*/
         //_chatwootClient.sendMessage(content: content, echoId: echoId)

        // Update presence
        //_chatwootClient!.sendAction(ChatwootActionType.update_presence);

        // Note: In a real implementation, you would upload the file
        // and send the file URL through the Chatwoot API
        // _showErrorSnackBar('File attachments require server-side implementation');
      }
    } catch (e) {
      _showErrorSnackBar('Error selecting file: $e');
    }
  }

  void _handleMessageTap(types.Message message) {
    if (message is types.FileMessage) {
      // Handle file opening
      _showErrorSnackBar('File opening not implemented in demo');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _recordAudioAndSend() async {
    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      if (path != null) {
        final file = File(path);
        final uri = file.uri.toString();
        print('>>>>>>>>>>>>> $uri');

        //final file = File(path);
        final fileName = path.split('/').last;

        // Copia el archivo a un directorio temporal con nombre consistente
        final tempDir = await getTemporaryDirectory();
        final tempFile = await File('${tempDir.path}/$fileName').create(recursive: true);
        await tempFile.writeAsBytes(await file.readAsBytes(), flush: true);
        final echoId = const Uuid().v4();
        print('🎧 Archivo listo: ${tempFile.path}');
        // [tempFile.uri.toString()];
        // _controller?.runJavaScript("window.postMessage(JSON.stringify({ event: 'attach-file', uri: '${tempFile.uri.toString()}' }), '*')");
        // 🔍 Intenta enviar el archivo al WebView
        _chatwootClient!.sendMessageAudio(content: "Audio", echoId: echoId, fileAudio: tempFile);
        /* if (Platform.isAndroid && widget.onAttachFile != null) {
          final androidController = _controller!.platform
          as webview_flutter_android.AndroidWebViewController;
          androidController.setOnShowFileSelector(_androidAudioPicker);
        }*/
      }
    } else {
      await _recorder.startRecorder(toFile: 'audio.aac');
    }
    setState(() {
      _isRecording = !_isRecording;
    });
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Agent is typing...',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    Color statusColor = _isConnected ? Colors.green : Colors.red;
    IconData statusIcon = _isConnected ? Icons.check_circle : Icons.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Text(
            _connectionStatus,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          if (_isAgentOnline)
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Online',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _chatwootClient?.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh messages',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _chatwootClient?.clearClientData();
                  setState(() {
                    _messages.clear();
                  });
                  break;
                case 'reconnect':
                  _initializeChatwoot();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reconnect',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Reconnect'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildConnectionStatus(),
          Expanded(
            child: Stack(
              children: [
                Chat(
                  messages: _messages,
                  onSendPressed: _handleSendPressed,
                  onAttachmentPressed: _handleAttachmentPressed,
                  onMessageTap: (context, message) => _handleMessageTap(message),
                  user: _user,
                  showUserAvatars: true,
                  showUserNames: true,
                  theme: DefaultChatTheme(
                    primaryColor: Theme.of(context).primaryColor,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    inputBackgroundColor: Theme.of(context).cardColor,
                    inputTextColor: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                    messageBorderRadius: 16,
                    userAvatarNameColors: [Theme.of(context).primaryColor],
                  ),
                 // customBottomWidget: _buildTypingIndicator(),
                ),
                Positioned(
                  top: 40,
                  right: 65,
                  child: IconButton(
                    onPressed: _recordAudioAndSend,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}