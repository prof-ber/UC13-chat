// list_message.dart
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../entities/message_entity.dart';
import 'message_from.dart';
import 'message_to.dart';

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
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isCurrentUser = message.name.toLowerCase() == "you";

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Align(
                alignment: isCurrentUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: isCurrentUser
                    ? MessageTo(
                        name: message.name,
                        message: message.text,
                        timestamp: message.timestamp,
                      )
                    : MessageFrom(
                        name: message.name,
                        message: message.text,
                        timestamp: message.timestamp,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}