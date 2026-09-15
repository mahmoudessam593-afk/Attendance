import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../services/api_service.dart';
import '../../screens/home/home_screen.dart' show friendlyErrorMessage;

class DayAttendance {
  final DateTime date;
  final String status;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final int? workedMinutes;

  DayAttendance({
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.workedMinutes,
  });

  factory DayAttendance.fromMap(Map<String, dynamic> map) {
    return DayAttendance(
      date: DateTime.parse(map['date']),
      status: map['status'],
      checkInTime: map['checkin_time'] != null
          ? DateTime.parse(map['checkin_time']).toLocal()
          : null,
      checkOutTime: map['checkout_time'] != null
          ? DateTime.parse(map['checkout_time']).toLocal()
          : null,
      workedMinutes: map['worked_minutes'],
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService();

  final DateTime _now = DateTime.now();
  late final DateTime _firstDay = DateTime(_now.year - 2, 1, 1);
  late final DateTime _lastDay = DateTime(_now.year, _now.month + 1, 0);

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  Map<String, DayAttendance> _days = {};
  Map<String, dynamic>? _summary;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMonth(_focusedMonth);
  }

  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _loadMonth(DateTime month) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _apiService.client.get('/attendance/monthly-report', queryParameters: {
        'month': month.month,
        'year': month.year,
      });
      if (response.data['success'] == true) {
        final data = response.data['data'];
        final days = (data['days'] as List).map((d) => DayAttendance.fromMap(d)).toList();
        setState(() {
          _days = {for (final d in days) _key(d.date): d};
          _summary = data['summary'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = response.data['error'] ?? 'Failed to load history';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay != null ? _days[_key(_selectedDay!)] : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryStat(label: 'Present', value: '${_summary!['present_days']}'),
                  _SummaryStat(label: 'Absent', value: '${_summary!['absent_days']}'),
                  _SummaryStat(label: 'Hours', value: '${_summary!['total_hours']}'),
                ],
              ),
            ),
          TableCalendar(
            firstDay: _firstDay,
            lastDay: _lastDay,
            focusedDay: _focusedMonth,
            selectedDayPredicate: (day) => _selectedDay != null && isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedMonth = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedMonth = focusedDay;
              _loadMonth(focusedDay);
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final info = _days[_key(day)];
                if (info == null) return null;
                final dots = <Widget>[
                  if (info.checkInTime != null) _dot(Colors.green),
                  if (info.checkOutTime != null) _dot(Colors.orange),
                ];
                if (dots.isEmpty) return null;
                return Row(mainAxisSize: MainAxisSize.min, children: dots);
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : selected == null
                    ? const Center(child: Text('Select a day to see details'))
                    : _DayDetail(day: selected),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) => Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _DayDetail extends StatelessWidget {
  final DayAttendance day;
  const _DayDetail({required this.day});

  String _fmtTime(DateTime? t) => t == null ? '--:--' : DateFormat('hh:mm a').format(t);

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETE':
        return Colors.green;
      case 'ABSENT':
        return Colors.red;
      case 'CHECKED_IN':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d, yyyy').format(day.date),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.login, color: Colors.green),
              const SizedBox(width: 8),
              Text('Check-in: ${_fmtTime(day.checkInTime)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.logout, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Check-out: ${_fmtTime(day.checkOutTime)}'),
            ],
          ),
          if (day.workedMinutes != null) ...[
            const SizedBox(height: 8),
            Text('Worked: ${(day.workedMinutes! / 60).toStringAsFixed(1)} hours'),
          ],
          const SizedBox(height: 8),
          Text('Status: ${day.status}', style: TextStyle(color: _statusColor(day.status))),
        ],
      ),
    );
  }
}
