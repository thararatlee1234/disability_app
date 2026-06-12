import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _currentCenter;
  final MapController _mapController = MapController();
  int _mapType = 0; // 0: OSM, 1: Google Street, 2: Google Satellite
  bool _isPopping = false;

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition ?? const LatLng(13.7563, 100.5018); // Default to Bangkok
    
    if (widget.initialPosition == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      final newPos = LatLng(position.latitude, position.longitude);
      _mapController.move(newPos, 16);
      setState(() => _currentCenter = newPos);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ไม่สามารถดึงตำแหน่งได้: $e')));
    }
  }

  void _showPasteLinkDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('วางลิงก์จาก Google Maps'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'วางลิงก์ที่นี่...',
            helperText: 'ระบบจะดึงพิกัดจากลิงก์ให้อัตโนมัติ',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () {
              final coords = _extractCoords(ctrl.text.trim());
              Navigator.pop(ctx);
              if (coords != null) {
                _mapController.move(coords, 16);
                setState(() => _currentCenter = coords);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบพิกัดในลิงก์นี้')));
              }
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  LatLng? _extractCoords(String url) {
    try {
      final patterns = [
        RegExp(r'query=([-\d.]+),([-\d.]+)'),
        RegExp(r'@([-\d.]+),([-\d.]+)'),
        RegExp(r'[?&]q=([-\d.]+),([-\d.]+)'),
      ];
      for (final p in patterns) {
        final match = p.firstMatch(url);
        if (match != null) {
          return LatLng(double.parse(match.group(1)!), double.parse(match.group(2)!));
        }
      }
    } catch (_) {}
    return null;
  }

  void _confirmSelection() {
    if (_isPopping) return;
    setState(() => _isPopping = true);
    Navigator.pop(context, _currentCenter);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isPopping,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmSelection();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ปักหมุดตำแหน่ง'),
          actions: [
            IconButton(
              icon: const Icon(Icons.link, color: Colors.blue),
              onPressed: _showPasteLinkDialog,
              tooltip: 'วางลิงก์แผนที่',
            ),
            PopupMenuButton<int>(
              icon: const Icon(Icons.layers),
              onSelected: (val) => setState(() => _mapType = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 0, child: Text('แผนที่ปกติ (OSM)')),
                const PopupMenuItem(value: 1, child: Text('Google Maps (Street)')),
                const PopupMenuItem(value: 2, child: Text('Google Maps (Satellite)')),
              ],
            ),
            TextButton(
              onPressed: _confirmSelection,
              child: const Text('ตกลง', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentCenter!,
                initialZoom: 16,
                onPositionChanged: (pos, hasGesture) {
                  setState(() => _currentCenter = pos.center);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: _mapType == 2
                    ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}' // Google Satellite Hybrid
                    : _mapType == 1
                      ? 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}' // Google Street
                      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.disability_app.app',
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      _mapType > 0 ? 'Google Maps' : 'OpenStreetMap contributors',
                      onTap: () => launchUrl(Uri.parse(_mapType > 0 ? 'https://www.google.com/help/terms_maps/' : 'https://openstreetmap.org/copyright')),
                    ),
                  ],
                ),
              ],
            ),
            // Fixed Center Pin
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 35),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'เลื่อนแผนที่ให้หมุดอยู่ตำแหน่งที่ต้องการ แล้วกดกลับ',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.location_on, size: 50, color: Colors.red),
                  ],
                ),
              ),
            ),
            // Bottom current location info
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Card(
                  color: Colors.white.withValues(alpha: 0.9),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Text(
                      'พิกัด: ${_currentCenter!.latitude.toStringAsFixed(6)}, ${_currentCenter!.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _goToCurrentLocation,
          tooltip: 'ตำแหน่งปัจจุบัน',
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }
}
