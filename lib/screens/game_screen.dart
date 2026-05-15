import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart'; // PAQUETE NUEVO
import 'dart:async';

class GameScreen extends StatefulWidget {
  final String juegoId;

  const GameScreen({super.key, required this.juegoId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _writingController = TextEditingController();

  bool _isMyTurn = false;
  String _turnOwnerName = "";
  String _previousTextExcerpt = "Esperando el primer fragmento...";
  int _secondsRemaining = 900; // 15 minutos exactos (Modo Caos)
  Timer? _countdownTimer;

  bool _isDarkMode = false;
  String _selectedFont = 'serif';
  Color _selectedColor = const Color(0xFF111827); // navyNoa
  
  final Color navyNoa = const Color(0xFF111827); 
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color darkBackground = const Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _protegerPantalla();
  }

  // --- SEGURIDAD: ANTI-SCREENSHOT ---
  Future<void> _protegerPantalla() async {
    await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
  }

  @override
  void dispose() {
    FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
    _countdownTimer?.cancel();
    _writingController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel(); 
    setState(() => _secondsRemaining = 900); 
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _countdownTimer?.cancel();
        _finishTurnAutomated(); // Salto automático
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return "$minutes:${secs.toString().padLeft(2, '0')}";
  }

  void _updateGameState(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;
    var data = snapshot.data() as Map<String, dynamic>;

    List participantes = List.from(data['participantes'] ?? []);
    int turnIndex = data['turnoActualIndice'] ?? 0;
    
    // Si algún usuario se desconecta o la data es inválida, se maneja el out of bounds
    if (turnIndex >= participantes.length) {
      turnIndex = 0; // O forzar finalización si aplica
    }
    
    _turnOwnerName = data['participantesNombres'][turnIndex] ?? "Escritor";
    bool wasMyTurn = _isMyTurn;
    _isMyTurn = currentUser != null && participantes.isNotEmpty && participantes[turnIndex] == currentUser!.uid;

    String fullText = data['textoAcumulado'] ?? "";
    _previousTextExcerpt = _obtenerUltimas20Palabras(fullText);

    if (_isMyTurn && !wasMyTurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _writingController.clear();
        _startTimer();
      });
    } else if (!_isMyTurn && wasMyTurn) {
      _countdownTimer?.cancel();
    }
  }

  // --- REGLA: MODO CAOS (Solo 20 palabras) ---
  String _obtenerUltimas20Palabras(String fullText) {
    if (fullText.trim().isEmpty) return "Te toca iniciar la historia. ¡Mucha suerte!";
    List<String> palabras = fullText.trim().split(RegExp(r'\s+'));
    if (palabras.length <= 20) return fullText;
    return "...${palabras.sublist(palabras.length - 20).join(' ')}";
  }

  Future<void> _submitFragment() async {
    // Si se acaba el tiempo y está vacío, pasamos el turno con un mensaje del sistema
    String textoEnviar = _writingController.text.trim();
    if (textoEnviar.isEmpty && _secondsRemaining > 0) {
      _mostrarAlerta("No puedes enviar un fragmento vacío.");
      return;
    }
    
    if (textoEnviar.isEmpty) textoEnviar = "[El autor fue devorado por el caos y perdió su turno...]";

    _countdownTimer?.cancel(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando fragmento...")));

    DocumentReference juegoRef = FirebaseFirestore.instance.collection('juegos_colaborativos').doc(widget.juegoId);
    bool juegoTerminado = false;

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(juegoRef);
        if (!snapshot.exists) throw Exception("El juego no existe");
        var data = snapshot.data() as Map<String, dynamic>;

        String textBefore = data['textoAcumulado'] ?? "";
        String newTextTotal = textBefore + (textBefore.isEmpty ? "" : "\n\n") + textoEnviar;
        int currentTurnIndex = data['turnoActualIndice'] ?? 0;
        List participantes = List.from(data['participantes'] ?? []);

        // El juego termina cuando todos han escrito una vez (o ajusta el límite de rondas aquí)
        if (currentTurnIndex >= participantes.length - 1) {
          juegoTerminado = true;
          List nombres = data['participantesNombres'] ?? [];
          List ids = data['participantes'] ?? [];
          List<Map<String, dynamic>> autoresData = [];

          for (int i = 0; i < ids.length; i++) {
            autoresData.add({
              'id': ids[i],
              'nombre': nombres[i],
            });
          }

          // --- PUBLICACIÓN EFÍMERA (48 HORAS) ---
          DocumentReference nuevaObraRef = FirebaseFirestore.instance.collection('obras').doc();
            transaction.set(nuevaObraRef, {
              "titulo": data['tituloJuego'] ?? "Obra del Caos", 
              "sinopsis": "Escritura a ciegas. Una obra maestra efímera creada en el Modo Caos.",
              "contenido": newTextTotal,
              "esGratis": true,
              "precioNoaCoins": 0,
              "autoresDetalle": autoresData, // <--- Nueva lista para los clics
              "autorId": "comunidad",
              "autorNombre": nombres.join(", "), // Mantenemos esto por compatibilidad
              "fecha": FieldValue.serverTimestamp(),
              "fecha_expiracion": Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
              "modo": "caos",
              // --- INICIALIZAMOS LOS CONTADORES EN CERO ---
              "vistas": 0,
              "favoritos": 0,
              "favoritosList": [],
              "ventas": 0
            });


          transaction.update(juegoRef, {
            'textoAcumulado': newTextTotal,
            'estado': 'terminado',
          });
        } else {
          transaction.update(juegoRef, {
            'textoAcumulado': newTextTotal,
            'turnoActualIndice': currentTurnIndex + 1,
            'turnoIniciadoEn': FieldValue.serverTimestamp(),
          });
        }
      });

      if (juegoTerminado) {
        _mostrarAlerta("¡HISTORIA TERMINADA Y PUBLICADA POR 48H! 🎉");
        if (mounted) Navigator.pop(context); 
      } else {
        _mostrarAlerta("¡Fragmento enviado al caos!");
        _writingController.clear();
      }
    } catch (e) {
      debugPrint("Error guardando turno: $e");
    }
  }

  void _finishTurnAutomated() {
    if (_isMyTurn) _submitFragment();
  }

  @override
  Widget build(BuildContext context) {
    Color currentBackground = _isDarkMode ? darkBackground : backgroundCream;
    Color currentTextColor = _isDarkMode ? Colors.white : navyNoa;
    Color parchmentColor = _isDarkMode ? navyNoa.withOpacity(0.3) : Colors.white;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('juegos_colaborativos').doc(widget.juegoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(backgroundColor: currentBackground, body: Center(child: CircularProgressIndicator(color: matteGold)));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>? ?? {}; 
        _updateGameState(snapshot.data!);

        return Scaffold(
          backgroundColor: currentBackground,
          appBar: AppBar(
            backgroundColor: currentBackground,
            elevation: 0,
            iconTheme: IconThemeData(color: currentTextColor),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_top, color: _secondsRemaining < 60 ? Colors.red : matteGold, size: 16),
                const SizedBox(width: 8),
                Text(_formatTime(_secondsRemaining), style: TextStyle(color: _secondsRemaining < 60 ? Colors.red : matteGold, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            actions: [
              Switch(value: _isDarkMode, activeColor: matteGold, onChanged: (v) => setState(() => _isDarkMode = v)),
              const SizedBox(width: 10),
            ],
          ),
          body: Column(
            children: [
              _buildTurnHeader(currentTextColor),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildMisionPanel(parchmentColor, currentTextColor, data),
                      const SizedBox(height: 25),
                      if (_isMyTurn) _buildWritingEditor(parchmentColor) else _buildWaitingMessage(currentTextColor),
                    ],
                  ),
                ),
              ),
              if (_isMyTurn) _buildStyleToolbar(currentTextColor),
            ],
          ),
          floatingActionButton: (_isMyTurn)
              ? FloatingActionButton.extended(
                  onPressed: _submitFragment,
                  backgroundColor: navyNoa,
                  icon: const Icon(Icons.bolt, color: Colors.white, size: 18),
                  label: const Text("ENVIAR AL CAOS", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                )
              : null,
        );
      },
    );
  }

  Widget _buildTurnHeader(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      color: _isDarkMode ? Colors.black26 : matteGold.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_isMyTurn ? Icons.edit_note : Icons.visibility_off, color: _isMyTurn ? navyNoa : Colors.grey, size: 18),
          const SizedBox(width: 10),
          Text(
            _isMyTurn ? "¡ES TU TURNO, ESCRITURA A CIEGAS!" : "TURNO DE: ${_turnOwnerName.toUpperCase()}",
            style: TextStyle(fontWeight: FontWeight.bold, color: _isMyTurn ? navyNoa : textColor, fontSize: 12, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildMisionPanel(Color panelColor, Color textColor, Map<String, dynamic> data) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: navyNoa.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: matteGold, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("MISIÓN CAÓTICA:", style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text("Título: ${data['tituloJuego']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text("Personajes: ${data['personajesAsignados']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text("Obligatorio: ${data['elementoObligatorio']}", style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: matteGold.withOpacity(0.3), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility_off, color: matteGold, size: 16),
                  const SizedBox(width: 8),
                  const Text("LAS ÚLTIMAS 20 PALABRAS...", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 20),
              Text(_previousTextExcerpt, style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.6, fontStyle: FontStyle.italic, fontFamily: 'serif')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWritingEditor(Color editorColor) {
    return Container(
      decoration: BoxDecoration(color: editorColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: navyNoa.withOpacity(0.1))),
      child: TextField(
        controller: _writingController,
        maxLines: 15,
        // --- SEGURIDAD: ANTI-COPIA Y PEGA ---
        enableInteractiveSelection: false,
        contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
        style: TextStyle(color: _selectedColor, fontFamily: _selectedFont, fontSize: 16, height: 1.5),
        decoration: InputDecoration(
          hintText: "Escribe sin mirar atrás...",
          hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5), fontFamily: 'serif'),
          contentPadding: const EdgeInsets.all(25),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildWaitingMessage(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const CircularProgressIndicator(color: Colors.grey),
          const SizedBox(height: 25),
          Text("Esperando a que $_turnOwnerName enfrente el caos.", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.5), fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildStyleToolbar(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: _isDarkMode ? Colors.black : Colors.white, border: const Border(top: BorderSide(color: Colors.black12, width: 0.5))),
      child: Row(
        children: [
          _buildFontButton('serif', 'Serif', textColor),
          _buildFontButton('sans-serif', 'Sans', textColor),
          const Spacer(),
          _buildColorButton(navyNoa),
          _buildColorButton(matteGold),
          _buildColorButton(_isDarkMode ? Colors.white : Colors.black),
        ],
      ),
    );
  }

  Widget _buildFontButton(String fontApi, String label, Color textColor) {
    bool selected = _selectedFont == fontApi;
    return GestureDetector(
      onTap: () => setState(() => _selectedFont = fontApi),
      child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: selected ? navyNoa : Colors.transparent, borderRadius: BorderRadius.circular(5)), child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : textColor, fontFamily: fontApi))),
    );
  }

  Widget _buildColorButton(Color color) {
    bool selected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(width: 25, height: 25, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: selected ? Border.all(color: matteGold, width: 2) : Border.all(color: Colors.black12, width: 0.5))),
    );
  }

  void _mostrarAlerta(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}