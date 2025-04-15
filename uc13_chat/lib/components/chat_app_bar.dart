import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'theme_settings.dart';

class Contact {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? lastMessage;

  Contact({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
  });
}

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Contact contact;
  final ImageProvider? avatarImage;
  final Function(ImageProvider) onAvatarError;

  const ChatAppBar({
    Key? key,
    required this.contact,
    required this.avatarImage,
    required this.onAvatarError,
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  return AppBar(
    backgroundColor: const Color(0xFF1F2C34),
    leadingWidth: 100,
    leading: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        CircleAvatar(
          backgroundImage: avatarImage,
          onBackgroundImageError: (exception, stackTrace) {
            onAvatarError(AssetImage('assets/default_avatar.png'));
          },
          radius: 18,
          child: avatarImage == null ? Icon(Icons.person) : null,
        ),
      ],
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(contact.name),
        Consumer<AppState>(
          builder: (context, appState, child) {
            final isOnline = appState.isUserOnline(contact.id);
            return Text(
              isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                color: isOnline ? Colors.green : Colors.grey,
              ),
            );
          },
        ),
      ],
    ),
    actions: [
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {
          switch (value) {
            case 'theme':
              // Navegar para a tela de configurações de tema
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ThemeSettingsScreen()),
              );
              break;
            case 'personalization':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Personalização selecionada')),
              );
              break;
            case 'settings':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Configurações selecionadas')),
              );
              break;
            case 'help':
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Ajuda selecionada')),
              );
              break;
          }
        },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'personalization',
              child: Row(
                children: [
                  Icon(Icons.color_lens, color: Color(0xFF1F2C34)),
                  SizedBox(width: 8),
                  Text('Personalização'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF1F2C34)),
                  SizedBox(width: 8),
                  Text('Configurações'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'help',
              child: Row(
                children: [
                  Icon(Icons.help, color: Color(0xFF1F2C34)),
                  SizedBox(width: 8),
                  Text('Ajuda'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}