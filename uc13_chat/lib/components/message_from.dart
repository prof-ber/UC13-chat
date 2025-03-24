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
        color: const Color(0xFF6a0dad), // Roxo escuro
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16.0),
          topRight: Radius.circular(16.0),
          bottomRight: Radius.circular(16.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontFamily: 'RobotoMono', // Fonte Roboto Mono
              fontWeight: FontWeight.bold, // Versão bold
              fontSize: 12.0,
              color: Colors.white.withOpacity(0.8),
              letterSpacing: -0.5, // Condensa as letras
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'RobotoMono', // Fonte Roboto Mono
              fontSize: 14.0,
              color: Colors.white,
              letterSpacing: -0.5, // Condensa as letras
            ),
          ),
        ],
      ),
    );
  }
}