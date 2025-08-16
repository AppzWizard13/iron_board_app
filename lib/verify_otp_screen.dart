import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VerifyOtpScreen extends StatefulWidget {
  final String phone;
  const VerifyOtpScreen({Key? key, required this.phone}) : super(key: key);

  @override
  _VerifyOtpScreenState createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> with SingleTickerProviderStateMixin {
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  late AnimationController _ctrl;

  // Dio + Cookie management (only one instance needed)
  final Dio _dio = Dio();
  final CookieJar _cookieJar = CookieJar();

  // Secure storage instance
  final FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _dio.interceptors.add(CookieManager(_cookieJar));
    _ctrl = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _sendOtp(); // Send OTP (and start session) when entering screen
  }

  @override
  void dispose() {
    _ctrl.dispose();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focus in _focusNodes) {
      focus.dispose();
    }
    super.dispose();
  }

  Future<void> _sendOtp() async {
    // Call Django to send OTP—this establishes the session.
    try {
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';
      final response = await _dio.post(
        '$baseUrl/api/send-otp/',
        data: {'phone_number': widget.phone},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final res = response.data;
      if (response.statusCode == 200 && res['success'] == true) {
        _showTopRightFlushBar("OTP sent to ${widget.phone}");
      } else {
        _showTopRightFlushBar(res['message'] ?? 'Could not send OTP. Try again.');
      }
    } catch (e) {
      _showTopRightFlushBar("Couldn't send OTP. Please check connection.");
    }
  }

  Future<void> _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showTopRightFlushBar("Please enter a 6-digit OTP.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final Dio dio = Dio(); // ✅ define dio here
      final baseUrl = dotenv.env['API_URL'] ?? 'https://example.com';

      final response = await dio.post(
        '$baseUrl/api/verify-otp/',
        data: {
          'otp': otp,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final data = response.data;

      if (response.statusCode == 200) {
        final String? authToken = data['access'] ?? data['token'] ?? data['key'];
        if (authToken != null) {
          await storage.write(key: 'auth_token_jwt', value: authToken);
          _showTopRightFlushBar("OTP Verified Successfully");
          Navigator.pushReplacementNamed(context, '/dashboard');
          return;
        }
        _showTopRightFlushBar("Verification succeeded but no auth token received!");
        return;
      }

      _showTopRightFlushBar(data['detail'] ?? 'Invalid OTP. Please try again.');
    } catch (e) {
      if (e is DioError) {
        final data = e.response?.data;
        if (data is Map && data['non_field_errors'] != null) {
          final errors = data['non_field_errors'];
          _showTopRightFlushBar(errors is List ? errors.join('\n') : errors.toString());
        } else {
          _showTopRightFlushBar('OTP verification error: ${data ?? e}');
        }
        print("Dio error type: ${e.type}");
        print("Dio error: $e");
        print("Dio error response: $data");
      } else {
        _showTopRightFlushBar('OTP verification error: $e');
        print("OTP verification error: $e");
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showTopRightFlushBar(String message) {
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

  Widget _buildOtpInputBox(int index) {
    return Container(
      width: 42,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final animationValue = _ctrl.value;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
              child: Column(
                children: [
                  const Text(
                    "Verify OTP",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'SF Pro Display'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Enter the 6-digit OTP sent to your mobile",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Text(widget.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (i) => _buildOtpInputBox(i)),
                  ),
                  const SizedBox(height: 24),
                  _isLoading
                      ? const SpinKitFadingCircle(
                          color: Color(0xFFA32EFF), // Use your accent color
                          size: 40,
                        )
                      : GradientButton(text: "Verify", onPressed: _verifyOtp, height: 38, radius: 22),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _sendOtp,
                    child: const Text("Resend OTP"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text("Back to Login"),
                  ),
                ],
              ),
            ),
          );
        },
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
