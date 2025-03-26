import 'package:flutter/material.dart';
import 'message.dart';

class MessageFrom extends MessageWidget {
  const MessageFrom({
    super.key,
    required super.name,
    required super.message,
    required super.timestamp,
  }) : super(direction: MessageDirection.from);
}