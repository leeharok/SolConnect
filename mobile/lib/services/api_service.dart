import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // 현재 Chrome에서 실행하는 개발 환경
  static const String baseUrl = 'http://localhost:3000';

  // 백엔드 연결 확인
  static Future<Map<String, dynamic>> checkHealth() async {
    final uri = Uri.parse('$baseUrl/api/health');

    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception(
        '서버 응답 오류: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic> || data['success'] != true) {
      throw Exception('서버 응답 형식이 올바르지 않습니다.');
    }

    return data;
  }
}
