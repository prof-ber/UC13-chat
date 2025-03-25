import 'package:flutter/material.dart';

class MessageTo extends StatelessWidget {
  const MessageTo({
    super.key,
    required this.name,
    required this.message,
    required this.timestamp,
  });

  final String name;
  final String message;
  final DateTime timestamp;

  String _formatAviationTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF00bcd4),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomLeft: Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontFamily: 'RobotoMono',
                fontWeight: FontWeight.bold,
                fontSize: 12.0,
                color: Colors.white.withOpacity(0.8),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'RobotoMono',
                fontSize: 14.0,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4.0),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                _formatAviationTime(timestamp),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}