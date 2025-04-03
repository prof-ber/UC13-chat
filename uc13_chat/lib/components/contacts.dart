import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chat_screen.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';

final SERVER_IP = '172.17.9.224';

class User {
  final String id;
  String name; // Changed from final to allow updates
  String? avatarUrl;
  String? lastMessage;

  User({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.lastMessage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['username'] ?? json['name'],
      avatarUrl: json['avatarUrl'],
      lastMessage: json['lastMessage'],
    );
  }

  void updateName(String newName) {
    name = newName;
  }
}

class Contact extends User {
  Contact({
    required String id,
    required String name,
    String? avatarUrl,
    String? lastMessage,
  }) : super(
         id: id,
         name: name,
         avatarUrl: avatarUrl,
         lastMessage: lastMessage,
       );

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['username'],
      avatarUrl: json['avatarUrl'],
      lastMessage: json['lastMessage'],
    );
  }
}

class ContactsScreen extends StatefulWidget {
  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  User? currentUser;
  List<Contact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _fetchContacts();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null) {
        try {
          // Fetch the user's data from the server
          final response = await http.get(
            Uri.parse('http://$SERVER_IP:3000/api/users/${user.id}'),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          );

          if (response.statusCode == 200) {
            final userData = json.decode(response.body);
            setState(() {
              currentUser = User(
                id: user.id,
                name: userData['username'] ?? user.name,
                avatarUrl: userData['avatarUrl'] ?? user.avatarUrl,
              );
            });

            // Update SharedPreferences with the latest user data
            await prefs.setString('userName', currentUser!.name);
            if (currentUser!.avatarUrl != null) {
              await prefs.setString('userAvatar', currentUser!.avatarUrl!);
            }
          } else {
            print("Failed to fetch user data: ${response.statusCode}");
          }

          // Fetch profile picture
          final pictureResponse = await http.get(
            Uri.parse('http://$SERVER_IP:3000/api/profile-picture/${user.id}'),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          );
          if (pictureResponse.statusCode == 200) {
            setState(() {
              currentUser!.avatarUrl =
                  'http://$SERVER_IP:3000/api/profile-picture/${user.id}';
            });
          }
        } catch (e) {
          print("Error fetching user data: $e");
        }
      }

      print("Current user name: ${currentUser?.name}");
      print("Current user ID: ${currentUser?.id}");
    }
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final headers = await AuthService.getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://$SERVER_IP:3000/api/contacts'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> contactsJson = json.decode(response.body);
        if (mounted) {
          setState(() {
            _contacts =
                contactsJson.map((json) => Contact.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        await _handleUnauthorized();
      } else {
        throw Exception('Failed to load contacts: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (e is Exception &&
            e.toString().contains('No authentication token found')) {
          await _handleUnauthorized();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching contacts: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleUnauthorized() async {
    bool refreshed = await AuthService.refreshToken();
    if (refreshed) {
      await _fetchContacts();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Session expired. Please log in again.')),
      );
      await AuthService.logout();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _startConversation(Contact contact) {
    if (currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  ChatScreen(contact: contact, currentUser: currentUser!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to start a conversation')),
      );
    }
  }

  void _copyUserId() {
    if (currentUser != null) {
      Clipboard.setData(ClipboardData(text: currentUser!.id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User ID copied to clipboard')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No user ID available')));
    }
  }

  Future<void> _addContact() async {
    final TextEditingController _controller = TextEditingController();
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Contact'),
          content: TextField(
            controller: _controller,
            decoration: InputDecoration(hintText: "Enter user ID"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final headers = await AuthService.getAuthHeaders();
                  final response = await http.post(
                    Uri.parse('http://$SERVER_IP:3000/api/contacts'),
                    headers: headers,
                    body: json.encode({'contactId': _controller.text}),
                  );

                  if (response.statusCode == 201) {
                    // Fetch the user's name after adding the contact
                    final userResponse = await http.get(
                      Uri.parse(
                        'http://$SERVER_IP:3000/api/users/${_controller.text}',
                      ),
                      headers: headers,
                    );

                    if (userResponse.statusCode == 200) {
                      final userData = json.decode(userResponse.body);
                      final userName = userData['username'];
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Contact "$userName" added successfully',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Contact added successfully')),
                      );
                    }
                    _fetchContacts();
                  } else if (response.statusCode == 401) {
                    await _handleUnauthorized();
                  } else {
                    throw Exception('Failed to add contact: ${response.body}');
                  }
                } catch (e) {
                  if (e is Exception &&
                      e.toString().contains('No authentication token found')) {
                    await _handleUnauthorized();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding contact: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      print('Logging out...');
      await AuthService.logout();
      print('Logout successful, navigating to login screen');

      // Navigate back to the login screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder:
              (context) => LoginScreen(
                setLoggedIn: (bool loggedIn, String? userId) {
                  if (loggedIn) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => ContactsScreen()),
                    );
                  }
                },
              ),
        ),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contacts', style: TextStyle(color: Colors.black)),
        iconTheme: IconThemeData(color: Colors.black),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // User Avatar
          CircleAvatar(
            backgroundColor: Colors.black,
            child:
                currentUser?.avatarUrl != null
                    ? ClipOval(
                      child: Image.network(
                        currentUser!.avatarUrl!,
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Text(
                            currentUser!.name[0].toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                            ),
                          );
                        },
                      ),
                    )
                    : Text(
                      currentUser?.name.isNotEmpty == true
                          ? currentUser!.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
          ),
          SizedBox(width: 10),
          // User Name
          Text(currentUser?.name ?? '', style: TextStyle(color: Colors.black)),
          SizedBox(width: 10),
          // PopupMenuButton
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.black),
            onSelected: (String result) {
              switch (result) {
                case 'copy_user_id':
                  _copyUserId();
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder:
                (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'copy_user_id',
                    child: Text('Copy User ID'),
                  ),
                  PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _contacts.isEmpty
              ? Center(child: Text('No contacts available'))
              : RefreshIndicator(
                onRefresh: _fetchContacts,
                child: ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    Contact contact = _contacts[index];
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => _startConversation(contact),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage:
                                contact.avatarUrl != null
                                    ? NetworkImage(
                                      'http://$SERVER_IP:3000/api/profile-picture/${contact.id}',
                                    )
                                    : null,
                            child:
                                contact.avatarUrl == null
                                    ? Text(contact.name[0].toUpperCase())
                                    : null,
                          ),
                          title: Text(contact.name),
                          subtitle: Text(
                            contact.lastMessage ?? 'No messages yet',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        child: Icon(Icons.add),
        tooltip: 'Add Contact',
      ),
    );
  }
}
