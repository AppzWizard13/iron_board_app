import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'gradient_constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({Key? key}) : super(key: key);

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _storage = FlutterSecureStorage();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  Map<DateTime, double> attendedHours = {};
  Set<DateTime> presentDates = {};
  Map<DateTime, List<String>> timeMap = {};
  bool _loading = false;
  String? _error;
  int _daysThisMonth = 0;
  int _attendedDaysThisMonth = 0;
  double _totalHoursThisMonth = 0;

  DateTime _firstDayOfMonth(DateTime date) => DateTime(date.year, date.month, 1);
  DateTime _lastDayOfMonth(DateTime date) => DateTime(date.year, date.month + 1, 0);

  // SHADOW + ELEVATION SETTINGS
  final double _cardElevation = 10;
  final Color _cardShadowColor = Colors.black.withOpacity(0.12);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAttendance();
  }

  Future<String?> _getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  Future<void> _fetchAttendance() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = await _getAuthToken();
    if (token == null) {
      setState(() {
        _error = "Not logged in!";
        _loading = false;
      });
      return;
    }
    try {
      final isJWT = token.split('.').length == 3;
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final response = await http.get(
        Uri.parse('$baseUrl/api/attendance/'), // ✅ Properly closed and comma after
        headers: {
          'Content-Type': 'application/json',
          'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
        },
      );
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        final presentSet = <DateTime>{};
        final hoursMap = <DateTime, double>{};
        final thisTimeMap = <DateTime, List<String>>{};
        for (var item in data) {
          final rawDate = item['date'];
          final checkIn = item['check_in_time'];
          final checkOut = item['check_out_time'];
          DateTime? date = rawDate != null ? DateTime.parse(rawDate) : null;
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            presentSet.add(normalized);
            double hoursSpent = 0;
            String? inTimeStr, outTimeStr;
            if (checkIn != null && checkOut != null) {
              final inTime = DateTime.parse(checkIn);
              final outTime = DateTime.parse(checkOut);
              hoursSpent = outTime.difference(inTime).inMinutes / 60.0;
              inTimeStr = formatTimeAMPM(inTime);
              outTimeStr = formatTimeAMPM(outTime);
              thisTimeMap[normalized] = [inTimeStr, outTimeStr];
            } else if (checkIn != null) {
              final inTime = DateTime.parse(checkIn);
              inTimeStr = formatTimeAMPM(inTime);
              thisTimeMap[normalized] = [inTimeStr, "-"];
            } else {
              thisTimeMap[normalized] = ["-", "-"];
            }
            hoursMap[normalized] = hoursSpent;
          }
        }
        setState(() {
          presentDates = presentSet;
          attendedHours = hoursMap;
          timeMap = thisTimeMap;
          _computeMonthStats(_focusedDay);
        });
      } else {
        setState(() {
          _error = "Unable to fetch attendance. (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network error while fetching attendance: $e";
      });
    }
    setState(() {
      _loading = false;
    });
  }

  String formatTimeAMPM(DateTime t) => DateFormat('hh:mm a').format(t);

  int get absentDays {
    final now = DateTime.now();
    final first = _firstDayOfMonth(_focusedDay);
    final last = _lastDayOfMonth(_focusedDay);
    final end = (_focusedDay.year == now.year && _focusedDay.month == now.month)
        ? now
        : last;
    int absent = 0;
    for (int i = 0; i <= end.day - first.day; i++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, first.day + i);
      if (date.isAfter(now)) continue;
      if (!presentDates.any((d) =>
          d.year == date.year && d.month == date.month && d.day == date.day)) {
        absent += 1;
      }
    }
    return absent;
  }

  void _computeMonthStats(DateTime month) {
    final first = _firstDayOfMonth(month);
    final last = _lastDayOfMonth(month);
    int attended = 0;
    double hours = 0.0;
    for (var date in presentDates) {
      if (!(date.isBefore(first) || date.isAfter(last))) {
        attended += 1;
        hours += attendedHours[date] ?? 0;
      }
    }
    setState(() {
      _daysThisMonth = last.day;
      _attendedDaysThisMonth = attended;
      _totalHoursThisMonth = double.parse(hours.toStringAsFixed(2));
    });
  }

  void _showAttendanceDetail(BuildContext context, DateTime date) {
    final times = timeMap[date];
    final isPresent = times != null;
    final String workoutStr = attendedHours[date] != null
        ? "${attendedHours[date]!.toStringAsFixed(2)} hours"
        : "-";
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 27.0, horizontal: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${date.day}-${date.month}-${date.year}",
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              if (!isPresent)
                Text("No check-in for this day.",
                    style: TextStyle(fontSize: 16, color: Colors.red))
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Workout time: $workoutStr",
                      style: TextStyle(
                          fontSize: 15.3,
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo[900]),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _badge(times![0], Colors.green, "Check-in"),
                        const SizedBox(width: 18),
                        _badge(times[1], Colors.blue, "Check-out"),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color, String label) {
    if (text == "-" || text == null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
            decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.17),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300)),
            child: Text("—", style: TextStyle(fontSize: 16, color: Colors.black54)),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      );
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.44))),
          child: Text(
            text,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.74))),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final double progress =
        _daysThisMonth > 0 ? _attendedDaysThisMonth / _daysThisMonth : 0.0;
    final percentString = "${(_daysThisMonth > 0 ? (100 * progress).round() : 0)}%";
    final Color violet = Colors.deepPurpleAccent;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: _loading
          ? Center(
              child: SpinKitFadingCircle(
                color: kGradient.colors.last,
                size: 47,
              ),
            )
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.red)))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final double contentMaxWidth = 500;
                    final bool isWide = constraints.maxWidth > contentMaxWidth;
                    return Align(
                      alignment: Alignment.topCenter,

                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
                          child: Column(
                            children: [
                              // Attendance Summary Card
                              Card(
                                elevation: _cardElevation,
                                shadowColor: _cardShadowColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                margin: EdgeInsets.zero,
                                child: Container(
                                  width: contentMaxWidth,
                                  decoration: BoxDecoration(
                                    gradient: kGradient,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: kGradient.colors.last.withOpacity(0.08),
                                        blurRadius: 22,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical:16),
                                 child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title with subtle purple shadow
                                          Text(
                                            'Monthly Attendance',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.white.withOpacity(0.85),
                                              shadows: [
                                                Shadow(
                                                  color: violet.withOpacity(0.28), // purple-tinted shadow
                                                  blurRadius: 3.0,
                                                  offset: const Offset(0, 1.2),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Progress with faint purple glow using foreground 'color' + outer shadow wrapper
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: violet.withOpacity(0.18), // subtle purple glow
                                                  blurRadius: 8,
                                                  spreadRadius: 0.5,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: LinearProgressIndicator(
                                              value: progress,
                                              minHeight: 9,
                                              backgroundColor: Colors.white.withOpacity(0.17),
                                              color: Colors.green, // keep the progress color green
                                            ),
                                          ),

                                          const SizedBox(height: 7),
                                          Text(
                                            'Attended: $_attendedDaysThisMonth / $_daysThisMonth days',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.white24.withOpacity(0.72),
                                              shadows: [
                                                Shadow(
                                                  color: violet.withOpacity(0.18),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),

                                      // Bottom-right percentage chip with purple-tinted shadow
                                      Positioned(
                                        bottom: 6,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.93),
                                            borderRadius: BorderRadius.circular(13),
                                            boxShadow: [
                                              BoxShadow(
                                                color: violet.withOpacity(0.25), // same purple shadow family
                                                blurRadius: 8,
                                                spreadRadius: 0.2,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            percentString,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[800],
                                              fontSize: 14.3,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Calendar Card
                              Card(
                                elevation: _cardElevation,
                                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                                shadowColor: _cardShadowColor, // keep same card-level shadow color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Container(
                                  width: contentMaxWidth,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.97),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      // Stronger, more premium dual-shadow effect
                                      BoxShadow(
                                        color: Colors.deepPurpleAccent.withOpacity(0.08), // subtle purple glow
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04), // light depth
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 6),
                                  child: SizedBox(
                                    height: 350,
                                    child: TableCalendar(
                                      availableCalendarFormats: const {
                                        CalendarFormat.month: 'Month',
                                      },
                                      calendarFormat: _calendarFormat,
                                      firstDay: DateTime.utc(2020, 1, 1),
                                      lastDay: DateTime.now(),
                                      focusedDay: _focusedDay.isAfter(DateTime.now())
                                          ? DateTime.now()
                                          : _focusedDay,
                                      selectedDayPredicate: (day) =>
                                          isSameDay(_selectedDay, day),
                                      rowHeight: 41,
                                      onDaySelected: (selectedDay, focusedDay) {
                                        if (!selectedDay.isAfter(DateTime.now())) {
                                          setState(() {
                                            _selectedDay = selectedDay;
                                            _focusedDay = focusedDay;
                                          });
                                          _computeMonthStats(focusedDay);
                                          final normSel = DateTime(
                                              selectedDay.year,
                                              selectedDay.month,
                                              selectedDay.day);
                                          if (presentDates.any((d) =>
                                              d.year == normSel.year &&
                                              d.month == normSel.month &&
                                              d.day == normSel.day)) {
                                            _showAttendanceDetail(context, normSel);
                                          }
                                        }
                                      },
                                      onPageChanged: (focusedDay) {
                                        if (focusedDay.isAfter(DateTime.now())) {
                                          setState(() {
                                            _focusedDay = DateTime.now();
                                          });
                                        } else {
                                          setState(() {
                                            _focusedDay = focusedDay;
                                          });
                                        }
                                        _computeMonthStats(_focusedDay);
                                      },
                                      onFormatChanged: (format) {
                                        setState(() {
                                          _calendarFormat = format;
                                        });
                                      },
                                      // Your existing calendarBuilders and calendarStyle remain unchanged
                                      calendarBuilders: CalendarBuilders(
                                        defaultBuilder: (context, date, _) {
                                          if (presentDates.any((d) =>
                                              d.year == date.year &&
                                              d.month == date.month &&
                                              d.day == date.day)) {
                                            if (_isToday(date)) {
                                              return Container(
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurple.shade100.withOpacity(0.53),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.deepPurple,
                                                    width: 1.6,
                                                  ),
                                                ),
                                                child: Text(
                                                  '${date.day}',
                                                  style: TextStyle(
                                                    color: Colors.deepPurple[900],
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.17),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.green,
                                                    width: 1.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.green.withOpacity(0.07),
                                                    blurRadius: 2.2,
                                                    offset: const Offset(0, 1),
                                                  )
                                                ],
                                              ),
                                              child: Text(
                                                '${date.day}',
                                                style: TextStyle(
                                                  color: Colors.green[900],
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );
                                          }
                                          if (_isToday(date)) {
                                            return Container(
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.shade100.withOpacity(0.53),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.deepPurple,
                                                  width: 1.6,
                                                ),
                                              ),
                                              child: Text(
                                                '${date.day}',
                                                style: TextStyle(
                                                  color: Colors.deepPurple[900],
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            );
                                          }
                                          return null;
                                        },
                                        selectedBuilder: (context, date, _) {
                                          return Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: kGradient.colors.last,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: kGradient.colors.last.withOpacity(0.15),
                                                  blurRadius: 7,
                                                  offset: const Offset(0, 2),
                                                )
                                              ],
                                            ),
                                            child: Text(
                                              '${date.day}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                        todayBuilder: (context, date, _) {
                                          return Container(
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: Colors.deepPurple.shade100.withOpacity(0.53),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.deepPurple,
                                                width: 1.6,
                                              ),
                                            ),
                                            child: Text(
                                              '${date.day}',
                                              style: TextStyle(
                                                color: Colors.deepPurple[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      calendarStyle: CalendarStyle(
                                        selectedDecoration: BoxDecoration(
                                          color: kGradient.colors.last,
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        todayDecoration: BoxDecoration(
                                          color: Colors.deepPurple.shade100.withOpacity(0.44),
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        defaultDecoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        weekendDecoration: BoxDecoration(
                                          shape: BoxShape.rectangle,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // More compact summary cards row
                              Padding(
                                padding: const EdgeInsets.only(top: 0, bottom: 0),
                                child: SizedBox(
                                  width: contentMaxWidth,
                                  child:Column(
                                    children: [
                                      _summaryListTile(
                                        icon: Icons.event_busy, // Absent
                                        label: "Absent",
                                        value: absentDays.toString(),
                                        badgeColor: Colors.redAccent,
                                      ),
                                      _summaryListTile(
                                        icon: Icons.fitness_center, // Present
                                        label: "Present",
                                        value: _attendedDaysThisMonth.toString(),
                                        badgeColor: Colors.green,
                                      ),
                                      _summaryListTile(
                                        icon: Icons.timelapse,
                                        label: "Hours",
                                        value: _totalHoursThisMonth.toStringAsFixed(1),
                                        badgeColor: kGradient.colors.last,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _summaryListTile({
    required IconData icon,
    required String label,
    required String value,
    required Color badgeColor,
    Color? violetColor,
  }) {
    final Color valueColor = violetColor ?? Colors.deepPurpleAccent.withOpacity(0.82);

    return Card(
      elevation: _cardElevation,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      shadowColor: valueColor.withOpacity(0.18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.98),
              Colors.grey.shade50,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 25, color: badgeColor),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: null,
            ),
          ),
          trailing: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ),
    );
  }



  
}
