import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import 'login_with_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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
    super.dispose();
  }

  LinearGradient get gradient => const LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFFA32EFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

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
                              const Icon(Icons.dashboard_rounded,
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
              Align(
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 35),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C63FF),
                          fontWeight: FontWeight.w600,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Login to Your Account',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro Display',
                        ),
                      ),
                      const SizedBox(height: 28),
                      _roundedField(
                        label: 'Enter mobile number',
                        isPassword: false,
                      ),
                      const SizedBox(height: 10),
                      _roundedField(
                        label: 'Password',
                        isPassword: true,
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: false,
                            onChanged: (_) {},
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(fontSize: 13),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      GradientButton(
                        text: 'Login',
                        onPressed: () {},
                        height: 38,
                        radius: 22,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 9),
                      const Text(
                        'or',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 9),
                      GradientButton(
                        text: 'Login With OTP',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginWithOtpScreen(),
                            ),
                          );
                        },
                        height: 38,
                        radius: 22,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 9),
                      GradientButton(
                        text: 'Login With Google',
                        onPressed: () {},
                        height: 38,
                        radius: 22,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 13),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {},
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 13,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {},
                        child: const Text(
                          'New here? Create an account',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 13,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
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

  Widget _roundedField({required String label, required bool isPassword}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: TextField(
          obscureText: isPassword,
          cursorColor: const Color(0xFF6C63FF),
          style: const TextStyle(fontSize: 14.5),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(
              fontSize: 13.5,
              color: Colors.black87,
              fontFamily: 'SF Pro Display',
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
}

// Keep existing GradientButton, GradientText, and MovingTrianglePainter classes here (unchanged).

// --- GradientButton and GradientText classes stay the same as before ---

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
      shaderCallback: (bounds) => gradient
          .createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        text,
        style: style,
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
