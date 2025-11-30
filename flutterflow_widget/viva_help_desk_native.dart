// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// DEPENDENCIES (add to pubspec.yaml in FlutterFlow):
//   dio: ^5.7.0
//   web_socket_channel: ^3.0.1
//   image_picker: ^1.0.7
//   flutter_chat_ui: ^2.9.1
//   flutter_chat_types: ^3.6.2
//   uuid: ^4.5.1
//   intl: (already included in FlutterFlow)

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';


// ============================================================================
// THEME
// ============================================================================

class ChatTheme {
  final bool isDark;

  ChatTheme({required this.isDark});

  Color get backgroundColor => isDark ? const Color(0xFF1A1A2E) : Colors.white;
  Color get surfaceColor => isDark ? const Color(0xFF16213E) : const Color(0xFFF5F5F5);
  Color get primaryColor => const Color(0xFF1F93FF);
  Color get textColor => isDark ? Colors.white : Colors.black87;
  Color get secondaryTextColor => isDark ? Colors.white70 : Colors.black54;
  Color get bubbleMyColor => primaryColor;
  Color get bubbleTheirColor => isDark ? const Color(0xFF2D3748) : const Color(0xFFE8E8E8);
  Color get inputBackgroundColor => isDark ? const Color(0xFF2D3748) : Colors.white;
  Color get borderColor => isDark ? Colors.white24 : Colors.black12;
  Color get onlineColor => const Color(0xFF22C55E);
  Color get offlineColor => const Color(0xFF9CA3AF);
}

// ============================================================================
// MODELS
// ============================================================================

class ChatMessage {
  final int id;
  final String? content;
  final bool isMine;
  final DateTime createdAt;
  final String? senderName;
  final String? senderAvatar;
  final String? contentType;
  final dynamic contentAttributes;
  final List<ChatAttachment> attachments;
  final bool isPrivate;

  ChatMessage({
    required this.id,
    this.content,
    required this.isMine,
    required this.createdAt,
    this.senderName,
    this.senderAvatar,
    this.contentType,
    this.contentAttributes,
    this.attachments = const [],
    this.isPrivate = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final messageType = json['message_type'];
    final isMine = messageType != 1; // 1 = incoming from agent

    DateTime createdAt;
    final createdAtValue = json['created_at'];
    if (createdAtValue is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue * 1000);
    } else if (createdAtValue is String) {
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final sender = json['sender'];
    final attachmentsList = (json['attachments'] as List<dynamic>?)
        ?.map((a) => ChatAttachment.fromJson(a))
        .toList() ?? [];

    return ChatMessage(
      id: json['id'] is String ? int.tryParse(json['id']) ?? 0 : json['id'] ?? 0,
      content: json['content'],
      isMine: isMine,
      createdAt: createdAt,
      senderName: sender?['name'],
      senderAvatar: sender?['avatar_url'],
      contentType: json['content_type'],
      contentAttributes: json['content_attributes'],
      attachments: attachmentsList,
      isPrivate: json['private'] ?? false,
    );
  }

  bool get isCSAT => contentType == 'input_csat';

  /// Convert to flutter_chat_types Message for flutter_chat_ui
  types.Message toFlutterChatMessage(String currentUserId) {
    final author = types.User(
      id: isMine ? currentUserId : (senderName ?? 'agent'),
      firstName: isMine ? null : senderName,
      imageUrl: senderAvatar,
    );

    // Check for image attachments
    if (attachments.isNotEmpty) {
      final imageAttachment = attachments.firstWhere(
        (a) => a.fileType == 'image',
        orElse: () => ChatAttachment(),
      );
      if (imageAttachment.dataUrl != null) {
        return types.ImageMessage(
          id: id.toString(),
          author: author,
          createdAt: createdAt.millisecondsSinceEpoch,
          name: 'image',
          size: 0,
          uri: imageAttachment.dataUrl!,
        );
      }

      // Check for file attachments
      final fileAttachment = attachments.firstWhere(
        (a) => a.fileType == 'file',
        orElse: () => ChatAttachment(),
      );
      if (fileAttachment.dataUrl != null) {
        return types.FileMessage(
          id: id.toString(),
          author: author,
          createdAt: createdAt.millisecondsSinceEpoch,
          name: fileAttachment.dataUrl!.split('/').last,
          size: 0,
          uri: fileAttachment.dataUrl!,
        );
      }
    }

    // Default to text message
    return types.TextMessage(
      id: id.toString(),
      author: author,
      createdAt: createdAt.millisecondsSinceEpoch,
      text: content ?? '',
    );
  }
}

class ChatAttachment {
  final String? fileType;
  final String? dataUrl;
  final String? thumbUrl;

  ChatAttachment({this.fileType, this.dataUrl, this.thumbUrl});

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      fileType: json['file_type'],
      dataUrl: json['data_url'],
      thumbUrl: json['thumb_url'],
    );
  }
}

class ChatContact {
  final String identifier;
  final String? pubsubToken;
  final String? name;
  final String? email;

  ChatContact({
    required this.identifier,
    this.pubsubToken,
    this.name,
    this.email,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      identifier: json['identifier'] ?? json['source_id'] ?? '',
      pubsubToken: json['pubsub_token'],
      name: json['name'],
      email: json['email'],
    );
  }
}

/// Inbox settings from Chatwoot server
class InboxSettings {
  final String? name;
  final String? timezone;
  final bool workingHoursEnabled;
  final bool csatSurveyEnabled;
  final bool greetingEnabled;
  final String? greetingMessage;
  final List<WorkingHour> workingHours;

  InboxSettings({
    this.name,
    this.timezone,
    this.workingHoursEnabled = false,
    this.csatSurveyEnabled = false,
    this.greetingEnabled = false,
    this.greetingMessage,
    this.workingHours = const [],
  });

  factory InboxSettings.fromJson(Map<String, dynamic> json) {
    final hoursJson = json['working_hours'] as List<dynamic>? ?? [];
    return InboxSettings(
      name: json['name'],
      timezone: json['timezone'],
      workingHoursEnabled: json['working_hours_enabled'] ?? false,
      csatSurveyEnabled: json['csat_survey_enabled'] ?? false,
      greetingEnabled: json['greeting_enabled'] ?? false,
      greetingMessage: json['greeting_message'],
      workingHours: hoursJson.map((h) => WorkingHour.fromJson(h)).toList(),
    );
  }

  /// Check if current time is within working hours
  bool isWithinWorkingHours() {
    if (!workingHoursEnabled || workingHours.isEmpty) return true;

    final now = DateTime.now();
    // Convert to inbox timezone if specified
    final currentDay = now.weekday % 7; // 0 = Sunday, 1 = Monday, etc.

    final todayHours = workingHours.where((h) => h.dayOfWeek == currentDay).toList();
    if (todayHours.isEmpty) return true;

    final hours = todayHours.first;
    if (hours.closedAllDay) return false;
    if (hours.openAllDay) return true;

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = hours.openHour * 60 + hours.openMinutes;
    final closeMinutes = hours.closeHour * 60 + hours.closeMinutes;

    return nowMinutes >= openMinutes && nowMinutes <= closeMinutes;
  }
}

class WorkingHour {
  final int dayOfWeek;
  final bool closedAllDay;
  final bool openAllDay;
  final int openHour;
  final int openMinutes;
  final int closeHour;
  final int closeMinutes;

  WorkingHour({
    required this.dayOfWeek,
    this.closedAllDay = false,
    this.openAllDay = false,
    this.openHour = 9,
    this.openMinutes = 0,
    this.closeHour = 17,
    this.closeMinutes = 0,
  });

  factory WorkingHour.fromJson(Map<String, dynamic> json) {
    return WorkingHour(
      dayOfWeek: json['day_of_week'] ?? 0,
      closedAllDay: json['closed_all_day'] ?? false,
      openAllDay: json['open_all_day'] ?? false,
      openHour: json['open_hour'] ?? 9,
      openMinutes: json['open_minutes'] ?? 0,
      closeHour: json['close_hour'] ?? 17,
      closeMinutes: json['close_minutes'] ?? 0,
    );
  }
}

/// File attachment to send with message
class AttachmentFile {
  final Uint8List bytes;
  final String filename;
  final String mimeType;

  AttachmentFile({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  /// Create from XFile (image_picker result)
  static Future<AttachmentFile> fromXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _guessMimeType(file.name);
    return AttachmentFile(
      bytes: bytes,
      filename: file.name,
      mimeType: mimeType,
    );
  }

  static String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}

// ============================================================================
// API SERVICE
// ============================================================================

class ChatwootApiService {
  final String baseUrl;
  final String websiteToken;
  final String? authToken;
  final dio.Dio _dio;

  String? _contactIdentifier;
  String? _conversationId;
  String? _pubsubToken;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;

  final StreamController<ChatMessage> _messageController = StreamController.broadcast();
  final StreamController<bool> _typingController = StreamController.broadcast();
  final StreamController<bool> _onlineController = StreamController.broadcast();

  Stream<ChatMessage> get onMessage => _messageController.stream;
  Stream<bool> get onTyping => _typingController.stream;
  Stream<bool> get onOnline => _onlineController.stream;

  ChatwootApiService({
    required this.baseUrl,
    required this.websiteToken,
    this.authToken,
  }) : _dio = dio.Dio(dio.BaseOptions(
    baseUrl: baseUrl,
    headers: {
      'Content-Type': 'application/json',
    },
  )) {
    // Add auth token to all requests if provided
    if (authToken != null && authToken!.isNotEmpty) {
      _dio.options.headers['X-Auth-Token'] = authToken;
      _pubsubToken = authToken; // Use for WebSocket too
    }
  }

  /// Widget API query params
  Map<String, dynamic> get _params => {'website_token': websiteToken};

  /// Fetch auth token from widget HTML page (like web widget does)
  Future<String?> fetchAuthToken() async {
    try {
      final response = await _dio.get(
        '/widget',
        queryParameters: {'website_token': websiteToken},
        options: dio.Options(
          headers: {'Accept': 'text/html'},
          responseType: dio.ResponseType.plain,
        ),
      );

      final html = response.data as String;

      // Extract authToken from: "authToken":"xxx"
      var match = RegExp('authToken":"([^"]+)"').firstMatch(html);
      if (match != null) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          _dio.options.headers['X-Auth-Token'] = token;
          _pubsubToken = token;
          return token;
        }
      }

      // Try: chatwootPubsubToken = "xxx"
      match = RegExp('chatwootPubsubToken = "([^"]+)"').firstMatch(html);
      if (match != null) {
        final token = match.group(1);
        if (token != null && token.isNotEmpty) {
          _pubsubToken = token;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get inbox settings - not available in widget API
  InboxSettings getInboxSettings() {
    return InboxSettings();
  }

  Future<ChatContact> createOrGetContact({
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, dynamic>? customAttributes,
  }) async {
    try {
      // If no auth token, fetch it from widget page first
      if (_dio.options.headers['X-Auth-Token'] == null) {
        print('[Chatwoot] No auth token, fetching from widget page...');
        await fetchAuthToken();
      }

      // Try to get existing contact via Widget API
      try {
        final response = await _dio.get(
          '/api/v1/widget/contact',
          queryParameters: _params,
        );
        print('[Chatwoot] Contact response: ${response.data}');
        if (response.statusCode == 200 && response.data != null) {
          final contact = ChatContact.fromJson(response.data);
          _contactIdentifier = contact.identifier;
          // Use contact's pubsub_token for WebSocket (not auth token)
          if (contact.pubsubToken != null && contact.pubsubToken!.isNotEmpty) {
            _pubsubToken = contact.pubsubToken;
            print('[Chatwoot] Got pubsub token from contact: $_pubsubToken');
          }

          // Update contact with new info if provided
          if (identifier != null || name != null || email != null) {
            await setUser(
              identifier: identifier,
              identifierHash: identifierHash,
              name: name,
              email: email,
              phoneNumber: phoneNumber,
              avatarUrl: avatarUrl,
              customAttributes: customAttributes,
            );
          }

          return contact;
        }
      } catch (e) {
        print('[Chatwoot] Get contact failed: $e');
        // Contact doesn't exist yet or no auth
      }

      // Set user info (creates contact if needed)
      final response = await _dio.patch(
        '/api/v1/widget/contact/set_user',
        queryParameters: _params,
        data: {
          if (identifier != null) 'identifier': identifier,
          if (identifierHash != null) 'identifier_hash': identifierHash,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (customAttributes != null) 'custom_attributes': customAttributes,
        },
      );

      print('[Chatwoot] set_user response: ${response.data}');
      final contact = ChatContact.fromJson(response.data);
      _contactIdentifier = contact.identifier;
      if (contact.pubsubToken != null && contact.pubsubToken!.isNotEmpty) {
        _pubsubToken = contact.pubsubToken;
        print('[Chatwoot] Got pubsub token from set_user: $_pubsubToken');
      }

      return contact;
    } catch (e) {
      print('[Chatwoot] Error creating contact: $e');
      rethrow;
    }
  }

  Future<void> setUser({
    String? identifier,
    String? identifierHash,
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, dynamic>? customAttributes,
  }) async {
    try {
      await _dio.patch(
        '/api/v1/widget/contact/set_user',
        queryParameters: _params,
        data: {
          if (identifier != null) 'identifier': identifier,
          if (identifierHash != null) 'identifier_hash': identifierHash,
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (customAttributes != null) 'custom_attributes': customAttributes,
        },
      );
    } catch (e) {
      print('Error setting user: $e');
    }
  }

  Future<void> updateContact({
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, dynamic>? customAttributes,
  }) async {
    try {
      await _dio.patch(
        '/api/v1/widget/contact',
        queryParameters: _params,
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
          if (customAttributes != null) 'custom_attributes': customAttributes,
        },
      );
    } catch (e) {
      print('Error updating contact: $e');
    }
  }

  Future<String> getOrCreateConversation() async {
    try {
      final response = await _dio.get(
        '/api/v1/widget/conversations',
        queryParameters: _params,
      );

      print('[Chatwoot] Conversations response: ${response.data}');

      // Handle both direct List and {payload: [...]} format
      List conversations;
      if (response.data is Map && response.data['payload'] != null) {
        conversations = response.data['payload'] as List;
      } else if (response.data is List) {
        conversations = response.data;
      } else {
        conversations = [];
      }

      print('[Chatwoot] Found ${conversations.length} conversations');
      if (conversations.isNotEmpty) {
        for (var conv in conversations) {
          if (conv['status'] != 'resolved') {
            _conversationId = conv['id'].toString();
            print('[Chatwoot] Using open conversation: $_conversationId');
            return _conversationId!;
          }
        }
        _conversationId = conversations.last['id'].toString();
        print('[Chatwoot] Using last conversation: $_conversationId');
        return _conversationId!;
      }

      // No conversations - will be created on first message
      print('[Chatwoot] No existing conversations');
      return '';
    } catch (e) {
      print('[Chatwoot] Error getting conversation: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessages() async {
    try {
      final response = await _dio.get(
        '/api/v1/widget/messages',
        queryParameters: _params,
      );

      print('[Chatwoot] Messages response: ${response.data}');

      // Response format is {payload: [...], meta: {...}} not a direct List
      List data;
      if (response.data is Map && response.data['payload'] != null) {
        data = response.data['payload'] as List;
      } else if (response.data is List) {
        data = response.data;
      } else {
        data = [];
      }

      final messages = data
          .map((m) => ChatMessage.fromJson(m))
          .where((m) => !m.isPrivate)
          .toList();

      print('[Chatwoot] Parsed ${messages.length} messages');
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    } catch (e) {
      print('[Chatwoot] Error getting messages: $e');
      return [];
    }
  }

  Future<ChatMessage?> sendMessage(String content) async {
    try {
      final response = await _dio.post(
        '/api/v1/widget/messages',
        queryParameters: _params,
        data: {'content': content},
      );

      if (response.data['conversation_id'] != null) {
        _conversationId = response.data['conversation_id'].toString();
      }

      return ChatMessage.fromJson(response.data);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  /// Send message with file attachment(s)
  Future<ChatMessage?> sendMessageWithAttachment({
    String? content,
    required List<AttachmentFile> attachments,
  }) async {
    try {
      final formData = dio.FormData();

      if (content != null && content.isNotEmpty) {
        formData.fields.add(MapEntry('content', content));
      }

      for (final attachment in attachments) {
        formData.files.add(MapEntry(
          'attachments[]',
          dio.MultipartFile.fromBytes(
            attachment.bytes,
            filename: attachment.filename,
            contentType: dio.DioMediaType.parse(attachment.mimeType),
          ),
        ));
      }

      final response = await _dio.post(
        '/api/v1/widget/messages',
        queryParameters: _params,
        data: formData,
        options: dio.Options(contentType: 'multipart/form-data'),
      );

      if (response.data['conversation_id'] != null) {
        _conversationId = response.data['conversation_id'].toString();
      }

      return ChatMessage.fromJson(response.data);
    } catch (e) {
      print('Error sending attachment: $e');
      return null;
    }
  }

  Future<void> submitCSAT(int messageId, int rating, {String? feedback}) async {
    try {
      await _dio.patch(
        '/api/v1/widget/messages/$messageId',
        queryParameters: _params,
        data: {
          'submitted_values': {
            'csat_survey_response': {
              'rating': rating,
              if (feedback != null) 'feedback_message': feedback,
            },
          },
        },
      );
    } catch (e) {
      print('Error submitting CSAT: $e');
    }
  }

  bool _wsSubscribed = false;

  void connectWebSocket() {
    if (_pubsubToken == null) {
      print('[Chatwoot] No pubsub token, skipping WebSocket');
      return;
    }

    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/cable';
      print('[Chatwoot] Connecting WebSocket to: $wsUrl');
      print('[Chatwoot] Using pubsub token: $_pubsubToken');
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSubscribed = false;

      _wsSubscription = _wsChannel!.stream.listen((data) {
        try {
          final decoded = jsonDecode(data);
          _handleWebSocketMessage(decoded);
        } catch (e) {
          print('[Chatwoot] WebSocket parse error: $e');
        }
      }, onError: (error) {
        print('[Chatwoot] WebSocket error: $error');
      }, onDone: () {
        print('[Chatwoot] WebSocket closed');
        _wsSubscribed = false;
      });

      // Send subscribe command after connection is established
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_wsChannel != null) {
          final identifier = jsonEncode({
            'channel': 'RoomChannel',
            'pubsub_token': _pubsubToken,
          });
          print('[Chatwoot] Subscribing with identifier: $identifier');
          _wsChannel!.sink.add(jsonEncode({
            'command': 'subscribe',
            'identifier': identifier,
          }));
        }
      });
    } catch (e) {
      print('[Chatwoot] WebSocket connection error: $e');
    }
  }

  // Stream for conversation resolved events
  final StreamController<bool> _resolvedController = StreamController.broadcast();
  Stream<bool> get onResolved => _resolvedController.stream;

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    print('[Chatwoot] WebSocket raw: $data');

    // Handle ActionCable system messages
    final type = data['type'];
    if (type != null) {
      switch (type) {
        case 'welcome':
          print('[Chatwoot] WebSocket connected (welcome)');
          return;
        case 'ping':
          // Keep-alive, ignore
          return;
        case 'confirm_subscription':
          print('[Chatwoot] Subscription confirmed!');
          _wsSubscribed = true;
          return;
        case 'reject_subscription':
          print('[Chatwoot] Subscription rejected!');
          _wsSubscribed = false;
          return;
      }
    }

    // Handle actual messages
    final message = data['message'];
    if (message == null) {
      print('[Chatwoot] No message in data');
      return;
    }

    // Message can be a map with event/data structure or direct message data
    String? event;
    dynamic messageData;

    if (message is Map) {
      event = message['event'] as String?;
      messageData = message['data'];

      // If no event, check if message itself is the message data
      if (event == null && message['id'] != null) {
        // This is a direct message object
        print('[Chatwoot] Direct message object received');
        final chatMessage = ChatMessage.fromJson(message as Map<String, dynamic>);
        if (!chatMessage.isPrivate) {
          _messageController.add(chatMessage);
        }
        return;
      }
    }

    print('[Chatwoot] Event: $event, data: $messageData');

    switch (event) {
      case 'message.created':
        if (messageData != null) {
          final chatMessage = ChatMessage.fromJson(messageData as Map<String, dynamic>);
          print('[Chatwoot] New message: ${chatMessage.content}, isMine: ${chatMessage.isMine}');
          if (!chatMessage.isPrivate) {
            _messageController.add(chatMessage);
          }
        }
        break;
      case 'conversation.typing_on':
        _typingController.add(true);
        break;
      case 'conversation.typing_off':
        _typingController.add(false);
        break;
      case 'conversation.resolved':
      case 'conversation.status_changed':
        final status = messageData is Map ? messageData['status'] : null;
        if (status == 'resolved') {
          print('[Chatwoot] Conversation resolved');
          _resolvedController.add(true);
        }
        break;
      case 'presence.update':
        final users = messageData is Map ? messageData['users'] as Map? : null;
        if (users != null && users.isNotEmpty) {
          final isOnline = users.values.any((u) => u == 'online');
          _onlineController.add(isOnline);
        }
        break;
      default:
        print('[Chatwoot] Unknown event: $event');
    }
  }

  void sendTypingIndicator(bool isTyping) {
    if (_wsChannel == null || _pubsubToken == null) return;

    try {
      _wsChannel!.sink.add(jsonEncode({
        'command': 'message',
        'identifier': jsonEncode({
          'channel': 'RoomChannel',
          'pubsub_token': _pubsubToken,
        }),
        'data': jsonEncode({
          'action': isTyping ? 'update_presence' : 'update_presence',
        }),
      }));
    } catch (_) {}
  }

  void dispose() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _messageController.close();
    _typingController.close();
    _onlineController.close();
    _resolvedController.close();
  }
}

// ============================================================================
// MAIN WIDGET
// ============================================================================

class VivaHelpDeskNative extends StatefulWidget {
  const VivaHelpDeskNative({
    super.key,
    this.width,
    this.height,
    required this.websiteToken,
    required this.baseUrl,
    // Auth
    this.authToken,
    // User data
    this.userIdentifier,
    this.identifierHash,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAvatarUrl,
    // Custom attributes
    this.tenantKey,
    this.pushToken,
    // Settings
    this.isDark = false,
    this.locale = 'ru',
    this.hideMessageBubble = false,
    this.showUnreadMessagesDialog = true,
    this.position = 'right',
    // UI
    this.primaryColor,
    this.showHeader = true,
    this.headerTitle,
  });

  final double? width;
  final double? height;
  final String websiteToken;
  final String baseUrl;

  // Auth - JWT token for X-Auth-Token header
  final String? authToken;

  // User
  final String? userIdentifier;
  final String? identifierHash;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAvatarUrl;

  // Custom attributes
  final String? tenantKey;
  final String? pushToken;

  // Settings
  final bool isDark;
  final String locale;
  final bool hideMessageBubble;
  final bool showUnreadMessagesDialog;
  final String position;

  // UI
  final Color? primaryColor;
  final bool showHeader;
  final String? headerTitle; // If null, uses inbox name from server

  @override
  State<VivaHelpDeskNative> createState() => _VivaHelpDeskNativeState();
}

class _VivaHelpDeskNativeState extends State<VivaHelpDeskNative> {
  late ChatTheme _theme;
  late ChatwootApiService _apiService;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  bool _isAgentOnline = false;
  String? _error;
  bool _conversationResolved = false;
  int _unreadCount = 0;
  InboxSettings? _inboxSettings; // Settings from Chatwoot server

  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _onlineSubscription;
  StreamSubscription? _resolvedSubscription;
  Timer? _typingTimer;

  // flutter_chat_ui user
  late types.User _user;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _theme = ChatTheme(isDark: widget.isDark);
    _apiService = ChatwootApiService(
      baseUrl: widget.baseUrl,
      websiteToken: widget.websiteToken,
      authToken: widget.authToken,
    );
    // Create user for flutter_chat_ui
    _user = types.User(
      id: widget.userIdentifier ?? _uuid.v4(),
      firstName: widget.userName,
      imageUrl: widget.userAvatarUrl,
    );
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get inbox settings (public API doesn't expose this, returns defaults)
      _inboxSettings = _apiService.getInboxSettings();

      // Build custom attributes
      final customAttrs = <String, dynamic>{};
      if (widget.tenantKey != null) customAttrs['tenant'] = widget.tenantKey;
      if (widget.pushToken != null) customAttrs['pushToken'] = widget.pushToken;

      // Create/get contact
      await _apiService.createOrGetContact(
        identifier: widget.userIdentifier,
        identifierHash: widget.identifierHash,
        name: widget.userName,
        email: widget.userEmail,
        phoneNumber: widget.userPhone,
        avatarUrl: widget.userAvatarUrl,
        customAttributes: customAttrs.isNotEmpty ? customAttrs : null,
      );

      // Get/create conversation
      await _apiService.getOrCreateConversation();

      // Load messages
      final messages = await _apiService.getMessages();

      // Check if conversation is resolved
      _conversationResolved = messages.isNotEmpty &&
          messages.last.contentType == 'input_csat';

      // Connect WebSocket
      _apiService.connectWebSocket();

      // Listen for new messages
      _messageSubscription = _apiService.onMessage.listen((message) {
        if (mounted) {
          setState(() {
            // Avoid duplicates
            if (!_messages.any((m) => m.id == message.id)) {
              _messages.add(message);
              if (!message.isMine) _unreadCount++;
            }
          });
          _scrollToBottom();
        }
      });

      // Listen for typing
      _typingSubscription = _apiService.onTyping.listen((isTyping) {
        if (mounted) {
          setState(() => _isTyping = isTyping);
        }
      });

      // Listen for online status
      _onlineSubscription = _apiService.onOnline.listen((isOnline) {
        if (mounted) {
          setState(() => _isAgentOnline = isOnline);
        }
      });

      // Listen for conversation resolved
      _resolvedSubscription = _apiService.onResolved.listen((resolved) {
        if (mounted && resolved) {
          setState(() {
            _conversationResolved = true;
          });
          // Reload messages to get CSAT
          _apiService.getMessages().then((msgs) {
            if (mounted) {
              setState(() => _messages = msgs);
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка подключения: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final message = await _apiService.sendMessage(text);

    if (message != null && mounted) {
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages.add(message);
        }
        _isSending = false;
        _conversationResolved = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startNewConversation() async {
    setState(() {
      _messages.clear();
      _conversationResolved = false;
      _isLoading = true;
    });

    await _apiService.getOrCreateConversation();
    final messages = await _apiService.getMessages();

    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }

  void _onTypingChanged(String text) {
    _typingTimer?.cancel();
    _apiService.sendTypingIndicator(true);

    _typingTimer = Timer(const Duration(seconds: 2), () {
      _apiService.sendTypingIndicator(false);
    });
  }

  /// Check if current time is within working hours (from server settings)
  bool get _isWithinWorkingHours {
    return _inboxSettings?.isWithinWorkingHours() ?? true;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _onlineSubscription?.cancel();
    _resolvedSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _theme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (widget.showHeader) _buildHeader(),
          if (!_isWithinWorkingHours) _buildWorkingHoursNotice(),
          Expanded(child: _buildContent()),
          // flutter_chat_ui Chat widget has built-in input, only show new conversation button when resolved
          if (_conversationResolved) _buildNewConversationButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: widget.primaryColor ?? _theme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.support_agent, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.headerTitle ?? _inboxSettings?.name ?? (widget.locale == 'ru' ? 'Чат поддержки' : 'Support Chat'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isAgentOnline ? _theme.onlineColor : _theme.offlineColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAgentOnline
                          ? (widget.locale == 'ru' ? 'Онлайн' : 'Online')
                          : (widget.locale == 'ru' ? 'Офлайн' : 'Offline'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    if (_isTyping) ...[
                      const SizedBox(width: 8),
                      Text(
                        widget.locale == 'ru' ? 'печатает...' : 'typing...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursNotice() {
    // Default message if not set on server
    final defaultMessage = widget.locale == 'ru'
        ? 'Сейчас нерабочее время. Мы ответим в рабочие часы.'
        : 'Outside working hours. We will reply during business hours.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.amber.withOpacity(0.2),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 20, color: Colors.amber[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              defaultMessage,
              style: TextStyle(
                color: _theme.textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Convert ChatMessage list to flutter_chat_types Message list
  List<types.Message> _convertMessages() {
    // Filter out CSAT messages (handled separately) and reverse for flutter_chat_ui (newest first)
    return _messages
        .where((m) => !m.isCSAT)
        .map((m) => m.toFlutterChatMessage(_user.id))
        .toList()
        .reversed
        .toList();
  }

  /// Build chat theme for flutter_chat_ui
  DefaultChatTheme _buildChatTheme() {
    final primaryColor = widget.primaryColor ?? _theme.primaryColor;

    return DefaultChatTheme(
      backgroundColor: _theme.backgroundColor,
      primaryColor: primaryColor,
      secondaryColor: _theme.bubbleTheirColor,
      inputBackgroundColor: _theme.inputBackgroundColor,
      inputTextColor: _theme.textColor,
      inputBorderRadius: BorderRadius.circular(24),
      inputPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      inputContainerDecoration: BoxDecoration(
        color: _theme.backgroundColor,
        border: Border(top: BorderSide(color: _theme.borderColor)),
      ),
      sentMessageBodyTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      receivedMessageBodyTextStyle: TextStyle(
        color: _theme.textColor,
        fontSize: 15,
      ),
      dateDividerTextStyle: TextStyle(
        color: _theme.secondaryTextColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      messageBorderRadius: 16,
      messageInsetsHorizontal: 14,
      messageInsetsVertical: 10,
      attachmentButtonIcon: Icon(
        Icons.attach_file,
        color: _theme.secondaryTextColor,
      ),
      sendButtonIcon: Icon(Icons.send, color: primaryColor),
      inputTextCursorColor: primaryColor,
      emptyChatPlaceholderTextStyle: TextStyle(
        color: _theme.secondaryTextColor,
        fontSize: 16,
      ),
    );
  }

  /// Handle message send from flutter_chat_ui
  void _handleSendPressed(types.PartialText message) async {
    if (message.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final response = await _apiService.sendMessage(message.text);

    if (response != null && mounted) {
      setState(() {
        if (!_messages.any((m) => m.id == response.id)) {
          _messages.add(response);
        }
        _isSending = false;
        _conversationResolved = false;
      });
    } else {
      setState(() => _isSending = false);
    }
  }

  /// Handle attachment button press
  void _handleAttachmentPressed() {
    _showAttachmentOptions();
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: widget.primaryColor ?? _theme.primaryColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _theme.textColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryColor ?? _theme.primaryColor,
                ),
                child: Text(widget.locale == 'ru' ? 'Повторить' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Check for CSAT message at the end
    final csatMessage = _messages.isNotEmpty && _messages.last.isCSAT
        ? _messages.last
        : null;

    return Column(
      children: [
        Expanded(
          child: Chat(
            messages: _convertMessages(),
            onSendPressed: _handleSendPressed,
            onAttachmentPressed: _handleAttachmentPressed,
            user: _user,
            theme: _buildChatTheme(),
            showUserAvatars: true,
            showUserNames: true,
            dateHeaderThreshold: 86400000, // 24 hours in ms
            l10n: widget.locale == 'ru'
                ? const ChatL10nEn(
                    and: 'и',
                    attachmentButtonAccessibilityLabel: 'Отправить файл',
                    emptyChatPlaceholder: 'Сообщений пока нет',
                    fileButtonAccessibilityLabel: 'Файл',
                    inputPlaceholder: 'Сообщение',
                    isTyping: 'печатает...',
                    others: 'других',
                    sendButtonAccessibilityLabel: 'Отправить',
                    unreadMessagesLabel: 'Непрочитанные сообщения',
                  )
                : const ChatL10nEn(),
            emptyState: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: _theme.secondaryTextColor.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.locale == 'ru'
                        ? 'Начните диалог с нами!'
                        : 'Start a conversation with us!',
                    style: TextStyle(
                      color: _theme.secondaryTextColor,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Hide built-in input if conversation is resolved
            customBottomWidget: _conversationResolved ? const SizedBox.shrink() : null,
          ),
        ),
        // Show CSAT widget if present
        if (csatMessage != null) _buildCSATWidget(csatMessage),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String text;

    if (_isSameDay(date, now)) {
      text = widget.locale == 'ru' ? 'Сегодня' : 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      text = widget.locale == 'ru' ? 'Вчера' : 'Yesterday';
    } else {
      text = DateFormat('d MMMM', widget.locale).format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          color: _theme.secondaryTextColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isMe = message.isMine;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && message.senderAvatar != null) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(message.senderAvatar!),
              backgroundColor: _theme.surfaceColor,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _theme.bubbleMyColor : _theme.bubbleTheirColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderName!,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : _theme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (message.content != null)
                    Text(
                      message.content!,
                      style: TextStyle(
                        color: isMe ? Colors.white : _theme.textColor,
                        fontSize: 15,
                      ),
                    ),
                  for (final attachment in message.attachments)
                    if (attachment.fileType == 'image' && attachment.dataUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            attachment.dataUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white60 : _theme.secondaryTextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCSATWidget(ChatMessage message) {
    return _CSATRatingWidget(
      messageId: message.id,
      apiService: _apiService,
      theme: _theme,
      locale: widget.locale,
      primaryColor: widget.primaryColor,
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isSending = true);

      final attachment = await AttachmentFile.fromXFile(pickedFile);
      final message = await _apiService.sendMessageWithAttachment(
        attachments: [attachment],
      );

      if (message != null && mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error picking image: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _theme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _theme.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.photo, color: _theme.primaryColor),
                ),
                title: Text(
                  widget.locale == 'ru' ? 'Галерея' : 'Gallery',
                  style: TextStyle(color: _theme.textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: _theme.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.camera_alt, color: _theme.primaryColor),
                ),
                title: Text(
                  widget.locale == 'ru' ? 'Камера' : 'Camera',
                  style: TextStyle(color: _theme.textColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final picker = ImagePicker();
                  final photo = await picker.pickImage(source: ImageSource.camera);
                  if (photo != null) {
                    setState(() => _isSending = true);
                    final attachment = await AttachmentFile.fromXFile(photo);
                    final message = await _apiService.sendMessageWithAttachment(
                      attachments: [attachment],
                    );
                    if (message != null && mounted) {
                      setState(() {
                        if (!_messages.any((m) => m.id == message.id)) {
                          _messages.add(message);
                        }
                        _isSending = false;
                      });
                      _scrollToBottom();
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _theme.backgroundColor,
        border: Border(
          top: BorderSide(color: _theme.borderColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button
            IconButton(
              onPressed: _isSending ? null : _showAttachmentOptions,
              icon: Icon(
                Icons.attach_file,
                color: _theme.secondaryTextColor,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _theme.inputBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _theme.borderColor),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  onChanged: _onTypingChanged,
                  onSubmitted: (_) => _sendMessage(),
                  style: TextStyle(color: _theme.textColor),
                  decoration: InputDecoration(
                    hintText: widget.locale == 'ru'
                        ? 'Введите сообщение...'
                        : 'Type a message...',
                    hintStyle: TextStyle(color: _theme.secondaryTextColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: widget.primaryColor ?? _theme.primaryColor,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: _isSending ? null : _sendMessage,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white, size: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewConversationButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _theme.backgroundColor,
        border: Border(
          top: BorderSide(color: _theme.borderColor),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _startNewConversation,
            icon: const Icon(Icons.add_comment),
            label: Text(
              widget.locale == 'ru'
                  ? 'Начать новый диалог'
                  : 'Start new conversation',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.primaryColor ?? _theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CSAT RATING WIDGET
// ============================================================================

class _CSATRatingWidget extends StatefulWidget {
  const _CSATRatingWidget({
    required this.messageId,
    required this.apiService,
    required this.theme,
    required this.locale,
    this.primaryColor,
  });

  final int messageId;
  final ChatwootApiService apiService;
  final ChatTheme theme;
  final String locale;
  final Color? primaryColor;

  @override
  State<_CSATRatingWidget> createState() => _CSATRatingWidgetState();
}

class _CSATRatingWidgetState extends State<_CSATRatingWidget> {
  int _selectedRating = 0;
  bool _submitted = false;
  bool _submitting = false;
  final _feedbackController = TextEditingController();

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0 || _submitting) return;

    setState(() => _submitting = true);

    await widget.apiService.submitCSAT(
      widget.messageId,
      _selectedRating,
      feedback: _feedbackController.text.isNotEmpty
          ? _feedbackController.text
          : null,
    );

    if (mounted) {
      setState(() {
        _submitted = true;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? widget.theme.primaryColor;

    if (_submitted) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: widget.theme.borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text(
              widget.locale == 'ru'
                  ? 'Спасибо за вашу оценку!'
                  : 'Thank you for your feedback!',
              style: TextStyle(
                color: widget.theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.theme.borderColor),
      ),
      child: Column(
        children: [
          Text(
            widget.locale == 'ru'
                ? 'Как вы оцениваете наш сервис?'
                : 'How would you rate our service?',
            style: TextStyle(
              color: widget.theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Star rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final isSelected = rating <= _selectedRating;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = rating),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isSelected ? Icons.star : Icons.star_border,
                    size: 40,
                    color: isSelected ? Colors.amber : widget.theme.secondaryTextColor,
                  ),
                ),
              );
            }),
          ),
          if (_selectedRating > 0) ...[
            const SizedBox(height: 16),
            // Feedback text field
            TextField(
              controller: _feedbackController,
              style: TextStyle(color: widget.theme.textColor),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: widget.locale == 'ru'
                    ? 'Оставьте комментарий (необязательно)'
                    : 'Leave a comment (optional)',
                hintStyle: TextStyle(color: widget.theme.secondaryTextColor),
                filled: true,
                fillColor: widget.theme.inputBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.theme.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: widget.theme.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryColor),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.locale == 'ru' ? 'Отправить' : 'Submit',
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// FLOATING CHAT BUBBLE
// ============================================================================

/// A floating chat bubble that shows unread messages and opens the chat
class VivaHelpDeskBubble extends StatefulWidget {
  const VivaHelpDeskBubble({
    super.key,
    required this.websiteToken,
    required this.baseUrl,
    // Auth
    this.authToken,
    // User data
    this.userIdentifier,
    this.identifierHash,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAvatarUrl,
    // Custom attributes
    this.tenantKey,
    this.pushToken,
    // Settings
    this.isDark = false,
    this.locale = 'ru',
    this.position = 'right',
    this.showUnreadMessagesDialog = true,
    // UI
    this.primaryColor,
    this.bubbleSize = 60.0,
    this.headerTitle, // If null, uses inbox name from server
  });

  final String websiteToken;
  final String baseUrl;

  // Auth - JWT token for X-Auth-Token header
  final String? authToken;

  // User
  final String? userIdentifier;
  final String? identifierHash;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAvatarUrl;

  // Custom attributes
  final String? tenantKey;
  final String? pushToken;

  // Settings
  final bool isDark;
  final String locale;
  final String position;
  final bool showUnreadMessagesDialog;

  // UI
  final Color? primaryColor;
  final double bubbleSize;
  final String? headerTitle; // If null, uses inbox name from server

  @override
  State<VivaHelpDeskBubble> createState() => _VivaHelpDeskBubbleState();
}

class _VivaHelpDeskBubbleState extends State<VivaHelpDeskBubble>
    with SingleTickerProviderStateMixin {
  late ChatwootApiService _apiService;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  int _unreadCount = 0;
  String? _lastMessagePreview;
  bool _showPreview = false;
  Timer? _previewTimer;

  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );

    _apiService = ChatwootApiService(
      baseUrl: widget.baseUrl,
      websiteToken: widget.websiteToken,
      authToken: widget.authToken,
    );

    _initService();
  }

  Future<void> _initService() async {
    try {
      // Build custom attributes
      final customAttrs = <String, dynamic>{};
      if (widget.tenantKey != null) customAttrs['tenant'] = widget.tenantKey;
      if (widget.pushToken != null) customAttrs['pushToken'] = widget.pushToken;

      await _apiService.createOrGetContact(
        identifier: widget.userIdentifier,
        identifierHash: widget.identifierHash,
        name: widget.userName,
        email: widget.userEmail,
        phoneNumber: widget.userPhone,
        avatarUrl: widget.userAvatarUrl,
        customAttributes: customAttrs.isNotEmpty ? customAttrs : null,
      );

      await _apiService.getOrCreateConversation();

      // Connect WebSocket
      _apiService.connectWebSocket();

      // Listen for new messages
      _messageSubscription = _apiService.onMessage.listen((message) {
        if (!message.isMine && mounted) {
          setState(() {
            _unreadCount++;
            _lastMessagePreview = message.content;
          });

          if (widget.showUnreadMessagesDialog && message.content != null) {
            _showMessagePreview();
          }
        }
      });
    } catch (e) {
      print('Bubble init error: $e');
    }
  }

  void _showMessagePreview() {
    setState(() => _showPreview = true);
    _animController.forward(from: 0.0);

    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showPreview = false);
      }
    });
  }

  void _openChat() {
    setState(() {
      _unreadCount = 0;
      _showPreview = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: VivaHelpDeskNative(
                  websiteToken: widget.websiteToken,
                  baseUrl: widget.baseUrl,
                  userIdentifier: widget.userIdentifier,
                  identifierHash: widget.identifierHash,
                  userName: widget.userName,
                  userEmail: widget.userEmail,
                  userPhone: widget.userPhone,
                  userAvatarUrl: widget.userAvatarUrl,
                  tenantKey: widget.tenantKey,
                  pushToken: widget.pushToken,
                  isDark: widget.isDark,
                  locale: widget.locale,
                  primaryColor: widget.primaryColor,
                  headerTitle: widget.headerTitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _previewTimer?.cancel();
    _messageSubscription?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor ?? const Color(0xFF1F93FF);
    final isRight = widget.position == 'right';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Message preview bubble
        if (_showPreview && _lastMessagePreview != null)
          Positioned(
            bottom: widget.bubbleSize + 12,
            right: isRight ? 0 : null,
            left: isRight ? null : 0,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: isRight ? Alignment.bottomRight : Alignment.bottomLeft,
              child: GestureDetector(
                onTap: _openChat,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF2D3748) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isRight ? 16 : 4),
                      bottomRight: Radius.circular(isRight ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.support_agent,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.locale == 'ru' ? 'Новое сообщение' : 'New message',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastMessagePreview!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Main bubble button
        GestureDetector(
          onTap: _openChat,
          child: Container(
            width: widget.bubbleSize,
            height: widget.bubbleSize,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(widget.bubbleSize / 2),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Chat icon
                Center(
                  child: Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: widget.bubbleSize * 0.45,
                  ),
                ),
                // Unread badge
                if (_unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(minWidth: 20),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
