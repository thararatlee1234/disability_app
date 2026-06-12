import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../models/person.dart';
import '../services/api_service.dart';
import '../utils/file_download.dart';
import 'person_detail_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> with SingleTickerProviderStateMixin {
  final api = ApiService();
  DateTimeRange? _dateRange;
  late TabController _tabController;
  
  bool _isLoading = false;
  List<Person> _checkedList = [];
  List<Person> _uncheckedList = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Default to current month
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
    _fetchReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReport() async {
    if (_dateRange == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formatter = DateFormat('yyyy-MM-dd');
      final start = formatter.format(_dateRange!.start);
      final end = formatter.format(_dateRange!.end);
      
      final result = await api.fetchCheckReport(start, end);
      
      setState(() {
        _checkedList = result['checked'] ?? [];
        _uncheckedList = result['unchecked'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = picked;
      });
      _fetchReport();
    }
  }

  Future<void> _exportExcel() async {
    if (_dateRange == null) return;
    try {
      final formatter = DateFormat('yyyy-MM-dd');
      final start = formatter.format(_dateRange!.start);
      final end = formatter.format(_dateRange!.end);
      
      final bytes = await api.downloadCheckReport(start, end);
      final fileName = 'check_report_${start}_to_${end}.xlsx';
      
      if (kIsWeb) {
        await downloadBytes(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await OpenFilex.open(file.path);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งออกรายงานสำเร็จ')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งออกรายงานไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายงานผลตรวจ'),
        actions: [
          IconButton(
            onPressed: _exportExcel,
            icon: const Icon(Icons.download_for_offline),
            tooltip: 'ส่งออก Excel',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'ตรวจแล้ว (${_checkedList.length})'),
            Tab(text: 'ยังไม่ได้ตรวจ (${_uncheckedList.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.teal.shade50,
            child: InkWell(
              onTap: _selectDateRange,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.teal),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ช่วงเวลาที่เลือก:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          _dateRange == null 
                            ? 'กรุณาเลือกช่วงเวลา' 
                            : '${dateFormat.format(_dateRange!.start)} - ${dateFormat.format(_dateRange!.end)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit, color: Colors.teal, size: 20),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('เกิดข้อผิดพลาด: $_error'),
                      ElevatedButton(onPressed: _fetchReport, child: const Text('ลองใหม่')),
                    ],
                  ))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPersonList(_checkedList),
                      _buildPersonList(_uncheckedList),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonList(List<Person> persons) {
    if (persons.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลในช่วงเวลาที่เลือก'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: persons.length,
      itemBuilder: (context, index) {
        final p = persons[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: p.photo != null
                ? CircleAvatar(backgroundImage: NetworkImage(p.photo!))
                : const CircleAvatar(child: Icon(Icons.person)),
            title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('เลขบัตร: ${p.citizenId}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PersonDetailScreen(person: p),
                ),
              );
              _fetchReport(); // Refresh when coming back
            },
          ),
        );
      },
    );
  }
}
