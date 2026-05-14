import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

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

  bool _isDarkMode = false;
  String _selectedFont = 'Serif'; 
  int _wordCount = 0;
  String _timeLeft = "Calculando...";
  Timer? _timer;
  Timestamp? _limiteTurnoActual;
  String _personajesOriginales = ""; 
  bool _inicializado = false;
  bool _saltandoTurno = false; // Evita bucles al saltar

  @override
  void initState() {
    super.initState();
    _gameStream = FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).snapshots();
    
    _writingController.addListener(() {
      final words = _writingController.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
      if (mounted && _wordCount != words) setState(() => _wordCount = words);
    });

    // RELOJ MAESTRO CON LÓGICA DE SALTO
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _limiteTurnoActual == null || _saltandoTurno) return;
      
      final now = DateTime.now();
      final diff = _limiteTurnoActual!.toDate().difference(now);
      
      if (diff.isNegative) {
        setState(() => _timeLeft = "TIEMPO AGOTADO");
        _saltarTurnoPorInactividad(); // <-- Aquí ocurre la magia
      } else {
        setState(() => _timeLeft = "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s");
      }
    });
  }

  // FUNCIÓN PARA QUITAR EL TURNO AL AUTOR LENTO
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
      List nombres = data['participantesNombres'] ?? [];

      // Pasamos al siguiente sin guardar texto nuevo
      await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({
        'turnoActualIndice': FieldValue.increment(1),
        'limiteTurno': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 12))),
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });

      // Notificar al nuevo autor que ahora es su turno por el salto
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Un autor perdió su turno por tiempo. El juego continúa."), backgroundColor: Colors.orange)
        );
      }
    } catch (e) {
      debugPrint("Error al saltar turno: $e");
    } finally {
      _saltandoTurno = false;
    }
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
        title: Image.asset('assets/images/logoNOA.png', height: 40),
        centerTitle: true,
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
          
          if (!_inicializado) {
            _titleController.text = data['titulo'] ?? "";
            _categoryController.text = data['categoria'] ?? "";
            _charsController.text = data['personajes'] ?? "";
            _personajesOriginales = data['personajes'] ?? "";
            _inicializado = true;
          }

          bool esMiTurno = currentUser != null && participantes[index % participantes.length] == currentUser!.uid;
          String autorActual = nombres[index % nombres.length];
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
                _buildFooter(esMiTurno, textoBase, index, nombres),
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
        Text(esMiTurno ? "TU TURNO" : "AUTOR: $autor", style: TextStyle(fontWeight: FontWeight.bold, color: esMiTurno ? tealNoa : navyNoa)),
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
          maxLines: null, minLines: 8, enabled: active, style: style,
          decoration: InputDecoration(
            hintText: "Escribe tu aporte aquí...", 
            fillColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool miTurno, String texto, int index, List nombres) {
    return Column(
      children: [
        Align(alignment: Alignment.centerRight, child: Text("$_wordCount palabras", style: const TextStyle(fontSize: 11))),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: (miTurno && _wordCount >= 30) ? () => _guardar(texto, index, nombres) : null,
          style: ElevatedButton.styleFrom(backgroundColor: navyNoa, minimumSize: const Size(double.infinity, 50)),
          child: Text((index + 1) == nombres.length ? "PUBLICAR LIBRO" : "GUARDAR PARTE", style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _guardar(String anterior, int index, List nombres) async {
    if (index > 0 && !_charsController.text.contains(_personajesOriginales)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No puedes borrar personajes anteriores.")));
      return;
    }

    String aporte = _writingController.text.trim();
    if (_subtitleController.text.trim().isNotEmpty) {
      aporte = "— ${_subtitleController.text.trim().toUpperCase()} —\n\n$aporte";
    }

    String finalTxt = anterior.isEmpty ? aporte : "$anterior\n\n$aporte";
    bool esUltimo = (index + 1) == nombres.length;

    Map<String, dynamic> up = {
      'textoAcumulado': finalTxt,
      'titulo': _titleController.text.isEmpty ? "Obra sin título" : _titleController.text,
      'categoria': _categoryController.text.isEmpty ? "General" : _categoryController.text,
      'personajes': _charsController.text,
      'fechaActualizacion': FieldValue.serverTimestamp(),
      'limiteTurno': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 12))),
    };

    if (esUltimo) {
      await FirebaseFirestore.instance.collection('obras').add({
        'titulo': up['titulo'],
        'contenido': finalTxt,
        'autores': nombres,
        'categoria': up['categoria'], 
        'fechaPublicacion': FieldValue.serverTimestamp(),
        'etiqueta': 'Modo Serio',
      });
      await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update({'estado': 'completado'});
      if (mounted) Navigator.pop(context);
    } else {
      // 1. Pasamos el turno
      up['turnoActualIndice'] = FieldValue.increment(1);
      await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).update(up);
      
      // 2. --- ENVIAR NOTIFICACIÓN AL SIGUIENTE AUTOR ---
      try {
        var docActual = await FirebaseFirestore.instance.collection('juegos').doc(widget.juegoId).get();
        List uids = docActual.data()?['participantes'] ?? [];
        int nextIndex = index + 1;
        
        if (uids.length > nextIndex) {
          String uidSiguiente = uids[nextIndex];
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uidSiguiente)
              .collection('notificaciones')
              .add({
            'titulo': '¡Es tu turno en NOA! ✍️',
            'mensaje': 'Te toca continuar la obra "${up['titulo']}". Tienes 12 horas para escribir tu parte.',
            'fecha': FieldValue.serverTimestamp(),
            'leida': false,
            'tipo': 'turno_juego',
            'juegoId': widget.juegoId,
          });
        }
      } catch (e) {
        debugPrint("Error al enviar notificación: $e");
      }
      // ------------------------------------------------

      _writingController.clear();
      _subtitleController.clear(); 
      _inicializado = false; 
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Aporte guardado. Hemos notificado al siguiente autor."), 
            backgroundColor: Color(0xFF009688) // Tu Teal corporativo
          )
        );
      }
    }
  }
}