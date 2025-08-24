import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'dashboard_screen.dart';
import 'login_with_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  const LoginScreen({super.key, required this.toggleTheme});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final storage = FlutterSecureStorage();
  bool isLoading = false;
  bool isRemember = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  LinearGradient get gradient => const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFFA32EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  // Show a custom flushbar in the top-right corner
  void showTopRightFlushBar(String message) {
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

  // Send FCM token to backend after successful authentication
  Future<void> _sendFCMTokenToBackend(String authToken) async {
    try {
      print('Attempting to send FCM token to backend...');
      
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('FCM Token obtained: $fcmToken');
      
      if (fcmToken != null && fcmToken.isNotEmpty) {
        final dio = Dio();
        final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
        
        final response = await dio.post(
          '$baseUrl/api/update-fcm-token/',
          data: {'fcm_token': fcmToken},
          options: Options(
            headers: {
              'Authorization': 'Token $authToken', // Changed from 'Bearer' to 'Token'
              'Content-Type': 'application/json',
            },
          ),
        );

        if (response.statusCode == 200) {
          print('FCM token sent to backend successfully: ${response.data}');
        } else {
          print('Failed to send FCM token. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error sending FCM token to backend: $e');
    }
  }


  Future<String?> loginUser(String mobile, String password) async {
    setState(() => isLoading = true);
    final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
    final url = Uri.parse('$baseUrl/api-v1/login/');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mobile': mobile, 'password': password}),
      );
      
      setState(() => isLoading = false);

      final decodedJson = json.decode(response.body);
      print("Login response decoded: $decodedJson");
      
      if (response.statusCode == 200) {
        // Try common key names for access token
        final token = decodedJson['access'] ?? decodedJson['key'];
        if (token != null) {
          await storage.write(key: 'auth_token_jwt', value: token);
          print('Access token stored securely!');
          
          // Optionally store refresh token
          if (decodedJson['refresh'] != null) {
            await storage.write(key: 'refresh_token_jwt', value: decodedJson['refresh']);
          }

          // Send FCM token to backend after successful login
          await _sendFCMTokenToBackend(token);
          
        } else {
          print('No access token received.');
        }
        return null; // Success, no error
      } else {
        final jsonResp = jsonDecode(response.body);
        return jsonResp['detail'] ?? 'Login failed';
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Login error: $e');
      return 'An error occurred. Please try again.';
    }
  }

  Future<void> _handleGoogleLogin() async {
    try {
      // Always show the account picker by signing out first
      await _googleSignIn.signOut();

      // Start Google sign-in
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        showTopRightFlushBar('Google sign-in cancelled!');
        return;
      }
      
      // Get authentication tokens
      final GoogleSignInAuthentication auth = await account.authentication;
      final String? accessToken = auth.accessToken;

      if (accessToken == null) {
        showTopRightFlushBar('Google sign-in failed: No access token received.');
        return;
      }
      print("Google accessToken: $accessToken");

      // Send access token to Django backend
      final dio = Dio();
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final response = await dio.post(
        '$baseUrl/dj-rest-auth/google/',
        data: {'access_token': accessToken},
        options: Options(contentType: Headers.jsonContentType),
      );
      
      print("Google login response status: ${response.statusCode}");
      print("Google login response data: ${response.data}");

      if (response.statusCode == 200) {
        final String? authToken = response.data['access'] ?? 
                                  response.data['token'] ?? 
                                  response.data['key'];
        if (authToken != null) {
          await storage.write(key: 'auth_token', value: authToken);
          
          // Send FCM token to backend after successful Google login
          await _sendFCMTokenToBackend(authToken);
          
          showTopRightFlushBar('Google login successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(toggleTheme: widget.toggleTheme),
            ),
          );
        } else {
          showTopRightFlushBar('Login succeeded but no auth token received!');
        }
      } else {
        print("Google login failed: ${response.data}");
        showTopRightFlushBar('Google login failed.');
      }
    } catch (e) {
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['non_field_errors'] != null) {
          final errors = data['non_field_errors'];
          if (errors is List && errors.any((err) => err.toString().contains('already registered'))) {
            showTopRightFlushBar('This Gmail is not registered with IRON BOARD.');
          } else {
            showTopRightFlushBar(errors.join('\n'));
          }
        } else {
          showTopRightFlushBar('Google login error: ${data ?? e}');
        }
        print("Dio error type: ${e.type}");
        print("Dio error: $e");
        print("Dio error response: $data");
      } else {
        showTopRightFlushBar('Google login error: $e');
        print("Google login error: $e");
      }
    }
  }

  Widget _roundedField({
    required String label,
    required bool isPassword,
    required TextEditingController controller,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          cursorColor: const Color(0xFF6C63FF),
          style: const TextStyle(fontSize: 14.5),
          keyboardType: isPassword ? TextInputType.text : TextInputType.phone,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontFamily: 'SF Pro Display',
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final animationValue = _ctrl.value;
          final circleSpecs = [
            {
              'top': -55 + 12 * sin(animationValue * 2 * pi),
              'left': -60 + 10 * cos(animationValue * 2 * pi),
              'size': 140.0,
              'color': const Color(0xFF6C63FF).withOpacity(0.13)
            },
            {
              'bottom': -40 + 7 * cos(animationValue * 2 * pi),
              'right': -30 + 8 * sin(animationValue * 2 * pi),
              'size': 80.0,
              'color': const Color(0xFFA32EFF).withOpacity(0.16)
            },
            {
              'top': 80 + 8 * sin(animationValue * 2 * pi + 1),
              'right': -28 + 5 * cos(animationValue * 2 * pi + 3),
              'size': 42.0,
              'color': const Color(0xFFA32EFF).withOpacity(0.12)
            },
            {
              'bottom': 220 + 13 * cos(animationValue * 2 * pi + 2),
              'left': -80 + 11 * sin(animationValue * 2 * pi + 1),
              'size': 175.0,
              'color': const Color(0xFF6C63FF).withOpacity(0.09)
            },
            {
              'top': 60 + 6 * cos(animationValue * pi + 1.2),
              'left': 90 + 6 * sin(animationValue * 2 * pi),
              'size': 24.0,
              'color': const Color(0xFFA32EFF).withOpacity(0.16)
            },
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    ...circleSpecs.map((spec) {
                      return Positioned(
                        top: spec['top'] as double?,
                        left: spec['left'] as double?,
                        right: spec['right'] as double?,
                        bottom: spec['bottom'] as double?,
                        child: _buildCircle(
                            spec['size'] as double, spec['color'] as Color),
                      );
                    }).toList(),
                    Positioned(
                      left: 0 + 14 * sin(animationValue * pi),
                      top: 310 + 13 * cos(animationValue * pi),
                      child: CustomPaint(
                        painter: MovingTrianglePainter(
                          color: const Color(0xFF6C63FF).withOpacity(0.13),
                        ),
                        size: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0, left: 20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          color: Colors.white.withOpacity(0.18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.dashboard_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              GradientText(
                                'IRON BOARD',
                                gradient: gradient,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontFamily: 'SF Pro Display',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Theme toggle button in top-right corner
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20.0, right: 20.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: widget.toggleTheme,
                            icon: Icon(
                              Theme.of(context).brightness == Brightness.dark
                                  ? Icons.light_mode
                                  : Icons.dark_mode,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 55),
                      Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Login to Your Account',
                        style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 28),
                      _roundedField(
                        label: 'Enter mobile number',
                        isPassword: false,
                        controller: _mobileController,
                      ),
                      const SizedBox(height: 10),
                      _roundedField(
                        label: 'Password',
                        isPassword: true,
                        controller: _passwordController,
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: isRemember,
                            onChanged: (val) {
                              setState(() {
                                isRemember = val ?? false;
                              });
                            },
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          Text(
                            'Remember me',
                            style: TextStyle(fontSize: 13),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      isLoading
                          ? const SpinKitFadingCircle(
                              color: Color(0xFF6C63FF),
                              size: 38.0,
                            )
                          : GradientButton(
                              text: 'Login',
                              onPressed: () async {
                                FocusScope.of(context).unfocus();
                                final mobile = _mobileController.text.trim();
                                final password = _passwordController.text;
                                if (mobile.isEmpty || password.isEmpty) {
                                  showTopRightFlushBar('Please enter all fields');
                                  return;
                                }
                                final errorMessage = await loginUser(mobile, password);
                                if (errorMessage == null) {
                                  showTopRightFlushBar('Login successful');
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardScreen(toggleTheme: widget.toggleTheme),
                                    ),
                                  );
                                } else {
                                  showTopRightFlushBar(errorMessage);
                                }
                              },
                              height: 38,
                              radius: 22,
                              fontSize: 15,
                            ),
                      const SizedBox(height: 9),
                      Text(
                        'or',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 9),
                      GradientButton(
                        text: 'Login With Google',
                        onPressed: _handleGoogleLogin,
                        height: 38,
                        radius: 22,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 13),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double height;
  final double radius;
  final double fontSize;

  const GradientButton({
    required this.text,
    required this.onPressed,
    this.height = 40,
    this.radius = 24,
    this.fontSize = 15,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFA32EFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: fontSize,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Gradient gradient;

  const GradientText(
    this.text, {
    required this.gradient,
    required this.style,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style),
    );
  }
}

class MovingTrianglePainter extends CustomPainter {
  final Color color;
  MovingTrianglePainter({required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final Path path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MovingTrianglePainter oldDelegate) => false;
}
