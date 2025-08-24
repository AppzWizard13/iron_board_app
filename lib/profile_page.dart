import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gradient_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:numberpicker/numberpicker.dart';

// Utility: BMI calculation
String calculateBMI(dynamic weight, dynamic height) {
  if (weight == null || height == null) return "—";
  final w = double.tryParse(weight.toString());
  final h = double.tryParse(height.toString());
  if (w == null || h == null || h == 0) return "—";
  final bmi = w / ((h / 100) * (h / 100));
  return bmi.toStringAsFixed(1);
}

class ProfilePage extends StatefulWidget {
  final VoidCallback? onSignOut;
  final VoidCallback toggleTheme; // Add this field
  const ProfilePage({this.onSignOut, required this.toggleTheme, Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _storage = FlutterSecureStorage();
  Map<String, dynamic>? _userData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<String?> _getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  void _showTopRightFlushBar(String message, {Color color = Colors.black87}) {
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

  Future<void> _fetchUserProfile() async {
    setState(() => _loading = true);

    final token = await _getAuthToken();
    print("tokentokentokentoken::::::::::::::::::::::::::: $token");

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
        Uri.parse('$baseUrl/api/user/profile/'), // ✅ Added comma here
        headers: {
          'Content-Type': 'application/json',
          'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _userData = json.decode(response.body);
          _loading = false;
        });
      } else {
        setState(() {
          _error = "Unable to fetch profile. (${response.statusCode})";
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network error: $e";
        _loading = false;
      });
    }
  }

  Future<void> _openHeightWeightPickerDialog() async {
    final token = await _getAuthToken();
    if (token == null) {
      _showTopRightFlushBar("Not logged in", color: Colors.redAccent);
      return;
    }
    final isJWT = token.split('.').length == 3;

    // --- Ensure both height & weight are loaded correctly from _userData ---
    // Try from int/double/String -> to the right type; fallback values if null/invalid
    int selectedHeight = 170;
    final heightRaw = _userData?['height'];
    if (heightRaw != null) {
      if (heightRaw is int) {
        selectedHeight = heightRaw;
      } else if (heightRaw is double) {
        selectedHeight = heightRaw.round();
      } else {
        final parsed = int.tryParse(heightRaw.toString());
        if (parsed != null) selectedHeight = parsed;
      }
    }

    double selectedWeight = 70.0;
    final weightRaw = _userData?['weight'];
    if (weightRaw != null) {
      if (weightRaw is double) {
        selectedWeight = weightRaw;
      } else if (weightRaw is int) {
        selectedWeight = weightRaw.toDouble();
      } else {
        final parsed = double.tryParse(weightRaw.toString());
        if (parsed != null) selectedWeight = parsed;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: Text("Track Measurements"),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Height Picker
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Height (cm)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          NumberPicker(
                            value: selectedHeight,
                            minValue: 100,
                            maxValue: 250,
                            step: 1,
                            itemWidth: 40,
                            selectedTextStyle: const TextStyle(
                              color: Colors.deepPurple, // ✅ Selected value color
                              fontWeight: FontWeight.w600, // ✅ Slightly bold
                              fontSize: 20,
                            ),
                            textStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            onChanged: (value) =>
                                setStateSB(() => selectedHeight = value),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Weight Picker
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Weight (kg)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DecimalNumberPicker(
                            value: selectedWeight,
                            minValue: 20,
                            maxValue: 250,
                            decimalPlaces: 1,
                            itemWidth: 35,
                            selectedTextStyle: const TextStyle(
                              color: Colors.deepPurple, // ✅ Selected value color
                              fontWeight: FontWeight.w600, // ✅ Slightly bold
                              fontSize: 20,
                            ),
                            textStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                            onChanged: (value) =>
                                setStateSB(() => selectedWeight = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final resp = await http.post(
        Uri.parse('$baseUrl/api/measurements/week/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
        },
        body: jsonEncode({
          "height_cm": selectedHeight,
          "weight_kg": double.parse(selectedWeight.toStringAsFixed(1)),
        }),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        _showTopRightFlushBar("Measurements updated!", color: Colors.green);
        await _fetchUserProfile();
      } else {
        _showTopRightFlushBar(
          "Update failed (${resp.statusCode})",
          color: Colors.redAccent,
        );
      }
    } catch (e) {
      _showTopRightFlushBar("Network error: $e", color: Colors.redAccent);
    }
  }

  Future<bool> signOutApiCall(BuildContext context) async {
    final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
    final url = Uri.parse('$baseUrl/api/signout/');
    try {
      final token = await _getAuthToken();
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null)
            'Authorization': token.split('.').length == 3
                ? 'Bearer $token'
                : 'Token $token',
        },
      );
      if (response.statusCode == 200) {
        await _storage.delete(key: 'auth_token');
        await _storage.delete(key: 'auth_token_jwt');
        return true;
      }
      return false;
    } catch (e) {
      _showTopRightFlushBar("Network error during sign out.", color: Colors.redAccent);
      return false;
    }
  }

  Widget _smallProfileCard({
    required IconData icon,
    required String label,
    required String value,
    Color? badgeColor,
    VoidCallback? onTap,
  }) {
    badgeColor ??= kGradient.colors.last.withOpacity(0.82);

    final violetColor = Colors.deepPurpleAccent; // Violet for value

    final content = Card(
      elevation: 6,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      shadowColor: badgeColor.withOpacity(0.18),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(0.98), Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row - Label & Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(icon, size: 22, color: badgeColor),
                ),
              ],
            ),

            // Centered Value
            Expanded(
              child: Center(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: violetColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return onTap != null
        ? InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: content,
          )
        : content;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: Center(
          child: SpinKitFadingCircle(color: kGradient.colors.last, size: 46),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFE),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: _fetchUserProfile,
                icon: Icon(Icons.refresh),
                label: Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGradient.colors.last,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final d = _userData!;
    final avatarUrl = d["profile_image"];
    final userName = d["name"] ?? "Member";
    final userEmail = d["email"] ?? "";
    final membership = d["package"] ?? "—";
    final phone = d["phone"] ?? "—";
    final gymName = d["gym_name"] ?? "—";
    final location = d["location"] ?? "—";
    final statusValue = d['status'];
    final packageStatus = (statusValue == true)
        ? 'Active'
        : (statusValue == false)
            ? 'Inactive'
            : '—';
    final badgeColor = (packageStatus == "Active")
        ? Colors.green
        : (packageStatus == "Inactive")
            ? Colors.redAccent
            : kGradient.colors.last.withOpacity(0.82);
    final renewalDate = d['package_expiry_date'] ?? '—';
    final height = d['height']?.toString();
    final weight = d['weight']?.toString();
    final bmi = calculateBMI(weight, height);
    final gender = d['gender'] ?? '—';
    final waterAlert = d['water_alert']?.toString() ?? '—';
    final stepCount = d['step_count']?.toString() ?? '—';

    // --- BMI category color + icon logic ---
    String bmiCategoryFromValue(String bmiString) {
      final double? bmiVal = double.tryParse(bmiString);
      if (bmiVal == null) return 'Unknown';
      if (bmiVal < 18.5) return 'Underweight';
      if (bmiVal < 25) return 'Normal';
      if (bmiVal < 30) return 'Overweight';
      return 'Obese';
    }

    Color bmiBadgeColor(String category) {
      switch (category) {
        case 'Underweight':
          return Colors.amber;
        case 'Normal':
          return Colors.green;
        case 'Overweight':
          return Colors.orange;
        case 'Obese':
          return Colors.redAccent;
        default:
          return Colors.grey;
      }
    }

    IconData bmiIcon(String category) {
      switch (category) {
        case 'Underweight':
          return Icons.info;
        case 'Normal':
          return Icons.check_circle;
        case 'Overweight':
          return Icons.warning_amber;
        case 'Obese':
          return Icons.error;
        default:
          return Icons.help;
      }
    }

    final String bmiCategory = bmiCategoryFromValue(bmi);
    final Color bmiColor = bmiBadgeColor(bmiCategory);
    final IconData bmiStatusIcon = bmiIcon(bmiCategory);

    // --- Grid fields with BMI dynamic icon & color ---
    final gridFields = [
      {
        "icon": Icons.check_circle,
        "label": "Package Status",
        "value": packageStatus,
        "badgeColor": badgeColor,
        "editable": false
      },
      {
        "icon": Icons.update,
        "label": "Renewal Date",
        "value": renewalDate,
        "badgeColor": null,
        "editable": false
      },
      {
        "icon": bmiStatusIcon,
        "label": "BMI ($bmiCategory)",
        "value": bmi,
        "badgeColor": bmiColor,
        "editable": false
      },
      {
        "icon": Icons.perm_identity,
        "label": "Gender",
        "value": gender,
        "badgeColor": null,
        "editable": false
      },
      {
        "icon": Icons.height,
        "label": "Height",
        "value": (height != null) ? "$height cm" : "—",
        "badgeColor": null,
        "editable": true
      },
      {
        "icon": Icons.monitor_weight,
        "label": "Weight",
        "value": (weight != null) ? "$weight kg" : "—",
        "badgeColor": null,
        "editable": true
      },
      {
        "icon": Icons.water_drop,
        "label": "Water Alert",
        "value": waterAlert,
        "badgeColor": null,
        "editable": false
      },
      {
        "icon": Icons.directions_walk,
        "label": "Step Counter",
        "value": stepCount,
        "badgeColor": null,
        "editable": false
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Column(
            children: [
              _mainProfileCompactCard(
                avatarUrl: avatarUrl,
                name: userName,
                email: userEmail,
                phone: phone,
                membership: membership,
                gymName: gymName,
                location: location,
              ),
              GridView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gridFields.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                  childAspectRatio: 1.7,
                ),
                itemBuilder: (ctx, i) => _smallProfileCard(
                  icon: gridFields[i]["icon"] as IconData,
                  label: gridFields[i]["label"] as String,
                  value: gridFields[i]["value"] as String,
                  badgeColor: gridFields[i]["badgeColor"] as Color?,
                  onTap: () {
                    final label = gridFields[i]["label"] as String;
                    if (label == "Height" || label == "Weight") {
                      _openHeightWeightPickerDialog();
                    }
                  },
                ),
              ),
              _logoutCard(context),
            ],
          ),
        ),
      ),
    );
  }

 Widget _mainProfileCompactCard({
    required String? avatarUrl,
    required String name,
    required String email,
    required String phone,
    required String membership,
    required String gymName,
    required String location,
  }) {
    return Card(
      elevation: 5,
      shadowColor: kGradient.colors.last.withOpacity(0.13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      margin: const EdgeInsets.symmetric(vertical: 15, horizontal: 2),
      child: Container(
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            const SizedBox(width: 30),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: avatarUrl != null
                    ? Image.network(avatarUrl, fit: BoxFit.cover)
                    : Container(
                        color: Colors.white12,
                        child: Icon(Icons.person, size: 35, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                      shadows: [Shadow(color: Colors.black26, blurRadius: 1)],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.email, color: Colors.white, size: 16),
                      const SizedBox(width: 3),
                      Text(email, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone, color: Colors.white, size: 16),
                      const SizedBox(width: 3),
                      Text(phone, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.fitness_center, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(gymName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      const SizedBox(width: 14),
                      Icon(Icons.card_membership, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(membership, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _logoutCard(BuildContext context) {
    final Color accent = Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Card(
        elevation: 6,
        shadowColor: Colors.deepPurpleAccent.withOpacity(0.18), // ✅ purple shadow
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showLogoutConfirm(context),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.98), Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: Colors.redAccent, size: 22),
                SizedBox(width: 9),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirm(BuildContext context) async {
    final doLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text("Logging  Out"),
        content: Text("Are you sure you want to log out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text("Logout")),
        ],
      ),
    );
    if (doLogout ?? false) {
      bool result = await signOutApiCall(context);
      if (result) {
        if (widget.onSignOut != null) widget.onSignOut!();
        Navigator.pushAndRemoveUntil(
            context, 
            MaterialPageRoute(
              builder: (context) => LoginScreen(toggleTheme: widget.toggleTheme) // Pass toggleTheme here
            ), 
            (route) => false
        );
      }
    }
  }
}
