import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart'; // Add this import
import '../entities/message_entity.dart'; // Update the import path

import 'message_from.dart';
import 'message_to.dart';

class ListMessageView extends StatelessWidget {
  const ListMessageView({
    Key? key,
    required this.messages,
  }) : super(key: key);

  final List<Message> messages;

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];

            return message.name.toLowerCase() == "joão"
                ? MessageFrom(
                    name: message.name,
                    message: message.text,
                  )
                : MessageTo(
                    name: message.name,
                    message: message.text,
                  );
          },
        );
      },
    );
  }
}