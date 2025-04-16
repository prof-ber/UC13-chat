import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:uc13_chat/appconstants.dart';

class ProfilePicture extends StatefulWidget {
  final String userId;

  const ProfilePicture({Key? key, required this.userId}) : super(key: key);

  @override
  _ProfilePictureState createState() => _ProfilePictureState();
}

class _ProfilePictureState extends State<ProfilePicture> {
  Uint8List? _imageData;
  final String baseUrl = 'http://${AppConstants.SERVER_IP}:3000';
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _loadProfilePicture();
  }

  Future<void> _loadProfilePicture() async {
    _setDebugInfo(''); // Clear previous debug info
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _setDebugInfo('No token found');
      setState(() {
        _imageData = null;
      });
      return;
    }

    try {
      _setDebugInfo('Attempting to load profile picture...');
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/profile-picture/${widget.userId}'),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(Duration(seconds: 30));

      _setDebugInfo(
        'Response status: ${response.statusCode}, Body length: ${response.bodyBytes.length}',
      );

      if (response.statusCode == 200) {
        if (response.headers['content-type']?.contains('application/json') ==
            true) {
          _setDebugInfo('No profile picture found (JSON response)');
          setState(() {
            _imageData = null;
          });
        } else {
          _setDebugInfo('Profile picture found, setting image data');
          setState(() {
            _imageData = response.bodyBytes;
          });
        }
      } else {
        _setDebugInfo('Error loading profile picture: ${response.statusCode}');
        setState(() {
          _imageData = null;
        });
      }
    } catch (e) {
      _setDebugInfo('Error loading profile picture: $e');
      setState(() {
        _imageData = null;
      });
    }
  }

  Future<void> _updateProfilePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      await _sendProfilePictureToServer(image);
    }
  }

  Future<void> _sendProfilePictureToServer(XFile image) async {
    _setDebugInfo(''); // Clear previous debug info
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      print('Token não encontrado');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa estar logado para atualizar sua foto de perfil.',
          ),
        ),
      );
      return;
    }

    var client = http.Client();
    try {
      final bytes = await image.readAsBytes();
      print('Tamanho da imagem em bytes: ${bytes.length}');
      print('Tipo MIME da imagem: ${image.mimeType}');

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/api/profile-picture'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: 'profile_picture.jpg',
          contentType: MediaType.parse(image.mimeType ?? 'image/jpeg'),
        ),
      );

      print('Enviando requisição...');
      _setDebugInfo('Sending profile picture...');
      var streamedResponse = await client
          .send(request)
          .timeout(Duration(seconds: 30));
      _setDebugInfo('Response received: ${streamedResponse.statusCode}');
      var response = await http.Response.fromStream(streamedResponse);
      _setDebugInfo('Response body: ${response.body}');

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de perfil atualizada com sucesso!'),
          ),
        );
        _loadProfilePicture();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao atualizar a foto de perfil: ${response.statusCode}\nBody: ${response.body}',
            ),
          ),
        );
      }
    } catch (e) {
      print('Erro ao enviar a imagem: $e');
      _setDebugInfo('Error sending profile picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao enviar a foto de perfil: ${e.toString()}'),
        ),
      );
    } finally {
      client.close();
    }
  }

  void _setDebugInfo(String info) {
    print(info); // Print to console
    setState(() {
      _debugInfo += '\n$info'; // Append new info instead of replacing
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _updateProfilePicture,
          child: CircleAvatar(
            radius: 50,
            backgroundImage:
                _imageData != null ? MemoryImage(_imageData!) : null,
            child:
                _imageData == null
                    ? Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          size: 30,
                          color: Colors.white,
                        ),
                        Text(
                          _imageData == null
                              ? 'No Image'
                              : 'Image: ${_imageData!.length} bytes',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    )
                    : null,
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }
}
