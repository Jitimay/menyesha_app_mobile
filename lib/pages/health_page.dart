import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class HealthPage extends StatefulWidget {
  @override
  _HealthPageState createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Event>> _events = {};
  List<DateTime> _periodDates = [];
  late SharedPreferences prefs;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  _loadData() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      _periodDates = (prefs.getStringList('periodDates') ?? [])
          .map((date) => DateTime.parse(date))
          .toList();
      _events = Map.fromEntries(
        (prefs.getStringList('events') ?? []).map((item) {
          final parsed = jsonDecode(item);
          return MapEntry(
            DateTime.parse(parsed['date']),
            (parsed['events'] as List)
                .map((e) => Event(e['title'], e['intensity']))
                .toList(),
          );
        }),
      );
    });
  }

  _saveData() {
    prefs.setStringList(
        'periodDates', _periodDates.map((date) => date.toIso8601String()).toList());
    prefs.setStringList(
      'events',
      _events.entries.map((entry) {
        return jsonEncode({
          'date': entry.key.toIso8601String(),
          'events': entry.value
              .map((e) => {'title': e.title, 'intensity': e.intensity})
              .toList(),
        });
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Period Tracker'),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2010, 10, 16),
            lastDay: DateTime.utc(2030, 3, 14),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) => _events[day] ?? [],
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isNotEmpty) {
                  return Positioned(
                    right: 1,
                    bottom: 1,
                    child: _buildEventsMarker(date, events),
                  );
                }
                return SizedBox();
              },
            ),
          ),
          const SizedBox(height: 8.0),
          Expanded(
            child: ListView(
              children: _getEventsForDay(_selectedDay)
                  .map((event) => ListTile(
                title: Text(event.title),
                subtitle: Text('Intensity: ${event.intensity}'),
              ))
                  .toList(),
            ),
          ),
          ElevatedButton(
            onPressed: _addNewPeriod,
            child: Text('Log Period'),
          ),
          if (_periodDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Next Predicted Period: ${DateFormat.yMMMd().format(_calculateNextPeriod())}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsMarker(DateTime date, List events) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _periodDates.contains(date) ? Colors.red : Colors.blue,
      ),
      width: 16.0,
      height: 16.0,
      child: Center(
        child: Text(
          '${events.length}',
          style: TextStyle().copyWith(
            color: Colors.white,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _events[day] ?? [];
  }

  void _addNewPeriod() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Period'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Date: ${DateFormat.yMMMd().format(_selectedDay)}'),
            SizedBox(height: 20),
            DropdownButton<int>(
              value: 1,
              items: [1, 2, 3, 4, 5].map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('Flow Intensity: $value'),
                );
              }).toList(),
              onChanged: (newValue) {
                // Handle intensity change
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _periodDates.add(_selectedDay);
                if (_events[_selectedDay] != null) {
                  _events[_selectedDay]!.add(Event('Period', 1));
                } else {
                  _events[_selectedDay] = [Event('Period', 1)];
                }
                _saveData();
              });
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  DateTime _calculateNextPeriod() {
    if (_periodDates.isNotEmpty) {
      _periodDates.sort((a, b) => b.compareTo(a));
      int averageCycle = _calculateAverageCycle();
      return _periodDates.first.add(Duration(days: averageCycle));
    }
    return DateTime.now();
  }

  int _calculateAverageCycle() {
    if (_periodDates.length < 2) return 28;
    int totalDays = 0;
    for (int i = 0; i < _periodDates.length - 1; i++) {
      totalDays += _periodDates[i].difference(_periodDates[i + 1]).inDays;
    }
    return totalDays ~/ (_periodDates.length - 1);
  }
}

class Event {
  final String title;
  final int intensity;

  Event(this.title, this.intensity);
}