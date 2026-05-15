import 'dart:io';
import 'dart:convert';
import 'dart:typed_data'; // Para manejar imágenes en Web
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para detectar si es Web (kIsWeb)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async'; // <--- ESTA ES LA QUE FALTA

class CreateThreadScreen extends StatefulWidget {
  const CreateThreadScreen({super.key});

  @override
  State<CreateThreadScreen> createState() => _CreateThreadScreenState();
}

class _CreateThreadScreenState extends State<CreateThreadScreen> {
  final TextEditingController _textoController = TextEditingController();
  bool _isPublishing = false;
  
  String _miNombre = "Cargando...";
  String _miFotoPerfil = "";
  
  File? _imagenAdjuntaFile; // Para móvil
  Uint8List? _webImage;     // Para Web (Codemagic)

  String _queryMencion = "";
  bool _mostrandoMenciones = false;

  // --- Lógica de Diseño Original ---
  final Color navyNoa = const Color(0xFF111827);
  final Color matteGold = const Color(0xFFC4A77D);

  @override
  void initState() {
    super.initState();
    _cargarMisDatos();
    _textoController.addListener(_detectarMencion);
  }

  @override
  void dispose() {
    _textoController.removeListener(_detectarMencion);
    _textoController.dispose();
    super.dispose();
  }

  // --- Recuperamos tu lógica de menciones ---
  void _detectarMencion() {
    String text = _textoController.text;
    int cursorPosition = _textoController.selection.baseOffset;
    if (cursorPosition < 0) return;

    String textUntilCursor = text.substring(0, cursorPosition);
    int lastAt = textUntilCursor.lastIndexOf("@");

    if (lastAt != -1 && !textUntilCursor.substring(lastAt).contains(" ")) {
      setState(() {
        _queryMencion = textUntilCursor.substring(lastAt + 1).toLowerCase();
        _mostrandoMenciones = true;
      });
    } else {
      if (_mostrandoMenciones) setState(() => _mostrandoMenciones = false);
    }
  }

  Future<void> _cargarMisDatos() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        setState(() {
          _miNombre = data['nombre'] ?? 'Escritor';
          _miFotoPerfil = data['fotoPerfilUrl'] ?? data['fotoBase64'] ?? '';
        });
      }
    }
  }

  // --- Recuperamos tu lógica de adjuntar imagen con fix para Web ---
  Future<void> _adjuntarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _webImage = bytes;
          _imagenAdjuntaFile = null;
        });
      } else {
        setState(() {
          _imagenAdjuntaFile = File(pickedFile.path);
          _webImage = null;
        });
      }
    }
  }

  // --- Fix para la subida y el error Object-Not-Found ---
  Future<void> _publicarHilo() async {
  final String texto = _textoController.text.trim();
  
  // 1. Verificamos si realmente hay un archivo seleccionado
  final bool tieneImagen = _imagenAdjuntaFile != null;

  print("DEBUG: ¿Hay texto?: ${texto.isNotEmpty}");
  print("DEBUG: ¿Hay archivo de imagen?: $tieneImagen");

  // 2. LA VALIDACIÓN: Si ambas están vacías, lanzamos el error
  if (texto.isEmpty && !tieneImagen) {
    _notificar("No puedes publicar un hilo vacío. Escribe algo o sube una foto.");
    return;
  }

  setState(() => _isPublishing = true);

  Future<void> _publicarHilo() async {
    final String texto = _textoController.text.trim();
    final bool tieneImagen = _imagenAdjuntaFile != null || _webImage != null;

    print("DEBUG: ¿Hay texto?: ${texto.isNotEmpty}");
    print("DEBUG: ¿Hay archivo de imagen?: $tieneImagen");

    if (texto.isEmpty && !tieneImagen) {
      _notificar("No puedes publicar un hilo vacío. Escribe algo o sube una foto.");
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Debes iniciar sesión";

      String imagenUrlFinal = "";

      // --- SUBIDA DE IMAGEN CON LÍMITE DE TIEMPO ---
      if (tieneImagen) {
        print("DEBUG: Iniciando subida a Storage...");
        String fileName = "hilo_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg";
        Reference storageRef = FirebaseStorage.instance.ref().child('hilos').child(fileName);
        
        UploadTask uploadTask = kIsWeb 
            ? storageRef.putData(_webImage!) 
            : storageRef.putFile(_imagenAdjuntaFile!);
            
        // Si no sube en 30 segundos, cancela todo
        TaskSnapshot snapshot = await uploadTask.timeout(
          const Duration(seconds: 30), 
          onTimeout: () => throw "El internet está lento o Storage no responde (Timeout)."
        );
        imagenUrlFinal = await snapshot.ref.getDownloadURL();
        print("DEBUG: Imagen subida con éxito: $imagenUrlFinal");
      }

      print("DEBUG: Iniciando guardado en Firestore...");
      // --- GUARDADO EN BASE DE DATOS CON LÍMITE DE TIEMPO ---
      await FirebaseFirestore.instance.collection('hilos').add({
        'autorId': user.uid,
        'autorNombre': _miNombre,
        'autorFoto': _miFotoPerfil, 
        'texto': texto,
        'imagenAdjunta': imagenUrlFinal,
        'fecha': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
      }).timeout(
        const Duration(seconds: 15), 
        onTimeout: () => throw "La base de datos de Firestore no responde."
      );
      print("DEBUG: ¡Hilo guardado en la base de datos!");

      if (mounted) Navigator.pop(context, true); 

    } catch (e) {
      print("DEBUG: ERROR FATAL: $e");
      _notificar("Error: $e"); // Esto te mostrará en pantalla qué falló exactamente
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }
}

  void _notificar(String msj) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msj),
          backgroundColor: const Color(0xFF111827), // Tu color Navy oficial
        ),
      );
    }
  }

  // Pequeña función de apoyo para avisos rápidos
  

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.startsWith('http')) return CachedNetworkImageProvider(imageData);
    return MemoryImage(base64Decode(imageData));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar", style: TextStyle(color: navyNoa))),
        title: Text("Nuevo Hilo", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publicarHilo,
              style: ElevatedButton.styleFrom(backgroundColor: navyNoa, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: _isPublishing 
                ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("Publicar", style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22, 
                  backgroundImage: _miFotoPerfil.isNotEmpty ? _obtenerImagenInteligente(_miFotoPerfil) : null,
                  child: _miFotoPerfil.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_miNombre, style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa)),
                      TextField(
                        controller: _textoController, 
                        maxLines: null, 
                        autofocus: true,
                        decoration: const InputDecoration(hintText: "¿Qué estás pensando?", border: InputBorder.none)
                      ),
                      
                      // Vista previa segura (Fix para pantalla roja)
                      if (_imagenAdjuntaFile != null || _webImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15), 
                                child: kIsWeb 
                                    ? Image.memory(_webImage!, fit: BoxFit.cover) 
                                    : Image.file(_imagenAdjuntaFile!, fit: BoxFit.cover)
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.white), 
                                onPressed: () => setState(() { _imagenAdjuntaFile = null; _webImage = null; })
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de menciones (Tu lógica original)
          if (_mostrandoMenciones)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                color: Colors.white,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const LinearProgressIndicator();
                    var users = snapshot.data!.docs.where((u) => u['nombre'].toString().toLowerCase().contains(_queryMencion)).toList();
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        var u = users[i].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(radius: 15, backgroundImage: _obtenerImagenInteligente(u['fotoPerfilUrl'] ?? u['fotoBase64'] ?? '')),
                          title: Text(u['nombre'], style: const TextStyle(fontSize: 14)),
                          onTap: () {
                            String text = _textoController.text;
                            int lastAt = text.lastIndexOf("@");
                            String nuevoTexto = "${text.substring(0, lastAt)}@${u['nombre']} ";
                            _textoController.text = nuevoTexto;
                            _textoController.selection = TextSelection.fromPosition(TextPosition(offset: nuevoTexto.length));
                            setState(() => _mostrandoMenciones = false);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      // Barra inferior con tus iconos originales
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12, width: 0.5))),
        child: Row(
          children: [
            IconButton(icon: Icon(Icons.image_outlined, color: matteGold), onPressed: _adjuntarImagen),
            IconButton(icon: Icon(Icons.alternate_email, color: matteGold), onPressed: () {
              _textoController.text = "${_textoController.text}@";
              _textoController.selection = TextSelection.fromPosition(TextPosition(offset: _textoController.text.length));
            }),
            IconButton(icon: const Icon(Icons.grid_view_rounded, color: Colors.black38), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}