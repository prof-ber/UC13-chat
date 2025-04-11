import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:mobx/mobx.dart';
import 'list_message.dart';
import '../entities/message_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'contacts.dart';
import 'package:uc13_chat/appconstants.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

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
  late IO.Socket socket;
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
        _avatarImage = NetworkImage(avatarUrl);
      });
    } else {
      setState(() {
        _avatarImage = AssetImage('assets/default_avatar.png');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addObserver(this);
    _loadUserAvatar();
    _connectToSocketIO();

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

  void _connectToSocketIO() async {
    // Obter o token de autenticação
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('Token não encontrado. O usuário precisa fazer login.');
      // Aqui você pode adicionar lógica para redirecionar o usuário para a tela de login
      return;
    }

    socket = IO.io('http://${AppConstants.SERVER_IP}:3000', <String, dynamic>{
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
          if (data is List) {
            try {
              messages.addAll(
                data.map((m) {
                  return Message(
                    name: m['is_sender'] == 1 ? 'You' : 'Other',
                    text: m['content'] ?? '',
                    to:
                        m['is_sender'] == 1
                            ? (m['other_user_id'] ?? '')
                            : 'You',
                    timestamp:
                        DateTime.tryParse(m['timestamp'] ?? '') ??
                        DateTime.now(),
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
    });

    socket.on('message', (data) {
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
    });

    socket.on('avatar_updated', (data) {
      if (_isMounted) {
        _loadUserAvatar();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    WidgetsBinding.instance.removeObserver(this);
    _messageFocusNode.removeListener(() {}); // Adicione esta linha
    _messageFocusNode.dispose();
    _controller.dispose();

    socket.disconnect();
    socket.close();
    socket.destroy();

    messages.clear();

    super.dispose();
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
      socket.emit('message', {
        'content': message.text,
        'to': message.to,
        'timestamp': message.timestamp.toIso8601String(),
      });
      setState(() {
        messages.add(message);
      });
      _controller.clear();

      // Adicione estas linhas para garantir que o foco retorne ao campo de entrada
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
        socket.emit('message', {
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
        title: Text(widget.contact.name),
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
                Row(
                  children: [
                    Expanded(
                      child: TextField(
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
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Color(0xFFd4d4d4)),
                      //TODO implementar a função de envio de arquivos
                      onPressed: () => _uploadFile(widget.token),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Color(0xFFd4d4d4)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
                //Espaço entre as rows
                SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed:
                          connectionStatus == 'Connected' ? _sendMessage : null,
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
