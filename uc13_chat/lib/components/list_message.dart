import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../entities/message_entity.dart';

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
          padding: const EdgeInsets.all(8.0), // Espaçamento ao redor da lista
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];

            return Align(
              alignment: message.name.toLowerCase() == "joão"
                  ? Alignment.centerLeft // Destinatário à esquerda
                  : Alignment.centerRight, // Remetente à direita
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0), // Espaço entre as mensagens
                child: message.name.toLowerCase() == "joão"
                    ? MessageFrom(
                        name: message.name,
                        message: message.text,
                      )
                    : MessageTo(
                        name: message.name,
                        message: message.text,
                      ),
              ),
            );
          },
        );
      },
    );
  }
}   