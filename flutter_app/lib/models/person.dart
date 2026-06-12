import '../services/api_service.dart';

class Person {
  final int id;
  final String prefix;
  final String firstName;
  final String lastName;
  final String fullName;
  final String citizenId;
  final String disabilityType;
  final String phone;
  final String address;
  final String subdistrict;
  final String district;
  final String province;
  final String? latitude;
  final String? longitude;
  final String mapUrl;
  final bool isGeocoded;
  final bool isCheckedThisYear;
  final String? latestCheckDateThisYear;
  final String? photo;
  final String notes;
  final Map<String, dynamic> rawData;

  Person({
    required this.id,
    required this.prefix,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.citizenId,
    required this.disabilityType,
    required this.phone,
    required this.address,
    required this.subdistrict,
    required this.district,
    required this.province,
    this.latitude,
    this.longitude,
    required this.mapUrl,
    this.isGeocoded = false,
    this.isCheckedThisYear = false,
    this.latestCheckDateThisYear,
    this.photo,
    required this.notes,
    required this.rawData,
  });

  factory Person.fromJson(Map<String, dynamic> json) {
    String? photoUrl = json['photo'];
    if (photoUrl != null && !photoUrl.startsWith('http')) {
      photoUrl = '${ApiService.serverHost}$photoUrl';
    }
    
    return Person(
      id: json['id'] ?? 0,
      prefix: json['prefix'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '${json['prefix'] ?? ''}${json['first_name'] ?? ''} ${json['last_name'] ?? ''}',
      citizenId: json['citizen_id'] ?? '',
      disabilityType: json['disability_type'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      subdistrict: json['subdistrict'] ?? '',
      district: json['district'] ?? '',
      province: json['province'] ?? '',
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      mapUrl: json['map_url'] ?? '',
      isGeocoded: json['is_geocoded'] ?? false,
      isCheckedThisYear: json['is_checked_this_year'] ?? false,
      latestCheckDateThisYear: json['latest_check_date_this_year'],
      photo: photoUrl,
      notes: json['notes'] ?? '',
      rawData: json['raw_data'] ?? {},
    );
  }
}
