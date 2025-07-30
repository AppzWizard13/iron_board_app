import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class VerifyOtpScreen extends StatefulWidget {
  final String phone;

  const VerifyOtpScreen({Key? key, required this.phone}) : super(key: key);

  @override
  _VerifyOtpScreenState createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends State<VerifyOtpScreen> with SingleTickerProviderStateMixin {
  List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  late AnimationController _ctrl;

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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focus in _focusNodes) {
      focus.dispose();
    }
    super.dispose();
  }

  void _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showMessage("Please enter a 6-digit OTP.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('https://iron-board.onrender.com/api/verify-otp/'),
        body: {
          'otp': otp,
          'phone_number': widget.phone,
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        _showMessage("OTP Verified Successfully");
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showMessage(data['message'] ?? 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      _showMessage("Verification failed. Please try again later.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
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
          final circleSpecs = [
            {'top': -55 + 12 * sin(animationValue * 2 * pi), 'left': -60 + 10 * cos(animationValue * 2 * pi), 'size': 140.0, 'color': const Color(0xFF6C63FF).withOpacity(0.13)},
            {'bottom': -40 + 7 * cos(animationValue * 2 * pi), 'right': -30 + 8 * sin(animationValue * 2 * pi), 'size': 80.0, 'color': const Color(0xFFA32EFF).withOpacity(0.16)},
            {'top': 80 + 8 * sin(animationValue * 2 * pi + 1), 'right': -28 + 5 * cos(animationValue * 2 * pi + 3), 'size': 42.0, 'color': const Color(0xFFA32EFF).withOpacity(0.12)},
            {'bottom': 220 + 13 * cos(animationValue * 2 * pi + 2), 'left': -80 + 11 * sin(animationValue * 2 * pi + 1), 'size': 175.0, 'color': const Color(0xFF6C63FF).withOpacity(0.09)},
            {'top': 60 + 6 * cos(animationValue * pi + 1.2), 'left': 90 + 6 * sin(animationValue * 2 * pi), 'size': 24.0, 'color': const Color(0xFFA32EFF).withOpacity(0.16)},
          ];

          return Stack(
            children: [
              Positioned.fill(
                child: Stack(
                  children: [
                    ...circleSpecs.map((spec) => Positioned(
                      top: spec['top'] as double?,
                      left: spec['left'] as double?,
                      right: spec['right'] as double?,
                      bottom: spec['bottom'] as double?,
                      child: _buildCircle(spec['size'] as double, spec['color'] as Color),
                    )),
                    Positioned(
                      left: 0 + 14 * sin(animationValue * pi),
                      top: 310 + 13 * cos(animationValue * pi),
                      child: CustomPaint(
                        painter: MovingTrianglePainter(color: const Color(0xFF6C63FF).withOpacity(0.13)),
                        size: const Size(44, 44),
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 64),
                  child: Column(
                    children: [
                      const Text("Verify OTP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'SF Pro Display')),
                      const SizedBox(height: 14),
                      const Text("Enter the 6-digit OTP sent to your mobile", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 24),
                      Text(widget.phone, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (i) => _buildOtpInputBox(i)),
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : GradientButton(text: "Verify", onPressed: _verifyOtp, height: 38, radius: 22),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login-with-otp'),
                        child: const Text("Resend OTP"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text("Back to Login"),
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
