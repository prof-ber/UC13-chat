import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../entities/message_entity.dart';
import 'message_from.dart'; // Importação do MessageFrom
import 'message_to.dart';   // Importação do MessageTo

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

            return Align(
              alignment: isCurrentUser
                  ? Alignment.centerRight // Mensagem enviada pelo usuário atual
                  : Alignment.centerLeft, // Mensagem recebida de outro usuário
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: isCurrentUser
                    ? MessageTo(
                        name: message.name,
                        message: message.text,
                      )
                    : MessageFrom(
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