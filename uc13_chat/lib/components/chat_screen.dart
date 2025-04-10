import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contacts.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/app_state.dart';
import 'package:provider/provider.dart';
import '../services/user_status_service.dart';


final SERVER_IP = "172.17.9.63";

class ChatScreen extends StatefulWidget {
  final Contact contact;
  final User currentUser;

  const ChatScreen({
    super.key,
    required this.contact,
    required this.currentUser,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ImageProvider? _avatarImage;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late final SocketService _socketService;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  bool _isMounted = false;

  Future<void> _loadUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
  
    if (userId != null) {
      final avatarUrl = 'http://$SERVER_IP:3000/api/profile-picture/$userId';
      setState(() {
        _avatarImage = NetworkImage(avatarUrl);
      });
    } else {
      setState(() {
        _avatarImage = AssetImage('assets/default_avatar.png');
      });
    }
  }

 Future<void> _initializeSocketService() async {
  await _socketService.initSocket();

  _socketService.on('connect', (_) {
    if (_isMounted) {
      setState(() {
        connectionStatus = _socketService.connectionStatus;
      });
    }
    print('Connection established');
  });

  _socketService.on('userStatusChanged', (data) {
    final userId = data['userId'];
    final isOnline = data['isOnline'];
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setUserStatus(userId, isOnline);
    if (mounted) {
      setState(() {
        // Atualiza a UI se necessário
      });
    }
  });
  
    _socketService.on('disconnect', (_) {
      if (_isMounted) {
        setState(() {
          connectionStatus = _socketService.connectionStatus;
        });
      }
      print('Connection Disconnected');
    });
  
    _socketService.on('connect_error', (err) {
      if (_isMounted) {
        setState(() {
          connectionStatus = _socketService.connectionStatus;
        });
      }
      print('Connect Error: $err');
    });
  
    _socketService.on('old_messages', _handleOldMessages);
    _socketService.on('user_status', _handleUserStatus);
    _socketService.on('message', _handleNewMessage);
    _socketService.on('avatar_updated', _handleAvatarUpdated);
  }

  Timer? _statusCheckTimer;


@override
void initState() {
  super.initState();
  
  _isMounted = true;
  WidgetsBinding.instance.addObserver(this);
  
  final appState = Provider.of<AppState>(context, listen: false);
  _socketService = SocketService(appState);
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadUserAvatar();
    _initializeSocketService();
    _startStatusCheckTimer();
    _updateAllUserStatuses();
    
    if (_messageFocusNode.hasFocus) {
      _messageFocusNode.unfocus();
    }
    _messageFocusNode.requestFocus();
  });

  _messageFocusNode.addListener(() {
    if (_messageFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(context, alignment: 1.0);
      });
    }
  });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_messageFocusNode.hasFocus) {
        _messageFocusNode.unfocus();
      }
      _messageFocusNode.requestFocus();
    });
  }

    void _startStatusCheckTimer() {
      _statusCheckTimer = Timer.periodic(Duration(seconds: 30), (timer) {
        if (_isMounted) {
          _updateAllUserStatuses();
        }
      });
    }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.removeListener(() {});
    _messageFocusNode.dispose();
    _controller.dispose();
    
    _socketService.disconnect();
    
    messages.clear();
    super.dispose();
  }

  void _handleOldMessages(dynamic data) {
  if (_isMounted) {
    setState(() {
      messages.clear(); // Limpa as mensagens existentes
      if (data is List) {
        try {
          messages.addAll(data.map((m) {
            return Message(
              name: m['is_sender'] == 1 ? 'You' : 'Other',
              text: m['content'] ?? '',
              to: m['is_sender'] == 1 ? (m['other_user_id'] ?? '') : 'You',
              timestamp: DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
            );
          }).toList());
        } catch (e) {
          print('Error processing old messages: $e');
        }
      } else {
        print('Received data is not a List: $data');
      }
    });
  }
}

void _updateAllUserStatuses() async {
  final appState = Provider.of<AppState>(context, listen: false);
  List<String> userIds = [widget.contact.id];
  Map<String, bool> statuses = await UserStatusService.getBulkUserStatus(userIds);
  statuses.forEach((userId, isOnline) {
    appState.setUserStatus(userId, isOnline);
  });
  if (mounted) {
    setState(() {
      // Atualiza a UI se necessário
    });
  }
}

void _handleUserStatus(dynamic data) {
  if (_isMounted && data['userId'] == widget.contact.id) {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.setUserStatus(data['userId'], data['status'] == 'online');
  }
}

void _handleNewMessage(dynamic data) {
  if (_isMounted) {
    setState(() {
      messages.add(Message(
        name: data['is_sender'] ? 'You' : 'Other',
        text: data['content'],
        to: data['is_sender'] ? data['other_user_id'] : 'You',
        timestamp: DateTime.parse(data['timestamp']),
      ));
    });
    _controller.clear();

    // Mantém o foco no campo após enviar
    _messageFocusNode.requestFocus();
  }
}

void _handleAvatarUpdated(dynamic data) {
  if (_isMounted) {
    _loadUserAvatar();
  }
}

  @override
  void didChangeMetrics() {
    if (!_isMounted) return;  // Adicione esta linha
    final bottomInset = WidgetsBinding.instance.window.viewInsets.bottom;
    if (bottomInset > 0) {
      _messageFocusNode.requestFocus();
    }
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = Message(
        name: 'You',
        text: _controller.text,
        to: widget.contact.id,
        timestamp: DateTime.now(),
      );
      _socketService.emit('message', {
        'content': message.text,
        'to': message.to,
        'timestamp': message.timestamp.toIso8601String(),
      });
      setState(() {
        messages.add(message);
      });
      _controller.clear();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageFocusNode.requestFocus();
      });
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
            child: _avatarImage == null ? Icon(Icons.person) : null,
          ),
        ],
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.contact.name),
          Consumer<AppState>(
            builder: (context, appState, child) {
              final isOnline = appState.isUserOnline(widget.contact.id);
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
    ),
      body: Column(
        children: [
          // Barra de status da conexão
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF252526), // Fundo secundário
            child: Text(
              connectionStatus,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFd4d4d4), // Texto cinza claro
              ),
            ),
          ),

          // Lista de mensagens
          Expanded(
            child: Container(
              color: const Color(0xFF1e1e1e), // Fundo principal
              child: ListMessageView(messages: messages),
            ),
          ),

          // Campo de texto e botões
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color.fromARGB(255, 37, 38, 37),
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
                      onPressed: _sendMessage,  // Adicione este botão
                      child: const Text('Send'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _socketService.reconnect();
                        setState(() {
                          connectionStatus = _socketService.connectionStatus;
                        });
                      },
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