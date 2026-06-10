import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/medical_check.dart';
import '../models/person.dart';

class ApiService {
  static const String serverHost = String.fromEnvironment('SERVER_HOST',
      defaultValue: 'http://localhost:8000');
  static const String baseUrl = '$serverHost/api';
  static String? accessToken;
  static String? currentUsername;

  bool get isLoggedIn => accessToken != null;

  Map<String, String> get _authHeaders {
    final token = accessToken;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  Future<void> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      String message = 'เข้าสู่ระบบไม่สำเร็จ';
      final text = utf8.decode(res.bodyBytes);
      try {
        final body = jsonDecode(text);
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {
        // Keep the generic login message when the server returns non-JSON.
      }
      throw Exception(message);
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    accessToken = body['access'];
    currentUsername = username;
  }

  void logout() {
    accessToken = null;
    currentUsername = null;
  }

  Future<List<Person>> fetchPersons({String search = '', String citizenId = ''}) async {
    final queryParams = <String, String>{};
    if (search.isNotEmpty) queryParams['search'] = search;
    if (citizenId.isNotEmpty) queryParams['citizen_id'] = citizenId;

    final uri = Uri.parse('$baseUrl/persons/')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('โหลดข้อมูลไม่สำเร็จ: ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final list = body is Map && body.containsKey('results')
        ? body['results'] as List
        : body as List;
    return list.map((e) => Person.fromJson(e)).toList();
  }

  Future<Person?> findByCitizenId(String citizenId) async {
    if (citizenId.trim().isEmpty) return null;
    final results = await fetchPersons(citizenId: citizenId.trim());
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Person> createPerson(Map<String, dynamic> data,
      {Uint8List? imageBytes, String? fileName}) async {
    final uri = Uri.parse('$baseUrl/persons/');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    if (imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        imageBytes,
        filename: fileName ?? 'photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 201) {
      throw Exception('เพิ่มข้อมูลไม่สำเร็จ: ${res.statusCode}');
    }
    return Person.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<Person> updatePerson(int id, Map<String, dynamic> data,
      {Uint8List? imageBytes, String? fileName}) async {
    final uri = Uri.parse('$baseUrl/persons/$id/');
    var request = http.MultipartRequest('PATCH', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    if (imageBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        imageBytes,
        filename: fileName ?? 'photo.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode != 200) {
      throw Exception('แก้ไขข้อมูลไม่สำเร็จ: ${res.statusCode}');
    }
    return Person.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<void> deletePerson(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/persons/$id/'),
        headers: _authHeaders);
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('ลบข้อมูลไม่สำเร็จ: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final res =
        await http.get(Uri.parse('$baseUrl/stats/'), headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('โหลดสรุปไม่สำเร็จ');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<List<MedicalCheck>> fetchMedicalChecks(int personId) async {
    final uri = Uri.parse('$baseUrl/checks/')
        .replace(queryParameters: {'person': personId.toString()});
    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('โหลดผลตรวจไม่สำเร็จ: ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    final list = body is Map && body.containsKey('results')
        ? body['results'] as List
        : body as List;
    return list.map((e) => MedicalCheck.fromJson(e)).toList();
  }

  Future<MedicalCheck> createMedicalCheck(
    Map<String, dynamic> data, {
    List<Uint8List> photoBytes = const [],
    List<String> fileNames = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/checks/');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    for (var i = 0; i < photoBytes.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        'photos',
        photoBytes[i],
        filename: i < fileNames.length ? fileNames[i] : 'check_photo_$i.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 201) {
      throw Exception('เพิ่มผลตรวจไม่สำเร็จ: ${res.statusCode}');
    }
    return MedicalCheck.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<MedicalCheck> updateMedicalCheck(
    int id,
    Map<String, dynamic> data, {
    List<Uint8List> photoBytes = const [],
    List<String> fileNames = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/checks/$id/');
    final request = http.MultipartRequest('PATCH', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    for (var i = 0; i < photoBytes.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        'photos',
        photoBytes[i],
        filename: i < fileNames.length ? fileNames[i] : 'check_photo_$i.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) {
      throw Exception('แก้ไขผลตรวจไม่สำเร็จ: ${res.statusCode}');
    }
    return MedicalCheck.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  Future<void> deleteMedicalCheck(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/checks/$id/'),
        headers: _authHeaders);
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('ลบผลตรวจไม่สำเร็จ: ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> importExcel(
      Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse('$baseUrl/import-excel/');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: MediaType('application',
          'vnd.openxmlformats-officedocument.spreadsheetml.sheet'),
    ));
    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    if (res.statusCode != 200) {
      final text = utf8.decode(res.bodyBytes);
      String message = 'นำเข้าข้อมูลไม่สำเร็จ: ${res.statusCode}';
      try {
        final body = jsonDecode(text);
        message = body['detail'] ?? message;
      } catch (_) {
        // Keep the generic status message when the server returns non-JSON.
      }
      throw Exception(message);
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<Uint8List> downloadTemplate() async {
    final res = await http.get(Uri.parse('$baseUrl/download-template/'),
        headers: _authHeaders);
    if (res.statusCode != 200) {
      throw Exception('ดาวน์โหลดเทมเพลตไม่สำเร็จ: ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
