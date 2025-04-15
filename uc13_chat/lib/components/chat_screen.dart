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
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:uc13_chat/appconstants.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../services/cripto.dart';

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
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();
  final EncryptionService _encryptionService = EncryptionService();
  bool _encryptionEnabled = false;

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
      _setupEncryption();

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

  void _handleOldMessages(dynamic data) async {
    if (_isMounted) {
      setState(() {
        messages.clear(); // Limpa as mensagens existentes
      });

      if (data is List) {
        try {
          List<Message> decryptedMessages = [];

          for (var m in data) {
            String messageContent = m['content'] ?? '';

            // Only decrypt messages from the other user
            if (m['is_sender'] != 1 && _encryptionEnabled) {
              try {
                messageContent = await _encryptionService.decryptMessage(
                  messageContent,
                  widget.currentUser.id,
                );
              } catch (e) {
                print('Error decrypting old message: $e');
                // Continue with the encrypted message if decryption fails
              }
            }

            decryptedMessages.add(
              Message(
                name: m['is_sender'] == 1 ? 'You' : 'Other',
                text: messageContent,
                to: m['is_sender'] == 1 ? (m['other_user_id'] ?? '') : 'You',
                timestamp:
                    DateTime.tryParse(m['timestamp'] ?? '') ?? DateTime.now(),
              ),
            );
          }

          if (mounted) {
            setState(() {
              messages.addAll(decryptedMessages);
            });
          }
        } catch (e) {
          print('Error processing old messages: $e');
        }
      } else {
        print('Received data is not a List: $data');
      }
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
      final appState = Provider.of<AppState>(context, listen: false);
      appState.setUserStatus(data['userId'], data['status'] == 'online');
    }
  }

  void _handleNewMessage(dynamic data) async {
    if (_isMounted) {
      String messageContent = data['content'];

      // Decrypt the message if it's not from the current user and encryption is enabled
      if (!data['is_sender'] && _encryptionEnabled) {
        try {
          messageContent = await _encryptionService.decryptMessage(
            messageContent,
            widget.currentUser.id,
          );
        } catch (e) {
          print('Error decrypting message: $e');
          // Continue with the encrypted message if decryption fails
        }
      }

      setState(() {
        messages.add(
          Message(
            name: data['is_sender'] ? 'You' : 'Other',
            text: messageContent,
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

  void _sendMessage() async {
    if (_controller.text.isNotEmpty) {
      String messageText = _controller.text;
      String encryptedText = messageText;

      // Encrypt the message if encryption is enabled
      if (_encryptionEnabled) {
        try {
          encryptedText = await _encryptionService.encryptMessage(
            messageText,
            widget.contact.id,
          );
        } catch (e) {
          print('Error encrypting message: $e');
          // Continue with unencrypted message if encryption fails
        }
      }

      final message = Message(
        name: 'You',
        text: messageText, // Store original text for display
        to: widget.contact.id,
        timestamp: DateTime.now(),
      );

      // Send encrypted message to server
      _socketService.emit('message', {
        'content': encryptedText, // Send encrypted text
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

  Future<void> _setupEncryption() async {
    try {
      // Check if we have keys for this contact
      bool hasKeys = await _encryptionService.hasKeysForContact(
        widget.contact.id,
      );

      if (!hasKeys) {
        // Exchange keys with the contact
        bool success = await _encryptionService.exchangeKeys(
          widget.currentUser.id,
          widget.contact.id,
          widget.token,
        );

        if (success) {
          if (mounted) {
            setState(() {
              _encryptionEnabled = true;
            });
          }
          print('Encryption keys exchanged successfully');
        } else {
          print('Failed to exchange encryption keys');
        }
      } else {
        if (mounted) {
          setState(() {
            _encryptionEnabled = true;
          });
        }
        print('Encryption already set up for this contact');
      }
    } catch (e) {
      print('Error setting up encryption: $e');
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
        String fileUrl = responseData['file']['url'];

        // Encrypt the file URL if encryption is enabled
        String encryptedContent = fileUrl;
        if (_encryptionEnabled) {
          try {
            encryptedContent = await _encryptionService.encryptMessage(
              fileUrl,
              widget.contact.id,
            );
          } catch (e) {
            print('Error encrypting file URL: $e');
            // Continue with unencrypted URL if encryption fails
          }
        }

        //Create a new Message with the uploaded file URL
        Message uploadedMessage = Message(
          name: 'You',
          text: fileUrl, // Store original URL for display
          to: widget.contact.id,
          timestamp: DateTime.now(),
          fileUrl: fileUrl,
        );
        setState(() {
          messages.add(uploadedMessage);
        });
        //Send the message to the server
        _socketService.emit('message', {
          'content': encryptedContent, // Send encrypted URL
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
        title: Row(
          children: [
            Text(widget.contact.name),
            SizedBox(width: 8),
            if (_encryptionEnabled)
              Icon(Icons.lock, color: Colors.green, size: 16)
            else
              Icon(Icons.lock_open, color: Colors.red, size: 16),
          ],
        ),
        actions: [
          // Add a button to manually trigger encryption setup if needed
          IconButton(
            icon: Icon(
              _encryptionEnabled
                  ? Icons.security
                  : Icons.security_update_warning,
              color: _encryptionEnabled ? Colors.green : Colors.amber,
            ),
            onPressed: () {
              if (!_encryptionEnabled) {
                _setupEncryption();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Attempting to set up encryption...')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Encryption is already enabled')),
                );
              }
            },
            tooltip:
                _encryptionEnabled ? 'Encryption enabled' : 'Set up encryption',
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de status da conexão
          Container(
            padding: const EdgeInsets.all(8.0),
            color: const Color(0xFF252526), // Fundo secundário
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  connectionStatus,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFd4d4d4), // Texto cinza claro
                  ),
                ),
                SizedBox(width: 8),
                // Show encryption status in the connection bar
                if (_encryptionEnabled)
                  Row(
                    children: [
                      Icon(Icons.lock, color: Colors.green, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Encrypted',
                        style: TextStyle(fontSize: 14, color: Colors.green),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.lock_open, color: Colors.red, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Not Encrypted',
                        style: TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    ],
                  ),
              ],
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
                          // Add a lock icon to the text field to indicate encryption
                          prefixIcon:
                              _encryptionEnabled
                                  ? Icon(
                                    Icons.lock,
                                    color: Colors.green,
                                    size: 16,
                                  )
                                  : Icon(
                                    Icons.lock_open,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                        ),
                        style: const TextStyle(color: Color(0xFFd4d4d4)),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Color(0xFFd4d4d4)),
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
