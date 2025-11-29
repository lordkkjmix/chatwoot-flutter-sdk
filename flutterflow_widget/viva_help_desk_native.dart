// FlutterFlow Custom Widget - VivaHelpDesk Native (Chatwoot Chat)
//
// DEPENDENCIES (add to pubspec.yaml):
//   dio: ^5.7.0
//   web_socket_channel: ^3.0.1
//   shared_preferences: (already included in FlutterFlow)
//   intl: (already included in FlutterFlow)
//
// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/backend/supabase/supabase.dart';
import '/actions/actions.dart' as action_blocks;
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart';
import '/custom_code/actions/index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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

// ============================================================================
// API SERVICE
// ============================================================================

class ChatwootApiService {
  final String baseUrl;
  final String websiteToken;
  final Dio _dio;

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
  }) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: {'Content-Type': 'application/json'},
  ));

  /// Fetch inbox settings from public API
  Future<InboxSettings> getInboxSettings() async {
    try {
      final response = await _dio.get(
        '/public/api/v1/inboxes/$websiteToken',
      );
      if (response.statusCode == 200) {
        return InboxSettings.fromJson(response.data);
      }
    } catch (e) {
      print('Error fetching inbox settings: $e');
    }
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
      // Try to get existing contact first
      final prefs = await SharedPreferences.getInstance();
      final savedContactId = prefs.getString('chatwoot_contact_$websiteToken');

      if (savedContactId != null) {
        try {
          final response = await _dio.get(
            '/public/api/v1/inboxes/$websiteToken/contacts/$savedContactId',
          );
          if (response.statusCode == 200) {
            _contactIdentifier = savedContactId;
            final contact = ChatContact.fromJson(response.data);
            _pubsubToken = contact.pubsubToken;

            // Update contact with new info
            await updateContact(
              name: name,
              email: email,
              phoneNumber: phoneNumber,
              avatarUrl: avatarUrl,
              customAttributes: customAttributes,
            );

            return contact;
          }
        } catch (_) {}
      }

      // Create new contact
      final response = await _dio.post(
        '/public/api/v1/inboxes/$websiteToken/contacts',
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

      final contact = ChatContact.fromJson(response.data);
      _contactIdentifier = contact.identifier;
      _pubsubToken = contact.pubsubToken;

      await prefs.setString('chatwoot_contact_$websiteToken', contact.identifier);

      return contact;
    } catch (e) {
      print('Error creating contact: $e');
      rethrow;
    }
  }

  Future<void> updateContact({
    String? name,
    String? email,
    String? phoneNumber,
    String? avatarUrl,
    Map<String, dynamic>? customAttributes,
  }) async {
    if (_contactIdentifier == null) return;

    try {
      await _dio.patch(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier',
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
    if (_contactIdentifier == null) throw Exception('No contact');

    try {
      // Get existing conversations
      final response = await _dio.get(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier/conversations',
      );

      final conversations = response.data as List;
      if (conversations.isNotEmpty) {
        // Find open conversation
        for (var conv in conversations) {
          if (conv['status'] != 'resolved') {
            _conversationId = conv['id'].toString();
            return _conversationId!;
          }
        }
      }

      // Create new conversation
      final createResponse = await _dio.post(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier/conversations',
      );

      _conversationId = createResponse.data['id'].toString();
      return _conversationId!;
    } catch (e) {
      print('Error getting conversation: $e');
      rethrow;
    }
  }

  Future<List<ChatMessage>> getMessages() async {
    if (_contactIdentifier == null || _conversationId == null) return [];

    try {
      final response = await _dio.get(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier/conversations/$_conversationId/messages',
      );

      final messages = (response.data as List)
          .map((m) => ChatMessage.fromJson(m))
          .where((m) => !m.isPrivate)
          .toList();

      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  Future<ChatMessage?> sendMessage(String content) async {
    if (_contactIdentifier == null || _conversationId == null) return null;

    try {
      final response = await _dio.post(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier/conversations/$_conversationId/messages',
        data: {
          'content': content,
        },
      );

      return ChatMessage.fromJson(response.data);
    } catch (e) {
      print('Error sending message: $e');
      return null;
    }
  }

  Future<void> submitCSAT(int messageId, int rating, {String? feedback}) async {
    if (_contactIdentifier == null || _conversationId == null) return;

    try {
      await _dio.patch(
        '/public/api/v1/inboxes/$websiteToken/contacts/$_contactIdentifier/conversations/$_conversationId/messages/$messageId',
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

  void connectWebSocket() {
    if (_pubsubToken == null) return;

    try {
      final wsUrl = baseUrl.replaceFirst('http', 'ws') + '/cable';
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Subscribe to channel
      _wsChannel!.sink.add(jsonEncode({
        'command': 'subscribe',
        'identifier': jsonEncode({
          'channel': 'RoomChannel',
          'pubsub_token': _pubsubToken,
        }),
      }));

      _wsSubscription = _wsChannel!.stream.listen((data) {
        try {
          final decoded = jsonDecode(data);
          _handleWebSocketMessage(decoded);
        } catch (_) {}
      });
    } catch (e) {
      print('WebSocket error: $e');
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    final message = data['message'];
    if (message == null) return;

    final event = message['event'];
    final messageData = message['data'];

    switch (event) {
      case 'message.created':
        if (messageData != null) {
          final chatMessage = ChatMessage.fromJson(messageData);
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
      case 'presence.update':
        final users = messageData?['users'] as Map?;
        if (users != null && users.isNotEmpty) {
          final isOnline = users.values.any((u) => u == 'online');
          _onlineController.add(isOnline);
        }
        break;
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
    this.customAttributes,
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
  final Map<String, dynamic>? customAttributes;

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
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _theme = ChatTheme(isDark: widget.isDark);
    _apiService = ChatwootApiService(
      baseUrl: widget.baseUrl,
      websiteToken: widget.websiteToken,
    );
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch inbox settings from server (working hours, CSAT, etc.)
      _inboxSettings = await _apiService.getInboxSettings();

      // Build custom attributes
      final customAttrs = <String, dynamic>{};
      if (widget.tenantKey != null) customAttrs['tenant'] = widget.tenantKey;
      if (widget.pushToken != null) customAttrs['pushToken'] = widget.pushToken;
      if (widget.customAttributes != null) customAttrs.addAll(widget.customAttributes!);

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
          if (!_conversationResolved) _buildInputArea(),
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

    if (_messages.isEmpty) {
      return Center(
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
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showDate = index == 0 ||
            !_isSameDay(_messages[index - 1].createdAt, message.createdAt);

        return Column(
          children: [
            if (showDate) _buildDateDivider(message.createdAt),
            if (message.isCSAT)
              _buildCSATWidget(message)
            else
              _buildMessageBubble(message),
          ],
        );
      },
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _theme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _theme.borderColor),
      ),
      child: Column(
        children: [
          Text(
            widget.locale == 'ru'
                ? 'Как вы оцениваете наш сервис?'
                : 'How would you rate our service?',
            style: TextStyle(
              color: _theme.textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final rating = index + 1;
              return GestureDetector(
                onTap: () => _apiService.submitCSAT(message.id, rating),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star_border,
                    size: 36,
                    color: _theme.primaryColor,
                  ),
                ),
              );
            }),
          ),
        ],
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
// FLOATING CHAT BUBBLE
// ============================================================================

/// A floating chat bubble that shows unread messages and opens the chat
class VivaHelpDeskBubble extends StatefulWidget {
  const VivaHelpDeskBubble({
    super.key,
    required this.websiteToken,
    required this.baseUrl,
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
    this.customAttributes,
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
  final Map<String, dynamic>? customAttributes;

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
    );

    _initService();
  }

  Future<void> _initService() async {
    try {
      // Build custom attributes
      final customAttrs = <String, dynamic>{};
      if (widget.tenantKey != null) customAttrs['tenant'] = widget.tenantKey;
      if (widget.pushToken != null) customAttrs['pushToken'] = widget.pushToken;
      if (widget.customAttributes != null) customAttrs.addAll(widget.customAttributes!);

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
                  customAttributes: widget.customAttributes,
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
