import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // <-- IMPORTANTE
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart'; // <-- IMPORTANTE

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
  
  File? _imagenAdjuntaFile; // Ahora guardamos como Archivo

  String _queryMencion = "";
  bool _mostrandoMenciones = false;

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.startsWith('http')) return CachedNetworkImageProvider(imageData);
    return MemoryImage(base64Decode(imageData));
  }

  @override
  void initState() {
    super.initState();
    _cargarMisDatos();
    _textoController.addListener(_detectarMencion);
  }
  @override
  void dispose() {
    // Matamos el vigilante de menciones y el controlador para liberar RAM
    _textoController.removeListener(_detectarMencion);
    _textoController.dispose();
    super.dispose();
  }

  void _detectarMencion() {
    String text = _textoController.text;
    if (text.contains("@")) {
      int lastAt = text.lastIndexOf("@");
      String filter = text.substring(lastAt + 1);
      if (!filter.contains(" ")) {
        setState(() { _queryMencion = filter; _mostrandoMenciones = true; });
      } else { setState(() => _mostrandoMenciones = false); }
    } else { setState(() => _mostrandoMenciones = false); }
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

  Future<void> _adjuntarImagen() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); // 70% calidad = carga veloz
    if (pickedFile != null) {
      setState(() => _imagenAdjuntaFile = File(pickedFile.path));
    }
  }

  Future<void> _publicarHilo() async {
    if (_textoController.text.trim().isEmpty && _imagenAdjuntaFile == null) return;
    setState(() => _isPublishing = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String imagenUrl = "";
        
        // Si hay foto, a Firebase Storage
        if (_imagenAdjuntaFile != null) {
          String fileName = "hilo_${DateTime.now().millisecondsSinceEpoch}.jpg";
          Reference ref = FirebaseStorage.instance.ref().child('hilos').child(fileName);
          await ref.putFile(_imagenAdjuntaFile!);
          imagenUrl = await ref.getDownloadURL();
        }

        await FirebaseFirestore.instance.collection('hilos').add({
          'autorId': user.uid,
          'autorNombre': _miNombre,
          'autorFoto': _miFotoPerfil, // Para retrocompatibilidad visual si lo necesitas
          'texto': _textoController.text.trim(),
          'imagenAdjunta': imagenUrl, // Ahora guardamos el LINK optimizado
          'fecha': FieldValue.serverTimestamp(),
          'likes': 0,
          'likedBy': [],
        });

        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);
    const Color matteGold = Color(0xFFC4A77D);
    const Color softGrey = Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0, leadingWidth: 80, centerTitle: true,
        leading: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: inkBlue, fontSize: 14))),
        title: const Text("Nuevo Hilo", style: TextStyle(color: inkBlue, fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15, top: 12, bottom: 12),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publicarHilo,
              style: ElevatedButton.styleFrom(backgroundColor: inkBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
              child: _isPublishing ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Publicar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      CircleAvatar(
                        radius: 22, backgroundColor: softGrey,
                        backgroundImage: _miFotoPerfil.isNotEmpty ? _obtenerImagenInteligente(_miFotoPerfil) : null,
                        child: _miFotoPerfil.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                      ),
                      Container(width: 2, height: 100, margin: const EdgeInsets.symmetric(vertical: 8), color: softGrey),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_miNombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: inkBlue)),
                        TextField(controller: _textoController, maxLines: null, autofocus: true, style: const TextStyle(fontSize: 16, color: inkBlue, height: 1.4), decoration: const InputDecoration(hintText: "¿Qué estás pensando?", hintStyle: TextStyle(color: Colors.black38), border: InputBorder.none)),
                        if (_imagenAdjuntaFile != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imagenAdjuntaFile!, fit: BoxFit.cover)),
                                IconButton(icon: const Icon(Icons.cancel, color: Colors.white), onPressed: () => setState(() => _imagenAdjuntaFile = null)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_mostrandoMenciones)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('usuarios').where('nombre', isGreaterThanOrEqualTo: _queryMencion).where('nombre', isLessThanOrEqualTo: '$_queryMencion\uf8ff').limit(5).snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox();
                  return ListView.builder(
                    shrinkWrap: true, itemCount: snap.data!.docs.length,
                    itemBuilder: (context, i) {
                      var u = snap.data!.docs[i].data() as Map<String, dynamic>;
                      String foto = u['fotoPerfilUrl'] ?? u['fotoBase64'] ?? '';
                      return ListTile(
                        leading: CircleAvatar(radius: 15, backgroundImage: foto.isNotEmpty ? _obtenerImagenInteligente(foto) : null, child: foto.isEmpty ? const Icon(Icons.person, size: 15) : null),
                        title: Text(u['nombre'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onTap: () {
                          String text = _textoController.text; int lastAt = text.lastIndexOf("@");
                          String nuevoTexto = text.substring(0, lastAt) + "@${u['nombre']} ";
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12, width: 0.5))),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.image_outlined, color: matteGold), onPressed: _adjuntarImagen),
                IconButton(icon: const Icon(Icons.alternate_email, color: matteGold), onPressed: () { _textoController.text = "${_textoController.text}@"; _textoController.selection = TextSelection.fromPosition(TextPosition(offset: _textoController.text.length)); }),
                IconButton(icon: const Icon(Icons.grid_view_rounded, color: Colors.black38), onPressed: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
}