import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../entities/message_entity.dart';
import 'message.dart';

class ListMessageView extends StatelessWidget {
  const ListMessageView({
    super.key,
    required this.messages,
  });

  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          reverse: true,
          physics: const BouncingScrollPhysics(),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final messageIndex = messages.length - 1 - index;
            final message = messages[messageIndex];
            
            return MessageWidget(
              name: message.name,
              message: message.text,
              timestamp: message.timestamp,
              direction: message.name.toLowerCase() == "you" 
                  ? MessageDirection.to 
                  : MessageDirection.from,
            );
          },
        );
      },
    );
  }
}