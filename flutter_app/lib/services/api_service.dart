import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/medical_check.dart';
import '../models/person.dart';

class ApiService {
  // If empty, we use relative paths (works for Web when hosted on the same server)
  static const String serverHost = String.fromEnvironment('SERVER_HOST',
      defaultValue: ''); 
  
  static String get baseUrl {
    if (serverHost.isEmpty) {
      return '/api';
    }
    // Ensure no trailing slash in host
    final host = serverHost.endsWith('/') 
        ? serverHost.substring(0, serverHost.length - 1) 
        : serverHost;
    return '$host/api';
  }

  static String? accessToken;
  static String? currentUsername;

  bool get isLoggedIn => accessToken != null;

  Map<String, String> get _authHeaders {
    final token = accessToken;
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  dynamic _handleResponse(http.Response res) {
    if (res.statusCode == 401) {
      logout();
      throw Exception('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.bodyBytes.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }

    String message = 'เกิดข้อผิดพลาด: ${res.statusCode}';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map) {
        if (body['detail'] != null) {
          message = body['detail'].toString();
        } else if (body.isNotEmpty) {
          // Handle field-specific validation errors from DRF
          final errors = <String>[];
          body.forEach((key, value) {
            errors.add('$key: $value');
          });
          message = errors.join(', ');
        }
      }
    } catch (_) {}
    throw Exception(message);
  }

  Future<void> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) {
      String message = 'เข้าสู่ระบบไม่สำเร็จ';
      try {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        if (body is Map && body['detail'] != null) {
          message = body['detail'].toString();
        }
      } catch (_) {}
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

  Future<List<Person>> fetchPersons({
    String search = '',
    String citizenId = '',
    String province = '',
    String district = '',
    String subdistrict = '',
    String address = '',
    String houseNo = '',
    String villageNo = '',
    bool all = false,
  }) async {
    final queryParams = <String, String>{};
    if (search.isNotEmpty) queryParams['search'] = search;
    if (citizenId.isNotEmpty) queryParams['citizen_id'] = citizenId;
    if (province.isNotEmpty) queryParams['province'] = province;
    if (district.isNotEmpty) queryParams['district'] = district;
    if (subdistrict.isNotEmpty) queryParams['subdistrict'] = subdistrict;
    if (address.isNotEmpty) queryParams['address'] = address;
    if (houseNo.isNotEmpty) queryParams['house_no'] = houseNo;
    if (villageNo.isNotEmpty) queryParams['village_no'] = villageNo;
    if (all) queryParams['all'] = 'true';

    final uri = Uri.parse('$baseUrl/persons/')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final res = await http.get(uri, headers: _authHeaders);
    final body = _handleResponse(res);
    final list = body is Map && body.containsKey('results')
        ? body['results'] as List
        : body as List;
    return list.map((e) => Person.fromJson(e)).toList();
  }

  Future<Person> fetchPerson(int id) async {
    final uri = Uri.parse('$baseUrl/persons/$id/');
    final res = await http.get(uri, headers: _authHeaders);
    return Person.fromJson(_handleResponse(res));
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
    
    if (imageBytes == null) {
      final res = await http.post(
        uri,
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return Person.fromJson(_handleResponse(res));
    }

    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      imageBytes,
      filename: fileName ?? 'photo.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    return Person.fromJson(_handleResponse(res));
  }

  Future<Person> updatePerson(int id, Map<String, dynamic> data,
      {Uint8List? imageBytes, String? fileName}) async {
    final uri = Uri.parse('$baseUrl/persons/$id/');

    if (imageBytes == null) {
      final res = await http.patch(
        uri,
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return Person.fromJson(_handleResponse(res));
    }

    var request = http.MultipartRequest('PATCH', uri);
    request.headers.addAll(_authHeaders);

    data.forEach((key, value) {
      request.fields[key] = value?.toString() ?? '';
    });

    request.files.add(http.MultipartFile.fromBytes(
      'photo',
      imageBytes,
      filename: fileName ?? 'photo.jpg',
      contentType: MediaType('image', 'jpeg'),
    ));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);
    return Person.fromJson(_handleResponse(res));
  }

  Future<void> deletePerson(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/persons/$id/'),
        headers: _authHeaders);
    _handleResponse(res);
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final res =
        await http.get(Uri.parse('$baseUrl/stats/'), headers: _authHeaders);
    return _handleResponse(res);
  }

  Future<List<MedicalCheck>> fetchMedicalChecks(int personId) async {
    final uri = Uri.parse('$baseUrl/checks/')
        .replace(queryParameters: {'person': personId.toString()});
    final res = await http.get(uri, headers: _authHeaders);
    final body = _handleResponse(res);
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
    
    if (photoBytes.isEmpty) {
      final res = await http.post(
        uri,
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return MedicalCheck.fromJson(_handleResponse(res));
    }

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
    return MedicalCheck.fromJson(_handleResponse(res));
  }

  Future<MedicalCheck> updateMedicalCheck(
    int id,
    Map<String, dynamic> data, {
    List<Uint8List> photoBytes = const [],
    List<String> fileNames = const [],
  }) async {
    final uri = Uri.parse('$baseUrl/checks/$id/');

    if (photoBytes.isEmpty) {
      final res = await http.patch(
        uri,
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      return MedicalCheck.fromJson(_handleResponse(res));
    }

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
    return MedicalCheck.fromJson(_handleResponse(res));
  }

  Future<void> deleteMedicalCheck(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/checks/$id/'),
        headers: _authHeaders);
    _handleResponse(res);
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
    return _handleResponse(res);
  }

  Future<Uint8List> downloadTemplate() async {
    final res = await http.get(Uri.parse('$baseUrl/download-template/'),
        headers: _authHeaders);
    if (res.statusCode == 401) {
      logout();
      throw Exception('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    if (res.statusCode != 200) {
      throw Exception('ดาวน์โหลดเทมเพลตไม่สำเร็จ: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  Future<Uint8List> downloadReport() async {
    final res = await http.get(Uri.parse('$baseUrl/export-excel/'),
        headers: _authHeaders);
    if (res.statusCode == 401) {
      logout();
      throw Exception('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    if (res.statusCode != 200) {
      throw Exception('ดาวน์โหลดรายงานไม่สำเร็จ: ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  Future<Map<String, List<Person>>> fetchCheckReport(String startDate, String endDate) async {
    final uri = Uri.parse('$baseUrl/check-report/')
        .replace(queryParameters: {'start_date': startDate, 'end_date': endDate});
    final res = await http.get(uri, headers: _authHeaders);
    final body = _handleResponse(res);
    final checked = (body['checked'] as List).map((e) => Person.fromJson(e)).toList();
    final unchecked = (body['unchecked'] as List).map((e) => Person.fromJson(e)).toList();
    return {'checked': checked, 'unchecked': unchecked};
  }

  Future<Uint8List> downloadCheckReport(String startDate, String endDate) async {
    final uri = Uri.parse('$baseUrl/export-check-report/')
        .replace(queryParameters: {'start_date': startDate, 'end_date': endDate});
    final res = await http.get(uri, headers: _authHeaders);
    if (res.statusCode == 401) {
      logout();
      throw Exception('เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    if (res.statusCode != 200) {
      throw Exception('ดาวน์โหลดรายงานไม่สำเร็จ: ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}
