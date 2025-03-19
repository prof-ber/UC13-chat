import 'package:flutter/material.dart';
import 'message.dart'; // Import the file containing MessageWidget and MessageDirection

class MessageFrom extends StatelessWidget {
  const MessageFrom({
    Key? key,
    required this.name,
    required this.message,
  }) : super(key: key);

  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MessageWidget(
      name: name,
      message: message,
      direction: MessageDirection.from,
    );
  }
}