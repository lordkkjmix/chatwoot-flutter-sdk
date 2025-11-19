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

  Future<void> initialize(ChatwootUser? user);

  void getPersistedMessages();

  Future<void> getMessages();

  void listenForEvents();

  Future<void> sendMessage(ChatwootNewMessageRequest request);

  Future<void> sendMessageAudio(
      ChatwootNewMessageRequest request, File fileAudio);

  Future<void> sendMessageMedia(ChatwootNewMessageRequest request, File media);

  void sendAction(ChatwootActionType action);

  Future<void> clear();

  void dispose();

  void fullDisconnect({bool clearLocalStorage = false});
}

class ChatwootRepositoryImpl extends ChatwootRepository {
  // Flags
  bool _isListeningForEvents = false;
  bool _isConnected = false;

  // Timers y suscripciones
  Timer? _publishPresenceTimer;
  Timer? _presenceResetTimer;
  StreamSubscription? _socketSubscription;

  ChatwootRepositoryImpl(
      {required ChatwootClientService clientService,
      required LocalStorage localStorage,
      required ChatwootCallbacks streamCallbacks})
      : super(clientService, localStorage, streamCallbacks);

  /// Fetches persisted messages.
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

  /// Fetches persisted messages.
  ///
  /// Calls [ChatwootCallbacks.onPersistedMessagesRetrieved] if persisted messages are found
  @override
  void getPersistedMessages() {
    final persistedMessages = localStorage.messagesDao.getMessages();
    if (persistedMessages.isNotEmpty) {
      callbacks.onPersistedMessagesRetrieved?.call(persistedMessages);
    }
  }

  /// Initializes chatwoot client repository
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

  ///Sends message to chatwoot inbox
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

  /// Connects to chatwoot websocket and starts listening for updates
  ///
  /// Received events/messages are pushed through [ChatwootClient.callbacks]
  @override
  void listenForEvents() {
    // Evita múltiples conexiones
    if (_isConnected) return;

    final token = localStorage.contactDao.getContact()?.pubsubToken;
    if (token == null || token.isEmpty) {
      return;
    }

    // Abre la conexión (clientService debe exponer startWebSocketConnection)
    try {
      clientService.startWebSocketConnection(
          localStorage.contactDao.getContact()!.pubsubToken ?? "");
      _isConnected = true;
    } on ChatwootClientException catch (e) {
      callbacks.onError?.call(ChatwootClientException(e.toString(), e.type));
      return;
    }

    // Subscribe a stream del client
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
          // Opcional: realizar limpieza automática
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
        // Atrapamos errores para no romper el stream
        debugPrint("Error procesando evento: $err\n$st");
      }
    }, onError: (err) {
      debugPrint("Websocket error: $err");
      callbacks.onError?.call(ChatwootClientException(err.toString(), err));
      // marcar desconectado y limpiar
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
    // Limpieza final
    fullDisconnect();
    //localStorage.dispose();
    callbacks = ChatwootCallbacks();
    try {
      localStorage.dispose();
    } catch (_) {}
    /*_presenceResetTimer?.cancel();
    _publishPresenceTimer?.cancel();
    _subscriptions.forEach((subs) {
      subs.cancel();
    });*/
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
  //  Limpieza total y desconexión
  // -------------------------

  /// Cancela timers, streams, y cierra websocket.
  /// Llamar cuando sales de la vista, entras al background o resuelves conversación.
  void fullDisconnect({bool clearLocalStorage = false}) {
    // Cancel timers
    _publishPresenceTimer?.cancel();
    _publishPresenceTimer = null;

    _presenceResetTimer?.cancel();
    _presenceResetTimer = null;

    // Cancelar todas las suscripciones
    for (final s in _subscriptions) {
      try {
        s.cancel();
      } catch (_) {}
    }
    _subscriptions.clear();

    // Socket específico
    _socketSubscription?.cancel();
    _socketSubscription = null;

    // Flags
    _isConnected = false;
    _isListeningForEvents = false;

    // Cerrar conexión en el clientService (implementa este método)
    try {
      //clientService.connection?.();
    } catch (_) {}

    if (clearLocalStorage) {
      localStorage.clear();
    }
  }
}
