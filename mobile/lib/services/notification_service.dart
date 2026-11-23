import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NotificationService {
  static Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const NotificationException('서버 응답 형식이 올바르지 않아요.');
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      throw NotificationException(
        decoded['message'] as String? ?? '알림 요청에 실패했어요.',
      );
    }

    return decoded;
  }

  // 내 알림 목록
  static Future<Map<String, dynamic>> getMyNotifications({
    required String token,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/notifications',
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

      return _decode(response);
    } on NotificationException {
      rethrow;
    } catch (_) {
      throw const NotificationException('알림을 불러오지 못했어요.');
    }
  }

  // 안 읽은 알림 수
  static Future<int> getUnreadCount({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/api/notifications/unread-count',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final data = _decode(response);
      final count = data['unreadCount'];

      return count is int ? count : 0;
    } on NotificationException {
      rethrow;
    } catch (_) {
      throw const NotificationException('알림 개수를 불러오지 못했어요.');
    }
  }

  // 알림 하나 읽음
  static Future<void> markAsRead({
    required String token,
    required String notificationId,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/notifications/$notificationId/read',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      _decode(response);
    } on NotificationException {
      rethrow;
    } catch (_) {
      throw const NotificationException('알림을 읽음 처리하지 못했어요.');
    }
  }

  // 모든 알림 읽음
  static Future<void> markAllAsRead({
    required String token,
  }) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/notifications/read-all',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      _decode(response);
    } on NotificationException {
      rethrow;
    } catch (_) {
      throw const NotificationException('알림 전체 읽음 처리에 실패했어요.');
    }
  }
}
