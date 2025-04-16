import 'package:flutter/material.dart';
import '../entities/message_entity.dart';
import 'message.dart';

class ListMessageView extends StatelessWidget {
  final List<Message> messages;

  const ListMessageView({Key? key, required this.messages}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isFromMe = message.name == 'You';
        
        return MessageWidget(
          name: isFromMe ? 'Você' : message.name,
          message: message.text,
          timestamp: message.timestamp,
          direction: isFromMe ? MessageDirection.to : MessageDirection.from,
        );
      },
    );
  }
}