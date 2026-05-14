import 'dart:typed_data'; 
import 'dart:convert'; // ¡NUEVO! Para convertir la foto en texto (Base64)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nombreController = TextEditingController();
  final _bioController = TextEditingController();
  final _ubicacionController = TextEditingController();
  
  bool _isLoading = true; 
  bool _isSaving = false; 

  Uint8List? _imagenBytes; 
  String _fotoBase64Actual = ''; // Aquí guardaremos el texto largo de la foto

  @override
  void initState() {
    super.initState();
    _cargarDatosActuales();
  }

  // 1. CARGAR DATOS Y FOTO ACTUAL
  Future<void> _cargarDatosActuales() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _nombreController.text = data['nombre'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _ubicacionController.text = data['ubicacion'] ?? '';
          _fotoBase64Actual = data['fotoBase64'] ?? ''; // Cargamos la foto en formato texto
          _isLoading = false;
        });
      }
    }
  }

  // 2. FUNCIÓN PARA ABRIR LA GALERÍA
  Future<void> _elegirFoto() async {
    final picker = ImagePicker();
    // Comprimimos mucho la foto para que el texto Base64 no sea tan gigante
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 50, // Lo bajamos a 50 para ahorrar espacio en la base de datos
      maxWidth: 400,
      maxHeight: 400,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imagenBytes = bytes; 
      });
    }
  }

  // 3. GUARDAR TODO (MODO HACKER: FOTO COMO TEXTO)
  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String fotoParaGuardar = _fotoBase64Actual;

        // Si elegiste una foto nueva, la transformamos en texto Base64
        if (_imagenBytes != null) {
          fotoParaGuardar = base64Encode(_imagenBytes!);
        }

        // Actualizamos todos los datos en Firestore (nada de Storage)
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'nombre': _nombreController.text.trim(),
          'bio': _bioController.text.trim(),
          'ubicacion': _ubicacionController.text.trim(),
          'fotoBase64': fotoParaGuardar, // Guardamos la foto como si fuera texto
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Perfil actualizado"), backgroundColor: Color(0xFFC4A77D)),
          );
          Navigator.pop(context); 
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al guardar: $e")),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  // Función ayudante para decidir qué imagen mostrar
  ImageProvider? _obtenerImagenPerfil() {
    if (_imagenBytes != null) {
      return MemoryImage(_imagenBytes!); // Foto recién elegida
    }
    if (_fotoBase64Actual.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(_fotoBase64Actual)); // Foto decodificada desde texto
      } catch (e) {
        return null;
      }
    }
    return null; // Ícono por defecto
  }

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);
    const Color matteGold = Color(0xFFC4A77D);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkBlue),
        title: const Text("Editar Perfil", style: TextStyle(color: inkBlue, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: inkBlue))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                // 4. EL BOTÓN DE LA FOTO (Usando el decodificador)
                GestureDetector(
                  onTap: _elegirFoto,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: inkBlue,
                        backgroundImage: _obtenerImagenPerfil(),
                        child: _imagenBytes == null && _fotoBase64Actual.isEmpty
                            ? const Icon(Icons.person, size: 40, color: Colors.white70)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: matteGold, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 30),

                TextField(
                  controller: _nombreController,
                  decoration: const InputDecoration(labelText: "Nombre", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: matteGold))),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _bioController,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: "Biografía corta", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: matteGold))),
                ),
                const SizedBox(height: 10),

                TextField(
                  controller: _ubicacionController,
                  decoration: const InputDecoration(labelText: "Ubicación", focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: matteGold))),
                ),
                const SizedBox(height: 50),

                _isSaving
                  ? const CircularProgressIndicator(color: matteGold)
                  : ElevatedButton(
                      onPressed: _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: inkBlue,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
              ],
            ),
          ),
    );
  }
}