import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ImageProvider? _avatarImage;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

bool _isMounted = false;

@override
void initState() {
  super.initState();
  _avatarImage = NetworkImage('https://example.com/avatar.jpg');
  _isMounted = true;
  WidgetsBinding.instance.addObserver(this);
  _connectToSocketIO();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
      }
      _messageFocusNode.requestFocus();
    });
  }

  void _connectToSocketIO() async {
  // Obter o token de autenticação
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null) {
    print('Token não encontrado. O usuário precisa fazer login.');
    // Aqui você pode adicionar lógica para redirecionar o usuário para a tela de login
    return;
  }

  socket = IO.io('http://localhost:3000', <String, dynamic>{
    'transports': ['websocket'],
    'autoConnect': false,
    'auth': {'token': token},
  });

  socket.connect();

 socket.onConnect((_) {
    if (_isMounted) {
      setState(() {
        connectionStatus = 'Connected';
      });
    }
    print('Connection established');
    socket.emit('authenticate', token);
  });

  socket.onDisconnect((_) {
    if (_isMounted) {
      setState(() {
        connectionStatus = 'Disconnected';
      });
    }
    print('Connection Disconnected');
  });

  socket.onConnectError((err) {
    if (_isMounted) {
      setState(() {
        connectionStatus = 'Connection Error: $err';
      });
    }
    print('Connect Error: $err');
  });

 socket.on('old_messages', (data) {
    if (_isMounted) {
      setState(() {
        messages.clear(); // Limpa as mensagens existentes
        messages.addAll((data as List).map((m) {
          return Message(
            name: m['is_sender'] ? 'You' : 'Other',
            text: m['content'],
            to: m['is_sender'] ? m['other_user_id'] : 'You',
            timestamp: DateTime.parse(m['timestamp']),
          );
        }));
      });
    }
  });

  socket.on('message', (data) {
    if (_isMounted) {
      setState(() {
        messages.add(Message(
          name: data['is_sender'] ? 'You' : 'Other',
          text: data['content'],
          to: data['is_sender'] ? data['other_user_id'] : 'You',
          timestamp: DateTime.parse(data['timestamp']),
        ));
      });
    }
  });
  socket.on('authentication_error', (error) {
    print('Erro de autenticação: $error');
    // Aqui você pode adicionar lógica para lidar com erros de autenticação
  });
}
 void _sendMessage() {
   if (!_isMounted) return;
   if (_controller.text.isNotEmpty) {
     if (_controller.text.length > 50000) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(
           content: Text('A mensagem excede o limite de 50.000 caracteres'),
           duration: Duration(seconds: 2),
         ),
       );
       return;
     }
 
     final message = {
       'content': _controller.text,
       'to': 'All', // Ou o ID do destinatário específico
     };
     socket.emit('message', message);
 
     _controller.clear();
     _messageFocusNode.requestFocus();
   }
 }

@override
void dispose() {
  _isMounted = false;
    WidgetsBinding.instance.removeObserver(this); // Remover o observer
    _messageFocusNode.dispose();
    _controller.dispose();
    
    // Desconectar e limpar o socket
    socket.disconnect();
    socket.close();
    socket.destroy();
    
    // Limpar a lista de mensagens
    messages.clear();
    
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_isMounted) return;  // Adicione esta linha
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      _messageFocusNode.requestFocus();
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF1e1e1e),
    appBar: AppBar(
      backgroundColor: const Color(0xFF1F2C34),
      leadingWidth: 100,
      leading: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CircleAvatar(
            backgroundImage: _avatarImage,
            onBackgroundImageError: (exception, stackTrace) {
              if (mounted) {
                setState(() {
                  _avatarImage = AssetImage('assets/default_avatar.png');
                });
              }
            },
            radius: 18,
          ),
        ],
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nome do Contato',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            connectionStatus == 'Connected' ? 'online' : 'offline',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
  IconButton(
    icon: const Icon(Icons.call, color: Colors.white), // Ícone de telefone
    onPressed: () {
      // Adicione aqui a lógica para iniciar uma chamada
    },
  ),
  IconButton(
    icon: const Icon(Icons.search, color: Colors.white),
    onPressed: () {
      // Ação de busca mantida
    },
  ),
  PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert, color: Colors.white),
    onSelected: (value) {
      if (value == 'Sair') {
        Navigator.of(context).pop();
      }
    },
    itemBuilder: (BuildContext context) {
      return {'Opções', 'Sair'}.map((String choice) {
        return PopupMenuItem<String>(
          value: choice,
          child: Text(choice),
        );
      }).toList();
    },
  ),
],
    ),
    body: Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF1e1e1e),
            child: ListMessageView(messages: messages),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8.0),
          color: const Color(0xFF252526),
          child: Column(
            children: [
              TextField(
                focusNode: _messageFocusNode,
                controller: _controller,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: 'Enter message',
                  labelStyle: TextStyle(color: Color(0xFFd4d4d4)),
                ),
                style: const TextStyle(color: Color(0xFFd4d4d4)),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: connectionStatus == 'Connected' 
                        ? _sendMessage 
                        : null,
                    child: const Text('Send Message'),
                  ),
                  ElevatedButton(
                    onPressed: _connectToSocketIO,
                    child: const Text('Reconnect'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
