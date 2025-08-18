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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    Flushbar(
      message: message,
      margin: EdgeInsets.only(
        top: 40, 
        right: 16, 
        left: isTablet ? screenWidth * 0.6 : screenWidth * 0.25
      ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final iconSize = isTablet ? 38.0 : 34.0;
    final containerSize = isTablet ? 80.0 : 72.0;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Center(
          child: Icon(
            iconData,
            size: iconSize,
            color: selected ? kGradient.colors.last : Colors.black38,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;
    
    // Responsive sizing
    final appBarHeight = isTablet ? 70.0 : 56.0;
    final titleFontSize = isTablet ? 26.0 : 22.0;
    final logoSize = isTablet ? 50.0 : 40.0;
    final profileIconSize = isTablet ? 50.0 : 40.0;
    final profileIconInnerSize = isTablet ? 26.0 : 22.0;
    final fabSize = isTablet ? 76.0 : 66.0;
    final fabIconSize = isTablet ? 34.0 : 30.0;
    final bottomNavHeight = isTablet ? 70.0 : 60.0;
    final fabOffset = isTablet ? 45.0 : 40.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight),
        child: AppBar(
          elevation: 0.5,
          backgroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            _titles[_selectedIndex],
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: titleFontSize,
              letterSpacing: 0.3,
            ),
          ),
          leading: Padding(
            padding: EdgeInsets.only(left: isTablet ? 16.0 : 12.0),
            child: SizedBox(
              width: logoSize,
              height: logoSize,
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(
                right: isTablet ? 20.0 : 16.0, 
                top: isTablet ? 10.0 : 6.0
              ),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedIndex = 3);
                },
                child: Container(
                  width: profileIconSize,
                  height: profileIconSize,
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
                    size: profileIconInnerSize,
                  ),
                ),
              ),
            ),
          ],
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
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
        notchMargin: isTablet ? 4.0 : 3.0,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: bottomNavHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavIcon(Icons.dashboard_outlined, 0),
              _buildNavIcon(Icons.calendar_month_rounded, 1),
              SizedBox(width: isTablet ? 120 : 100),
              _buildNavIcon(Icons.emoji_food_beverage, 2),
              _buildNavIcon(Icons.person, 3),
            ],
          ),
        ),
      ),
      floatingActionButton: SizedBox(
        height: fabSize,
        width: fabSize,
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
          child: Icon(
            Icons.qr_code_scanner, 
            size: fabIconSize, 
            color: Colors.white
          ),
          elevation: 8,
        ),
      ),
      floatingActionButtonLocation: LoweredCenterDockedFabLocation(offsetY: fabOffset),
    );
  }
}
