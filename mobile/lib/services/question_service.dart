import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user.dart';
import 'api_service.dart';

class QuestionException implements Exception {
  const QuestionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class QuestionService {
  // 이미지 확장자에 따른 MIME 타입 확인
  static String _getMimeType(XFile file) {
    final mime = file.mimeType?.toLowerCase();

    const allowedTypes = [
      'image/jpeg',
      'image/png',
      'image/webp',
    ];

    if (mime != null && allowedTypes.contains(mime)) {
      return mime;
    }

    final extension = file.name.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        throw const QuestionException(
          'JPG, PNG, WEBP 형식의 사진만 업로드할 수 있어요.',
        );
    }
  }

  // 질문 등록
  static Future<Map<String, dynamic>> createQuestion({
    required String token,
    required SchoolLevel schoolLevel,
    required int grade,
    required String subject,
    String? curriculum,
    String? content,
    List<XFile> images = const [],
  }) async {
    if (images.length > 5) {
      throw const QuestionException('사진은 최대 5장까지 첨부할 수 있어요.');
    }

    if (content?.trim().isEmpty != false && images.isEmpty) {
      throw const QuestionException(
        '문제 사진이나 질문 내용을 입력해 주세요.',
      );
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/api/questions'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // 학교급
    final level = switch (schoolLevel) {
      SchoolLevel.elementary => 'ELEMENTARY',
      SchoolLevel.middle => 'MIDDLE',
      SchoolLevel.high => 'HIGH',
    };

    request.fields.addAll({
      'schoolLevel': level,
      'grade': grade.toString(),
      'subject': subject.trim(),
    });

    if (curriculum?.trim().isNotEmpty == true) {
      request.fields['curriculum'] = curriculum!.trim();
    }

    if (content?.trim().isNotEmpty == true) {
      request.fields['content'] = content!.trim();
    }

    // 사진 파일 첨부
    for (final image in images) {
      final bytes = await image.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        throw QuestionException(
          '${image.name} 파일이 5MB를 초과했어요.',
        );
      }

      final mimeType = _getMimeType(image);

      request.files.add(
        http.MultipartFile.fromBytes(
          'images',
          bytes,
          filename: image.name,
          contentType: MediaType.parse(mimeType),
        ),
      );
    }

    try {
      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 60));

      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const QuestionException(
          '서버 응답 형식이 올바르지 않아요.',
        );
      }

      if (response.statusCode != 201 || decoded['success'] != true) {
        throw QuestionException(
          decoded['message'] as String? ?? '질문 등록에 실패했어요.',
        );
      }

      return decoded;
    } on QuestionException {
      rethrow;
    } catch (error) {
      throw const QuestionException(
        '질문을 등록하지 못했어요. 서버 연결을 확인해 주세요.',
      );
    }
  }

  // 멘토가 답변 가능한 질문 목록 조회
  static Future<Map<String, dynamic>> getAvailableQuestions({
    required String token,
    SchoolLevel? schoolLevel,
    int? grade,
    String? subject,
    int page = 1,
    int limit = 10,
  }) async {
    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (schoolLevel != null) {
      queryParameters['schoolLevel'] = switch (schoolLevel) {
        SchoolLevel.elementary => 'ELEMENTARY',
        SchoolLevel.middle => 'MIDDLE',
        SchoolLevel.high => 'HIGH',
      };
    }

    if (grade != null) {
      queryParameters['grade'] = grade.toString();
    }

    if (subject?.trim().isNotEmpty == true) {
      queryParameters['subject'] = subject!.trim();
    }

    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/questions/available',
    ).replace(queryParameters: queryParameters);

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
        throw const QuestionException(
          '서버 응답 형식이 올바르지 않아요.',
        );
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw QuestionException(
          decoded['message'] as String? ?? '질문 목록을 불러오지 못했어요.',
        );
      }

      return decoded;
    } on QuestionException {
      rethrow;
    } catch (error) {
      throw const QuestionException(
        '질문 목록을 불러오지 못했어요. 서버 연결을 확인해 주세요.',
      );
    }
  }

  // 멘티 본인이 등록한 질문 목록 조회
  static Future<Map<String, dynamic>> getMyQuestions({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/questions/mine',
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
        throw const QuestionException('서버 응답 형식이 올바르지 않아요.');
      }

      if (response.statusCode != 200 || decoded['success'] != true) {
        throw QuestionException(
          decoded['message'] as String? ?? '내 질문 목록을 불러오지 못했어요.',
        );
      }

      return decoded;
    } on QuestionException {
      rethrow;
    } catch (_) {
      throw const QuestionException('내 질문 목록을 불러오지 못했어요.');
    }
  }

  // 멘토가 질문 수락 및 채팅방 생성
  static Future<Map<String, dynamic>> acceptQuestion({
    required String token,
    required String questionId,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/api/questions/$questionId/accept',
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const QuestionException(
          '서버 응답 형식이 올바르지 않아요.',
        );
      }

      if (response.statusCode != 201 || decoded['success'] != true) {
        throw QuestionException(
          decoded['message'] as String? ?? '질문 수락에 실패했어요.',
        );
      }

      return decoded;
    } on QuestionException {
      rethrow;
    } catch (error) {
      throw const QuestionException(
        '질문 수락 중 서버 연결 오류가 발생했어요.',
      );
    }
  }
}
