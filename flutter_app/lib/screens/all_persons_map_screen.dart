import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import 'person_detail_screen.dart';

class AllPersonsMapScreen extends StatefulWidget {
  const AllPersonsMapScreen({super.key});

  @override
  State<AllPersonsMapScreen> createState() => _AllPersonsMapScreenState();
}

class _AllPersonsMapScreenState extends State<AllPersonsMapScreen> {
  final api = ApiService();
  final searchController = TextEditingController();
  final mapController = MapController();
  
  List<Person> allPersons = [];
  List<Person> filteredPersons = [];
  bool isLoading = true;
  bool _isSatellite = false;
  LatLng? _myLocation;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _myLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      final list = await api.fetchPersons(all: true);
      if (mounted) {
        setState(() {
          allPersons = list;
          _applyFilter();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ: $e')),
        );
      }
    }
  }

  void _applyFilter() {
    final query = searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        filteredPersons = List.from(allPersons);
      } else {
        filteredPersons = allPersons.where((p) {
          final fullName = p.fullName.toLowerCase();
          final citizenId = p.citizenId.toLowerCase();
          return fullName.contains(query) || citizenId.contains(query);
        }).toList();
      }
    });
  }

  LatLng? _getLatLng(Person p) {
    if (p.latitude != null && p.longitude != null && p.latitude!.isNotEmpty && p.longitude!.isNotEmpty) {
      final lat = double.tryParse(p.latitude!);
      final lng = double.tryParse(p.longitude!);
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    
    if (p.mapUrl.isNotEmpty) {
      final atMatch = RegExp(r'@([-\d.]+),([-\d.]+)').firstMatch(p.mapUrl);
      if (atMatch != null) {
        final lat = double.tryParse(atMatch.group(1)!);
        final lng = double.tryParse(atMatch.group(2)!);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      
      final queryMatch = RegExp(r'query=([-\d.]+),([-\d.]+)').firstMatch(p.mapUrl);
      if (queryMatch != null) {
        final lat = double.tryParse(queryMatch.group(1)!);
        final lng = double.tryParse(queryMatch.group(2)!);
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แผนที่ (${filteredPersons.length} คน)'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt),
            onPressed: () => setState(() => _isSatellite = !_isSatellite),
            tooltip: _isSatellite ? 'สลับเป็นแผนที่ปกติ' : 'สลับเป็นภาพถ่ายดาวเทียม',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildMap(context),
          ),
        ],
      ),
      floatingActionButton: _myLocation != null ? FloatingActionButton(
        onPressed: () {
          if (_myLocation != null) {
            mapController.move(_myLocation!, 15);
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.teal),
      ) : null,
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อ หรือเลขบัตร...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          _applyFilter();
                        },
                      )
                    : null,
              ),
              onChanged: (v) => _applyFilter(),
              onSubmitted: (v) => _applyFilter(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _applyFilter,
            style: FilledButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('ค้นหา'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context) {
    final Map<LatLng, List<Person>> groupedMarkers = {};
    
    for (var p in filteredPersons) {
      final pos = _getLatLng(p);
      if (pos != null) {
        final key = LatLng(
          double.parse(pos.latitude.toStringAsFixed(6)),
          double.parse(pos.longitude.toStringAsFixed(6)),
        );
        groupedMarkers.putIfAbsent(key, () => []).add(p);
      }
    }

    final markers = groupedMarkers.entries.map((entry) {
      final pos = entry.key;
      final peopleAtPos = entry.value;
      final count = peopleAtPos.length;
      final checkedCount = peopleAtPos.where((p) => p.isCheckedThisYear).length;
      
      // Determine color: blue if ALL at this position are geocoded
      final isAnyGps = peopleAtPos.any((p) => !p.isGeocoded);
      final markerColor = isAnyGps ? Colors.red : Colors.blue;
      
      // Determine border color based on check status
      Color labelBorderColor = isAnyGps ? Colors.teal : Colors.blue.shade800;
      if (count == 1) {
        labelBorderColor = peopleAtPos.first.isCheckedThisYear ? Colors.green : Colors.orange;
      } else {
        // For clusters, use green if everyone is checked, orange if none, teal/blue otherwise
        if (checkedCount == count) labelBorderColor = Colors.green;
        else if (checkedCount == 0) labelBorderColor = Colors.orange;
      }

      return Marker(
        point: pos,
        width: 160,
        height: 110,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () {
            if (count == 1) {
              _showSinglePersonDetail(context, peopleAtPos.first);
            } else {
              _showPeopleAtLocation(context, pos, peopleAtPos);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2))],
                  border: Border.all(color: labelBorderColor, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count == 1 ? peopleAtPos.first.fullName : '$count คน',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      count == 1 
                        ? (peopleAtPos.first.isCheckedThisYear 
                            ? 'ตรวจแล้ว (${peopleAtPos.first.latestCheckDateThisYear ?? ''})' 
                            : 'ยังไม่ตรวจ')
                        : 'ตรวจแล้ว $checkedCount/$count',
                      style: TextStyle(
                        fontSize: 9, 
                        fontWeight: FontWeight.bold, 
                        color: (count == 1 ? peopleAtPos.first.isCheckedThisYear : checkedCount > 0) ? Colors.green : Colors.orange
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.location_on, 
                color: markerColor, 
                size: 40,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black38, offset: Offset(0, 2))],
              ),
            ],
          ),
        ),
      );
    }).toList();

    // Add user location marker
    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 60,
          height: 60,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'คุณ',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(
                Icons.person,
                color: Colors.green,
                size: 40,
                shadows: [Shadow(blurRadius: 4, color: Colors.black38, offset: Offset(0, 2))],
              ),
            ],
          ),
        ),
      );
    }

    LatLng initialCenter = const LatLng(13.7563, 100.5018);
    if (markers.isNotEmpty) {
      initialCenter = markers.first.point;
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: _isSatellite 
            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.disability_app.app',
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () => launchUrl(Uri.parse('https://openstreetmap.org/copyright')),
            ),
          ],
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  void _showSinglePersonDetail(BuildContext context, Person p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person, color: Colors.teal),
            SizedBox(width: 8),
            Text('ข้อมูลผู้ทุพพลภาพ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('ชื่อ-นามสกุล:', p.fullName),
            const SizedBox(height: 8),
            _detailRow('สถานะการตรวจปีนี้:', p.isCheckedThisYear ? 'ตรวจแล้ว' : 'ยังไม่ตรวจ', 
              valueColor: p.isCheckedThisYear ? Colors.green : Colors.orange),
            const SizedBox(height: 8),
            _detailRow('เลขบัตรประชาชน:', p.citizenId),
            const SizedBox(height: 8),
            _detailRow('ประเภทความพิการ:', p.disabilityType),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonDetailScreen(person: p),
                ),
              );
              _fetchData(); // Refresh data after returning
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('ดูรายละเอียดทั้งหมด'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
        Text(value.isEmpty ? '-' : value, style: TextStyle(fontSize: 16, color: valueColor)),
      ],
    );
  }

  void _showPeopleAtLocation(BuildContext context, LatLng pos, List<Person> people) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ผู้ทุพพลภาพในบริเวณนี้ (${people.length} คน)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: people.length,
                itemBuilder: (context, index) {
                  final p = people[index];
                  return ListTile(
                    leading: p.photo != null
                        ? CircleAvatar(backgroundImage: NetworkImage(p.photo!))
                        : const CircleAvatar(child: Icon(Icons.person)),
                    title: Row(
                      children: [
                        Expanded(child: Text(p.fullName)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: p.isCheckedThisYear ? Colors.green.shade50 : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: p.isCheckedThisYear ? Colors.green : Colors.orange),
                          ),
                          child: Text(
                            p.isCheckedThisYear ? 'ตรวจแล้ว' : 'ยังไม่ตรวจ',
                            style: TextStyle(
                              fontSize: 9, 
                              fontWeight: FontWeight.bold, 
                              color: p.isCheckedThisYear ? Colors.green.shade800 : Colors.orange.shade800
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(p.disabilityType),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PersonDetailScreen(person: p),
                        ),
                      );
                      _fetchData(); // Refresh data after returning
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
