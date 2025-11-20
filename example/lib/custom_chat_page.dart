import 'dart:io';

import 'package:chatwoot_example/permision/utils.dart';
import 'package:chatwoot_example/widget_chat/audio_player_widget.dart';
import 'package:chatwoot_example/widget_chat/video_player_widget.dart';
import 'package:chatwoot_flutter_sdk/chatwoot_sdk.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action_data.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

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
    Utils().requestPermissions();
    _initializeUsers();
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
            _addMessage(_convertChatwootMessageToType(message, _agent));
          },
          onMessageSent: (message, echoId) {
            // Message already added when sending
          },
          onMessageDelivered: (message, echoId) {
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
          msg, msg.isMine ? _user : _agent))
          .toList();
      _messages.insertAll(0, convertedMessages.reversed);
    });
  }

  void _loadRemoteMessages(List<ChatwootMessage> messages) {
    setState(() {
      _messages.clear();
      final convertedMessages = messages
          .map((msg) => _convertChatwootMessageToType(
          msg, msg.isMine ? _user : _agent))
          .toList();
      _messages.addAll(convertedMessages.reversed);
    });
  }

  types.Message _convertChatwootMessageToType(ChatwootMessage chatwootMessage, types.User author) {
    // Handle different message types
    if (chatwootMessage.attachments?.isNotEmpty == true) {
      final attachment = chatwootMessage.attachments!.first;
      if (attachment is Map<String, dynamic>) {

        final fileType = attachment['file_type']?.toString();
        final dataUrl = attachment['data_url']?.toString();
        if (fileType != null && fileType == 'image') {
          return types.ImageMessage(
            author: author,
            createdAt: DateTime
                .parse(chatwootMessage.createdAt)
                .millisecondsSinceEpoch,
            id: chatwootMessage.id.toString(),
            name: dataUrl
                ?.split('/')
                .last ?? 'image',
            size: fileType.length.toDouble(),
            uri: dataUrl ?? '',
          );
        } else {
          if (fileType != null && fileType == 'audio') {
            return types.AudioMessage(
              author: author,
              createdAt: DateTime
                  .parse(chatwootMessage.createdAt)
                  .millisecondsSinceEpoch,
              id: chatwootMessage.id.toString(),
              name: dataUrl
                  ?.split('/')
                  .last ?? 'audio',
              size: fileType.length.toDouble(),
              uri: dataUrl ?? '',
              duration: Duration(seconds: 10),
            );
          } else {
            if (fileType != null && fileType == 'video') {
              return types.VideoMessage(
                author: author,
                createdAt: DateTime
                    .parse(chatwootMessage.createdAt)
                    .millisecondsSinceEpoch,
                id: chatwootMessage.id.toString(),
                name: dataUrl
                    ?.split('/')
                    .last ?? 'video',
                size: fileType.length.toDouble(),
                uri: dataUrl ?? '',
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

        // Convert the file to base64
        List<int> fileBytes = await File(filePath).readAsBytes();

        //convert filepath into uri
        final tempUri = (await getTemporaryDirectory()).uri.resolve(fileName);
        final file = await File.fromUri(tempUri).create(recursive: true);
        //convert file in bytes
        final resultPath = await file.writeAsBytes(fileBytes, flush: true);

        final echoId = const Uuid().v4();

        // Aquí puedes actuar según el tipo
        switch (fileType) {
          case 'image':
          // Mostrar vista previa o enviarlo como imagen
          //final file = result.files.first;
            final fileMessage = types.ImageMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: echoId,
              name: fileName,
              size: fileTemp.size,
              uri: filePath,
            );
            _addMessage(fileMessage);
            _chatwootClient!.sendMessageMedia(
                content: "", echoId: echoId, media: resultPath);

            break;
          case 'audio':
          // Enviar al API o mostrar reproductor
          //final file = result.files.first;
            final fileMessage = types.AudioMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
                id: echoId,
              name: fileName,
              size: fileTemp.size,
                uri: filePath,
              duration: Duration(seconds: 10)
            );

            _addMessage(fileMessage);
            _chatwootClient!.sendMessageAudio(
                content: "", echoId: echoId, fileAudio: resultPath);
            break;
          case 'video':
          // Enviar al API o mostrar reproductor
          //final file = result.files.first;
            final fileMessage = types.VideoMessage(
              author: _user,
              createdAt: DateTime
                  .now()
                  .millisecondsSinceEpoch,
              id: echoId,
              name: fileName,
              size: fileTemp.size,
              uri: filePath,
            );
            _addMessage(fileMessage);
            _chatwootClient!.sendMessageMedia(
                content: "", echoId: echoId, media: resultPath);
            break;
          default:
          //final file = result.files.first;
            final fileMessage = types.FileMessage(
              author: _user,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              id: echoId,
              name: fileName,
              size: fileTemp.size,
              uri: filePath,
            );
            _addMessage(fileMessage);
            _chatwootClient!.sendMessageMedia(
                content: "File", echoId: echoId, media: resultPath);
            break;
        }

        // Update presence
        _chatwootClient!.sendAction(ChatwootActionType.update_presence);

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
        final fileName = path.split('/').last;
        //final fileTemp = file.first;
        // Copia el archivo a un directorio temporal con nombre consistente
        final tempDir = await getTemporaryDirectory();
        final tempFile = await File('${tempDir.path}/$fileName').create(recursive: true);
        await tempFile.writeAsBytes(await file.readAsBytes(), flush: true);
        final echoId = const Uuid().v4();
        print('🎧 Archivo listo: ${tempFile.path}');
        final int sizeInBytes = await file.length();
        final fileMessage = types.AudioMessage(
            author: _user,
            createdAt: DateTime
                .now()
                .millisecondsSinceEpoch,
            id: echoId,
            name: fileName,
            size: sizeInBytes,
            uri: file.path,
            duration: Duration(seconds: 10)
        );

        _addMessage(fileMessage);
        _chatwootClient!.sendMessageAudio(
            content: "", echoId: echoId, fileAudio: tempFile);
        _chatwootClient!.sendAction(ChatwootActionType.update_presence);
      }
    } else {
      await _recorder.startRecorder(toFile: 'audio.aac');
    }
    setState(() {
      _isRecording = !_isRecording;
    });
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
            child: Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              onAttachmentPressed: _handleAttachmentPressed,
              onMessageTap: (context, message) => _handleMessageTap(message),
              audioMessageBuilder: (message, {required messageWidth}) {
                return AudioPlayerWidget(uri: message.uri);
              },
              videoMessageBuilder: (message, {required messageWidth}) {
                return VideoPlayerWidget(uri: message.uri);
              },
              user: _user,
              userAgent: _agent.firstName,
              showUserAvatars: true,
              showUserNames: true,
              theme: DefaultChatTheme(
                primaryColor: Theme
                    .of(context)
                    .primaryColor,
                backgroundColor: Theme
                    .of(context)
                    .scaffoldBackgroundColor,
                inputBackgroundColor: Theme
                    .of(context)
                    .cardColor,
                inputTextColor: Theme
                    .of(context)
                    .textTheme
                    .bodyLarge
                    ?.color ?? Colors.black,
                messageBorderRadius: 16,
                userAvatarNameColors: [Theme
                    .of(context)
                    .primaryColor
                ],
              ),
              customBottomWidget: _buildCustomInputBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          // 📎 Botón de adjuntar archivos (solo visible si no está grabando)
          if (!_isRecording)
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _handleAttachmentPressed,
            ),

          // 💬 / 🔊 Campo dinámico
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _isRecording
                  ? _buildRecordingIndicator()
                  : TextField(
                key: const ValueKey('textField'),
                controller: _controller,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  filled: true,
                  fillColor: Theme
                      .of(context)
                      .colorScheme
                      .surface,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (text) {
                  if (text
                      .trim()
                      .isNotEmpty) {
                    _handleSendPressed(types.PartialText(text: text.trim()));
                    _controller.clear();
                    setState(() {});
                  }
                },
              ),
            ),
          ),

          // 🎤 / 📩 Botón dinámico
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _isRecording
                ? IconButton(
              key: const ValueKey('stop'),
              icon: const Icon(Icons.stop_circle_outlined,
                  color: Colors.red, size: 30),
              onPressed: _recordAudioAndSend,
            )
                : (_controller.text
                .trim()
                .isNotEmpty
                ? IconButton(
              key: const ValueKey('send'),
              icon: const Icon(Icons.send,
                  color: Colors.blueAccent, size: 26),
              onPressed: () {
                final text = _controller.text.trim();
                if (text.isNotEmpty) {
                  _handleSendPressed(types.PartialText(text: text));
                  _controller.clear();
                  setState(() {});
                }
              },
            )
                : IconButton(
              key: const ValueKey('mic'),
              icon: Icon(Icons.mic_none,
                  color: Theme
                      .of(context)
                      .primaryColor, size: 28),
              onPressed: _recordAudioAndSend,
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    return AnimatedContainer(
      key: const ValueKey('recordingIndicator'),
      duration: const Duration(milliseconds: 300),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(25),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Icon(Icons.mic, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedOpacity(
              opacity: _isRecording ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(
                  4,
                      (i) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 300 + (i * 100)),
                          width: 4,
                          height: _isRecording
                              ? (10 + (i * 5)).toDouble()
                              : 10, // alturas variables
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Grabando...',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}