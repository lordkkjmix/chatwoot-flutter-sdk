import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:chatwoot_flutter_sdk/chatwoot_callbacks.dart';
import 'package:chatwoot_flutter_sdk/chatwoot_client.dart';
import 'package:chatwoot_flutter_sdk/data/local/entity/chatwoot_user.dart';
import 'package:chatwoot_flutter_sdk/data/local/local_storage.dart';
import 'package:chatwoot_flutter_sdk/data/remote/chatwoot_client_exception.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action_data.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_new_message_request.dart';
import 'package:chatwoot_flutter_sdk/data/remote/responses/chatwoot_event.dart';
import 'package:chatwoot_flutter_sdk/data/remote/service/chatwoot_client_service.dart';
import 'package:flutter/material.dart';

/// Handles interactions between chatwoot client api service[clientService] and
/// [localStorage] if persistence is enabled.
///
/// Results from repository operations are passed through [callbacks] to be handled
/// appropriately
abstract class ChatwootRepository {
  @protected
  final ChatwootClientService clientService;
  @protected
  final LocalStorage localStorage;
  @protected
  ChatwootCallbacks callbacks;
  List<StreamSubscription> _subscriptions = [];

  ChatwootRepository(this.clientService, this.localStorage, this.callbacks);

  /// Initializes the repository, fetches contact and conversation details.
  Future<void> initialize(ChatwootUser? user);

  /// Retrieves persisted messages from local storage.
  void getPersistedMessages();

  /// Fetches all messages for the conversation from the server.
  Future<void> getMessages();

  /// Listens for incoming websocket events from Chatwoot.
  void listenForEvents();

  /// Sends a message to the conversation.
  Future<void> sendMessage(ChatwootNewMessageRequest request);

  /// Sends an audio file to the conversation.
  Future<void> sendMessageAudio(
      ChatwootNewMessageRequest request, File fileAudio);

  /// Sends a media file to the conversation.
  Future<void> sendMessageMedia(ChatwootNewMessageRequest request, File media);

  /// Sends a user action (eg. typing) to the conversation.
  void sendAction(ChatwootActionType action);

  /// Clears all data related to the current Chatwoot instance.
  Future<void> clear();

  /// Disposes the repository and closes all streams and connections.
  void dispose();
}

class ChatwootRepositoryImpl extends ChatwootRepository {
  // Flags
  bool _isListeningForEvents = false;
  bool _isConnected = false;

  // Timers and subscriptions
  Timer? _publishPresenceTimer;
  Timer? _presenceResetTimer;
  StreamSubscription? _socketSubscription;

  ChatwootRepositoryImpl(
      {required ChatwootClientService clientService,
      required LocalStorage localStorage,
      required ChatwootCallbacks streamCallbacks})
      : super(clientService, localStorage, streamCallbacks);

  /// Fetches all messages for the conversation from the server.
  ///
  /// Calls [ChatwootCallbacks.onMessagesRetrieved] when [ChatwootClientService.getAllMessages] is successful
  /// Calls [ChatwootCallbacks.onError] when [ChatwootClientService.getAllMessages] fails
  @override
  Future<void> getMessages() async {
    try {
      final messages = await clientService.getAllMessages();
      await localStorage.messagesDao.saveAllMessages(messages);
      callbacks.onMessagesRetrieved?.call(messages);
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(e);
    }
  }

  /// Fetches persisted messages from local storage.
  ///
  /// Calls [ChatwootCallbacks.onPersistedMessagesRetrieved] if persisted messages are found
  @override
  void getPersistedMessages() {
    final persistedMessages = localStorage.messagesDao.getMessages();
    if (persistedMessages.isNotEmpty) {
      callbacks.onPersistedMessagesRetrieved?.call(persistedMessages);
    }
  }

  /// Initializes chatwoot client repository, fetches/updates contact and conversation.
  /// After initialization, starts listening for websocket events.
  @override
  Future<void> initialize(ChatwootUser? user) async {
    try {
      if (user != null) {
        await localStorage.userDao.saveUser(user);
      }

      //refresh contact
      final contact = await clientService.getContact();
      localStorage.contactDao.saveContact(contact);

      //refresh conversation
      final conversations = await clientService.getConversations();
      final persistedConversation =
          localStorage.conversationDao.getConversation()!;
      final refreshedConversation = conversations.firstWhere(
          (element) => element.id == persistedConversation.id,
          orElse: () =>
              persistedConversation //highly unlikely orElse will be called but still added it just in case
          );
      localStorage.conversationDao.saveConversation(refreshedConversation);
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(e);
    }

    listenForEvents();
  }

  ///Sends message to chatwoot inbox.
  ///
  /// On success, [ChatwootCallbacks.onMessageSent] is called.
  /// On failure, [ChatwootCallbacks.onError] is called.
  @override
  Future<void> sendMessage(ChatwootNewMessageRequest request) async {
    try {
      final createdMessage = await clientService.createMessage(request);
      await localStorage.messagesDao.saveMessage(createdMessage);
      callbacks.onMessageSent?.call(createdMessage, request.echoId);
      if (clientService.connection != null && !_isListeningForEvents) {
        listenForEvents();
      }
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(
          ChatwootClientException(e.cause, e.type, data: request.echoId));
    }
  }

  /// Sends an audio file to the chatwoot inbox.
  ///
  /// On success, [ChatwootCallbacks.onMessageSent] is called.
  /// On failure, [ChatwootCallbacks.onError] is called.
  @override
  Future<void> sendMessageAudio(
      ChatwootNewMessageRequest request, File audioFile) async {
    try {
      final createdMessage =
          await clientService.sendMessageAudio(request, audioFile);
      await localStorage.messagesDao.saveMessage(createdMessage);
      callbacks.onMessageSent?.call(createdMessage, request.echoId);
      if (clientService.connection != null && !_isListeningForEvents) {
        listenForEvents();
      }
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(
          ChatwootClientException(e.cause, e.type, data: request.echoId));
    }
  }

  /// Sends a media file to the chatwoot inbox.
  ///
  /// On success, [ChatwootCallbacks.onMessageSent] is called.
  /// On failure, [ChatwootCallbacks.onError] is called.
  @override
  Future<void> sendMessageMedia(
      ChatwootNewMessageRequest request, File media) async {
    try {
      final createdMessage =
          await clientService.sendMessageMedia(request, media);
      await localStorage.messagesDao.saveMessage(createdMessage);
      callbacks.onMessageSent?.call(createdMessage, request.echoId);
      if (clientService.connection != null && !_isListeningForEvents) {
        listenForEvents();
      }
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(
          ChatwootClientException(e.cause, e.type, data: request.echoId));
    }
  }

  /// Connects to chatwoot websocket and starts listening for updates.
  ///
  /// Received events/messages are pushed through [ChatwootClient.callbacks].
  @override
  void listenForEvents() {
    // Avoid multiple connections
    if (_isConnected) return;

    final token = localStorage.contactDao.getContact()?.pubsubToken;
    if (token == null || token.isEmpty) {
      return;
    }

    // Open the connection
    try {
      clientService.startWebSocketConnection(
          localStorage.contactDao.getContact()!.pubsubToken ?? "");
      _isConnected = true;
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(ChatwootClientException(e.toString(), e.type));
      return;
    }

    // Subscribe to the client's stream
    final stream = clientService.connection?.stream;
    if (stream == null) {
      _isConnected = false;
      return;
    }

    _socketSubscription = stream.listen((event) {
      try {
        ChatwootEvent chatwootEvent = ChatwootEvent.fromJson(jsonDecode(event));
        if (chatwootEvent.type == ChatwootEventType.welcome) {
          callbacks.onWelcome?.call();
        } else if (chatwootEvent.type == ChatwootEventType.ping) {
          callbacks.onPing?.call();
        } else
        if (chatwootEvent.type == ChatwootEventType.confirm_subscription) {
          if (!_isListeningForEvents) {
            _isListeningForEvents = true;
          }
          _publishPresenceUpdates();
          callbacks.onConfirmedSubscription?.call();
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.message_created) {
          debugPrint("here comes message: $event");
          final message = chatwootEvent.message!.data!.getMessage();
          localStorage.messagesDao.saveMessage(message);
          final echoId = chatwootEvent.message!.data?.echoId ?? "-1";
          if (message.isMine && echoId != "-1") {
            callbacks.onMessageDelivered?.call(
                message, chatwootEvent.message!.data!.echoId!);
          } else {
            callbacks.onMessageReceived?.call(message);
          }
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.message_updated) {
          debugPrint("here comes the updated message: $event");

          final message = chatwootEvent.message!.data!.getMessage();
          localStorage.messagesDao.saveMessage(message);

          callbacks.onMessageUpdated?.call(message);
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.conversation_typing_off) {
          callbacks.onConversationStoppedTyping?.call();
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.conversation_typing_on) {
          callbacks.onConversationStartedTyping?.call();
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.conversation_status_changed &&
            chatwootEvent.message?.data?.status == "resolved" &&
            chatwootEvent.message?.data?.id == (localStorage.conversationDao
                .getConversation()
                ?.id ?? 0)) {
          //delete conversation result
          // localStorage.conversationDao.deleteConversation();
          localStorage.messagesDao.clearAll();
          callbacks.onConversationResolved?.call();
          // Optional: perform automatic cleanup
           fullDisconnect();
        } else if (chatwootEvent.message?.event ==
            ChatwootEventMessageType.presence_update) {
          final presenceStatuses =
              (chatwootEvent.message!.data!.users as Map<dynamic, dynamic>)
                  .values;
          final isOnline = presenceStatuses.contains("online");
          if (isOnline) {
            callbacks.onConversationIsOnline?.call();
            _presenceResetTimer?.cancel();
            _startPresenceResetTimer();
          } else {
            callbacks.onConversationIsOffline?.call();
          }
        } else {
          debugPrint("chatwoot unknown event: $event");
        }
      }catch (err, st) {
        // We catch errors so as not to break the stream
        debugPrint("Error processing event: $err\n$st");
      }
    }, onError: (err) {
      debugPrint("Websocket error: $err");
      callbacks.onError?.call(ChatwootClientException(err.toString(), err));
      // mark as disconnected and clean up
      _isConnected = false;
    }, onDone: () {
      debugPrint("Websocket connection closed (onDone).");
      _isConnected = false;
    }, cancelOnError: true);
    if (_socketSubscription != null) {
      _subscriptions.add(_socketSubscription!);
    }
  }

  /// Clears all data related to current chatwoot client instance
  @override
  Future<void> clear() async {
    await localStorage.clear();
  }

  /// Cancels websocket stream subscriptions and disposes [localStorage]
  @override
  void dispose() {
    // Final cleanup
    fullDisconnect();
    callbacks = ChatwootCallbacks();
    try {
      localStorage.dispose();
    } catch (_) {}
  }

  ///Send actions like user started typing
  @override
  void sendAction(ChatwootActionType action) {
    final token = localStorage.contactDao.getContact()?.pubsubToken ?? "";
    if (token.isEmpty) return;
    try {
      clientService.sendAction(token, action);
    } catch (e) {
      debugPrint("Error sending action: $e");
    }
  }

  ///Publishes presence update to websocket channel at a 30 second interval
  void _publishPresenceUpdates() {
    sendAction(ChatwootActionType.update_presence);
    _publishPresenceTimer?.cancel();
    _publishPresenceTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      sendAction(ChatwootActionType.update_presence);
    });
  }

  ///Triggers an offline presence event after 40 seconds without receiving a presence update event
  void _startPresenceResetTimer() {
    _presenceResetTimer?.cancel();
    _presenceResetTimer = Timer.periodic(Duration(seconds: 40), (timer) {
      callbacks.onConversationIsOffline?.call();
      _presenceResetTimer?.cancel();
    });
  }

  // -------------------------
  //  Full cleanup and disconnection
  // -------------------------

  /// Cancels timers, streams, and closes the websocket.
  /// Call when leaving the view, entering the background, or resolving a conversation.
  void fullDisconnect({bool clearLocalStorage = false}) {
    // Cancel timers
    _publishPresenceTimer?.cancel();
    _publishPresenceTimer = null;

    _presenceResetTimer?.cancel();
    _presenceResetTimer = null;

    // Cancel all subscriptions
    for (final s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();

    // Specific socket
    _socketSubscription?.cancel();
    _socketSubscription = null;

    // Flags
    _isConnected = false;
    _isListeningForEvents = false;

    if (clearLocalStorage) {
      localStorage.clear();
    }
  }
}
