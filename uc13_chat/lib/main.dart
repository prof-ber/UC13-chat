import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'components/list_message.dart';
import 'entities/message_entity.dart';
import 'components/signup.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoggedIn = false;

  void setLoggedIn(bool value) {
    setState(() {
      isLoggedIn = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                if (isLoggedIn) {
                  // Implement logout logic here
                  setLoggedIn(false);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => LoginScreen(setLoggedIn: setLoggedIn),
                    ),
                  );
                }
              },
              child: Text(isLoggedIn ? 'Logout' : 'Login'),
            ),
            SizedBox(height: 20),
            if (isLoggedIn)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => ChatScreen()),
                  );
                },
                child: Text('Entrar no Chat'),
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CadastroScreen()),
                );
              },
              child: Text('Cadastrar'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final Function(bool) setLoggedIn;

  LoginScreen({required this.setLoggedIn});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class LoginScreenState extends StatefulWidget {
  final Function(bool) setLoggedIn;

  LoginScreenState({required this.setLoggedIn});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      String name = _nameController.text;
      String password = _passwordController.text;

      // Prepare the request body
      Map<String, String> body = {'nome': name, 'senha': password};
      try {
        final response = await http.post(
          Uri.parse('http://localhost:3000/api/login'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          // Successful login
          Map<String, dynamic> data = jsonDecode(response.body);

          // TODO: Store the user data securely (e.g., using flutter_secure_storage)
          // String userId = data['usuario']['id'];
          // String token = data['token'];
          // String sessionId = data['sessionId'];

          // For now, we'll just print them to demonstrate they're being received
          print('Logged in user name: ${data['usuario']['nome']}');
          print('Received token: ${data['token']}');
          print('Session ID: ${data['sessionId']}');

          widget.setLoggedIn(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login realizado com sucesso!')),
          );

          Navigator.pop(context); // Go back to HomeScreen
        } else {
          // Login failed
          Map<String, dynamic> data = jsonDecode(response.body);
          setState(() {
            _errorMessage = data['error'] ?? 'Erro ao fazer login';
          });
        }
      } catch (e) {
        print('Error during login: $e');
        setState(() {
          _errorMessage = 'Erro de conexão. Tente novamente mais tarde.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha';
                  }
                  if (value.length < 6) {
                    return 'Senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16.0),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: TextStyle(color: Colors.red)),
              SizedBox(height: 16.0),
              ElevatedButton(onPressed: _login, child: Text('Login')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  final ObservableList<Message> messages = ObservableList<Message>();

  @override
  void initState() {
    super.initState();
    _connectToSocketIO();
  }

  void _connectToSocketIO() {
    socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      setState(() {
        connectionStatus = 'Connected';
      });
      print('Connection established');
    });

    socket.onDisconnect((_) {
      setState(() {
        connectionStatus = 'Disconnected';
      });
      print('Connection Disconnected');
    });

    socket.onConnectError((err) {
      setState(() {
        connectionStatus = 'Connection Error: $err';
      });
      print('Connect Error: $err');
    });

    socket.on('message', (data) {
      setState(() {
        messages.add(Message(name: 'Server', text: data.toString()));
      });
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      final message = Message(name: 'You', text: _controller.text);
      socket.emit('message', message.text);
      setState(() {
        messages.add(message);
      });
      _controller.clear();
    }
  }

  @override
  void dispose() {
    socket.disconnect();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chat')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Text(
              connectionStatus,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: ListMessageView(messages: messages)),
          Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey[200],
            child: Column(
              children: [
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Enter message',
                  ),
                ),
                const SizedBox(height: 10),
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
