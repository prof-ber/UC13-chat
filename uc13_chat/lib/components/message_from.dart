// message_from.dart
import 'package:flutter/material.dart';

class MessageFrom extends StatelessWidget {
  const MessageFrom({
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75, // 75% da largura da tela
      ),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: const Color(0xFF6a0dad),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16.0),
            topRight: Radius.circular(16.0),
            bottomRight: Radius.circular(16.0),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Align(
              alignment: Alignment.bottomRight,
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