import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_check.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import 'person_list_screen.dart';
import 'map_picker_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final Person person;

  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  static const int _maxCheckPhotos = 5;
  static const int _maxCheckPhotoBytes = 50 * 1024 * 1024;
  static const double _checkPhotoPreviewSize = 114;

  late Person person;
  final api = ApiService();
  List<MedicalCheck> medicalChecks = [];
  bool isLoadingChecks = false;

  @override
  void initState() {
    super.initState();
    person = widget.person;
    _loadMedicalChecks();
  }

  Future<void> _loadMedicalChecks() async {
    setState(() => isLoadingChecks = true);
    try {
      final checks = await api.fetchMedicalChecks(person.id);
      final updatedPerson = await api.fetchPerson(person.id);
      if (mounted) {
        setState(() {
          medicalChecks = checks;
          person = updatedPerson;
          isLoadingChecks = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingChecks = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('โหลดผลตรวจไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _updateField(String key, String value) async {
    try {
      Map<String, dynamic> data = {key: value};
      
      // Auto-extract coordinates if updating map_url
      if (key == 'map_url' && value.isNotEmpty) {
        final coords = _extractCoords(value);
        if (coords != null) {
          data['latitude'] = double.parse(coords.latitude.toStringAsFixed(10));
          data['longitude'] = double.parse(coords.longitude.toStringAsFixed(10));
        }
      }

      // Round if editing lat/lng directly
      if ((key == 'latitude' || key == 'longitude') && value.isNotEmpty) {
        try {
          data[key] = double.parse(double.parse(value).toStringAsFixed(10));
        } catch (_) {}
      }

      final updated = await api.updatePerson(person.id, data);
      if (mounted) {
        setState(() => person = updated);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตข้อมูลแล้ว')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  LatLng? _extractCoords(String url) {
    try {
      // Pattern 1: query=lat,lng
      final queryMatch = RegExp(r'query=([-\d.]+),([-\d.]+)').firstMatch(url);
      if (queryMatch != null) {
        return LatLng(double.parse(queryMatch.group(1)!), double.parse(queryMatch.group(2)!));
      }
      
      // Pattern 2: @lat,lng,zoom
      final atMatch = RegExp(r'@([-\d.]+),([-\d.]+)').firstMatch(url);
      if (atMatch != null) {
        return LatLng(double.parse(atMatch.group(1)!), double.parse(atMatch.group(2)!));
      }

      // Pattern 3: lat,lng directly (e.g. from maps.google.com/?q=lat,lng)
      final qMatch = RegExp(r'[?&]q=([-\d.]+),([-\d.]+)').firstMatch(url);
      if (qMatch != null) {
        return LatLng(double.parse(qMatch.group(1)!), double.parse(qMatch.group(2)!));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _updateFields(Map<String, dynamic> data) async {
    try {
      final updated = await api.updatePerson(person.id, data);
      if (mounted) {
        setState(() => person = updated);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตข้อมูลแล้ว')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _openMapPicker() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('เลือกวิธีปักหมุด'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'picker'),
            child: const Row(
              children: [
                Icon(Icons.map, color: Colors.teal),
                SizedBox(width: 12),
                Text('เลือกในแอป (แผนที่ OSM)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'google'),
            child: const Row(
              children: [
                Icon(Icons.open_in_new, color: Colors.blue),
                SizedBox(width: 12),
                Text('ปักหมุดใน Google Maps (ภายนอก)'),
              ],
            ),
          ),
        ],
      ),
    );

    if (action == 'picker') {
      LatLng? initial;
      if (person.latitude != null && person.latitude!.isNotEmpty) {
        try {
          initial = LatLng(double.parse(person.latitude!), double.parse(person.longitude!));
        } catch (_) {}
      }

      final LatLng? picked = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MapPickerScreen(initialPosition: initial)),
      );

      if (picked != null) {
        final lat = double.parse(picked.latitude.toStringAsFixed(10));
        final lng = double.parse(picked.longitude.toStringAsFixed(10));
        await _updateFields({
          'latitude': lat,
          'longitude': lng,
          'map_url': 'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        });
      }
    } else if (action == 'google') {
      // Open Google Maps search page or current location
      String url = 'https://www.google.com/maps';
      if (person.latitude != null && person.latitude!.isNotEmpty) {
        url = 'https://www.google.com/maps/search/?api=1&query=${person.latitude},${person.longitude}';
      }
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เมื่อปักหมุดใน Google Maps เสร็จแล้ว ให้คัดลอกลิงก์มาวางในช่อง "ลิงก์ Google Maps"'),
              duration: Duration(seconds: 10),
            ),
          );
        }
      }
    }
  }

  Future<void> _clearLocation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้างพิกัด'),
        content: const Text('คุณต้องการล้างข้อมูลพิกัดและลิงก์แผนที่ทั้งหมดหรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ล้างข้อมูล', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _updateFields({
        'latitude': null,
        'longitude': null,
        'map_url': '',
      });
    }
  }

  Future<void> _updatePhoto() async {
    final img = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เปลี่ยนรูปถ่าย'),
        actions: [
          TextButton(
            onPressed: () async {
              final i = await ImagePicker().pickImage(
                source: ImageSource.camera,
                maxWidth: 400, // Approx 2x2 cm proportional to typical 1024-1080 screen width
                maxHeight: 400,
                imageQuality: 50,
              );
              if (ctx.mounted) Navigator.pop(ctx, i);
            },
            child: const Text('กล้อง'),
          ),
          TextButton(
            onPressed: () async {
              final i = await ImagePicker().pickImage(
                source: ImageSource.gallery,
                maxWidth: 400,
                maxHeight: 400,
                imageQuality: 50,
              );
              if (ctx.mounted) Navigator.pop(ctx, i);
            },
            child: const Text('แกลเลอรี่'),
          ),
        ],
      ),
    );

    if (img != null) {
      try {
        final bytes = await img.readAsBytes();
        final updated = await api.updatePerson(person.id, {}, imageBytes: bytes, fileName: img.name);
        if (mounted) setState(() => person = updated);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปโหลดรูปไม่สำเร็จ: $e')));
      }
    }
  }

  void _showEditFieldDialog(String label, String key, String initialValue, {bool isLong = false}) {
    final ctrl = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('แก้ไข $label'),
        content: TextField(
          controller: ctrl,
          maxLines: isLong ? 5 : 1,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
          FilledButton(
            onPressed: () async {
              final newValue = ctrl.text.trim();
              if (key == 'citizen_id' && newValue.isNotEmpty && newValue != initialValue) {
                try {
                  final existing = await api.findByCitizenId(newValue);
                  if (existing != null && existing.id != person.id) {
                    if (ctx.mounted) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx2) => AlertDialog(
                          title: const Text('พบข้อมูลซ้ำ'),
                          content: Text(
                              'พบเลขบัตรประชาชนนี้ในระบบแล้ว (${existing.fullName})\nคุณต้องการบันทึกต่อไปหรือไม่?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx2, false),
                                child: const Text('ยกเลิก')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx2, true),
                                child: const Text('ยืนยันบันทึก')),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                    }
                  }
                } catch (e) {
                  debugPrint('Error checking duplicate: $e');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _updateField(key, newValue);
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _displayDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  Future<bool> _canAddCheckPhotos(List<XFile> current, List<XFile> incoming) async {
    if (current.length + incoming.length > _maxCheckPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('แนบรูปผลตรวจได้ไม่เกิน 5 รูป')));
      return false;
    }

    for (final image in incoming) {
      final size = await image.length();
      if (!mounted) return false;
      if (size > _maxCheckPhotoBytes) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รูปแต่ละรูปต้องมีขนาดไม่เกิน 50 MB')));
        return false;
      }
    }

    return true;
  }

  Future<void> _deleteMedicalCheck(MedicalCheck check) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบผลตรวจ'),
        content: const Text('คุณต้องการลบผลตรวจนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await api.deleteMedicalCheck(check.id);
        await _loadMedicalChecks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบผลตรวจแล้ว')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบผลตรวจไม่สำเร็จ: $e')));
        }
      }
    }
  }

  Future<void> _showMedicalCheckDialog({MedicalCheck? existingCheck}) async {
    DateTime selectedDate = existingCheck != null ? DateTime.parse(existingCheck.checkDate) : DateTime.now();
    final detailCtrl = TextEditingController(text: existingCheck?.detail ?? '');
    final selectedImages = <XFile>[];
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> addImages(List<XFile> images) async {
            if (images.isEmpty) return;
            // Count existing photos if editing
            int existingPhotoCount = existingCheck?.photos.length ?? 0;
            if (await _canAddCheckPhotos([], [...selectedImages, ...images]) && (existingPhotoCount + selectedImages.length + images.length <= _maxCheckPhotos)) {
               setDialogState(() => selectedImages.addAll(images));
            } else if (existingPhotoCount + selectedImages.length + images.length > _maxCheckPhotos) {
               if (!mounted) return;
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('แนบรูปผลตรวจได้ไม่เกิน 5 รูป')));
            }
          }

          Future<void> saveCheck() async {
            setDialogState(() => isSaving = true);
            try {
              final bytes = <Uint8List>[];
              final names = <String>[];
              for (final image in selectedImages) {
                bytes.add(await image.readAsBytes());
                names.add(image.name);
              }

              if (existingCheck == null) {
                await api.createMedicalCheck(
                  {
                    'person': person.id,
                    'check_date': _formatDate(selectedDate),
                    'detail': detailCtrl.text.trim(),
                  },
                  photoBytes: bytes,
                  fileNames: names,
                );
              } else {
                await api.updateMedicalCheck(
                  existingCheck.id,
                  {
                    'check_date': _formatDate(selectedDate),
                    'detail': detailCtrl.text.trim(),
                  },
                  photoBytes: bytes,
                  fileNames: names,
                );
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await _loadMedicalChecks();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(existingCheck == null ? 'เพิ่มผลตรวจแล้ว' : 'แก้ไขผลตรวจแล้ว')));
              }
            } catch (e) {
              setDialogState(() => isSaving = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('บันทึกไม่สำเร็จ: $e')));
              }
            }
          }

          return AlertDialog(
            title: Text(existingCheck == null ? 'เพิ่มผลตรวจ' : 'แก้ไขผลตรวจ'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('วันที่'),
                      subtitle: Text(_displayDate(_formatDate(selectedDate))),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'รายละเอียด',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (existingCheck != null && existingCheck.photos.isNotEmpty) ...[
                      const Text('รูปภาพเดิม:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: existingCheck.photos
                            .where((p) => p.image != null)
                            .map((p) => ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    p.image!,
                                    width: _checkPhotoPreviewSize,
                                    height: _checkPhotoPreviewSize,
                                    fit: BoxFit.cover,
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: (existingCheck?.photos.length ?? 0) + selectedImages.length >= _maxCheckPhotos
                              ? null
                              : () async {
                                  final image = await ImagePicker().pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 1024,
                                    maxHeight: 1024,
                                    imageQuality: 70,
                                  );
                                  if (image != null) await addImages([image]);
                                },
                          icon: const Icon(Icons.photo_camera),
                          label: const Text('กล้อง'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: (existingCheck?.photos.length ?? 0) + selectedImages.length >= _maxCheckPhotos
                              ? null
                              : () async {
                                  final images = await ImagePicker().pickMultiImage(
                                    maxWidth: 1024,
                                    maxHeight: 1024,
                                    imageQuality: 70,
                                  );
                                  await addImages(images);
                                },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('รูปถ่าย'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(existingCheck?.photos.length ?? 0) + selectedImages.length}/$_maxCheckPhotos รูป • รูปละไม่เกิน 50 MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    if (selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('รูปใหม่ที่เลือก:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < selectedImages.length; i++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: FutureBuilder<Uint8List>(
                                    future: selectedImages[i].readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox(
                                          width: _checkPhotoPreviewSize,
                                          height: _checkPhotoPreviewSize,
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      }
                                      return Image.memory(
                                        snapshot.data!,
                                        width: _checkPhotoPreviewSize,
                                        height: _checkPhotoPreviewSize,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton.filledTonal(
                                    onPressed: () => setDialogState(() => selectedImages.removeAt(i)),
                                    icon: const Icon(Icons.close, size: 12),
                                    constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: isSaving ? null : saveCheck,
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );

    detailCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasMap = person.mapUrl.isNotEmpty || (person.latitude != null && person.latitude!.isNotEmpty);
    
    final shownValues = {
      person.prefix, person.firstName, person.lastName, person.citizenId, 
      person.phone, person.disabilityType, person.address, 
      person.subdistrict, person.district, person.province,
      person.mapUrl, person.notes, person.latitude, person.longitude,
    }.where((v) => v != null && v.isNotEmpty).map((v) => v!.toLowerCase().trim()).toSet();

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายละเอียด'),
        actions: [
          if (hasMap)
            IconButton(
              icon: const Icon(Icons.directions),
              tooltip: 'นำทาง',
              onPressed: () => PersonListScreen.openMap(context, person),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onDoubleTap: _updatePhoto,
                child: Column(
                  children: [
                    if (person.photo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          person.photo!,
                          height: 75, // Approx 2 cm
                          width: 75,  // Approx 2 cm
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => const CircleAvatar(radius: 37.5, child: Icon(Icons.person, size: 40)),
                        ),
                      )
                    else
                      const CircleAvatar(
                        radius: 37.5,
                        child: Icon(Icons.person, size: 40),
                      ),
                    const SizedBox(height: 8),
                    const Text('ดับเบิ้ลคลิกเพื่อเปลี่ยนรูป', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    const SizedBox(height: 16),
                    Text(
                      person.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'เลขบัตรประชาชน: ${person.citizenId}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: person.isCheckedThisYear ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: person.isCheckedThisYear ? Colors.green : Colors.orange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            person.isCheckedThisYear ? Icons.check_circle : Icons.warning_amber_rounded,
                            size: 16,
                            color: person.isCheckedThisYear ? Colors.green.shade900 : Colors.orange.shade900,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            person.isCheckedThisYear 
                              ? 'ตรวจแล้วปีนี้ (${person.latestCheckDateThisYear ?? ''})' 
                              : 'ยังไม่ได้ตรวจในปีนี้',
                            style: TextStyle(
                              fontSize: 12,
                              color: person.isCheckedThisYear ? Colors.green.shade900 : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 32),
            const Center(child: Text('💡 ดับเบิ้ลคลิกที่ข้อมูลเพื่อแก้ไข', style: TextStyle(color: Colors.teal, fontSize: 11))),
            const SizedBox(height: 16),
            
            _buildSection(context, 'ข้อมูลส่วนตัว', [
              _buildEditableItem('คำนำหน้า', 'prefix', person.prefix),
              _buildEditableItem('ชื่อ', 'first_name', person.firstName),
              _buildEditableItem('นามสกุล', 'last_name', person.lastName),
              _buildEditableItem('เลขบัตรประชาชน', 'citizen_id', person.citizenId),
              _buildEditableItem('เบอร์โทรศัพท์', 'phone', person.phone),
            ]),
            
            _buildSection(context, 'ข้อมูลความพิการ', [
              _buildEditableItem('อาการ/ประเภท', 'disability_type', person.disabilityType),
              _buildEditableItem('ที่อยู่', 'address', person.address, isLong: true),
              _buildEditableItem('ตำบล', 'subdistrict', person.subdistrict),
              _buildEditableItem('อำเภอ', 'district', person.district),
              _buildEditableItem('จังหวัด', 'province', person.province),
            ]),

            _buildSection(context, 'ตำแหน่ง GPS', [
              Card(
                color: Colors.teal.shade50,
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map_outlined, color: Colors.teal),
                      title: const Text('ปักหมุดตำแหน่ง', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(person.latitude != null && person.latitude!.isNotEmpty ? '${person.latitude}, ${person.longitude}' : 'ยังไม่มีพิกัด'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasMap)
                            IconButton(
                              icon: const Icon(Icons.location_off, color: Colors.red),
                              onPressed: _clearLocation,
                              tooltip: 'ล้างพิกัด',
                            ),
                          ElevatedButton.icon(
                            onPressed: _openMapPicker,
                            icon: const Icon(Icons.pin_drop),
                            label: const Text('ปักหมุด', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildEditableItem('ละติจูด', 'latitude', person.latitude ?? ''),
                    _buildEditableItem('ลองจิจูด', 'longitude', person.longitude ?? ''),
                    _buildEditableItem('ลิงก์ Google Maps', 'map_url', person.mapUrl),
                    if (hasMap)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: FilledButton.icon(
                          onPressed: () => PersonListScreen.openMap(context, person),
                          icon: const Icon(Icons.directions),
                          label: const Text('นำทางด้วย Google Maps'),
                          style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
                        ),
                      ),
                  ],
                ),
              ),
            ]),

            _buildMedicalChecksSection(context),

            _buildSection(context, 'อื่น ๆ', [
              _buildEditableItem('หมายเหตุ', 'notes', person.notes, isLong: true),
            ]),

            if (person.rawData.isNotEmpty)
              _buildSection(context, 'ข้อมูลดั้งเดิม (Excel)', 
                person.rawData.entries.where((e) {
                  final k = e.key.toLowerCase().trim();
                  final v = e.value.toString().toLowerCase().trim();
                  if (k.isEmpty || v.isEmpty) return false;
                  return !shownValues.contains(v);
                }).map((e) => 
                  _buildDetailItem(e.key, e.value.toString())
                ).toList()
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    final filtered = children.where((w) => w is! SizedBox).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
        ),
        ...filtered,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMedicalChecksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ผลตรวจ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.teal, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton.filled(
                onPressed: () => _showMedicalCheckDialog(),
                icon: const Icon(Icons.add),
                tooltip: 'เพิ่มผลตรวจ',
              ),
            ],
          ),
        ),
        if (isLoadingChecks)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          )
        else if (medicalChecks.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('ยังไม่มีผลตรวจ'),
              trailing: IconButton(
                onPressed: () => _showMedicalCheckDialog(),
                icon: const Icon(Icons.add),
                tooltip: 'เพิ่มผลตรวจ',
              ),
            ),
          )
        else
          ...medicalChecks.map((check) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_note, color: Colors.teal),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _displayDate(check.checkDate),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                            onPressed: () => _showMedicalCheckDialog(existingCheck: check),
                            tooltip: 'แก้ไข',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            onPressed: () => _deleteMedicalCheck(check),
                            tooltip: 'ลบ',
                          ),
                        ],
                      ),
                      if (check.detail.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(check.detail),
                      ],
                      if (check.photos.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: check.photos
                              .where((photo) => photo.image != null && photo.image!.isNotEmpty)
                              .map((photo) => ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      photo.image!,
                                      width: _checkPhotoPreviewSize,
                                      height: _checkPhotoPreviewSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: _checkPhotoPreviewSize,
                                        height: _checkPhotoPreviewSize,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image, size: 20),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEditableItem(String label, String key, String value, {bool isLong = false}) {
    return GestureDetector(
      onTap: key == 'map_url' && value.isNotEmpty 
          ? () => PersonListScreen.openMap(context, person)
          : null,
      onDoubleTap: () => _showEditFieldDialog(label, key, value, isLong: isLong),
      child: _buildDetailItem(label, value.isEmpty ? '(ว่าง - ดับเบิ้ลคลิกเพื่อเพิ่ม)' : value, isLongText: isLong),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isLongText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
              maxLines: isLongText ? 10 : 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
