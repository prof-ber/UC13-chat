import 'package:flutter/material.dart';
import 'package:uc13_chat/appconstants.dart';

enum MessageDirection { from, to }

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.name,
    required this.message,
    required this.timestamp,
    required this.direction,
    this.fileUrl,
  });

  final String name;
  final String message;
  final DateTime timestamp;
  final MessageDirection direction;
  final String? fileUrl;

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

  // Simple check if message looks like an image URL
  bool get _isImageMessage {
    return message.contains('/uploads/') &&
        (message.endsWith('.jpg') ||
            message.endsWith('.jpeg') ||
            message.endsWith('.png') ||
            message.endsWith('.gif'));
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          direction == MessageDirection.from
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
          crossAxisAlignment:
              direction == MessageDirection.from
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

            // Display image if message looks like an image URL
            if (_isImageMessage) ...[
              Container(
                constraints: BoxConstraints(
                  maxHeight: 200,
                  maxWidth: MediaQuery.of(context).size.width * 0.6,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.startsWith('http')
                        ? message
                        : 'http://${AppConstants.SERVER_IP}:3000${message}',
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 150,
                        alignment: Alignment.center,
                        child: CircularProgressIndicator(
                          value:
                              loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                          color: Colors.white70,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("Error loading image: $error");
                      return Container(
                        height: 100,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.white70,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Failed to load image",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else ...[
              // Display regular text message
              Text(
                message,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],

            const SizedBox(height: 4),
            Text(
              _formatTime(timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.white60),
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
