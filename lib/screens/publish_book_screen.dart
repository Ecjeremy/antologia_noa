import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class PublishBookScreen extends StatefulWidget {
  final String? obraId; // NUEVO: Si trae ID es para editar/añadir capítulos. Si es null, es obra nueva.
  
  const PublishBookScreen({super.key, this.obraId});

  @override
  State<PublishBookScreen> createState() => _PublishBookScreenState();
}

class _PublishBookScreenState extends State<PublishBookScreen> {
  // --- COLORES CORPORATIVOS NOA ---
  final Color inkBlue = const Color(0xFF111827); // Corregido al Navy estricto de NOA
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color darkInk = const Color(0xFF121212); // Fondo oscuro
  final Color darkCard = const Color(0xFF1E1E1E); // Tarjetas en modo oscuro

  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _sinopsisController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController(text: "150");

  List<Map<String, String>> _capitulos = [
    {"titulo": "Capítulo 1", "contenido": ""}
  ];

  String _categoriaSeleccionada = "Fantasía";
  final List<String> _categorias = ["Fantasía", "Romance", "Terror", "Suspenso", "Drama", "Poesía", "Aventura", "Ciencia Ficción"];

  bool _esGratis = true;
  bool _cobrarPorCapitulos = true;
  Uint8List? _portadaBytes; 
  String? _portadaUrlExistente;
  
  bool _isUploading = false;
  bool _isLoadingData = false;
  bool _isDarkMode = false; // NUEVO: Toggle de Modo Oscuro

  @override
  void initState() {
    super.initState();
    if (widget.obraId != null) {
      _cargarObraExistente(); // Si estamos editando, traemos los datos de Firebase
    }
  }

  // --- LÓGICA PARA CONTINUAR UN LIBRO EXISTENTE ---
  Future<void> _cargarObraExistente() async {
    setState(() => _isLoadingData = true);
    try {
      // 1. Cargar datos generales de la obra
      var doc = await FirebaseFirestore.instance.collection('obras').doc(widget.obraId).get();
      if (doc.exists) {
        var data = doc.data()!;
        _tituloController.text = data['titulo'] ?? "";
        _sinopsisController.text = data['sinopsis'] ?? "";
        _categoriaSeleccionada = data['categoria'] ?? "Fantasía";
        _esGratis = data['esGratis'] ?? true;
        _portadaUrlExistente = data['portadaUrl'];
        
        if (data['monetizacionTipo'] != null) {
          _cobrarPorCapitulos = data['monetizacionTipo'] == 'por_capitulo';
        }
        if (!_esGratis) {
          _coinsController.text = (data['precioNoaCoins'] ?? 150).toString();
        }
      }

      // 2. Cargar los capítulos que el autor ya había escrito
      var caps = await FirebaseFirestore.instance.collection('obras').doc(widget.obraId).collection('capitulos').orderBy('orden').get();
      if (caps.docs.isNotEmpty) {
        _capitulos.clear();
        for (var c in caps.docs) {
          var cData = c.data();
          _capitulos.add({
            "id": c.id, // Guardamos el ID para saber que este capítulo ya existe
            "titulo": cData['titulo'] ?? "",
            "contenido": cData['contenido'] ?? "",
          });
        }
      }
    } catch (e) {
      _notificar("Error al cargar la obra: $e");
    }
    setState(() => _isLoadingData = false);
  }

  Future<void> _seleccionarPortada() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _portadaBytes = bytes);
    }
  }

  void _agregarCapitulo() {
    setState(() {
      _capitulos.add({"titulo": "Capítulo ${_capitulos.length + 1}", "contenido": ""});
    });
  }

  @override
  Widget build(BuildContext context) {
    // Definición de colores dinámicos según el modo noche
    final Color currentBg = _isDarkMode ? darkInk : backgroundCream;
    final Color currentCard = _isDarkMode ? darkCard : Colors.white;
    final Color currentText = _isDarkMode ? Colors.white : inkBlue;

    if (_isLoadingData) {
      return Scaffold(backgroundColor: currentBg, body: Center(child: CircularProgressIndicator(color: inkBlue)));
    }

    return Scaffold(
      backgroundColor: currentBg,
      appBar: AppBar(
        backgroundColor: currentBg, 
        elevation: 0,
        iconTheme: IconThemeData(color: currentText),
        title: Text(widget.obraId == null ? "NUEVA OBRA" : "CONTINUAR OBRA", 
          style: TextStyle(color: currentText, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          // BOTÓN DE MODO NOCHE
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: _isDarkMode ? Colors.amber : inkBlue),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ÁREA DE PORTADA
            Center(
              child: GestureDetector(
                onTap: _seleccionarPortada,
                child: Container(
                  width: 120, height: 180,
                  decoration: BoxDecoration(
                    color: currentCard, 
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: matteGold.withOpacity(0.3)),
                    image: _portadaBytes != null 
                        ? DecorationImage(image: MemoryImage(_portadaBytes!), fit: BoxFit.cover) 
                        : (_portadaUrlExistente != null && _portadaUrlExistente!.isNotEmpty)
                            ? DecorationImage(image: NetworkImage(_portadaUrlExistente!), fit: BoxFit.cover)
                            : null,
                  ),
                  child: (_portadaBytes == null && (_portadaUrlExistente == null || _portadaUrlExistente!.isEmpty)) 
                      ? Icon(Icons.add_a_photo_outlined, color: currentText) 
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 30),

            _label("Título de la Obra", currentText),
            _buildTextField(_tituloController, "Ej: Crónicas de Zaruma", currentCard, currentText),
            
            _label("Categoría", currentText),
            _buildCategorySelector(currentCard, currentText),

            _label("Sinopsis", currentText),
            _buildTextField(_sinopsisController, "De qué trata tu historia...", currentCard, currentText, maxLines: 3),

            const SizedBox(height: 30),
            const Divider(),
            
            // LISTA DE CAPÍTULOS DINÁMICA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("CAPÍTULOS (${_capitulos.length})", style: TextStyle(fontWeight: FontWeight.bold, color: currentText)),
                TextButton.icon(
                  onPressed: _agregarCapitulo, 
                  icon: Icon(Icons.add, size: 18, color: _isDarkMode ? Colors.white70 : inkBlue), 
                  label: Text("Añadir otro", style: TextStyle(fontSize: 12, color: _isDarkMode ? Colors.white70 : inkBlue)),
                )
              ],
            ),

            ..._capitulos.asMap().entries.map((entry) => _buildEditorCapitulo(entry.key, currentCard, currentText)).toList(),

            const SizedBox(height: 30),
            _buildNoaCoinsCard(currentCard, currentText),
            const SizedBox(height: 40),

            // BOTÓN GUARDAR / PUBLICAR
            ElevatedButton(
              onPressed: _isUploading ? null : _publicarObraCompleta,
              style: ElevatedButton.styleFrom(
                backgroundColor: inkBlue, 
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _isUploading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : Text(widget.obraId == null ? "PUBLICAR AHORA" : "GUARDAR CAMBIOS", 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorCapitulo(int index, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        children: [
          TextField(
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Título del capítulo", 
              border: InputBorder.none, 
              hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black38)
            ),
            onChanged: (val) => _capitulos[index]["titulo"] = val,
            controller: TextEditingController(text: _capitulos[index]["titulo"]),
          ),
          Divider(color: _isDarkMode ? Colors.white24 : Colors.black12),
          TextField(
            maxLines: 15, // Más espacio para escribir
            minLines: 8,
            style: TextStyle(color: textColor, height: 1.6),
            decoration: InputDecoration(
              hintText: "Escribe el contenido de tu capítulo...", 
              border: InputBorder.none,
              hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black38)
            ),
            onChanged: (val) => _capitulos[index]["contenido"] = val,
            controller: TextEditingController(text: _capitulos[index]["contenido"]),
          ),
          if (index > 0)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                onPressed: () => setState(() => _capitulos.removeAt(index)),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildNoaCoinsCard(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _isDarkMode ? matteGold.withOpacity(0.05) : matteGold.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Vender esta obra", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Switch(value: !_esGratis, activeColor: inkBlue, onChanged: (v) => setState(() => _esGratis = !v)),
            ],
          ),
          if (!_esGratis) ...[
            const SizedBox(height: 15),
            _buildOptionBoton("Cobrar por libro completo", !_cobrarPorCapitulos, () {
              setState(() {
                _cobrarPorCapitulos = false;
                _coinsController.text = "500";
              });
            }),
            _buildOptionBoton("Cobrar por capítulo (Cap 4+)", _cobrarPorCapitulos, () {
              setState(() {
                _cobrarPorCapitulos = true;
                _coinsController.text = "150";
              });
            }),
            const SizedBox(height: 20),
            TextField(
              controller: _coinsController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.toll, color: Colors.orange), 
                labelText: _cobrarPorCapitulos ? "Noa Coins por capítulo" : "Precio total del libro", 
                labelStyle: TextStyle(color: _isDarkMode ? Colors.white54 : Colors.black54),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: cardColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "* Los usuarios sin monedas podrán ver un anuncio para desbloquear capítulos bloqueados.",
              style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildOptionBoton(String texto, bool seleccionado, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? inkBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: inkBlue),
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: TextStyle(color: seleccionado ? Colors.white : inkBlue, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  // --- LÓGICA DE GUARDADO INTELIGENTE (CREAR O ACTUALIZAR) ---
  Future<void> _publicarObraCompleta() async {
    if (_tituloController.text.isEmpty || _capitulos[0]["contenido"]!.isEmpty) {
      _notificar("Faltan datos obligatorios o el capítulo está vacío.");
      return;
    }

    setState(() => _isUploading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String url = _portadaUrlExistente ?? "";
      
      // Si el usuario subió una portada nueva, la guardamos
      if (_portadaBytes != null) {
        Reference ref = FirebaseStorage.instance.ref().child('portadas/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_portadaBytes!);
        url = await ref.getDownloadURL();
      }

      // Preparamos los datos base del libro
      Map<String, dynamic> obraData = {
        "titulo": _tituloController.text.trim(),
        "categoria": _categoriaSeleccionada,
        "sinopsis": _sinopsisController.text.trim(),
        "portadaUrl": url,
        "autorId": user.uid,
        "autorNombre": user.displayName ?? "Escritor",
        "esGratis": _esGratis,
        "monetizacionTipo": _cobrarPorCapitulos ? "por_capitulo" : "libro_completo",
        "precioNoaCoins": _esGratis ? 0 : int.tryParse(_coinsController.text) ?? 0,
        "aceptaAds": true,
        "ultimaActualizacion": FieldValue.serverTimestamp(),
      };

      DocumentReference obraRef;

      // CREAR vs ACTUALIZAR
      if (widget.obraId == null) {
        // Es un libro nuevo
        obraData["fechaPublicacion"] = FieldValue.serverTimestamp();
        obraRef = await FirebaseFirestore.instance.collection('obras').add(obraData);
        // Le sumamos 1 al contador de obras del usuario
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({'obras': FieldValue.increment(1)});
      } else {
        // Es una actualización
        obraRef = FirebaseFirestore.instance.collection('obras').doc(widget.obraId);
        await obraRef.update(obraData);
      }

      // GUARDAR LOS CAPÍTULOS (Nuevos y Existentes)
      for (int i = 0; i < _capitulos.length; i++) {
        Map<String, dynamic> capData = {
          "orden": i + 1,
          "titulo": _capitulos[i]["titulo"],
          "contenido": _capitulos[i]["contenido"],
          "esGratis": _cobrarPorCapitulos ? (i < 3) : _esGratis, 
        };

        // Si el capítulo ya tenía un ID, lo actualizamos. Si no, lo creamos.
        if (_capitulos[i].containsKey("id") && _capitulos[i]["id"] != null) {
          await obraRef.collection('capitulos').doc(_capitulos[i]["id"]).update(capData);
        } else {
          await obraRef.collection('capitulos').add(capData);
        }
      }
      
      if (mounted) {
        _notificar(widget.obraId == null ? "¡Libro publicado con éxito!" : "¡Cambios y capítulos guardados!");
        Navigator.pop(context, true);
      }
    } catch (e) {
      _notificar("Error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- WIDGETS AUXILIARES ---
  Widget _label(String t, Color c) => Padding(padding: const EdgeInsets.only(top: 20, bottom: 8), child: Text(t.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.withOpacity(0.5))));
  
  Widget _buildTextField(TextEditingController c, String h, Color cardColor, Color textColor, {int maxLines = 1}) {
    return TextField(
      controller: c, maxLines: maxLines, style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: h, hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black38), 
        filled: true, fillColor: cardColor, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
      )
    );
  }
  
  Widget _buildCategorySelector(Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12), 
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)), 
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _categoriaSeleccionada, 
          isExpanded: true, 
          dropdownColor: cardColor,
          style: TextStyle(color: textColor, fontSize: 16),
          items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), 
          onChanged: (v) => setState(() => _categoriaSeleccionada = v!)
        )
      )
    );
  }
  
  void _notificar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}