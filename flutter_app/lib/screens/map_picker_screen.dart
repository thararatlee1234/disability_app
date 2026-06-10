import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPickerScreen({super.key, this.initialPosition});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? _currentCenter;
  final MapController _mapController = MapController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentCenter = widget.initialPosition ?? const LatLng(13.7563, 100.5018); // Default to Bangkok
    
    if (widget.initialPosition == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToCurrentLocation());
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

  void _confirmSelection() {
    Navigator.pop(context, _currentCenter);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmSelection();
      },
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
            _confirmSelection();
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: const Text('ลากแผนที่เพื่อปักหมุด'),
          actions: [
            TextButton(
              onPressed: _confirmSelection,
              child: const Text('ยืนยัน', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.disability_app',
                ),
              ],
            ),
            // Fixed Center Pin
            Center(
              child: GestureDetector(
                onDoubleTap: _confirmSelection,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 35),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ดับเบิ้ลคลิก หรือ กด Enter เพื่อปักหมุด',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                      const Icon(Icons.location_on, size: 50, color: Colors.red),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom current location info
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Card(
                  color: Colors.white.withValues(alpha: 0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'พิกัด: ${_currentCenter!.latitude.toStringAsFixed(6)}, ${_currentCenter!.longitude.toStringAsFixed(6)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
      ),
    );
  }
}
