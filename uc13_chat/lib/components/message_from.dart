import 'package:flutter/material.dart';

class MessageFrom extends StatelessWidget {
  const MessageFrom({
    Key? key,
    required this.name,
    required this.message,
  }) : super(key: key);

  final String name;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey[300], // Cor de fundo para mensagens do destinatário
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha o conteúdo à esquerda
        children: [
          Text(
            name,
            style: TextStyle(
              color: Colors.black.withOpacity(0.8),
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 4.0), // Espaço entre o nome e a mensagem
          Text(
            message,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14.0,
            ),
          ),
        ],
      ),
    );
  }
}