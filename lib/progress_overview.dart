import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'gradient_constants.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

const Color violet = Color(0xFF7C4DFF);

class WeightProgressChart extends StatefulWidget {
  const WeightProgressChart({Key? key}) : super(key: key);

  @override
  State<WeightProgressChart> createState() => _WeightProgressChartState();
}

class _WeightProgressChartState extends State<WeightProgressChart> {
  final _storage = const FlutterSecureStorage();
  bool _loading = false;

  // Plot data
  List<FlSpot> spots = [];
  List<DateTime> xDates = [];
  double minY = 0;
  double maxY = 0;

  // BMI plot data
  List<FlSpot> bmiSpots = [];
  List<DateTime> bmiDates = [];
  double bmiMinY = 0;
  double bmiMaxY = 0;

  // Style knobs (match your summary card look)
  final double _cardElevation = 10;
  final double _cardRadius = 18;
  final Color _valueAccent = Colors.deepPurpleAccent;

  // Dynamically adjust chart height so card doesn't look taller than needed
  double get _chartHeight {
    double h = 200;
    if (xDates.length > 12) h = 220;
    if (xDates.length > 24) h = 240;
    return h.clamp(160, 260);
  }

  double get _bmiChartHeight {
    double h = 180;
    if (bmiDates.length > 12) h = 200;
    if (bmiDates.length > 24) h = 220;
    return h.clamp(150, 240);
  }

  // ---------- Auth ----------
  Future<String?> _getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  // ---------- UI helpers ----------
  void _showTopRightFlushBar(String message, {Color color = Colors.black87}) {
    if (!mounted) return;
    Flushbar(
      message: message,
      margin: const EdgeInsets.only(top: 40, right: 16, left: 100),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: color,
      flushbarPosition: FlushbarPosition.TOP,
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    ).show(context);
  }

  @override
  void initState() {
    super.initState();
    fetchProgressData();
  }

  // ---------- Fetch & parse ----------
  Future<void> fetchProgressData() async {
    setState(() => _loading = true);

    final token = await _getAuthToken();
    if (token == null) {
      _showTopRightFlushBar("Not logged in!", color: Colors.red);
      setState(() => _loading = false);
      return;
    }

    try {
      final isJWT = token.split('.').length == 3;
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final apiUrl = '$baseUrl/api/measurements/progress/';

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final List<dynamic> progressList =
            (jsonData["progress"] ?? []) as List<dynamic>;

        // Parse and sort entries by date
        final df = DateFormat('yyyy-MM-dd');
        final entries = progressList
            .map((e) {
              final dtStr =
                  (e["date"] ?? e["created_at"] ?? e["timestamp"] ?? "")
                      .toString();
              DateTime? dt;
              try {
                dt = df.parse(dtStr, true).toLocal();
              } catch (_) {
                try {
                  dt = DateTime.parse(dtStr).toLocal();
                } catch (_) {
                  dt = null;
                }
              }
              final weight = ((e["weight_kg"] ?? 0) as num).toDouble();
              final heightCm = (e["height_cm"] == null)
                  ? null
                  : ((e["height_cm"] as num).toDouble());
              if (dt == null) return null;
              return {
                "date": dt,
                "weight_kg": weight,
                "height_cm": heightCm,
              };
            })
            .where((e) => e != null)
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort((a, b) => (a["date"] as DateTime).compareTo(b["date"] as DateTime));

        // Build weight spots
        final newSpots = <FlSpot>[];
        final newDates = <DateTime>[];
        for (int i = 0; i < entries.length; i++) {
          newSpots.add(FlSpot(i.toDouble(), (entries[i]["weight_kg"] as double)));
          newDates.add(entries[i]["date"] as DateTime);
        }

        // Build BMI spots if height available; otherwise keep empty (we will also accept local list provided below).
        final newBmiSpots = <FlSpot>[];
        final newBmiDates = <DateTime>[];
        for (int i = 0; i < entries.length; i++) {
          final hCm = entries[i]["height_cm"] as double?;
          final w = entries[i]["weight_kg"] as double;
          if (hCm != null && hCm > 0) {
            final hM = hCm / 100.0;
            final bmi = w / (hM * hM);
            newBmiSpots.add(FlSpot(i.toDouble(), bmi));
            newBmiDates.add(entries[i]["date"] as DateTime);
          }
        }

        if (newSpots.isNotEmpty) {
          final ys = newSpots.map((s) => s.y).toList();
          final localMin = ys.reduce((a, b) => a < b ? a : b);
          final localMax = ys.reduce((a, b) => a > b ? a : b);
          final pad = ((localMax - localMin).abs() * 0.1).clamp(0.5, 5.0);
          setState(() {
            spots = newSpots;
            xDates = newDates;
            minY = (localMin - pad);
            maxY = (localMax + pad);
          });
        } else {
          setState(() {
            spots = [];
            xDates = [];
          });
        }

        if (newBmiSpots.isNotEmpty) {
          final ys = newBmiSpots.map((s) => s.y).toList();
          final localMin = ys.reduce((a, b) => a < b ? a : b);
          final localMax = ys.reduce((a, b) => a > b ? a : b);
          final pad = ((localMax - localMin).abs() * 0.1).clamp(0.2, 2.0);
          setState(() {
            bmiSpots = newBmiSpots;
            bmiDates = newBmiDates;
            bmiMinY = (localMin - pad);
            bmiMaxY = (localMax + pad);
          });
        } else {
          // If API did not include height, try to use provided inline data example (fallback)
          // Example payload received in the prompt (parsed locally here):
          final provided = [
            {'date': DateTime(2025, 7, 7), 'height_cm': 166.0, 'weight_kg': 56.0},
            {'date': DateTime(2025, 7, 15), 'height_cm': 166.0, 'weight_kg': 50.0},
            {'date': DateTime(2025, 7, 23), 'height_cm': 166.0, 'weight_kg': 75.0},
            {'date': DateTime(2025, 8, 1), 'height_cm': 166.0, 'weight_kg': 68.2},
            {'date': DateTime(2025, 7, 30), 'height_cm': 166.0, 'weight_kg': 70.0},
            {'date': DateTime(2025, 8, 15), 'height_cm': 166.0, 'weight_kg': 68.0},
          ]..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

          final pBmiSpots = <FlSpot>[];
          final pBmiDates = <DateTime>[];
          for (int i = 0; i < provided.length; i++) {
            final dt = provided[i]['date'] as DateTime;
            final hCm = (provided[i]['height_cm'] as num).toDouble();
            final w = (provided[i]['weight_kg'] as num).toDouble();
            final hM = hCm / 100.0;
            final bmi = w / (hM * hM);
            pBmiSpots.add(FlSpot(i.toDouble(), bmi));
            pBmiDates.add(dt);
          }
          if (pBmiSpots.isNotEmpty) {
            final ys = pBmiSpots.map((s) => s.y).toList();
            final localMin = ys.reduce((a, b) => a < b ? a : b);
            final localMax = ys.reduce((a, b) => a > b ? a : b);
            final pad = ((localMax - localMin).abs() * 0.1).clamp(0.2, 2.0);
            setState(() {
              bmiSpots = pBmiSpots;
              bmiDates = pBmiDates;
              bmiMinY = (localMin - pad);
              bmiMaxY = (localMax + pad);
            });
          } else {
            setState(() {
              bmiSpots = [];
              bmiDates = [];
            });
          }
        }

        setState(() => _loading = false);
      } else {
        _showTopRightFlushBar(
          "Unable to fetch progress. (${response.statusCode})",
          color: Colors.red,
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      _showTopRightFlushBar("Network error: $e", color: Colors.red);
      setState(() => _loading = false);
    }
  }

  // ---------- Axis title formatters ----------
  String _formatDateLabelFrom(List<DateTime> dates, int xIndex) {
    if (xIndex < 0 || xIndex >= dates.length) return '';
    return DateFormat('MMM d').format(dates[xIndex]);
  }

  String _formatDateLabel(int xIndex) => _formatDateLabelFrom(xDates, xIndex);
  String _formatBmiDateLabel(int xIndex) => _formatDateLabelFrom(bmiDates, xIndex);

  String _formatWeightLabel(double value) {
    final v = (value * 10).roundToDouble() / 10.0;
    return '${v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1)}kg';
  }

  String _formatBmiLabel(double value) {
    final v = (value * 10).roundToDouble() / 10.0;
    return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
  }

  List<int> _bottomTickIndexesFrom(List<DateTime> dates, int desired) {
    if (dates.isEmpty) return [];
    if (dates.length <= desired) {
      return List.generate(dates.length, (i) => i);
    }
    final step = (dates.length - 1) / (desired - 1);
    return List.generate(desired, (i) => (i * step).round());
  }

  List<int> _bottomTickIndexes(int desired) => _bottomTickIndexesFrom(xDates, desired);
  List<int> _bmiBottomTickIndexes(int desired) => _bottomTickIndexesFrom(bmiDates, desired);

  // ---------- BMI helpers ----------
  String _bmiStatus(double? lastBmi) {
    if (lastBmi == null) return 'N/A';
    if (lastBmi < 18.5) return 'Underweight';
    if (lastBmi < 25.0) return 'Normal';
    if (lastBmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color _bmiStatusColor(String status) {
    switch (status) {
      case 'Underweight':
        return Colors.blueAccent;
      case 'Normal':
        return Colors.green;
      case 'Overweight':
        return Colors.orangeAccent;
      case 'Obese':
        return Colors.redAccent;
      default:
        return Colors.grey.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color valueColor = _valueAccent.withOpacity(0.82);
    final Color shadowColor = valueColor.withOpacity(0.18);

    // Loading with SpinKitFadingCircle
    if (_loading) {
      return Center(
        child: SpinKitFadingCircle(
          color: kGradient.colors.last,
          size: 47,
        ),
      );
    }

    final tickIdx = _bottomTickIndexes(4);
    final bmiTickIdx = _bmiBottomTickIndexes(4);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weight Card
        if (spots.isEmpty)
          Card(
            elevation: _cardElevation,
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            shadowColor: shadowColor,
            child: Container(
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: kGradient.colors.last.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Center(
                child: Text(
                  "No data available",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            elevation: _cardElevation,
            margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            shadowColor: shadowColor,
            child: Container(
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: kGradient.colors.last.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(top: 20, bottom: 12, left: 12, right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min, // shrink-wrap to content
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with subtle purple shadow
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                    child: Text(
                      "Weight Progress",
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16.5,
                        color: Colors.white.withOpacity(0.85),
                        shadows: [
                          Shadow(
                            color: violet.withOpacity(0.28),
                            blurRadius: 3.0,
                            offset: const Offset(0, 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      "Last ${xDates.length} entries",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
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
                  ),
                  const SizedBox(height: 10),
                  // Chart with rounded corners; white line and grey axis labels
                  ClipRRect(
                    borderRadius: BorderRadius.circular(_cardRadius - 4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(_cardRadius - 4),
                      ),
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                      child: SizedBox(
                        height: _chartHeight,
                        width: double.infinity,
                        child: LineChart(
                          LineChartData(
                            minY: minY,
                            maxY: maxY,
                            minX: 0,
                            maxX: (spots.length - 1).toDouble(),
                            backgroundColor: Colors.transparent,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              verticalInterval: 1,
                              horizontalInterval: ((maxY - minY) / 4).clamp(1, 10),
                              getDrawingHorizontalLine: (v) => FlLine(
                                color: Colors.white.withOpacity(0.12),
                                strokeWidth: 1,
                              ),
                              getDrawingVerticalLine: (v) => FlLine(
                                color: Colors.white.withOpacity(0.08),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 22,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.round();
                                    if (!tickIdx.contains(idx)) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      _formatDateLabel(idx),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                        color: Colors.grey, // axis values in grey
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: ((maxY - minY) / 4).clamp(1, 10),
                                  getTitlesWidget: (value, meta) => Text(
                                    _formatWeightLabel(value),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: Colors.grey, // axis values in grey
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                top: BorderSide(color: Colors.white.withOpacity(0.10)),
                                right: BorderSide(color: Colors.white.withOpacity(0.10)),
                                bottom: BorderSide(color: Colors.white.withOpacity(0.10)),
                                left: BorderSide(color: Colors.white.withOpacity(0.10)),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                tooltipRoundedRadius: 8,
                                tooltipPadding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                tooltipMargin: 8,
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                getTooltipColor: (LineBarSpot spot) =>
                                    Colors.black.withOpacity(0.75),
                                getTooltipItems: (touchedSpots) {
                                  final df = DateFormat('MMM d, yyyy');
                                  return touchedSpots.map((barSpot) {
                                    final idx = barSpot.x.round();
                                    final dateStr =
                                        (idx >= 0 && idx < xDates.length)
                                            ? df.format(xDates[idx])
                                            : '';
                                    final w = barSpot.y.toStringAsFixed(1);
                                    return LineTooltipItem(
                                      '$dateStr\n$w kg',
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                barWidth: 3,
                                color: Colors.white, // chart line in white
                                isStrokeCapRound: true,
                                dotData: const FlDotData(show: false),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.20),
                                      Colors.white.withOpacity(0.04),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // BMI Card
        if (bmiSpots.isEmpty)
          Card(
            elevation: _cardElevation,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            shadowColor: shadowColor,
            child: Container(
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: kGradient.colors.last.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: const Center(
                child: Text(
                  "BMI data not available",
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
        else
          Card(
            elevation: _cardElevation,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_cardRadius),
            ),
            shadowColor: shadowColor,
            child: Container(
              decoration: BoxDecoration(
                gradient: kGradient,
                borderRadius: BorderRadius.circular(_cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: kGradient.colors.last.withOpacity(0.08),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.only(top: 20, bottom: 12, left: 12, right: 12),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                        child: Text(
                          "BMI Trend",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16.5,
                            color: Colors.white.withOpacity(0.88),
                            shadows: [
                              Shadow(
                                color: violet.withOpacity(0.28),
                                blurRadius: 3.0,
                                offset: const Offset(0, 1.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          "Last ${bmiDates.length} entries",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.5,
                            color: Colors.white24.withOpacity(0.75),
                            shadows: [
                              Shadow(
                                color: violet.withOpacity(0.18),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // BMI Chart
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_cardRadius - 4),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(_cardRadius - 4),
                          ),
                          padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
                          child: SizedBox(
                            height: _bmiChartHeight,
                            width: double.infinity,
                            child: LineChart(
                              LineChartData(
                                minY: bmiMinY,
                                maxY: bmiMaxY,
                                minX: 0,
                                maxX: (bmiSpots.length - 1).toDouble(),
                                backgroundColor: Colors.transparent,
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: true,
                                  verticalInterval: 1,
                                  horizontalInterval:
                                      ((bmiMaxY - bmiMinY) / 4).clamp(0.5, 5.0),
                                  getDrawingHorizontalLine: (v) => FlLine(
                                    color: Colors.white.withOpacity(0.12),
                                    strokeWidth: 1,
                                  ),
                                  getDrawingVerticalLine: (v) => FlLine(
                                    color: Colors.white.withOpacity(0.08),
                                    strokeWidth: 1,
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 22,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final idx = value.round();
                                        if (!bmiTickIdx.contains(idx)) {
                                          return const SizedBox.shrink();
                                        }
                                        return Text(
                                          _formatBmiDateLabel(idx),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      interval: ((bmiMaxY - bmiMinY) / 4)
                                          .clamp(0.5, 5.0),
                                      getTitlesWidget: (value, meta) => Text(
                                        _formatBmiLabel(value),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    top: BorderSide(
                                        color: Colors.white.withOpacity(0.10)),
                                    right: BorderSide(
                                        color: Colors.white.withOpacity(0.10)),
                                    bottom: BorderSide(
                                        color: Colors.white.withOpacity(0.10)),
                                    left: BorderSide(
                                        color: Colors.white.withOpacity(0.10)),
                                  ),
                                ),
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  touchTooltipData: LineTouchTooltipData(
                                    tooltipRoundedRadius: 8,
                                    tooltipPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    tooltipMargin: 8,
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    getTooltipColor: (LineBarSpot spot) =>
                                        Colors.black.withOpacity(0.75),
                                    getTooltipItems: (touchedSpots) {
                                      final df = DateFormat('MMM d, yyyy');
                                      return touchedSpots.map((barSpot) {
                                        final idx = barSpot.x.round();
                                        final dateStr =
                                            (idx >= 0 && idx < bmiDates.length)
                                                ? df.format(bmiDates[idx])
                                                : '';
                                        final v = barSpot.y.toStringAsFixed(1);
                                        final status = _bmiStatus(barSpot.y);
                                        return LineTooltipItem(
                                          '$dateStr\nBMI $v • $status',
                                          const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      }).toList();
                                    },
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: bmiSpots,
                                    isCurved: true,
                                    barWidth: 3,
                                    color: Colors.white,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.20),
                                          Colors.white.withOpacity(0.04),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  // Optional: Normal BMI band (18.5-24.9) using extra lines
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // BMI status chip (top-right)
                  Positioned(
                    top: 6,
                    right: 2,
                    child: Builder(
                      builder: (_) {
                        final lastBmi =
                            bmiSpots.isNotEmpty ? bmiSpots.last.y : null;
                        final status = _bmiStatus(lastBmi);
                        final color = _bmiStatusColor(status);
                        final label = lastBmi == null
                            ? status
                            : '${lastBmi.toStringAsFixed(1)} • $status';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.93),
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: violet.withOpacity(0.25),
                                blurRadius: 8,
                                spreadRadius: 0.2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: color.darken(0.35),
                                  fontSize: 13.8,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Small extension to darken colors for the BMI chip text contrast
extension _ColorShade on Color {
  Color darken([double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
