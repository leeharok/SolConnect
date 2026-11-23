import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class PointException implements Exception {
  const PointException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PointService {
  static Future<Map<String, dynamic>> getMyTransactions({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/api/points',
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

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const PointException('서버 응답 형식이 올바르지 않아요.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw PointException(
          decoded['message'] as String? ?? '포인트 내역을 불러오지 못했어요.',
        );
      }

      return decoded;
    } on PointException {
      rethrow;
    } catch (error) {
      throw const PointException(
        '포인트 내역을 불러오지 못했어요. 서버 연결을 확인해 주세요.',
      );
    }
  }
}
