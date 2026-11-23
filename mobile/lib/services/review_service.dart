import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class ReviewException implements Exception {
  const ReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReviewService {
  static const int reviewPoints = 200;

  // 만족 / 불만족 후기 제출
  static Future<Map<String, dynamic>> submitReview({
    required String token,
    required String chatRoomId,
    required String sentiment,
    String? comment,
    String? dissatisfactionReason,
  }) async {
    if (!['SATISFIED', 'UNSATISFIED'].contains(sentiment)) {
      throw const ReviewException('만족 또는 불만족을 선택해 주세요.');
    }

    final cleanComment = comment?.trim() ?? '';
    final cleanReason = dissatisfactionReason?.trim() ?? '';

    if (sentiment == 'UNSATISFIED' && cleanReason.length < 100) {
      throw const ReviewException('불만족 사유를 100자 이상 작성해 주세요.');
    }

    if (cleanComment.length > 5000 || cleanReason.length > 5000) {
      throw const ReviewException('후기는 5000자까지 작성할 수 있습니다.');
    }

    try {
      final response = await http
          .post(
            Uri.parse(
              '${ApiService.baseUrl}/api/chats/$chatRoomId/review',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sentiment': sentiment,
              'comment': sentiment == 'SATISFIED' ? cleanComment : '',
              'dissatisfactionReason':
                  sentiment == 'UNSATISFIED' ? cleanReason : '',
            }),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const ReviewException('서버 응답 형식이 올바르지 않아요.');
      }

      if (response.statusCode != 201 || decoded['success'] != true) {
        throw ReviewException(
          decoded['message'] as String? ?? '후기 등록에 실패했어요.',
        );
      }

      return decoded;
    } on ReviewException {
      rethrow;
    } catch (error) {
      throw const ReviewException(
        '후기를 등록하지 못했어요. 서버 연결을 확인해 주세요.',
      );
    }
  }

  // 멘토가 받은 후기 목록 조회
  static Future<Map<String, dynamic>> getReceivedReviews({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/reviews/received',
    ).replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const ReviewException('서버 응답 형식이 올바르지 않아요.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw ReviewException(
          decoded['message'] as String? ?? '받은 후기를 불러오지 못했어요.',
        );
      }

      return decoded;
    } on ReviewException {
      rethrow;
    } catch (_) {
      throw const ReviewException('받은 후기를 불러오지 못했어요.');
    }
  }
}
