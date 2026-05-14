import 'package:flutter/material.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkBlue),
        title: const Text("CONFIGURACIÓN", style: TextStyle(color: inkBlue, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Cuenta", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(leading: const Icon(Icons.lock_outline, color: inkBlue), title: const Text("Privacidad y Seguridad"), onTap: () {}),
          ListTile(leading: const Icon(Icons.notifications_none, color: inkBlue), title: const Text("Notificaciones"), onTap: () {}),
          
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Información", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(leading: const Icon(Icons.description_outlined, color: inkBlue), title: const Text("Términos y Condiciones"), onTap: () {}),
          ListTile(leading: const Icon(Icons.privacy_tip_outlined, color: inkBlue), title: const Text("Políticas de Privacidad"), onTap: () {}),
          ListTile(leading: const Icon(Icons.help_outline, color: inkBlue), title: const Text("Soporte y Ayuda"), onTap: () {}),
          
          const Divider(height: 40),
          
          ListTile(
            leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            onTap: () {
              // Regresa al Login y borra el historial
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
            },
          ),
        ],
      ),
    );
  }
}