import 'package:flutter/material.dart';

enum MessageDirection { from, to }

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.name,
    required this.message,
    required this.timestamp,
    this.direction = MessageDirection.from,
  });

  final String name;
  final String message;
  final DateTime timestamp;
  final MessageDirection direction;

  String _formatAviationTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: direction == MessageDirection.from 
          ? Alignment.centerLeft 
          : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: direction == MessageDirection.from
              ? const Color(0xFF6a0dad)  // Cor para mensagens recebidas
              : const Color(0xFF00bcd4),  // Cor para mensagens enviadas
          borderRadius: direction == MessageDirection.from
              ? const BorderRadius.only(
                  topLeft: Radius.circular(16.0),
                  topRight: Radius.circular(16.0),
                  bottomRight: Radius.circular(16.0),
                )
              : const BorderRadius.only(
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
          crossAxisAlignment: direction == MessageDirection.from
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
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
              alignment: direction == MessageDirection.from
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
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