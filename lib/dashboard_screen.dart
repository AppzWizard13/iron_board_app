import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:another_flushbar/flushbar.dart';
import 'gradient_constants.dart';
import 'glassmorphic_card.dart';
import 'exercise_card.dart';
import 'calendar_page.dart';
import 'progress_overview.dart';
import 'profile_page.dart';
import 'qr_scan_screen.dart';
import 'home_dashboard_tab.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class LoweredCenterDockedFabLocation extends FloatingActionButtonLocation {
  final double offsetY;
  const LoweredCenterDockedFabLocation({this.offsetY = 14});
  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX =
        (scaffoldGeometry.scaffoldSize.width - scaffoldGeometry.floatingActionButtonSize.width) / 2;
    final double contentBottom = scaffoldGeometry.contentBottom;
    final double maxFabY = contentBottom - scaffoldGeometry.floatingActionButtonSize.height / 2;
    final double fabY = maxFabY + offsetY;
    return Offset(fabX, fabY);
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  static const _storage = FlutterSecureStorage();
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _userData;

  static const _titles = [
    "Home",
    "Gym Tracker",
    "Overview",
    "Profile",
  ];

  @override
  void initState() {
    super.initState();
    _pages = [
      CalendarPage(),
      const WeightProgressChart(),
      ProfilePage(
        onSignOut: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Signed out!")),
          );
        },
      ),
    ];
    _fetchUserProfile();
  }

  Future<String?> _getAuthToken() async {
    final jwtToken = await _storage.read(key: 'auth_token_jwt');
    if (jwtToken != null && jwtToken.trim().isNotEmpty) return jwtToken;
    final drfToken = await _storage.read(key: 'auth_token');
    if (drfToken != null && drfToken.trim().isNotEmpty) return drfToken;
    return null;
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _loading = true;
      _error = null;
      _userData = null;
    });
    final token = await _getAuthToken();
    print("token:::::::::::::::::::::::::::: $token");
    if (token == null) {
      setState(() {
        _error = "Not logged in!";
        _loading = false;
      });
      return;
    }
    try {
      final isJWT = token.split('.').length == 3;
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final response = await dio.get(
        '$baseUrl/api/user/profile/',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': isJWT ? 'Bearer $token' : 'Token $token',
          },
          responseType: ResponseType.json,
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _userData = response.data;
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

  void _showTopRightFlushBar(BuildContext context, String message) {
    Flushbar(
      message: message,
      margin: const EdgeInsets.only(top: 40, right: 16, left: 100),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: Colors.black.withOpacity(0.5),
      flushbarPosition: FlushbarPosition.TOP,
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      forwardAnimationCurve: Curves.easeOut,
      reverseAnimationCurve: Curves.easeIn,
    ).show(context);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      _fetchUserProfile();
    }
  }

  Widget _buildNavIcon(IconData iconData, int index) {
    final bool selected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth * 0.21, // Responsive width
            height: double.infinity,
            child: Center(
              child: Icon(
                iconData,
                size: constraints.maxHeight * 0.51, // Responsive icon size
                color: selected ? kGradient.colors.last : Colors.black38,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final screenHeight = media.size.height;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          _titles[_selectedIndex],
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: screenWidth * 0.055, // Responsive font size
            letterSpacing: 0.3,
          ),
        ),
        leading: Padding(
          padding: EdgeInsets.only(left: screenWidth * 0.03),
          child: SizedBox(
            width: screenWidth * 0.12, height: screenWidth * 0.12,
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: screenWidth * 0.04, top: screenWidth * 0.015),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 3);
              },
              child: Container(
                width: screenWidth * 0.11, height: screenWidth * 0.11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: kGradient,
                  boxShadow: [
                    BoxShadow(
                      color: kGradient.colors.last.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      spreadRadius: 1,
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: screenWidth * 0.055,
                ),
              ),
            ),
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _selectedIndex == 0
          ? HomeDashboardTab(
              userData: _userData,
              loading: _loading,
              error: _error,
              onReload: _fetchUserProfile,
            )
          : _pages[_selectedIndex - 1],

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 3.0,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: screenHeight * 0.07, // Responsive height
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavIcon(Icons.dashboard_outlined, 0),
              _buildNavIcon(Icons.calendar_month_rounded, 1),
              SizedBox(width: screenWidth * 0.23), // Responsive empty space for FAB
              _buildNavIcon(Icons.emoji_food_beverage, 2),
              _buildNavIcon(Icons.person, 3),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        height: screenWidth * 0.18,
        width: screenWidth * 0.18,
        child: FloatingActionButton(
          backgroundColor: kGradient.colors.last,
          onPressed: () async {
            final qrData = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScanScreen()),
            );
            if (qrData != null) {
              String? scheduleId = qrData.toString();
              try {
                final dio = Dio();
                final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
                final response = await dio.get(
                  '$baseUrl/api/check-qr-status/$scheduleId/',
                  options: Options(
                    headers: {'Accept': 'application/json'},
                    responseType: ResponseType.json,
                  ),
                );
                final data = response.data;
                if (data['status'] == 'ok') {
                  _showTopRightFlushBar(context, 'QR Valid!\nToken: ${data['token']}');
                } else if (data['status'] == 'waiting') {
                  _showTopRightFlushBar(context, 'Waiting for QR to become active.');
                } else {
                  _showTopRightFlushBar(context, data['message'] ?? 'Unknown response.');
                }
              } catch (e) {
                _showTopRightFlushBar(context, 'Failed to check QR: $e');
              }
            }
          },
          shape: const CircleBorder(),
          child: Icon(Icons.qr_code_scanner, size: screenWidth * 0.081, color: Colors.white),
          elevation: 8,
        ),
      ),
      floatingActionButtonLocation: LoweredCenterDockedFabLocation(offsetY: (screenWidth * 0.11)),
    );
  }
}
