import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'serious_game_screen.dart';
import 'serious_lobby_screen.dart';

class SeriousLobbyScreen extends StatefulWidget {
  const SeriousLobbyScreen({super.key});

  @override
  State<SeriousLobbyScreen> createState() => _SeriousLobbyScreenState();
}

class _SeriousLobbyScreenState extends State<SeriousLobbyScreen> {
  final Color navyNoa = const Color(0xFF111827);
  final Color matteGold = const Color(0xFFC4A77D);
  final Color tealNoa = const Color(0xFF009688);

  String _estadoBusqueda = "Buscando escritores...";
  String? _miJuegoId;
  bool _encontrado = false;

  @override
  void initState() {
    super.initState();
    _buscarOCrearPartida();
  }

  Future<void> _buscarOCrearPartida() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Obtener mi nombre real de la BD
      var miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      String miNombre = miDoc.data()?['nombre'] ?? "Escritor";

      // 2. Buscar si hay una partida seria esperando gente (estado: reclutando)
      var query = await FirebaseFirestore.instance.collection('juegos')
          .where('tipo', isEqualTo: 'serio')
          .where('estado', isEqualTo: 'reclutando')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        // ME UNO A UNA PARTIDA EXISTENTE
        var doc = query.docs.first;
        _miJuegoId = doc.id;
        List participantes = doc['participantes'] ?? [];
        
        if (!participantes.contains(user.uid)) {
          await FirebaseFirestore.instance.collection('juegos').doc(_miJuegoId).update({
            'participantes': FieldValue.arrayUnion([user.uid]),
            'participantesNombres': FieldValue.arrayUnion([miNombre]),
          });
          participantes.add(user.uid);
        }

        // Si conmigo ya somos 3, iniciamos la partida!
        if (participantes.length >= 3) {
          await FirebaseFirestore.instance.collection('juegos').doc(_miJuegoId).update({
            'estado': 'activo',
            'limiteTurno': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 3))), // 3 HORAS iniciales
          });
        }
      } else {
        // NO HAY PARTIDAS, CREO UNA NUEVA
        var nuevaPartida = await FirebaseFirestore.instance.collection('juegos').add({
          'tipo': 'serio',
          'estado': 'reclutando',
          'participantes': [user.uid],
          'participantesNombres': [miNombre],
          'turnoActualIndice': 0,
          'fechaCreacion': FieldValue.serverTimestamp(),
          'textoAcumulado': "",
          'borradorActivo': "",
        });
        _miJuegoId = nuevaPartida.id;
      }

      setState(() => _encontrado = true);
      _escucharSala();

    } catch (e) {
      setState(() => _estadoBusqueda = "Error al buscar: $e");
    }
  }

  void _escucharSala() {
    if (_miJuegoId == null) return;

    FirebaseFirestore.instance.collection('juegos').doc(_miJuegoId).snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      
      var data = snap.data()!;
      if (data['estado'] == 'activo') {
        // YA SOMOS 3, NOS VAMOS AL JUEGO
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => SeriousGameScreen(juegoId: _miJuegoId!)),
        );
      }
    });
  }

  Future<void> _cancelarBusqueda() async {
    if (_miJuegoId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Me salgo de la lista de participantes
        await FirebaseFirestore.instance.collection('juegos').doc(_miJuegoId).update({
          'participantes': FieldValue.arrayRemove([user.uid]),
          // Nota: Sería ideal remover también el nombre, pero para simplificar lo dejamos así
        });
      }
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navyNoa,
      body: Center(
        child: _encontrado ? _buildSalaEspera() : _buildBuscando(),
      ),
    );
  }

  Widget _buildBuscando() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(color: matteGold),
        const SizedBox(height: 20),
        Text(_estadoBusqueda, style: const TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(height: 30),
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar", style: TextStyle(color: Colors.white54)))
      ],
    );
  }

  Widget _buildSalaEspera() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('juegos').doc(_miJuegoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        List participantes = data['participantes'] ?? [];

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 80, color: matteGold),
            const SizedBox(height: 20),
            const Text("SALA MODO SERIO", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Esperando escritores... (${participantes.length}/3)", style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 40),
            
            // Animación de carga bonita
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: participantes.length / 3,
                backgroundColor: Colors.white12,
                color: tealNoa,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 40),
            OutlinedButton(
              onPressed: _cancelarBusqueda,
              style: OutlinedButton.styleFrom(side: BorderSide(color: matteGold)),
              child: Text("SALIR DE LA SALA", style: TextStyle(color: matteGold)),
            )
          ],
        );
      }
    );
  }
}