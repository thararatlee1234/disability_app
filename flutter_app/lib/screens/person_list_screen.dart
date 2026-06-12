import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../models/person.dart';
import '../services/api_service.dart';
import '../utils/file_download.dart';
import 'login_screen.dart';
import 'person_detail_screen.dart';
import 'all_persons_map_screen.dart';
import 'report_screen.dart';

class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key});

  static Future<void> openMap(BuildContext context, Person p) async {
    final mapLink = p.mapUrl.trim();
    if (mapLink.isEmpty) {
      if (p.latitude == null ||
          p.longitude == null ||
          p.latitude!.isEmpty ||
          p.longitude!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบลิงก์หรือพิกัด GPS')));
        return;
      }
    }

    Uri url;
    if (mapLink.isNotEmpty) {
      url = Uri.parse(mapLink);
    } else {
      // Use a more universal format for Google Maps directions
      url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}');
    }

    try {
      // On Web, canLaunchUrl can be unreliable. For HTTPS links, it's safer to just attempt launching.
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && context.mounted) {
        // Fallback for some browsers
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้: $e')));
      }
    }
  }

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  final api = ApiService();
  final searchController = TextEditingController();
  
  // Advanced filters controllers
  final provinceController = TextEditingController();
  final districtController = TextEditingController();
  final subdistrictController = TextEditingController();
  final houseNoController = TextEditingController();
  final villageNoController = TextEditingController();
  
  // Advanced filters state
  String? selectedProvince;
  String? selectedDistrict;
  String? selectedSubdistrict;
  
  List<String> provinces = [];
  List<String> districts = [];
  List<String> subdistricts = [];

  late Future<List<Person>> future;
  final Set<int> _deletingIds = {};
  Timer? _debounce;
  bool _isImporting = false;
  String _checkFilter = 'all'; // 'all', 'checked', 'unchecked'
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    search();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final all = await api.fetchPersons(all: true);
      setState(() {
        provinces = all.map((p) => p.province).where((s) => s.isNotEmpty).toSet().toList()..sort();
        _updateDistricts(all);
        _updateSubdistricts(all);
      });
    } catch (e) {
      debugPrint('Error loading filters: $e');
    }
  }

  void _updateDistricts(List<Person> all) {
    districts = all
        .where((p) => selectedProvince == null || p.province == selectedProvince)
        .map((p) => p.district)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  void _updateSubdistricts(List<Person> all) {
    subdistricts = all
        .where((p) => (selectedProvince == null || p.province == selectedProvince) && 
                      (selectedDistrict == null || p.district == selectedDistrict))
        .map((p) => p.subdistrict)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    provinceController.dispose();
    districtController.dispose();
    subdistrictController.dispose();
    houseNoController.dispose();
    villageNoController.dispose();
    super.dispose();
  }

  Future<void> _importExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
      );

      if (result == null) {
        return;
      }

      final file = result.files.single;
      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }

      if (bytes == null) {
        throw Exception('ไม่สามารถอ่านไฟล์ Excel ที่เลือกได้');
      }

      if (mounted) {
        setState(() => _isImporting = true);
      }

      final res = await api.importExcel(bytes, file.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'นำเข้าสำเร็จ: สร้างใหม่ ${res['created']}, อัปเดต ${res['updated']}, ข้าม ${res['skipped']}')),
        );
        _loadFilterOptions();
        search();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        search();
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  Future<void> _downloadTemplate() async {
    try {
      final bytes = await api.downloadTemplate();
      if (kIsWeb) {
        await downloadBytes(
          bytes: bytes,
          fileName: 'template_disability.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/template_disability.xlsx');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ดาวน์โหลดไม่สำเร็จ: $e')));
      }
    }
  }

  Future<void> _downloadReport() async {
    try {
      final bytes = await api.downloadReport();
      final now = DateTime.now();
      final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'disability_report_$dateStr.xlsx';
      
      if (kIsWeb) {
        await downloadBytes(
          bytes: bytes,
          fileName: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ดาวน์โหลดรายงานสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('ดาวน์โหลดรายงานไม่สำเร็จ: $e')));
      }
    }
  }

  void search() {
    setState(() {
      future = api.fetchPersons(
        search: searchController.text.trim(),
        province: selectedProvince ?? '',
        district: selectedDistrict ?? '',
        subdistrict: selectedSubdistrict ?? '',
        houseNo: houseNoController.text.trim(),
        villageNo: villageNoController.text.trim(),
      ).then((list) {
        if (_checkFilter == 'checked') {
          return list.where((p) => p.isCheckedThisYear).toList();
        } else if (_checkFilter == 'unchecked') {
          return list.where((p) => !p.isCheckedThisYear).toList();
        }
        return list;
      });
    });
  }

  void _clearFilters() {
    setState(() {
      searchController.clear();
      selectedProvince = null;
      selectedDistrict = null;
      selectedSubdistrict = null;
      houseNoController.clear();
      villageNoController.clear();
      _checkFilter = 'all';
    });
    search();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      search();
    });
    setState(() {}); // Update suffixIcon visibility
  }

  Future<void> _deletePerson(Person p) async {
    if (_deletingIds.contains(p.id)) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบ ${p.fullName} หรือไม่?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ยกเลิก')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _deletingIds.add(p.id));
      try {
        await api.deletePerson(p.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ลบข้อมูลเรียบร้อยแล้ว')));
          search();
          _loadFilterOptions();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
        }
      } finally {
        if (mounted) {
          setState(() => _deletingIds.remove(p.id));
        }
      }
    }
  }

  void _showAddDialog() {
    _showPersonDialog();
  }

  void _logout() {
    api.logout();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showPersonDialog({Person? person}) {
    final isEdit = person != null;
    final prefixCtrl = TextEditingController(text: person?.prefix);
    final firstCtrl = TextEditingController(text: person?.firstName);
    final lastCtrl = TextEditingController(text: person?.lastName);
    final cidCtrl = TextEditingController(text: person?.citizenId);
    final phoneCtrl = TextEditingController(text: person?.phone);
    final typeCtrl = TextEditingController(text: person?.disabilityType);
    final mapUrlCtrl = TextEditingController(text: person?.mapUrl);
    final latCtrl = TextEditingController(text: person?.latitude);
    final lngCtrl = TextEditingController(text: person?.longitude);
    final notesCtrl = TextEditingController(text: person?.notes);

    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'แก้ไขข้อมูล' : 'เพิ่มข้อมูลใหม่'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ... (image picker code remains same)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final img = await ImagePicker().pickImage(
                          source: ImageSource.camera,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 50,
                        );
                        if (img != null) {
                          setDialogState(() => selectedImage = img);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('กล้อง'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final img = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          maxHeight: 800,
                          imageQuality: 50,
                        );
                        if (img != null) {
                          setDialogState(() => selectedImage = img);
                        }
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('แกลเลอรี่'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: prefixCtrl,
                    decoration: const InputDecoration(
                        labelText: 'คำนำหน้า (เช่น นาย)')),
                TextField(
                    controller: firstCtrl,
                    decoration: const InputDecoration(labelText: 'ชื่อ')),
                TextField(
                    controller: lastCtrl,
                    decoration: const InputDecoration(labelText: 'นามสกุล')),
                TextField(
                    controller: cidCtrl,
                    decoration:
                        const InputDecoration(labelText: 'เลขบัตรประชาชน')),
                TextField(
                    controller: phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'เบอร์โทรศัพท์')),
                TextField(
                    controller: typeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'อาการ/ประเภทความพิการ')),
                TextField(
                    controller: mapUrlCtrl,
                    decoration: const InputDecoration(
                        labelText: 'ลิงก์ Google Maps',
                        hintText: 'https://maps.app.goo.gl/...')),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latCtrl,
                        decoration: const InputDecoration(labelText: 'ละติจูด (Lat)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: lngCtrl,
                        decoration: const InputDecoration(labelText: 'ลองจิจูด (Lng)'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'หมายเหตุ'),
                    maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('ยกเลิก')),
            FilledButton(
              onPressed: () async {
                if (firstCtrl.text.isEmpty || lastCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('กรุณากรอกชื่อและนามสกุล')));
                  return;
                }

                // ตรวจสอบเลขบัตรประชาชนซ้ำ
                final cid = cidCtrl.text.trim();
                if (cid.isNotEmpty) {
                  try {
                    final existing = await api.findByCitizenId(cid);
                    if (existing != null && (!isEdit || existing.id != person.id)) {
                      if (context.mounted) {
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

                try {
                  dynamic finalLat = latCtrl.text.trim();
                  dynamic finalLng = lngCtrl.text.trim();
                  
                  if (finalLat.isNotEmpty) {
                    try { finalLat = double.parse(double.parse(finalLat).toStringAsFixed(10)); } catch (_) {}
                  } else {
                    finalLat = null;
                  }
                  
                  if (finalLng.isNotEmpty) {
                    try { finalLng = double.parse(double.parse(finalLng).toStringAsFixed(10)); } catch (_) {}
                  } else {
                    finalLng = null;
                  }

                  final payload = {
                    'prefix': prefixCtrl.text,
                    'first_name': firstCtrl.text,
                    'last_name': lastCtrl.text,
                    'citizen_id': cidCtrl.text,
                    'phone': phoneCtrl.text,
                    'disability_type': typeCtrl.text,
                    'map_url': mapUrlCtrl.text,
                    'latitude': finalLat,
                    'longitude': finalLng,
                    'notes': notesCtrl.text,
                  };

                  Uint8List? imageBytes;
                  String? imageName;
                  if (selectedImage != null) {
                    imageBytes = await selectedImage!.readAsBytes();
                    imageName = selectedImage!.name;
                  }

                  if (isEdit) {
                    await api.updatePerson(person.id, payload,
                        imageBytes: imageBytes, fileName: imageName);
                  } else {
                    await api.createPerson(payload,
                        imageBytes: imageBytes, fileName: imageName);
                  }
                  if (mounted) {
                    if (!ctx.mounted) {
                      return;
                    }
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                        content: Text(isEdit
                            ? 'แก้ไขข้อมูลเรียบร้อยแล้ว'
                            : 'เพิ่มข้อมูลเรียบร้อยแล้ว')));
                    _loadFilterOptions();
                    search();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
                  }
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายชื่อผู้ทุพพลภาพ'),
        actions: [
          if (ApiService.currentUsername != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text(ApiService.currentUsername!)),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportScreen()),
                );
              }
              if (value == 'import') {
                _importExcel();
              }
              if (value == 'template') {
                _downloadTemplate();
              }
              if (value == 'export') {
                _downloadReport();
              }
            },
            tooltip: 'เมนูเพิ่มเติม',
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'report',
                child: Row(children: [
                  Icon(Icons.assignment, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('รายงานการตรวจ')
                ]),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(children: [
                  Icon(Icons.upload_file, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('นำเข้า Excel')
                ]),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(children: [
                  Icon(Icons.download_for_offline, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('ดึงรายงาน Excel')
                ]),
              ),
              const PopupMenuItem(
                value: 'template',
                child: Row(children: [
                  Icon(Icons.download, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('ตัวอย่างไฟล์')
                ]),
              ),
            ],
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        tooltip: 'เพิ่มข้อมูล',
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'ค้นหาชื่อ/นามสกุล/เลขบัตร/เบอร์โทร',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            search();
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: (_) => search(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: search,
              icon: const Icon(Icons.search),
              label: const Text('ค้นหา'),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AllPersonsMapScreen(),
                  ),
                );
                search(); // Refresh main list when returning from map
              },
              icon: const Icon(Icons.map),
              tooltip: 'ดูแผนที่รวม',
              style: IconButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('ทั้งหมด'),
                        selected: _checkFilter == 'all',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _checkFilter = 'all');
                            search();
                          }
                        },
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('ตรวจแล้ว'),
                        selected: _checkFilter == 'checked',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _checkFilter = 'checked');
                            search();
                          }
                        },
                        selectedColor: Colors.green.shade100,
                        checkmarkColor: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('ยังไม่ตรวจ'),
                        selected: _checkFilter == 'unchecked',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _checkFilter = 'unchecked');
                            search();
                          }
                        },
                        selectedColor: Colors.orange.shade100,
                        checkmarkColor: Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      ActionChip(
                        avatar: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.filter_list, size: 16),
                        label: const Text('ตัวกรองที่อยู่ละเอียด'),
                        onPressed: () {
                          setState(() => _showAdvancedFilters = !_showAdvancedFilters);
                        },
                        backgroundColor: Colors.blue.shade50,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showAdvancedFilters)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedProvince,
                        decoration: const InputDecoration(labelText: 'จังหวัด', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                          ...provinces.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) async {
                          setState(() {
                            selectedProvince = v;
                            selectedDistrict = null;
                            selectedSubdistrict = null;
                          });
                          final all = await api.fetchPersons(all: true);
                          setState(() {
                            _updateDistricts(all);
                            _updateSubdistricts(all);
                          });
                          search();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDistrict,
                        decoration: const InputDecoration(labelText: 'อำเภอ', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                          ...districts.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) async {
                          setState(() {
                            selectedDistrict = v;
                            selectedSubdistrict = null;
                          });
                          final all = await api.fetchPersons(all: true);
                          setState(() => _updateSubdistricts(all));
                          search();
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedSubdistrict,
                        decoration: const InputDecoration(labelText: 'ตำบล', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                          ...subdistricts.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) {
                          setState(() => selectedSubdistrict = v);
                          search();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: houseNoController,
                        decoration: const InputDecoration(
                          labelText: 'บ้านเลขที่', 
                          isDense: true,
                        ),
                        onChanged: (v) => _onSearchChanged(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: villageNoController,
                        decoration: const InputDecoration(
                          labelText: 'หมู่ที่', 
                          isDense: true,
                          hintText: 'เช่น 1',
                        ),
                        onChanged: (v) => _onSearchChanged(v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _clearFilters, 
                      child: const Text('ล้างตัวกรอง'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        Expanded(
          child: FutureBuilder<List<Person>>(

            future: future,
            builder: (context, snapshot) {
              if (_isImporting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('กำลังนำเข้าข้อมูล...'),
                    ],
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return const Center(child: Text('ไม่พบข้อมูล'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final p = items[index];
                  final isDeleting = _deletingIds.contains(p.id);
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: p.photo != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(p.photo!))
                          : const CircleAvatar(child: Icon(Icons.person)),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(p.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.isCheckedThisYear ? Colors.green.shade100 : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: p.isCheckedThisYear ? Colors.green : Colors.orange),
                            ),
                            child: Text(
                              p.isCheckedThisYear 
                                ? 'ตรวจแล้ว (${p.latestCheckDateThisYear ?? ''})' 
                                : 'ยังไม่ได้ตรวจปีนี้',
                              style: TextStyle(
                                fontSize: 10,
                                color: p.isCheckedThisYear ? Colors.green.shade900 : Colors.orange.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('เลขบัตร: ${p.citizenId}'),
                          if (p.disabilityType.isNotEmpty)
                            Text('อาการ: ${p.disabilityType}'),
                          if (p.mapUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 14, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      p.mapUrl,
                                      style: const TextStyle(fontSize: 11, color: Colors.teal),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (p.mapUrl.isNotEmpty || (p.latitude != null && p.longitude != null && p.latitude!.isNotEmpty && p.longitude!.isNotEmpty))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (p.mapUrl.isNotEmpty || (p.latitude != null && p.longitude != null))
                                    InkWell(
                                      onTap: () => PersonListScreen.openMap(context, p),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.directions, size: 14, color: Colors.green),
                                            const SizedBox(width: 4),
                                            Text(
                                              'เปิดแผนที่',
                                              style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (p.latitude != null && p.longitude != null && p.latitude!.isNotEmpty && p.longitude!.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.location_on, size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(
                                            'GPS: ${p.latitude}, ${p.longitude}',
                                            style: TextStyle(fontSize: 11, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          isDeleting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _deletePerson(p),
                                  tooltip: 'ลบข้อมูล',
                                ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: isDeleting
                          ? null
                          : () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PersonDetailScreen(person: p),
                                ),
                              );
                              search(); // Refresh after return
                            },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
