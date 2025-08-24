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
import 'payment_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback toggleTheme;  // Add this field
  const DashboardScreen({super.key, required this.toggleTheme});

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

class ResponsiveHelper {
  static const double smallScreen = 360;
  static const double mediumScreen = 480;
  static const double largeScreen = 600;
  static const double extraLargeScreen = 900;

  static ScreenSize getScreenSize(double width) {
    if (width <= smallScreen) return ScreenSize.small;
    if (width <= mediumScreen) return ScreenSize.medium;
    if (width <= largeScreen) return ScreenSize.large;
    return ScreenSize.extraLarge;
  }

  static ResponsiveDimensions getDimensions(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenSize = getScreenSize(size.width);
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    
    return ResponsiveDimensions(
      screenWidth: size.width,
      screenHeight: size.height,
      screenSize: screenSize,
      pixelRatio: pixelRatio,
    );
  }
}

enum ScreenSize { small, medium, large, extraLarge }

class ResponsiveDimensions {
  final double screenWidth;
  final double screenHeight;
  final ScreenSize screenSize;
  final double pixelRatio;

  ResponsiveDimensions({
    required this.screenWidth,
    required this.screenHeight,
    required this.screenSize,
    required this.pixelRatio,
  });

  // App Bar dimensions
  double get appBarHeight {
    switch (screenSize) {
      case ScreenSize.small:
        return 56.0;
      case ScreenSize.medium:
        return 60.0;
      case ScreenSize.large:
        return 64.0;
      case ScreenSize.extraLarge:
        return 70.0;
    }
  }

  double get titleFontSize {
    switch (screenSize) {
      case ScreenSize.small:
        return 18.0;
      case ScreenSize.medium:
        return 20.0;
      case ScreenSize.large:
        return 22.0;
      case ScreenSize.extraLarge:
        return 26.0;
    }
  }

  double get logoSize {
    switch (screenSize) {
      case ScreenSize.small:
        return 32.0;
      case ScreenSize.medium:
        return 36.0;
      case ScreenSize.large:
        return 40.0;
      case ScreenSize.extraLarge:
        return 50.0;
    }
  }

  double get profileIconSize {
    switch (screenSize) {
      case ScreenSize.small:
        return 34.0;
      case ScreenSize.medium:
        return 38.0;
      case ScreenSize.large:
        return 42.0;
      case ScreenSize.extraLarge:
        return 50.0;
    }
  }

  double get profileIconInnerSize => profileIconSize * 0.6;

  // Bottom Navigation dimensions
  double get bottomNavHeight {
    final baseHeight = screenHeight * 0.08;
    switch (screenSize) {
      case ScreenSize.small:
        return (baseHeight).clamp(56.0, 65.0);
      case ScreenSize.medium:
        return (baseHeight).clamp(60.0, 70.0);
      case ScreenSize.large:
        return (baseHeight).clamp(65.0, 75.0);
      case ScreenSize.extraLarge:
        return (baseHeight).clamp(70.0, 80.0);
    }
  }

  double get navIconSize {
    final baseSize = screenWidth * 0.065;
    switch (screenSize) {
      case ScreenSize.small:
        return (baseSize).clamp(24.0, 30.0);
      case ScreenSize.medium:
        return (baseSize).clamp(28.0, 34.0);
      case ScreenSize.large:
        return (baseSize).clamp(32.0, 38.0);
      case ScreenSize.extraLarge:
        return (baseSize).clamp(36.0, 42.0);
    }
  }

  double get navIconContainerSize {
    return navIconSize * 2.2;
  }

  double get notchMargin {
    switch (screenSize) {
      case ScreenSize.small:
        return 2.0;
      case ScreenSize.medium:
        return 3.0;
      case ScreenSize.large:
        return 4.0;
      case ScreenSize.extraLarge:
        return 5.0;
    }
  }

  // FAB dimensions
  double get fabSize {
    final baseSize = screenWidth * 0.16;
    switch (screenSize) {
      case ScreenSize.small:
        return (baseSize).clamp(56.0, 66.0);
      case ScreenSize.medium:
        return (baseSize).clamp(60.0, 70.0);
      case ScreenSize.large:
        return (baseSize).clamp(66.0, 76.0);
      case ScreenSize.extraLarge:
        return (baseSize).clamp(70.0, 80.0);
    }
  }

  double get fabIconSize => fabSize * 0.45;

  double get fabOffset {
    final baseOffset = bottomNavHeight * 0.65;
    return baseOffset.clamp(25.0, 50.0);
  }

  // Spacing
  EdgeInsets get horizontalPadding {
    final basePadding = screenWidth * 0.04;
    final padding = basePadding.clamp(12.0, 24.0);
    return EdgeInsets.symmetric(horizontal: padding);
  }

  EdgeInsets get appBarActionsPadding {
    final rightPadding = screenWidth * 0.04;
    final topPadding = screenHeight * 0.01;
    return EdgeInsets.only(
      right: rightPadding.clamp(12.0, 24.0),
      top: topPadding.clamp(4.0, 12.0),
    );
  }

  // Flushbar positioning
  EdgeInsets get flushbarMargin {
    final leftMargin = screenWidth * 0.25;
    return EdgeInsets.only(
      top: 40,
      right: 16,
      left: leftMargin.clamp(80.0, screenWidth * 0.6),
    );
  }

  // Profile card dimensions - REDUCED SIZE
  double get cardProfilePictureSize {
    switch (screenSize) {
      case ScreenSize.small:
        return 60.0; // Reduced from 80.0
      case ScreenSize.medium:
        return 65.0; // Reduced from 90.0
      case ScreenSize.large:
        return 70.0; // Reduced from 100.0
      case ScreenSize.extraLarge:
        return 75.0; // Reduced from 110.0
    }
  }

  // Name title font size - REDUCED SIZE
  double get cardTitleFontSize {
    switch (screenSize) {
      case ScreenSize.small:
        return 20.0; // Reduced from 28.0
      case ScreenSize.medium:
        return 22.0; // Reduced from 28.0
      case ScreenSize.large:
        return 24.0; // Reduced from 28.0
      case ScreenSize.extraLarge:
        return 26.0; // Reduced from 28.0
    }
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
        toggleTheme: widget.toggleTheme, // Add this line to fix the error
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

  // Enhanced status badge widget with payment button for inactive status
  Widget _buildStatusBadge(bool isActive) {
    if (isActive) {
      // Return just the active badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16), // Reduced border radius
          border: Border.all(
            color: Colors.green,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6, // Reduced from 8
              height: 6, // Reduced from 8
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 4), // Reduced from 6
            Text(
              'Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 11, // Reduced from 12
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    } else {
      // Return inactive badge with payment button
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16), // Reduced border radius
              border: Border.all(
                color: Colors.red,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, // Reduced from 8
                  height: 6, // Reduced from 8
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 4), // Reduced from 6
                Text(
                  'Inactive',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 11, // Reduced from 12
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8), // Space between badge and button
          SizedBox(
            height: 24, // Match the badge height approximately
            child: ElevatedButton(
              onPressed: _navigateToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Pay Now'),
            ),
          ),
        ],
      );
    }
  }

  // Enhanced default profile icon
  Widget _buildDefaultProfileIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Icon(
        Icons.fitness_center,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  // Add this method to your DashboardScreen class
  void _navigateToPayment() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen( // ← Remove 'const'
          amount: 999.0,
          itemName: 'Gym Subscription', 
          packageId: 2, // Make sure package ID matches your backend
        ),
      ),
    ).then((success) {
      if (success == true) {
        // Handle successful payment
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment completed successfully!')),
        );
      }
    });
  }

  // Enhanced gradient top card with profile picture - REDUCED SIZE
  Widget _buildEnhancedGradientCard({
    required String title,
    required String subtitle,
    Widget? badge,
    List<Widget>? additionalContent,
    String? profilePictureUrl,
  }) {
    final dimensions = ResponsiveHelper.getDimensions(context);
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6), // Reduced margin
      decoration: BoxDecoration(
        gradient: kGradient,
        borderRadius: BorderRadius.circular(16), // Reduced border radius
        boxShadow: [
          BoxShadow(
            color: kGradient.colors.last.withOpacity(0.3), // Reduced opacity
            blurRadius: 15, // Reduced blur
            offset: const Offset(0, 6), // Reduced offset
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Reduced opacity
            blurRadius: 8, // Reduced blur
            offset: const Offset(0, 3), // Reduced offset
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Decorative circles - REDUCED SIZE
          Positioned(
            top: -20, // Reduced from -30
            right: -20, // Reduced from -30
            child: Container(
              width: 70, // Reduced from 100
              height: 70, // Reduced from 100
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08), // Reduced opacity
              ),
            ),
          ),
          Positioned(
            bottom: -15, // Reduced from -20
            left: -15, // Reduced from -20
            child: Container(
              width: 45, // Reduced from 60
              height: 45, // Reduced from 60
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04), // Reduced opacity
              ),
            ),
          ),
          // Main content - REDUCED PADDING
          Padding(
            padding: const EdgeInsets.all(18), // Reduced from 24
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Profile picture section
                    Container(
                      width: dimensions.cardProfilePictureSize,
                      height: dimensions.cardProfilePictureSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2.5, // Reduced from 3
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15), // Reduced opacity
                            blurRadius: 12, // Reduced blur
                            offset: const Offset(0, 4), // Reduced offset
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                            ? Image.network(
                                profilePictureUrl,
                                fit: BoxFit.cover,
                                width: dimensions.cardProfilePictureSize,
                                height: dimensions.cardProfilePictureSize,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultProfileIcon(dimensions.cardProfilePictureSize);
                                },
                              )
                            : _buildDefaultProfileIcon(dimensions.cardProfilePictureSize),
                      ),
                    ),
                    SizedBox(width: 16), // Reduced from 20
                    // Title and badge section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: dimensions.cardTitleFontSize, // Using new reduced font size
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.4, // Reduced letter spacing
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6), // Reduced from 8
                          if (badge != null) badge,
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14), // Reduced from 20
                // Subtitle
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2, // Reduced letter spacing
                  ),
                ),
                // Additional content with improved styling
                if (additionalContent != null) ...[
                  SizedBox(height: 12), // Reduced from 16
                  Container(
                    padding: const EdgeInsets.all(12), // Reduced from 16
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08), // Reduced opacity
                      borderRadius: BorderRadius.circular(10), // Reduced from 12
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15), // Reduced opacity
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: additionalContent.map((widget) => Padding(
                        padding: const EdgeInsets.only(bottom: 6), // Reduced from 8
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.8),
                              size: 14, // Reduced from 16
                            ),
                            SizedBox(width: 6), // Reduced from 8
                            Expanded(child: widget),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTopRightFlushBar(BuildContext context, String message) {
    final dimensions = ResponsiveHelper.getDimensions(context);
    
    Flushbar(
      message: message,
      margin: dimensions.flushbarMargin,
      borderRadius: BorderRadius.circular(12),
      backgroundColor: Colors.black.withOpacity(0.8),
      flushbarPosition: FlushbarPosition.TOP,
      duration: const Duration(seconds: 3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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

  Widget _buildNavIcon(IconData iconData, int index, ResponsiveDimensions dimensions) {
    final bool selected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        width: dimensions.navIconContainerSize,
        height: dimensions.navIconContainerSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(dimensions.navIconContainerSize / 4),
          color: selected ? kGradient.colors.last.withOpacity(0.1) : Colors.transparent,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Icon(
              iconData,
              size: dimensions.navIconSize,
              color: selected ? kGradient.colors.last : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveBottomAppBar(ResponsiveDimensions dimensions) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: dimensions.notchMargin,
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      child: Container(
        height: dimensions.bottomNavHeight,
        padding: EdgeInsets.symmetric(
          horizontal: dimensions.screenWidth * 0.05,
          vertical: dimensions.bottomNavHeight * 0.1,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            _buildNavIcon(Icons.dashboard_outlined, 0, dimensions),
            _buildNavIcon(Icons.calendar_month_rounded, 1, dimensions),
            SizedBox(width: dimensions.fabSize + 20), // Space for FAB
            _buildNavIcon(Icons.emoji_food_beverage, 2, dimensions),
            _buildNavIcon(Icons.person, 3, dimensions),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveFAB(ResponsiveDimensions dimensions) {
    return SizedBox(
      height: dimensions.fabSize,
      width: dimensions.fabSize,
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
        elevation: 8,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kGradient.colors.last.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.qr_code_scanner,
            size: dimensions.fabIconSize,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = ResponsiveHelper.getDimensions(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(dimensions.appBarHeight),
        child: AppBar(
          leadingWidth: 70, 
          elevation: 0.5,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          centerTitle: true,
          title: Text(
            _titles[_selectedIndex],
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              fontSize: dimensions.titleFontSize,
              letterSpacing: 0.3,
            ),
          ),
          leading: Container(
            margin: const EdgeInsets.only(left: 0.0), // Add left margin
            child: Center(
              child: SizedBox(
                height: 50,
                child: Image.asset(
                  'assets/app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.fitness_center, color: Colors.blue),
                ),
              ),
            ),
          ),

          actions: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0.0, 0.0, 25.0, 0.0),
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = 3),
                child: Container(
                  width: dimensions.profileIconSize,
                  height: dimensions.profileIconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: kGradient,
                    boxShadow: [
                      BoxShadow(
                        color: kGradient.colors.last.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: dimensions.profileIconSize * 0.5,
                  ),
                ),
              ),
            ),
          ],



          iconTheme: const IconThemeData(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: _selectedIndex == 0
            ? Column(
                children: [
                  // Enhanced gradient card with profile picture - NOW SMALLER
                  _buildEnhancedGradientCard(
                    title: _userData?['name'] ?? 'Welcome',
                    subtitle: _userData?['email'] ?? 'Loading user data...',
                    profilePictureUrl: _userData?['profile_picture'],
                    badge: _userData != null ? _buildStatusBadge(_userData!['status'] ?? false) : null,
                    additionalContent: [
                      Text(
                        'Membership: ${_userData?['package'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13, // Reduced from 14
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Expire Date: ${_userData?['package_expiry_date'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13, // Reduced from 14
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: HomeDashboardTab(
                      userData: _userData,
                      loading: _loading,
                      error: _error,
                      onReload: _fetchUserProfile,
                    ),
                  ),
                ],
              )
            : _pages[_selectedIndex - 1],
      ),
      bottomNavigationBar: _buildResponsiveBottomAppBar(dimensions),
      floatingActionButton: _buildResponsiveFAB(dimensions),
      floatingActionButtonLocation: LoweredCenterDockedFabLocation(
        offsetY: dimensions.fabOffset,
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
