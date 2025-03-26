import 'package:flutter/material.dart';
import 'message.dart';

class MessageTo extends MessageWidget {
  const MessageTo({
    super.key,
    required super.message,
    required super.timestamp,
  }) : super(
          direction: MessageDirection.to,
          name: 'Você', // Valor padrão
        );
}