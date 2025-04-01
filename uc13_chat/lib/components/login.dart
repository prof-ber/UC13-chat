import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final SERVER_IP = "172.17.9.224";

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _senhaController = TextEditingController();

  String _errorMessage = '';

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      String id = _idController.text;
      String senha = _senhaController.text;

      // Prepare the request body
      Map<String, String> body = {'id': id, 'senha': senha};
      try {
        print('Sending request with body: ${jsonEncode(body)}');
        final response = await http.post(
          Uri.parse('http://$SERVER_IP:3000/api/login'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(body),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          // Successful login
          Map<String, dynamic> data = jsonDecode(response.body);
          String userId = data['usuario']['id'];

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Login realizado com sucesso!')),
          );

          // Navega para a tela de chat
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        } else {
          // Login failed
          setState(() {
            _errorMessage = 'ID ou senha incorretos';
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
            children: [
              TextFormField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: 'Nome de usuário',
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
                controller: _senhaController,
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
              SizedBox(height: 16.0),
              TextButton(
                onPressed: () {
                  // Navega para a tela de cadastro
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Text('Não tem uma conta? Cadastre-se'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}
