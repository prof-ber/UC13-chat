import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../entities/message_entity.dart';
import 'message.dart'; // Importação do MessageWidget

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

            // Verifica se a mensagem foi enviada pelo usuário atual
            final isCurrentUser = message.name.toLowerCase() == "you";

            return MessageWidget(
              name: message.name,
              message: message.text,
              direction: isCurrentUser
                  ? MessageDirection.to // Mensagem enviada pelo usuário atual
                  : MessageDirection.from, // Mensagem recebida de outro usuário
            );
          },
        );
      },
    );
  }
}