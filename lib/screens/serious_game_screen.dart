import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'package:share_plus/share_plus.dart'; 

class SeriousGameScreen extends StatefulWidget {
  final String juegoId;
  const SeriousGameScreen({super.key, required this.juegoId});

  @override
  State<SeriousGameScreen> createState() => _SeriousGameScreenState();
}

class _SeriousGameScreenState extends State<SeriousGameScreen> {
  late Stream<DocumentSnapshot> _gameStream;
  final User? currentUser = FirebaseAuth.instance.currentUser;
  
  final TextEditingController _writingController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _charsController = TextEditingController();

  final Color navyNoa = const Color(0xFF111827); 
  final Color tealNoa = const Color(0xFF009688);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color matteGold = const Color(0xFFC4A77D);

  bool _isDarkMode = false;
  String _selectedFont = 'Serif'; 
  int _wordCount = 0;
  String _timeLeft = "Calculando...";
  Timer? _timer;
  Timestamp? _limiteTurnoActual;
  String _personajesOriginales = ""; 
  bool _inicializado = false;
  bool _saltandoTurno = false;

  @override
  void initState() {
    super.initState();
    
    _gameStream = FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).snapshots();
    
    _writingController.addListener(() {
      final words = _writingController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (mounted && _wordCount != words) setState(() => _wordCount = words);
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _limiteTurnoActual == null || _saltandoTurno) return;
      
      final now = DateTime.now();
      final diff = _limiteTurnoActual!.toDate().difference(now);
      
      if (diff.isNegative) {
        setState(() => _timeLeft = "TIEMPO AGOTADO");
        _saltarTurnoPorInactividad(); 
      } else {
        setState(() => _timeLeft = "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s");
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _writingController.dispose();
    _subtitleController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _charsController.dispose();
    super.dispose();
  }

  Future<void> _saltarTurnoPorInactividad() async {
    if (_saltandoTurno) return;
    _saltandoTurno = true;

    try {
      final doc = await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).get();
      if (!doc.exists) return;
      
      var data = doc.data()!;
      if (data['estado'] == 'completado') return;

      int indexActual = data['turnoActualIndice'] ?? 0;
      List uids = data['participantes'] ?? [];

      await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
        'turnoActualIndice': FieldValue.increment(1),
        'limiteTurno': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 3))), // 3 HORAS
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      int nextIndex = (indexActual + 1) % uids.length;
      String uidSiguiente = uids[nextIndex];
      
      await FirebaseFirestore.instance.collection('usuarios').doc(uidSiguiente).collection('notificaciones').add({
        'titulo': '¡Tu turno ha llegado antes! ⚡',
        'mensaje': 'El autor anterior perdió su turno por inactividad. ¡Es momento de que escribas en "${data['titulo']}"!',
        'fecha': FieldValue.serverTimestamp(),
        'leida': false,
        'tipo': 'turno_juego',
        'juegoId': widget.juegoId,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Un autor perdió su turno por tiempo. El juego continúa."), backgroundColor: Colors.orange));
    } catch (e) {
      debugPrint("Error al saltar turno: $e");
    } finally {
      _saltandoTurno = false;
    }
  }

  void _compartirObra(String titulo) {
    Share.share("Sigue la creación de '$titulo' en NOA. ¡Una historia escrita colaborativamente por varios autores!");
  }

  Future<void> _toggleFavorito(List favoritosActuales) async {
    final miUid = currentUser?.uid;
    if (miUid == null) return;
    bool esFav = favoritosActuales.contains(miUid);

    await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
      'favoritosBy': esFav ? FieldValue.arrayRemove([miUid]) : FieldValue.arrayUnion([miUid]),
    });
  }

  Future<void> _pagarPorEditar() async {
    final miUid = currentUser?.uid;
    if (miUid == null) return;
    int costo = 50;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference miRef = FirebaseFirestore.instance.collection('usuarios').doc(miUid);
        DocumentSnapshot miDoc = await transaction.get(miRef);
        
        int miSaldo = miDoc.get('noaCoins') ?? 0;
        if (miSaldo < costo) throw Exception("SaldoInsuficiente");

        transaction.update(miRef, {'noaCoins': FieldValue.increment(-costo)});
      });

      await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
        'turnoActualIndice': FieldValue.increment(-1),
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pagaste $costo Coins. Recuperaste tu turno para editar."), backgroundColor: matteGold));
    } catch (e) {
      if (mounted && e.toString().contains("SaldoInsuficiente")) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes suficientes Noa Coins para esta acción."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(
      fontSize: 16, height: 1.6,
      color: _isDarkMode ? Colors.white.withOpacity(0.9) : navyNoa,
      fontFamily: _selectedFont == 'Serif' ? 'serif' : (_selectedFont == 'Mono' ? 'monospace' : 'sans-serif'),
    );

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF121212) : backgroundCream,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? const Color(0xFF121212) : backgroundCream,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : navyNoa),
        title: Image.asset('assets/images/logoNOA.png', height: 40),
        centerTitle: true,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: _gameStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
              var data = snapshot.data!.data() as Map<String, dynamic>;
              List favs = data['favoritosBy'] ?? [];
              bool isFav = currentUser != null && favs.contains(currentUser!.uid);
              return Row(
                children: [
                  IconButton(
                    icon: Icon(isFav ? Icons.bookmark : Icons.bookmark_border, color: isFav ? matteGold : (_isDarkMode ? Colors.white : navyNoa)),
                    onPressed: () => _toggleFavorito(favs),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _compartirObra(data['titulo'] ?? 'esta obra'),
                  ),
                ],
              );
            }
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _gameStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());
          
          var data = snapshot.data!.data() as Map<String, dynamic>;
          int index = data['turnoActualIndice'] ?? 0;
          List participantes = data['participantes'] ?? [];
          List nombres = data['participantesNombres'] ?? [];
          String textoBase = data['textoAcumulado'] ?? "";
          String borradorTemp = data['borradorActivo'] ?? "";
          
          if (!_inicializado) {
            _titleController.text = data['titulo'] ?? "";
            _categoryController.text = data['categoria'] ?? "";
            _charsController.text = data['personajes'] ?? "";
            _personajesOriginales = data['personajes'] ?? "";
            if (borradorTemp.isNotEmpty && _writingController.text.isEmpty) _writingController.text = borradorTemp;
            _inicializado = true;
          }

          bool esMiTurno = currentUser != null && participantes.isNotEmpty && participantes[index % participantes.length] == currentUser!.uid;
          bool fuiAnterior = currentUser != null && index > 0 && participantes.isNotEmpty && participantes[(index - 1) % participantes.length] == currentUser!.uid;
          String autorActual = nombres.isNotEmpty ? nombres[index % nombres.length] : "Desconocido";
          _limiteTurnoActual = data['limiteTurno'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildFicha(esMiTurno, index == 0),
                const SizedBox(height: 10),
                _buildHerramientas(),
                _buildCronometro(autorActual, esMiTurno),
                const SizedBox(height: 15),
                if (textoBase.isNotEmpty) _buildContexto(textoBase, style),
                const SizedBox(height: 20),
                _buildEditor(esMiTurno, style),
                _buildFooter(esMiTurno, fuiAnterior, textoBase, index, nombres, participantes),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFicha(bool esMiTurno, bool esAutorUno) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: navyNoa, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          _buildInput(_titleController, "Título", Icons.book, esMiTurno && esAutorUno),
          _buildInput(_categoryController, "Categoría", Icons.label, esMiTurno && esAutorUno),
          _buildInput(_charsController, "Personajes y Roles", Icons.face, esMiTurno, isMultiline: true),
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, bool enabled, {bool isMultiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        enabled: enabled,
        maxLines: isMultiline ? null : 1,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint, hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: Icon(icon, color: tealNoa, size: 18),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildHerramientas() {
    return Row(
      children: [
        DropdownButton<String>(
          value: _selectedFont,
          dropdownColor: navyNoa,
          style: TextStyle(color: _isDarkMode ? Colors.white : navyNoa, fontWeight: FontWeight.bold),
          underline: const SizedBox(),
          items: ['Serif', 'Sans', 'Mono'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
          onChanged: (v) => setState(() => _selectedFont = v!),
        ),
        const Spacer(),
        IconButton(icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode), color: _isDarkMode ? Colors.amber : navyNoa, onPressed: () => setState(() => _isDarkMode = !_isDarkMode)),
      ],
    );
  }

  Widget _buildCronometro(String autor, bool esMiTurno) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(esMiTurno ? "TU TURNO" : "AUTOR: $autor", style: TextStyle(fontWeight: FontWeight.bold, color: esMiTurno ? tealNoa : (_isDarkMode ? Colors.white : navyNoa))),
        Text(_timeLeft, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildContexto(String texto, TextStyle style) {
    List<String> p = texto.split('\n\n');
    String resumen = p.length <= 2 ? texto : "... ${p.sublist(p.length - 2).join('\n\n')}";
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tealNoa.withOpacity(0.05), border: Border(left: BorderSide(color: tealNoa, width: 4))),
      child: Text(resumen, style: style.copyWith(fontSize: 14, fontStyle: FontStyle.italic)),
    );
  }

  Widget _buildEditor(bool active, TextStyle style) {
    return Column(
      children: [
        TextField(
          controller: _subtitleController,
          enabled: active,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isDarkMode ? Colors.white : navyNoa),
          decoration: InputDecoration(
            hintText: "Capítulo o Subtítulo (Opcional)",
            hintStyle: TextStyle(color: _isDarkMode ? Colors.white30 : Colors.black26),
            fillColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _writingController,
          maxLines: null, minLines: 8, enabled: active, 
          style: style,
          enableInteractiveSelection: false, 
          decoration: InputDecoration(
            hintText: active ? "Escribe tu aporte aquí..." : "Espera tu turno para escribir...", 
            fillColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool miTurno, bool fuiAnterior, String texto, int index, List nombres, List uids) {
    return Column(
      children: [
        Align(alignment: Alignment.centerRight, child: Text("$_wordCount palabras", style: const TextStyle(fontSize: 11))),
        const SizedBox(height: 10),
        if (miTurno) ...[
          OutlinedButton(
            onPressed: () => _guardarBorrador(),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45), side: BorderSide(color: navyNoa)),
            child: Text("GUARDAR BORRADOR", style: TextStyle(color: _isDarkMode ? Colors.white : navyNoa)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: (_wordCount >= 30) ? () => _finalizarTurno(texto, index, nombres, uids) : null,
            style: ElevatedButton.styleFrom(backgroundColor: navyNoa, minimumSize: const Size(double.infinity, 50)),
            child: Text((index + 1) >= nombres.length ? "PUBLICAR LIBRO" : "FINALIZAR TURNO", style: const TextStyle(color: Colors.white)),
          ),
        ],
        if (!miTurno && fuiAnterior)
          TextButton.icon(
            onPressed: _pagarPorEditar,
            icon: Icon(Icons.generating_tokens, color: matteGold),
            label: Text("Editar turno anterior (50 Coins)", style: TextStyle(color: _isDarkMode ? Colors.white : navyNoa)),
          ),
      ],
    );
  }

  Future<void> _guardarBorrador() async {
    await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
      'borradorActivo': _writingController.text.trim(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Borrador guardado localmente.")));
  }

  Future<void> _finalizarTurno(String anterior, int index, List nombres, List uids) async {
    if (_writingController.text.trim().length < 30) {
      _notificar("Escribe al menos 30 palabras para dar calidad a la obra.");
      return;
    }

    setState(() => _saltandoTurno = true);
    
    String aporte = _writingController.text.trim();
    if (_subtitleController.text.trim().isNotEmpty) {
      aporte = "— ${_subtitleController.text.trim().toUpperCase()} —\n\n$aporte";
    }

    String finalTxt = anterior.isEmpty ? aporte : "$anterior\n\n$aporte";
    
    bool esUltimo = (index + 1) >= nombres.length;

    try {
      if (esUltimo) {
        await FirebaseFirestore.instance.collection('obras').add({
          'titulo': _titleController.text.trim().isEmpty ? "Obra sin título" : _titleController.text.trim(),
          'contenido': finalTxt,
          'autoresUids': uids, 
          'autoresNombres': nombres,
          'categoria': _categoryController.text.trim().isEmpty ? "General" : _categoryController.text.trim(),
          'fechaPublicacion': FieldValue.serverTimestamp(),
          'vistas': 0,        
          'favoritos': 0,     
          'portadaUrl': '',   
          'esModoSerio': true,
        });

        await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({'estado': 'completado'});
        
        if (mounted) {
          _notificar("¡Obra publicada! Ahora otros podrán verla y darte propinas.");
          Navigator.pop(context); 
        }
      } else {
        await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
          'textoAcumulado': finalTxt,
          'turnoActualIndice': FieldValue.increment(1),
          'fechaActualizacion': FieldValue.serverTimestamp(),
          'limiteTurno': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 3))), // 3 HORAS
        });
        
        _writingController.clear();
        _subtitleController.clear();
        _notificar("Turno enviado al siguiente autor.");
      }
    } catch (e) {
      _notificar("Error al procesar: $e");
    } finally {
      if (mounted) setState(() => _saltandoTurno = false);
    }
  }

  void _notificar(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF111827),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}