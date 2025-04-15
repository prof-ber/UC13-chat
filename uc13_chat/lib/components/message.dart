import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'text_styles.dart';

enum MessageDirection { from, to }

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.name,
    required this.message,
    required this.timestamp,
    required this.direction,
  });

  final String name;
  final String message;
  final DateTime timestamp;
  final MessageDirection direction;

  // Mantemos apenas a sombra como estilo estático
  static const _boxShadow = BoxShadow(
    color: Colors.black38,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  BorderRadius _getBorderRadius() {
    return direction == MessageDirection.from
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          );
  }

  @override
  Widget build(BuildContext context) {
    // Obtemos o tema atual
    final appTheme = Provider.of<AppTheme>(context);
    
    // Definimos as cores com base na direção da mensagem e no tema
    final messageColor = direction == MessageDirection.from 
        ? appTheme.fromMessageColor  // Mensagens recebidas
        : appTheme.toMessageColor;   // Mensagens enviadas
    
    // Definimos as cores de texto com base na direção da mensagem
    final textColor = direction == MessageDirection.from 
        ? appTheme.fromTextColor     // Cor do texto para mensagens recebidas
        : appTheme.toTextColor;      // Cor do texto para mensagens enviadas
    
    return Align(
      alignment: direction == MessageDirection.from 
          ? Alignment.centerLeft 
          : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: messageColor,
          borderRadius: _getBorderRadius(),
          boxShadow: const [_boxShadow],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
          minWidth: 0, // Permite que a largura seja tão pequena quanto necessário
        ),
        child: IntrinsicWidth( // Adiciona IntrinsicWidth para ajustar ao conteúdo
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nome do remetente
              Text(
                name,
                style: TextStyles.getMessageTextStyle(
                  appTheme.fontFamily,
                  textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Conteúdo da mensagem
              Text(
                message,
                style: TextStyles.getMessageTextStyle(
                  appTheme.fontFamily,
                  textColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              // Timestamp
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(timestamp),
                  style: TextStyles.getMessageTextStyle(
                    appTheme.fontFamily,
                    textColor.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}