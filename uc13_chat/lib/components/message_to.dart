import 'package:flutter/material.dart';
import 'message.dart'; // Import the file containing MessageWidget and MessageDirection

class MessageTo extends StatelessWidget {
  const MessageTo({
    super.key,
    required this.name,
    required this.message,
  });

  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MessageWidget(
      name: name,
      message: message,
      direction: MessageDirection.to,
    );
  }
}