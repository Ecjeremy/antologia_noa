import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // Variables de Estado del Juego
  bool _isMyTurn = false;
  String _turnOwnerName = "";
  String _previousTextExcerpt = "Esperando el primer párrafo...";
  int _secondsRemaining = 600; // 20 minutos
  Timer? _countdownTimer;

  // Variables de Personalización 
  bool _isDarkMode = false;
  String _selectedFont = 'serif';
  Color _selectedColor = const Color(0xFF1B3D4D);

  // Paleta de colores Antología
  final Color inkBlue = const Color(0xFF1B3D4D);
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color darkBackground = const Color(0xFF121212);

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _writingController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel(); 
    setState(() {
      _secondsRemaining = 1200; 
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _countdownTimer?.cancel();
        _finishTurnAutomated();
      }
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return "$minutes:${secs.toString().padLeft(2, '0')}";
  }

  // --- INTERACCIÓN CON FIREBASE ---

  void _updateGameState(DocumentSnapshot snapshot) {
    if (!snapshot.exists) return;
    var data = snapshot.data() as Map<String, dynamic>;

    List participantes = data['participantes'] ?? [];
    int turnIndex = data['turnoActualIndice'] ?? 0;
    _turnOwnerName = data['participantesNombres'][turnIndex] ?? "Escritor";

    // Comprobar si es mi turno
    bool wasMyTurn = _isMyTurn;
    _isMyTurn = currentUser != null && participantes.isNotEmpty && participantes[turnIndex] == currentUser!.uid;

    String fullText = data['textoAcumulado'] ?? "";
    _previousTextExcerpt = _filtrarUltimosParrafos(fullText);

    // Evita el error rojo de Flutter
    if (_isMyTurn && !wasMyTurn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _writingController.clear();
        _startTimer();
      });
    } else if (!_isMyTurn && wasMyTurn) {
      _countdownTimer?.cancel();
    }
  }

  String _filtrarUltimosParrafos(String fullText) {
    if (fullText.isEmpty) return "Te toca iniciar la historia. ¡Mucha suerte!";
    List<String> parrafos = fullText.split('\n\n');
    if (parrafos.length <= 2) return fullText;
    return "...${parrafos[parrafos.length - 2]}\n\n${parrafos.last}";
  }

  Future<void> _submitFragment() async {
    if (_writingController.text.isEmpty) {
      _mostrarAlerta("No puedes enviar un fragmento vacío.");
      return;
    }

    _countdownTimer?.cancel(); 
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Procesando fragmento...")));

    DocumentReference juegoRef = FirebaseFirestore.instance.collection('juegos_colaborativos').doc(widget.juegoId);
    bool juegoTerminado = false;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(juegoRef);
      if (!snapshot.exists) throw Exception("El juego no existe");
      var data = snapshot.data() as Map<String, dynamic>;

      String textBefore = data['textoAcumulado'] ?? "";
      String newTextTotal = textBefore + (textBefore.isEmpty ? "" : "\n\n") + _writingController.text;
      int currentTurnIndex = data['turnoActualIndice'] ?? 0;

      // ¿ES EL ÚLTIMO TURNO?
      if (currentTurnIndex == 4) {
        juegoTerminado = true;
        List nombres = data['participantesNombres'] ?? [];
        String autoresJuntos = nombres.join(", ");

        // PUBLICAR LIBRO CON EL TÍTULO DE LA MISIÓN
        DocumentReference nuevaObraRef = FirebaseFirestore.instance.collection('obras').doc();
        transaction.set(nuevaObraRef, {
          "titulo": data['tituloJuego'] ?? "Obra Colaborativa", 
          "sinopsis": "Una obra maestra única, escrita a 10 manos por la comunidad creativa de Antología.",
          "contenido": newTextTotal,
          "esGratis": true,
          "precio": "0.00",
          "autorId": "comunidad",
          "autorNombre": autoresJuntos,
          "portada": "", 
          "fecha": FieldValue.serverTimestamp(),
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
          'ultimoFragmentoEstilo': {
            'color': _selectedColor.value.toString(),
            'fontFamily': _selectedFont
          }
        });
      }
    });

    if (juegoTerminado) {
      _mostrarAlerta("¡HISTORIA TERMINADA Y PUBLICADA! 🎉");
      if (context.mounted) Navigator.pop(context); 
    } else {
      _mostrarAlerta("¡Fragmento enviado!");
      _writingController.clear();
    }
  }

  void _finishTurnAutomated() {
    if (_isMyTurn && _writingController.text.isNotEmpty) {
      _submitFragment();
    } else if (_isMyTurn) {
      print("Tiempo agotado, saltar turno");
    }
  }

  // --- DISEÑO ---

  @override
  Widget build(BuildContext context) {
    Color currentBackground = _isDarkMode ? darkBackground : backgroundCream;
    Color currentTextColor = _isDarkMode ? Colors.white : inkBlue;
    Color parchmentColor = _isDarkMode ? inkBlue.withOpacity(0.3) : Colors.white;

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
                Icon(Icons.hourglass_top, color: matteGold, size: 16),
                const SizedBox(width: 8),
                Text(_formatTime(_secondsRemaining), style: TextStyle(color: matteGold, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            actions: [
              Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode, size: 16, color: currentTextColor),
              Switch(
                value: _isDarkMode,
                activeColor: matteGold,
                onChanged: (v) => setState(() => _isDarkMode = v),
              ),
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
                      // Panel superior con la misión y el texto anterior
                      _buildPreviousExcerptPanel(parchmentColor, currentTextColor, data),
                      const SizedBox(height: 25),
                      
                      if (_isMyTurn)
                        _buildWritingEditor(parchmentColor)
                      else
                        _buildWaitingMessage(currentTextColor),
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
                  backgroundColor: inkBlue,
                  icon: const Icon(Icons.send_outlined, color: Colors.white, size: 18),
                  label: const Text("TERMINAR MI PARTE", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
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
          Icon(_isMyTurn ? Icons.edit_note : Icons.person_search, color: _isMyTurn ? inkBlue : Colors.grey, size: 18),
          const SizedBox(width: 10),
          Text(
            _isMyTurn ? "¡ES TU TURNO, ${currentUser?.displayName?.toUpperCase() ?? 'ESCRITOR'}!" : "TURNO DE: ${_turnOwnerName.toUpperCase()}",
            style: TextStyle(fontWeight: FontWeight.bold, color: _isMyTurn ? inkBlue : textColor, fontSize: 12, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviousExcerptPanel(Color panelColor, Color textColor, Map<String, dynamic> data) {
    String tituloMision = data['tituloJuego'] ?? "Historia sin título";
    String personajesMision = data['personajesSugeridos'] ?? "Sin restricciones de personajes";

    return Column(
      children: [
        // --- TARJETA DE MISIÓN ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: inkBlue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: matteGold, width: 1, style: BorderStyle.solid),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("TU MISIÓN:", style: TextStyle(fontWeight: FontWeight.bold, color: inkBlue, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 5),
              Text("Título: $tituloMision", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text("Personajes obligatorios: $personajesMision", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),

        // --- EL PAPEL CON EL TEXTO ANTERIOR ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: panelColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: matteGold.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_edu, color: matteGold, size: 16),
                  const SizedBox(width: 8),
                  const Text("LO QUE DEJÓ EL AUTOR ANTERIOR...", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _previousTextExcerpt,
                style: TextStyle(fontSize: 15, color: textColor.withOpacity(0.8), height: 1.6, fontStyle: FontStyle.italic, fontFamily: 'serif'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWritingEditor(Color editorColor) {
    return Container(
      decoration: BoxDecoration(
        color: editorColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: inkBlue.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _writingController,
        maxLines: 15,
        style: TextStyle(color: _selectedColor, fontFamily: _selectedFont, fontSize: 16, height: 1.5),
        decoration: InputDecoration(
          hintText: "Continúa la historia aquí...",
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
          Text(
            "Esperando a que $_turnOwnerName termine su fragmento.",
            textAlign: TextAlign.center,
            style: TextStyle(color: textColor.withOpacity(0.5), fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleToolbar(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.black : Colors.white,
        border: const Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          const Text("ESTILO:", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          _buildFontButton('serif', 'Serif', textColor),
          _buildFontButton('sans-serif', 'Sans', textColor),
          const Spacer(),
          _buildColorButton(inkBlue),
          _buildColorButton(matteGold),
          _buildColorButton(_isDarkMode ? Colors.white : Colors.black),
          _buildColorButton(Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildFontButton(String fontApi, String label, Color textColor) {
    bool selected = _selectedFont == fontApi;
    return GestureDetector(
      onTap: () => setState(() => _selectedFont = fontApi),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: selected ? inkBlue : Colors.transparent, borderRadius: BorderRadius.circular(5)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? Colors.white : textColor, fontFamily: fontApi)),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    bool selected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 25,
        height: 25,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: matteGold, width: 2) : Border.all(color: Colors.black12, width: 0.5),
        ),
      ),
    );
  }

  void _mostrarAlerta(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}