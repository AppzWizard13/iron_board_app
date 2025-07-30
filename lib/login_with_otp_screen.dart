import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_screen.dart';
import 'verify_otp_screen.dart'; // Make sure this is the correct import path


class LoginWithOtpScreen extends StatefulWidget {
  @override
  _LoginWithOtpScreenState createState() => _LoginWithOtpScreenState();
}

class _LoginWithOtpScreenState extends State<LoginWithOtpScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;
  final String apiUrl = 'http://127.0.0.1:8000/api/send-otp/';

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
    _phoneController.dispose();
    super.dispose();
  }

  LinearGradient get gradient => const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFFA32EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );


  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage("Please enter your phone number");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"phone_number": phone}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showMessage(data['message'] ?? "OTP sent successfully");

        // ✅ Navigate using MaterialPageRoute and pass phone to VerifyOtpScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VerifyOtpScreen(phone: phone),
          ),
        );
      } else {
        _showMessage(data['message'] ?? "Failed to send OTP");
      }
    } catch (e) {
      _showMessage("Something went wrong. Please try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      const Text(
                        'OTP Login',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        "Enter your mobile number to receive an OTP.",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'SF Pro Display',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        cursorColor: const Color(0xFF6C63FF),
                        decoration: InputDecoration(
                          labelText: "Enter your mobile number",
                          labelStyle: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontFamily: 'SF Pro Display',
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : GradientButton(
                              text: 'Send OTP',
                              onPressed: _sendOtp,
                              height: 38,
                              radius: 22,
                              fontSize: 15,
                            ),
                      const SizedBox(height: 16),
                      const Text("or",
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 12),
                      GradientButton(
                        text: 'Back to Login',
                        onPressed: () => Navigator.pop(context),
                        height: 38,
                        radius: 22,
                        fontSize: 15,
                      ),
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
  bool shouldRepaint(covariant MovingTrianglePainter oldDelegate) {
    return false;
  }
}
