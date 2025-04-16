import 'package:flutter/material.dart';
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import 'chat_app_bar.dart' as app_bar;
import '../entities/message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contacts.dart';
import 'dart:async';
import '../services/socket_service.dart';
import '../services/app_state.dart';
import 'package:provider/provider.dart';
import '../services/user_status_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uc13_chat/appconstants.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'app_theme.dart';

app_bar.Contact convertToAppBarContact(Contact contact) {
  return app_bar.Contact(
    id: contact.id,
    name: contact.name,
    avatarUrl: contact.avatarUrl,
  );
}

class ChatScreen extends StatefulWidget {
  final Contact contact;
  final User currentUser;
  final String token;

  const ChatScreen({
    super.key,
    required this.contact,
    required this.currentUser,
    required this.token,
  });

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  ImageProvider? _avatarImage;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late final SocketService _socketService;
  late final AppState _appState;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  bool _isMounted = false;

  Future<void> _loadUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');

    
    if (userId != null) {
      final avatarUrl =
          'http://${AppConstants.SERVER_IP}:3000/api/profile-picture/$userId';
      setState(() {
        // Use NetworkImage diretamente, sem concatenar com outras URLs
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
     // Verifique se o widget ainda está montado antes de acessar o context
     if (!_isMounted) return;
     
     try {
       final userId = data['userId'];
       final isOnline = data['isOnline'];
       
       // Armazene a referência ao AppState no initState para evitar acessar o context aqui
       final appState = Provider.of<AppState>(context, listen: false);
       appState.setUserStatus(userId, isOnline);
       
       if (mounted) {
         setState(() {
           // Atualiza a UI se necessário
         });
       }
     } catch (e) {
       print('Error handling userStatusChanged: $e');
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
            messages.addAll(
              data.map((m) {
                return Message(
                  name: m['is_sender'] == 1 ? 'You' : 'Other',
                  text: m['content'] ?? '',
                  to: m['is_sender'] == 1 ? (m['other_user_id'] ?? '') : 'You',
                  timestamp:
                      DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
                );
              }).toList(),
            );
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
    Map<String, bool> statuses = await UserStatusService.getBulkUserStatus(
      userIds,
    );
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
    // Use _appState em vez de acessar o context
    _appState.setUserStatus(data['userId'], data['status'] == 'online');
  }
}

  void _handleNewMessage(dynamic data) {
    if (_isMounted) {
      setState(() {
        messages.add(
          Message(
            name: data['is_sender'] ? 'You' : 'Other',
            text: data['content'],
            to: data['is_sender'] ? data['other_user_id'] : 'You',
            timestamp: DateTime.parse(data['timestamp']),
          ),
        );
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
    if (!_isMounted) return; // Adicione esta linha
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

  Future<void> _uploadFile(String token) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4'],
      );
      if (result == null) return;

      var uri = Uri.parse('http://${AppConstants.SERVER_IP}:3000/api/upload');
      var request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $token';

      String fileName = result.files.single.name;

      if (kIsWeb) {
        var bytes = result.files.single.bytes;
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes!, filename: fileName),
        );
      } else {
        var file = File(result.files.single.path!);
        var stream = http.ByteStream(file.openRead());
        var length = await file.length();
        request.files.add(
          http.MultipartFile('file', stream, length, filename: fileName),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print('File uploaded successfully');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('File uploaded successfully')));
        var responseData = json.decode(response.body);
        //Create a new Message with the uploaded file URL
        Message uploadedMessage = Message(
          name: 'You',
          text: responseData['file']['url'],
          to: widget.contact.id,
          timestamp: DateTime.now(),
          fileUrl: responseData['file']['url'],
        );
        setState(() {
          messages.add(uploadedMessage);
        });
        //Send the message to the server
        _socketService.emit('message', {
          'content': uploadedMessage.text,
          'to': uploadedMessage.to,
          'timestamp': uploadedMessage.timestamp.toIso8601String(),
        });
      } else {
        print('Failed to upload file. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        var errorMessage = 'Failed to upload file';
        try {
          var responseData = json.decode(response.body);
          errorMessage = responseData['error'] ?? errorMessage;
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = Provider.of<AppTheme>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: app_bar.ChatAppBar(
        contact: convertToAppBarContact(widget.contact),
        avatarImage: _avatarImage,
        onAvatarError: (newImage) {
          if (mounted) {
            setState(() {
              _avatarImage = newImage;
            });
          }
        },
      ),
      body: Column(
        children: [
          // Barra de status da conexão
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).colorScheme.surface,
            child: Text(
              connectionStatus,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: appTheme.fontFamily,
              ),
            ),
          ),
  
          // Lista de mensagens
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.background,
              child: ListMessageView(messages: messages),
            ),
          ),
  
          // Campo de texto e botões
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                TextField(
                  focusNode: _messageFocusNode,
                  controller: _controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Digite uma mensagem',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: appTheme.fontFamily,
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: appTheme.fontFamily,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                  textInputAction: TextInputAction.send,
                ),IconButton(
                      icon: Icon(Icons.attach_file, color: Color(0xFFd4d4d4)),
                      //TODO implementar a função de envio de arquivos
                      onPressed: () => _uploadFile(widget.token),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Color(0xFFd4d4d4)),
                      onPressed: _sendMessage,
                    ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _sendMessage,
                      style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontFamily: appTheme.fontFamily),
                      ),
                      child: const Text('Enviar'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        await _socketService.reconnect();
                        setState(() {
                          connectionStatus = _socketService.connectionStatus;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontFamily: appTheme.fontFamily),
                      ),
                      child: const Text('Reconectar'),
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
