import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Colores corporativos NOA
  final Color navyNoa = const Color(0xFF111827);
  final Color tealNoa = const Color(0xFF009688);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  Future<void> _registrar() async {
    if (_nombreController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _mostrarSnackBar("Por favor, llena todos los campos.");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // 1. Crear el usuario en Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Crear el perfil extendido en Firestore
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .set({
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'bio': 'Escritor en NOA',
        'ubicacion': 'Zaruma, Ecuador',
        'fotoPerfilUrl': '',
        'obras': 0,
        'seguidores': 0,
        'siguiendo': 0,
        'noaCoins': 0,        // Inicializamos su billetera
        'favoritosList': [],  // Lista para la pestaña de favoritos
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error al registrar";
      if (e.code == 'weak-password') mensaje = "La contraseña es muy débil.";
      if (e.code == 'email-already-in-use') mensaje = "Este correo ya está registrado.";
      _mostrarSnackBar(mensaje);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarSnackBar(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: Colors.redAccent)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: navyNoa), // Botón de "atrás" elegante
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 35.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // LOGO PEQUEÑO PARA DAR ESPACIO A LOS CAMPOS
                Image.asset(
                  'assets/images/logoNOA.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),

                Text(
                  "Crear cuenta",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: navyNoa,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Únete a la nueva era de la literatura.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: navyNoa.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 40),

                // CAMPO NOMBRE
                _buildCustomTextField(
                  controller: _nombreController,
                  label: "Nombre completo",
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                // CAMPO EMAIL
                _buildCustomTextField(
                  controller: _emailController,
                  label: "Correo electrónico",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // CAMPO CONTRASEÑA
                _buildCustomTextField(
                  controller: _passwordController,
                  label: "Tu contraseña",
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 40),

                // BOTÓN DE REGISTRO
                _isLoading
                    ? CircularProgressIndicator(color: tealNoa)
                    : ElevatedButton(
                        onPressed: _registrar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: navyNoa,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 60),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "COMENZAR MI AVENTURA",
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 14, 
                            letterSpacing: 1.2
                          ),
                        ),
                      ),

                const SizedBox(height: 30),

                // VOLVER AL LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "¿Ya eres parte de NOA?",
                      style: TextStyle(color: navyNoa.withOpacity(0.7)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Inicia sesión",
                        style: TextStyle(
                          color: tealNoa, 
                          fontWeight: FontWeight.w900, 
                          fontSize: 15
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // WIDGET REUTILIZABLE (IGUAL AL DEL LOGIN)
  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12, width: 1),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        keyboardType: keyboardType,
        style: TextStyle(color: navyNoa, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: navyNoa.withOpacity(0.5)),
          prefixIcon: Icon(icon, color: tealNoa),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: navyNoa.withOpacity(0.4),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }
}