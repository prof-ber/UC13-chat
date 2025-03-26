import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'chat_screen.dart';
import 'signup.dart';
import 'profile_picture.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoggedIn = false;
  String? userId;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('userId');
    if (storedUserId != null) {
      setState(() {
        isLoggedIn = true;
        userId = storedUserId;
      });
    }
  }

  void setLoggedIn(bool value, String? newUserId) {
    setState(() {
      isLoggedIn = value;
      userId = newUserId;
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('token');
    setLoggedIn(false, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoggedIn && userId != null) ProfilePicture(userId: userId!),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (isLoggedIn) {
                  _logout();
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
            const SizedBox(height: 20),
            if (isLoggedIn)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatScreen()),
                  );
                },
                child: const Text('Entrar no Chat'),
              ),
            const SizedBox(height: 20),
            if (!isLoggedIn)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CadastroScreen(), // Removed const
                    ),
                  );
                },
                child: const Text('Cadastrar'),
              ),
          ],
        ),
      ),
    );
  }
}
