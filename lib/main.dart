import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 

// --- IMPORTS DE TUS PANTALLAS ---
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/create_thread_screen.dart'; 
import 'screens/publish_book_screen.dart'; // Tu archivo original
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const LivroApp());
}

class LivroApp extends StatelessWidget {
  const LivroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NOA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B3D4D)),
        fontFamily: 'serif', 
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) return const MainNavigation();
          return const LoginScreen();
        },
      ),
      routes: {
        '/home': (context) => const MainNavigation(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const SizedBox(), 
    const ProfileScreen(),
  ];

  // --- MENÚ "+" ACTUALIZADO ---
  void _mostrarMenuCreacion() {
    const Color inkBlue = Color(0xFF1B3D4D);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFCF6F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  "¿QUÉ VAS A CREAR?", 
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 14, 
                    letterSpacing: 1.5,
                    color: Colors.black87
                  ),
                ),
              ),
              
              // OPCIÓN 1: HILO (Comunidad)
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline, color: inkBlue),
                title: const Text('Nuevo Hilo', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Comparte un pensamiento rápido', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateThreadScreen()),
                  );
                },
              ),

              const Divider(indent: 70, endIndent: 20, height: 1, color: Colors.black12),

              // OPCIÓN 2: OBRA (Biblioteca con Categorías)
              ListTile(
                leading: const Icon(Icons.menu_book_rounded, color: inkBlue),
                title: const Text("Nueva Obra (Libro/Poesía)", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Contenido clasificado con categoría y portada', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context, 
                    // AQUÍ ESTÁ LA CORRECCIÓN: Usamos PublishBookScreen
                    MaterialPageRoute(builder: (context) => const PublishBookScreen()), 
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);
    const Color matteGold = Color(0xFFC4A77D);

    return Scaffold(
      body: _pages[_selectedIndex],
      
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarMenuCreacion,
        backgroundColor:  const Color(0xFF009688),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        height: 65,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: Icon(
                Icons.home_filled, 
                size: 28,
                color: _selectedIndex == 0 ? inkBlue : const Color(0xFF009688),
              ),
              onPressed: () => setState(() => _selectedIndex = 0),
            ),
            const SizedBox(width: 48), 
            IconButton(
              icon: Icon(
                Icons.person, 
                size: 28,
                color: _selectedIndex == 2 ? inkBlue :  const Color(0xFF009688),
              ),
              onPressed: () => setState(() => _selectedIndex = 2),
            ),
          ],
        ),
      ),
    );
  }
}