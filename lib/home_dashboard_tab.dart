// lib/home_dashboard_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gradient_constants.dart';
import 'glassmorphic_card.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeDashboardTab extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final bool loading;
  final String? error;
  final VoidCallback? onReload;

  const HomeDashboardTab({
    Key? key,
    required this.userData,
    required this.loading,
    required this.error,
    this.onReload,
  }) : super(key: key);

  @override
  State<HomeDashboardTab> createState() => _HomeDashboardTabState();
}

class _HomeDashboardTabState extends State<HomeDashboardTab> {
  // Loading/Error states for API sections
  bool _loadingToday = true;
  bool _loadingUpcoming = true;
  String? _errorToday;
  String? _errorUpcoming;

  // Data - Modified to match Django API structure
  Map<String, dynamic>? _todayPayload;
  List<Map<String, dynamic>> _upcomingDays = [];

  // Secure storage for tokens
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchToday();
    _fetchUpcoming();
  }

  // Compose proper base API URL and endpoints
  String _apiBase() {
    final base = dotenv.env['API_URL']?.trim() ?? '';
    return base.replaceAll(RegExp(r'/$'), '');
  }

  // Compose headers with token (JWT or DRF token supported)
  Future<Map<String, String>> _authHeaders() async {
    final token = await _getAuthToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      final isJWT = token.split('.').length == 3;
      headers['Authorization'] = isJWT ? 'Bearer $token' : 'Token $token';
    }
    return headers;
  }

  // Get token from secure storage, preferring JWT if present
  Future<String?> _getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  Future<void> _fetchToday() async {
    setState(() {
      _loadingToday = true;
      _errorToday = null;
    });
    try {
      // Updated URL to match Django API
      final url = Uri.parse('${_apiBase()}/api/workouts/today/');
      final resp = await http.get(url, headers: await _authHeaders());

      // Debug logs
      print('[TODAY] GET $url');
      print('[TODAY] Status: ${resp.statusCode}');
      print('[TODAY] Body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          _todayPayload = data;
          _loadingToday = false;
        });
      } else {
        setState(() {
          _errorToday = 'Failed to load today\'s workout (${resp.statusCode})';
          _loadingToday = false;
        });
      }
    } catch (e, st) {
      print('[TODAY] Error: $e');
      print('[TODAY] Stack: $st');
      setState(() {
        _errorToday = 'Network error loading today\'s workout';
        _loadingToday = false;
      });
    }
  }

  Future<void> _fetchUpcoming() async {
    setState(() {
      _loadingUpcoming = true;
      _errorUpcoming = null;
    });
    try {
      // Updated URL to match Django API
      final url = Uri.parse('${_apiBase()}/api/workouts/upcoming/');
      final resp = await http.get(url, headers: await _authHeaders());

      // Debug logs
      print('[UPCOMING] GET $url');
      print('[UPCOMING] Status: ${resp.statusCode}');
      print('[UPCOMING] Body: ${resp.body}');

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          // Parse upcoming workouts from Django API structure
          final upcomingWorkouts = data['data']?['upcoming_workouts'] as List? ?? [];
          _upcomingDays = upcomingWorkouts.cast<Map<String, dynamic>>();
          _loadingUpcoming = false;
        });
      } else {
        setState(() {
          _errorUpcoming = 'Failed to load upcoming workouts (${resp.statusCode})';
          _loadingUpcoming = false;
        });
      }
    } catch (e, st) {
      print('[UPCOMING] Error: $e');
      print('[UPCOMING] Stack: $st');
      setState(() {
        _errorUpcoming = 'Network error loading upcoming workouts';
        _loadingUpcoming = false;
      });
    }
  }

  Future<void> _reloadAll() async {
    await Future.wait([_fetchToday(), _fetchUpcoming()]);
  }

  // Helper method to format date
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = date.difference(now).inDays;
      
      if (difference == 0) return 'Today';
      if (difference == 1) return 'Tomorrow';
      if (difference <= 7) return 'in $difference days';
      return '${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }

  // Helper method to calculate total estimated time for all exercises
  int _calculateTotalTime(List<dynamic> activities) {
    int total = 0;
    for (var activity in activities) {
      final duration = activity['estimated_duration'] as String? ?? '';
      // Extract minutes from duration like "10min" or "10-12min"
      final match = RegExp(r'(\d+)').firstMatch(duration);
      if (match != null) {
        total += int.tryParse(match.group(1)!) ?? 0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return Center(
        child: SpinKitFadingCircle(
          color: kGradient.colors.last,
          size: 46.0,
        ),
      );
    }

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.error!, style: const TextStyle(color: Colors.red, fontSize: 18)),
            const SizedBox(height: 18),
            if (widget.onReload != null)
              ElevatedButton.icon(
                onPressed: widget.onReload,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
              )
          ],
        ),
      );
    }

    final userName = widget.userData?['name'] ?? 'Member';
    final packageName = widget.userData?['package'] ?? 'Active Plan';
    final renewalDate = widget.userData?['package_expiry_date'] ?? '—';

    // Parse today's workout data from Django API response
    final todayData = _todayPayload?['data'] as Map<String, dynamic>?;
    final todayWorkouts = todayData?['workouts'] as List? ?? [];
    final hasWorkoutToday = todayWorkouts.isNotEmpty;
    final todayDayName = todayData?['day_name'] as String? ?? '';

    // Layout: Top card stays visible; only workout lists scroll
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fixed top profile card (non-scrollable)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: GlassmorphicCard(
            elevation: 20,
            shadowColor: kGradient.colors.last.withOpacity(0.1),
            child: Row(
              children: [
                Container(
                  width: 75,
                  height: 110,
                  decoration: BoxDecoration(
                    gradient: kGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kGradient.colors.last.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    size: 52,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back, $userName!",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBadge(icon: Icons.badge, text: packageName),
                        const SizedBox(height: 10),
                        _buildBadge(icon: Icons.verified_rounded, text: "Active"),
                        const SizedBox(height: 10),
                        _buildBadge(icon: Icons.calendar_month, text: "Next Renewal: $renewalDate"),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ),

        // Scrollable content: Today's workout + Upcoming workouts
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reloadAll,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              children: [
                // Today's Workout Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Today's Workout ($todayDayName)",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _fetchToday,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(60, 30),
                      ),
                      label: Text(
                        "Reload",
                        style: TextStyle(
                          color: kGradient.colors.last,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_loadingToday)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: SpinKitThreeBounce(color: kGradient.colors.last, size: 18),
                    ),
                  )
                else if (_errorToday != null)
                  _errorTile(_errorToday!, onRetry: _fetchToday)
                else if (!hasWorkoutToday)
                  _emptyTile(
                    title: "No Workout Today",
                    subtitle: "Enjoy your rest day or check with your trainer for updates.",
                  )
                else ...[
                  // Render all workouts for today
                  ...todayWorkouts.map((workout) {
                    final templateName = workout['template_name'] as String? ?? '';
                    final trainerName = workout['trainer_name'] as String? ?? '';
                    final dayTemplate = workout['day_template'] as Map<String, dynamic>? ?? {};
                    final workoutName = dayTemplate['name'] as String? ?? 'Workout';
                    final isRestDay = dayTemplate['is_rest_day'] as bool? ?? false;
                    final estimatedDuration = dayTemplate['estimated_duration'] as String? ?? '';
                    final activities = dayTemplate['activities'] as List? ?? [];

                    if (isRestDay) {
                      return _summaryTile(
                        icon: Icons.free_breakfast,
                        title: "Rest Day",
                        value: "Recovery",
                        sub: templateName,
                      );
                    }

                    // Summary card for the workout
                    return Column(
                      children: [
                        _summaryTile(
                          icon: Icons.event_available,
                          title: workoutName,
                          value: estimatedDuration.isEmpty ? "—" : estimatedDuration,
                          sub: "$templateName • by $trainerName",
                        ),
                        const SizedBox(height: 8),
                        
                        // Render all exercises
                        ...activities.map((activity) {
                          final exerciseName = activity['exercise']?['name'] as String? ?? '';
                          final sets = activity['sets']?.toString() ?? '-';
                          final reps = activity['reps']?.toString() ?? '-';
                          final restTime = activity['rest_time'] as String? ?? '';
                          final formCues = activity['form_cues'] as String? ?? '';
                          final estimatedDuration = activity['estimated_duration'] as String? ?? '';

                          final descParts = <String>[
                            "Sets: $sets",
                            "Reps: $reps",
                            if (restTime.isNotEmpty) "Rest: $restTime",
                            if (formCues.isNotEmpty) "Form: $formCues",
                          ];
                          final description = descParts.join(" • ");

                          return _exerciseListTile(
                            icon: Icons.fitness_center,
                            label: exerciseName,
                            description: description,
                            duration: estimatedDuration,
                            badgeColor: Colors.blue,
                          );
                        }).toList(),
                      ],
                    );
                  }).toList(),
                ],

                const SizedBox(height: 20),

                // Upcoming Workouts Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Upcoming Workouts",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _fetchUpcoming,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(60, 30),
                      ),
                      label: Text(
                        "Reload",
                        style: TextStyle(
                          color: kGradient.colors.last,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_loadingUpcoming)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: SpinKitThreeBounce(color: kGradient.colors.last, size: 18),
                    ),
                  )
                else if (_errorUpcoming != null)
                  _errorTile(_errorUpcoming!, onRetry: _fetchUpcoming)
                else if (_upcomingDays.isEmpty)
                  _emptyTile(
                    title: "No Upcoming Workouts",
                    subtitle: "There are no workouts scheduled in the next week.",
                  )
                else
                  Column(
                    children: _upcomingDays.map((day) {
                      final date = day['date'] as String? ?? '';
                      final dayName = day['day_name'] as String? ?? '';
                      final workouts = day['workouts'] as List? ?? [];
                      final totalWorkouts = day['total_workouts'] as int? ?? 0;

                      return ExpansionTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_month, color: Colors.green, size: 20),
                        ),
                        title: Text(
                          "$dayName (${_formatDate(date)})",
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text("$totalWorkouts workout(s)"),
                        children: workouts.map((workout) {
                          final templateName = workout['template_name'] as String? ?? '';
                          final dayTemplate = workout['day_template'] as Map<String, dynamic>? ?? {};
                          final workoutName = dayTemplate['name'] as String? ?? 'Workout';
                          final isRestDay = dayTemplate['is_rest_day'] as bool? ?? false;
                          final activities = dayTemplate['activities'] as List? ?? [];
                          final estimatedDuration = dayTemplate['estimated_duration'] as String? ?? '';

                          if (isRestDay) {
                            return _exerciseListTile(
                              icon: Icons.free_breakfast,
                              label: "Rest Day",
                              description: templateName,
                              duration: "Recovery",
                              badgeColor: Colors.orange,
                            );
                          }

                          return _exerciseListTile(
                            icon: Icons.fitness_center,
                            label: workoutName,
                            description: "$templateName • ${activities.length} exercises",
                            duration: estimatedDuration,
                            badgeColor: Colors.green,
                          );
                        }).cast<Widget>().toList(),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Reusable badge
  Widget _buildBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kGradient.colors.last.withOpacity(0.13),
            blurRadius: 8,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Summary ListTile
  Widget _summaryTile({
    required IconData icon,
    required String title,
    required String value,
    String? sub,
  }) {
    final Color valueColor = Colors.deepPurpleAccent.withOpacity(0.82);
    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      shadowColor: valueColor.withOpacity(0.18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.98), Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 25, color: valueColor),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87),
          ),
          subtitle: sub == null || sub.isEmpty
              ? null
              : Text(sub, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          trailing: Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ),
      ),
    );
  }

  // Exercise tile
  Widget _exerciseListTile({
    required IconData icon,
    required String label,
    required String description,
    required String duration,
    required Color badgeColor,
  }) {
    final Color valueColor = Colors.deepPurpleAccent.withOpacity(0.82);

    return Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      shadowColor: valueColor.withOpacity(0.18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.98), Colors.grey.shade50],
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
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black54,
            ),
          ),
          trailing: Text(
            duration,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ),
      ),
    );
  }

  // Empty state tile
  Widget _emptyTile({required String title, String? subtitle}) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.info_outline, color: Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: subtitle == null ? null : Text(subtitle),
      ),
    );
  }

  // Error tile
  Widget _errorTile(String message, {VoidCallback? onRetry}) {
    return Card(
      elevation: 0,
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: const Text("Error", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
        subtitle: Text(message, style: const TextStyle(color: Colors.red)),
        trailing: onRetry == null
            ? null
            : TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text("Retry"),
              ),
      ),
    );
  }
}
