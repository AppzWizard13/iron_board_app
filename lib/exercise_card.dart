import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'gradient_constants.dart';

class ExerciseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String duration;

  const ExerciseCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.duration,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(left: 10, bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: kGradient.colors.last.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGradient.colors.last, size: 36),
          const SizedBox(height: 10),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              description,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, size: 14, color: kGradient.colors.last),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  duration,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
