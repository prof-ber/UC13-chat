import 'package:flutter/material.dart';

enum MessageDirection { from, to }

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.name,
    required this.message,
    required this.timestamp,
    required this.direction,
  });

  final String name;
  final String message;
  final DateTime timestamp;
  final MessageDirection direction;

  // Estilos centralizados
  static const Color _fromColor = Color(0xFF6a0dad);
  static const Color _toColor = Color(0xFF00bcd4);
  static const String _fontFamily = 'RobotoMono';
  static const _boxShadow = BoxShadow(
    color: Colors.black38,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  BorderRadius _getBorderRadius() {
    return direction == MessageDirection.from
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          );
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
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: direction == MessageDirection.from ? _fromColor : _toColor,
          borderRadius: _getBorderRadius(),
          boxShadow: const [_boxShadow],
        ),
        child: Column(
          crossAxisAlignment: direction == MessageDirection.from 
              ? CrossAxisAlignment.start 
              : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              direction == MessageDirection.to ? 'Você' : name,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white70,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 14,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}