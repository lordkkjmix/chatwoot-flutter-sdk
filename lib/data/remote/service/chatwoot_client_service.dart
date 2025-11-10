import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chatwoot_flutter_sdk/data/local/entity/chatwoot_contact.dart';
import 'package:chatwoot_flutter_sdk/data/local/entity/chatwoot_conversation.dart';
import 'package:chatwoot_flutter_sdk/data/local/entity/chatwoot_message.dart';
import 'package:chatwoot_flutter_sdk/data/remote/chatwoot_client_exception.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_action_data.dart';
import 'package:chatwoot_flutter_sdk/data/remote/requests/chatwoot_new_message_request.dart';
import 'package:chatwoot_flutter_sdk/data/remote/service/chatwoot_client_api_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service for handling chatwoot api calls
/// See [ChatwootClientServiceImpl]
abstract class ChatwootClientService {
  final String _baseUrl;
  WebSocketChannel? connection;
  final Dio _dio;

  ChatwootClientService(this._baseUrl, this._dio);

  Future<ChatwootContact> updateContact(update);

  Future<ChatwootContact> getContact();

  Future<List<ChatwootConversation>> getConversations();

  Future<ChatwootMessage> createMessage(ChatwootNewMessageRequest request);

  Future<ChatwootMessage> sendMessageAudio(ChatwootNewMessageRequest request, File audioFile);

  Future<ChatwootMessage> sendMessageMedia(ChatwootNewMessageRequest request, File media);

  Future<ChatwootMessage> updateMessage(String messageIdentifier, update);

  Future<List<ChatwootMessage>> getAllMessages();

  void startWebSocketConnection(String contactPubsubToken,
      {WebSocketChannel Function(Uri)? onStartConnection});

  void sendAction(String contactPubsubToken, ChatwootActionType action);
}

class ChatwootClientServiceImpl extends ChatwootClientService {
  ChatwootClientServiceImpl(String baseUrl, {required Dio dio})
      : super(baseUrl, dio);

  ///Sends message to chatwoot inbox
  @override
  Future<ChatwootMessage> createMessage(
      ChatwootNewMessageRequest request) async {
    try {
      final createResponse = await _dio.post(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations/${ChatwootClientApiInterceptor.INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER}/messages",
          data: request.toJson());
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootMessage.fromJson(createResponse.data);
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
    }
  }

  @override
  Future<ChatwootMessage> sendMessageAudio(
      ChatwootNewMessageRequest request, File audioFile) async {
    try {
      // Prepara el FormData (multipart)
      final Map<String, dynamic> formMap = request.toJson();
      // Añadimos los campos obligatorios si no están en el request
      formMap['content'] ??= '🎤 Audio';
      formMap['message_type'] ??= 'incoming';

      // Añadimos el archivo adjunto
      formMap['attachments[]'] = await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.path.split('/').last,
        contentType: DioMediaType.parse('audio/aac'),
      );

      final formData = FormData.fromMap(formMap);

      // Construye la URL pública de Chatwoot (usando placeholders dinámicos)
      final url =
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations/${ChatwootClientApiInterceptor.INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER}/messages";

      // Envía el archivo usando Dio
      final response = await _dio.post(url, data: formData);

      // Validación de respuesta
      if ((response.statusCode ?? 0).isBetween(199, 300)) { //if ((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        print('✅ Audio enviado correctamente a Chatwoot');
        return ChatwootMessage.fromJson(response.data);
      } else {
        print('❌ Error al enviar audio: ${response.statusCode}');
        print(response.data);
        throw ChatwootClientException(response.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
      }
    } on DioException catch (e) {
      print('🚨 Error Dio al enviar audio: ${e.response?.statusCode}');
      print(e.response?.data ?? e.message);
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
    } catch (e) {
      print('⚠️ Error inesperado: $e');
      throw ChatwootClientException(
          '', ChatwootClientExceptionType.SEND_MESSAGE_FAILED);
    }
  }


  @override
  Future<ChatwootMessage> sendMessageMedia(
      ChatwootNewMessageRequest request,
      File file,
      ) async {
    try {
      final fileName = file.path.split('/').last;
      final extension = fileName.split('.').last.toLowerCase();

      // Determinar tipo MIME según extensión
      String mimeType;
      String emojiLabel;
      switch (extension) {
        case 'mp3':
        case 'aac':
        case 'wav':
        case 'm4a':
          mimeType = 'audio/$extension';
          emojiLabel = '🎤 Audio message';
          break;

        case 'mp4':
        case 'mov':
        case 'avi':
        case 'mkv':
        case 'webm':
          mimeType = 'video/$extension';
          emojiLabel = '🎥 Video message';
          break;

        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          emojiLabel = '🖼️ Image message';
          break;
        case 'png':
          mimeType = 'image/png';
          emojiLabel = '🖼️ Image message';
          break;
        case 'gif':
          mimeType = 'image/gif';
          emojiLabel = '🖼️ Image message';
          break;
        case 'webp':
          mimeType = 'image/webp';
          emojiLabel = '🖼️ Image message';
          break;
        default:
          mimeType = 'application/octet-stream';
          emojiLabel = '📎 File message';
          break;
      }

      final Map<String, dynamic> reqMap = request.toJson();

      // Obtener el tipo de mensaje
      final messageType = (reqMap['message_type'] as String?) ??
          (reqMap['messageType'] as String?) ??
          'incoming';

      // Construir el FormData con los datos del request
      final formMap = Map<String, dynamic>.from(reqMap);

      // Reforzamos valores clave que Chatwoot necesita
      formMap['content'] = (request.content.isNotEmpty == true)
          ? request.content
          : emojiLabel;
      formMap['message_type'] = messageType;

      // Adjuntar el archivo
      formMap['attachments[]'] = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: DioMediaType.parse(mimeType),
      );

      // Crear FormData
      final formData = FormData.fromMap(formMap);
      print('>>>>>>>>>>>   formData >>> ${formData}');
      // Construcción de URL (usa placeholders del interceptor)
      final url =
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations/${ChatwootClientApiInterceptor.INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER}/messages";

      // Envío de archivo
      final response = await _dio.post(url, data: formData);

      if ((response.statusCode ?? 0).isBetween(199, 300)) { //((response.statusCode ?? 0) >= 200 && (response.statusCode ?? 0) < 300) {
        print('✅ Archivo ($mimeType) enviado correctamente a Chatwoot');
        return ChatwootMessage.fromJson(response.data);
      } else {
        print('❌ Error al enviar archivo: ${response.statusCode}');
        print(response.data);
        throw ChatwootClientException(
          response.statusMessage ?? "unknown error",
          ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
        );
      }
    } on DioException catch (e) {
      print('🚨 Error Dio al enviar archivo: ${e.response?.statusCode}');
      print(e.response?.data ?? e.message);
      throw ChatwootClientException(
        e.message ?? '',
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );
    } catch (e) {
      print('⚠️ Error inesperado: $e');
      throw ChatwootClientException(
        e.toString(),
        ChatwootClientExceptionType.SEND_MESSAGE_FAILED,
      );
    }
  }


  ///Gets all messages of current chatwoot client instance's conversation
  @override
  Future<List<ChatwootMessage>> getAllMessages() async {
    try {
      final createResponse = await _dio.get(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations/${ChatwootClientApiInterceptor.INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER}/messages");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return (createResponse.data as List<dynamic>)
            .map(((json) => ChatwootMessage.fromJson(json)))
            .toList();
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_MESSAGES_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.GET_MESSAGES_FAILED);
    }
  }

  ///Gets contact of current chatwoot client instance
  @override
  Future<ChatwootContact> getContact() async {
    try {
      final createResponse = await _dio.get(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootContact.fromJson(createResponse.data);
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_CONTACT_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.GET_CONTACT_FAILED);
    }
  }

  ///Gets all conversation of current chatwoot client instance
  @override
  Future<List<ChatwootConversation>> getConversations() async {
    try {
      final createResponse = await _dio.get(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations");
      if ((createResponse.statusCode ?? 0).isBetween(199, 300)) {
        return (createResponse.data as List<dynamic>)
            .map(((json) => ChatwootConversation.fromJson(json)))
            .toList();
      } else {
        throw ChatwootClientException(
            createResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.GET_CONVERSATION_FAILED);
    }
  }

  ///Update current client instance's contact
  @override
  Future<ChatwootContact> updateContact(update) async {
    try {
      final updateResponse = await _dio.patch(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}",
          data: update);
      if ((updateResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootContact.fromJson(updateResponse.data);
      } else {
        throw ChatwootClientException(
            updateResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.UPDATE_CONTACT_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.UPDATE_CONTACT_FAILED);
    }
  }

  ///Update message with id [messageIdentifier] with contents of [update]
  @override
  Future<ChatwootMessage> updateMessage(
      String messageIdentifier, update) async {
    try {
      final updateResponse = await _dio.patch(
          "/public/api/v1/inboxes/${ChatwootClientApiInterceptor.INTERCEPTOR_INBOX_IDENTIFIER_PLACEHOLDER}/contacts/${ChatwootClientApiInterceptor.INTERCEPTOR_CONTACT_IDENTIFIER_PLACEHOLDER}/conversations/${ChatwootClientApiInterceptor.INTERCEPTOR_CONVERSATION_IDENTIFIER_PLACEHOLDER}/messages/$messageIdentifier",
          data: update);
      if ((updateResponse.statusCode ?? 0).isBetween(199, 300)) {
        return ChatwootMessage.fromJson(updateResponse.data);
      } else {
        throw ChatwootClientException(
            updateResponse.statusMessage ?? "unknown error",
            ChatwootClientExceptionType.UPDATE_MESSAGE_FAILED);
      }
    } on DioException catch (e) {
      throw ChatwootClientException(
          e.message ?? '', ChatwootClientExceptionType.UPDATE_MESSAGE_FAILED);
    }
  }

  @override
  void startWebSocketConnection(String contactPubsubToken,
      {WebSocketChannel Function(Uri)? onStartConnection}) {
    final socketUrl = Uri.parse(_baseUrl.replaceFirst("http", "ws") + "/cable");
    this.connection = onStartConnection == null
        ? WebSocketChannel.connect(socketUrl)
        : onStartConnection(socketUrl);
    connection!.sink.add(jsonEncode({
      "command": "subscribe",
      "identifier": jsonEncode(
          {"channel": "RoomChannel", "pubsub_token": contactPubsubToken})
    }));
  }

  @override
  void sendAction(String contactPubsubToken, ChatwootActionType actionType) {
    final ChatwootAction action;
    final identifier = jsonEncode(
        {"channel": "RoomChannel", "pubsub_token": contactPubsubToken});
    switch (actionType) {
      case ChatwootActionType.subscribe:
        action = ChatwootAction(identifier: identifier, command: "subscribe");
        break;
      default:
        action = ChatwootAction(
            identifier: identifier,
            data: ChatwootActionData(action: actionType),
            command: "message");
        break;
    }
    connection?.sink.add(jsonEncode(action.toJson()));
  }
}
