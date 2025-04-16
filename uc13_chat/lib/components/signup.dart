import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uc13_chat/appconstants.dart';

class CadastroScreen extends StatefulWidget {
  @override
  _CadastroScreenState createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _senhaController = TextEditingController();
  String? _userId;

  Future<void> _cadastrar() async {
    if (_formKey.currentState!.validate()) {
      String nome = _nomeController.text;
      String senha = _senhaController.text;

      // Prepare the request body
      Map<String, String> body = {'nome': nome, 'senha': senha};

      try {
        print('Sending request with body: ${jsonEncode(body)}');
        final response = await http.post(
          Uri.parse('http://${AppConstants.SERVER_IP}:3000/api/cadastro'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(body),
        );

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 201) {
          // Successful registration
          Map<String, dynamic> data = jsonDecode(response.body);
          String userId = data['usuario']['id'];

          setState(() {
            _userId = userId;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cadastro realizado com sucesso!')),
          );

          // You might want to navigate to another screen here
        } else {
          // Registration failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro no cadastro. Tente novamente.')),
          );
        }
      } catch (e) {
        print('Error during registration: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão. Tente novamente mais tarde.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cadastro')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Nome'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira seu nome';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _senhaController,
                decoration: InputDecoration(labelText: 'Senha'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, insira sua senha';
                  }
                  if (value.length < 6) {
                    return 'A senha deve ter pelo menos 6 caracteres';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _cadastrar, child: Text('Cadastrar')),
              if (_userId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    'ID Gerado: $_userId',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _senhaController.dispose();
    super.dispose();
  }
}
