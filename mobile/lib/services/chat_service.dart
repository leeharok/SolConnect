import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import 'api_service.dart';

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ChatService {
  socket_io.Socket? _socket;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  final _readController = StreamController<Map<String, dynamic>>.broadcast();

  final _completedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _completionRequestedController =
      StreamController<Map<String, dynamic>>.broadcast();

  final _completionResponseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  Stream<Map<String, dynamic>> get readEvents => _readController.stream;

  Stream<Map<String, dynamic>> get completedEvents =>
      _completedController.stream;

  Stream<Map<String, dynamic>> get completionRequestedEvents =>
      _completionRequestedController.stream;

  Stream<Map<String, dynamic>> get completionResponseEvents =>
      _completionResponseController.stream;

  bool get isConnected => _socket?.connected ?? false;

  // 서버 응답을 Map으로 변환
  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const ChatException('서버 응답 형식이 올바르지 않아요.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw ChatException(
        decoded['message'] as String? ?? '요청에 실패했어요.',
      );
    }

    return decoded;
  }

  // 내 채팅방 목록 조회
  Future<List<Map<String, dynamic>>> getMyChatRooms({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/chats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final data = _decode(response);
      final rooms = data['chatRooms'];

      if (rooms is! List) return [];

      return rooms
          .whereType<Map>()
          .map((room) => Map<String, dynamic>.from(room))
          .toList();
    } on ChatException {
      rethrow;
    } catch (error) {
      throw const ChatException('채팅방 목록을 불러오지 못했어요.');
    }
  }

  // 안 읽은 채팅 메시지 수 조회
  Future<int> getUnreadCount({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/chats/unread-count'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final data = _decode(response);
      final value = data['unreadCount'];

      if (value is int) return value;
      return int.tryParse(value?.toString() ?? '') ?? 0;
    } on ChatException {
      rethrow;
    } catch (error) {
      throw const ChatException('안 읽은 메시지 수를 불러오지 못했어요.');
    }
  }

  // 기존 채팅 내역 조회
  Future<List<Map<String, dynamic>>> getMessages({
    required String token,
    required String chatRoomId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/chats/$chatRoomId/messages',
      ).replace(
        queryParameters: {
          'page': page.toString(),
          'limit': limit.toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final data = _decode(response);
      final rawMessages = data['messages'];

      if (rawMessages is! List) return [];

      return rawMessages
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on ChatException {
      rethrow;
    } catch (error) {
      throw const ChatException('채팅 기록을 불러오지 못했어요.');
    }
  }

  // Socket.IO 연결 및 JWT 인증
  Future<void> connect({
    required String token,
  }) async {
    if (isConnected) return;

    disconnect();

    final completer = Completer<void>();

    final socket = socket_io.io(
      ApiService.baseUrl,
      {
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true,
        'multiplex': false,
        'auth': {'token': token},
      },
    );

    _socket = socket;

    // 실시간 메시지 수신
    socket.on('chat:message', (data) {
      if (data is Map) {
        _messageController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // 읽음 상태 수신
    socket.on('chat:read', (data) {
      if (data is Map) {
        _readController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // 멘토의 풀이 전달 완료 요청 수신
    socket.on('chat:completion-requested', (data) {
      if (data is Map) {
        _completionRequestedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // 멘티의 해결 여부 응답 수신
    socket.on('chat:completion-response', (data) {
      if (data is Map) {
        _completionResponseController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    // 멘토링 종료 수신
    socket.on('chat:completed', (data) {
      if (data is Map) {
        _completedController.add(
          Map<String, dynamic>.from(data),
        );
      }
    });

    socket.onConnect((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    socket.onConnectError((error) {
      if (!completer.isCompleted) {
        completer.completeError(
          ChatException('채팅 서버 연결 실패: $error'),
        );
      }
    });

    socket.connect();

    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
      );
    } on TimeoutException {
      socket.disconnect();
      throw const ChatException('채팅 서버 연결 시간이 초과됐어요.');
    }
  }

  // 서버에 채팅방 입장 요청
  Future<Map<String, dynamic>> joinChatRoom({
    required String chatRoomId,
  }) {
    return _emitWithAck(
      'chat:join',
      {'chatRoomId': chatRoomId},
    );
  }

  // 메시지 전송
  Future<Map<String, dynamic>> sendMessage({
    required String chatRoomId,
    required String content,
  }) {
    return _emitWithAck(
      'chat:send',
      {
        'chatRoomId': chatRoomId,
        'content': content,
      },
    );
  }

  // 상대방 메시지 읽음 처리
  Future<Map<String, dynamic>> markAsRead({
    required String chatRoomId,
  }) {
    return _emitWithAck(
      'chat:read',
      {'chatRoomId': chatRoomId},
    );
  }

  // Socket.IO 이벤트 응답 처리
  Future<Map<String, dynamic>> _emitWithAck(
    String event,
    Map<String, dynamic> payload,
  ) {
    final socket = _socket;

    if (socket == null || !socket.connected) {
      throw const ChatException('채팅 서버에 연결되어 있지 않아요.');
    }

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(
      event,
      payload,
      ack: (response) {
        if (completer.isCompleted) return;

        if (response is! Map) {
          completer.completeError(
            const ChatException('서버 응답을 확인할 수 없어요.'),
          );
          return;
        }

        final data = Map<String, dynamic>.from(response);

        if (data['success'] != true) {
          completer.completeError(
            ChatException(
              data['message'] as String? ?? '요청에 실패했어요.',
            ),
          );
          return;
        }

        completer.complete(data);
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw const ChatException('서버 응답이 지연되고 있어요.');
      },
    );
  }

  // 멘토의 풀이 전달 완료 요청
  Future<Map<String, dynamic>> requestChatCompletion({
    required String token,
    required String chatRoomId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/api/chats/$chatRoomId/request-completion',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      return _decode(response);
    } on ChatException {
      rethrow;
    } catch (error) {
      throw const ChatException('풀이 전달 완료 요청 중 오류가 발생했어요.');
    }
  }

  // 멘티의 문제 해결 여부 확인
  Future<Map<String, dynamic>> confirmChatCompletion({
    required String token,
    required String chatRoomId,
    required bool resolved,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiService.baseUrl}/api/chats/$chatRoomId/confirm-completion',
            ),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'resolved': resolved,
            }),
          )
          .timeout(const Duration(seconds: 15));

      return _decode(response);
    } on ChatException {
      rethrow;
    } catch (error) {
      throw const ChatException('문제 해결 여부를 전달하지 못했어요.');
    }
  }

  // Socket.IO 연결 해제
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _readController.close();
    _completedController.close();
    _completionRequestedController.close();
    _completionResponseController.close();
  }
}
