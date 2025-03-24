import 'package:flutter/material.dart';

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    Key? key,
    required this.name,
    required this.message,
    this.direction = MessageDirection.from,
  }) : super(key: key);

  final String name;
  final String message;
  final MessageDirection direction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: direction == MessageDirection.from
          ? Alignment.centerLeft // Destinatário à esquerda
          : Alignment.centerRight, // Remetente à direita
      child: _MessageContainer(
        messageDirection: direction,
        child: Column(
          crossAxisAlignment: direction == MessageDirection.from
              ? CrossAxisAlignment.start // Alinha o conteúdo à esquerda
              : CrossAxisAlignment.end, // Alinha o conteúdo à direita
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color.fromARGB(179, 222, 44, 44), // Cor do nome (transparente)
              ),
            ),
            const SizedBox(height: 4), // Espaço entre o nome e a mensagem
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Color.fromARGB(255, 113, 19, 19), // Cor do texto da mensagem
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MessageDirection {
  from,
  to,
}

class _MessageContainer extends Container {
  _MessageContainer({
    required Widget child,
    required MessageDirection messageDirection,
  }) : super(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: child,
          ),
          decoration: BoxDecoration(
            color: messageDirection == MessageDirection.from
                ? Colors.grey[800] // Cor para mensagens do destinatário
                : Colors.blueAccent, // Cor para mensagens do remetente
            borderRadius: messageDirection == MessageDirection.from
                ? const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          margin: const EdgeInsets.symmetric(
            vertical: 4.0,
            horizontal: 8.0,
          ),
          constraints: const BoxConstraints(
            maxWidth: 280, // Largura máxima da caixa de mensagem
          ),
        );
}