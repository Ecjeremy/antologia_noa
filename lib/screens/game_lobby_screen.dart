import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'game_screen.dart';

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

class _GameLobbyScreenState extends State<GameLobbyScreen> {
  final Color inkBlue = const Color(0xFF1B3D4D);
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  String? _juegoId;
  bool _buscando = true;
  bool _navegando = false; // Para evitar que abra la pantalla dos veces

  @override
  void initState() {
    super.initState();
    _buscarOCrearSala();
  }

  // --- LÓGICA DE MATCHMAKING ---
  Future<void> _buscarOCrearSala() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Buscamos si hay alguna sala esperando jugadores (menos de 5)
    var query = await FirebaseFirestore.instance
        .collection('juegos_colaborativos')
        .where('estado', isEqualTo: 'esperando')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // ¡Hay una sala disponible! Nos unimos
      var doc = query.docs.first;
      _juegoId = doc.id;
      
      List participantes = doc['participantes'] ?? [];
      List nombres = doc['participantesNombres'] ?? [];

      // Si por error me salí y volví a entrar, no me duplico
      if (!participantes.contains(user.uid)) {
        participantes.add(user.uid);
        nombres.add(user.displayName ?? "Escritor");

        // Si conmigo ya somos 5, arrancamos el juego
        String nuevoEstado = participantes.length >= 5 ? 'en_curso' : 'esperando';

        await FirebaseFirestore.instance.collection('juegos_colaborativos').doc(_juegoId).update({
          'participantes': participantes,
          'participantesNombres': nombres,
          'estado': nuevoEstado,
          if (nuevoEstado == 'en_curso') 'turnoIniciadoEn': FieldValue.serverTimestamp(),
        });
      }
    } else {
  final random = Random();

  // --- MATRIZ DE TÍTULOS GLOBALES ---
  final List<String> inicios = [
    "El susurro", "La caída", "El renacer", "La última sombra", 
    "El código", "El secreto", "La danza", "El grito", "El pacto"
  ];
  
  final List<String> sujetos = [
    "del samurái", "de los neones", "del faraón", "del hacker", 
    "de la inteligencia artificial", "del chamán", "del astronauta", 
    "del viejo violín", "del mapa perdido", "del último tren"
  ];
  
  final List<String> lugares = [
    "en las calles de Tokio", "bajo el cielo de París", "en el desierto del Sahara", 
    "en una estación espacial", "en lo profundo del Amazonas", "en el corazón de Nueva York", 
    "bajo el hielo de la Antártida", "en un templo en Kioto", "en el Barrio Limoncito" // Dejamos el toque local ;)
  ];

  // --- MATRIZ DE PERSONAJES DIVERSOS ---
  final List<String> p1 = ["Un nómada del desierto", "Una detective cibernética", "Un monje tibetano", "Un astronauta retirado", "Una chef de Lyon"];
  final List<String> p2 = ["un cuervo mecánico", "una reliquia prohibida", "un mensaje del futuro", "un gato que habla", "un violín de oro"];
  final List<String> p3 = ["un espía de la Guerra Fría", "una inteligencia artificial", "un guardián de sueños", "un extraño sin sombra"];

  // --- CATEGORÍAS PARA TODOS LOS GUSTOS ---
  final List<String> categorias = [
    "Ciencia Ficción", "Terror", "Fantasía", "Romance", "Suspenso", 
    "Mitología", "Cyberpunk", "Histórico", "Drama", "Aventura"
  ];

  // COMBINACIÓN ALEATORIA TOTAL
  String tituloGenerado = "${inicios[random.nextInt(inicios.length)]} ${sujetos[random.nextInt(sujetos.length)]} ${lugares[random.nextInt(lugares.length)]}";
  
  String personajesGenerados = "${p1[random.nextInt(p1.length)]}, ${p2[random.nextInt(p2.length)]} y ${p3[random.nextInt(p3.length)]}";
  
  String categoriaElegida = categorias[random.nextInt(categorias.length)];

  // CREAR LA SALA
  var docRef = await FirebaseFirestore.instance.collection('juegos_colaborativos').add({
    'estado': 'esperando',
    'participantes': [user.uid],
    'participantesNombres': [user.displayName ?? "Escritor Global"],
    'tituloJuego': tituloGenerado, 
    'personajesSugeridos': personajesGenerados, 
    'categoria': categoriaElegida, 
    'turnoActualIndice': 0,
    'textoAcumulado': "",
  });
  _juegoId = docRef.id;
}

    // Ya encontramos/creamos sala, mostramos la interfaz
    if (mounted) {
      setState(() {
        _buscando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_buscando || _juegoId == null) {
      return Scaffold(
        backgroundColor: backgroundCream,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: matteGold),
              const SizedBox(height: 20),
              Text("Conectando con el servidor...", style: TextStyle(color: inkBlue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // Escuchamos la sala en tiempo real
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('juegos_colaborativos').doc(_juegoId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        List nombres = data['participantesNombres'] ?? [];
        String estado = data['estado'] ?? 'esperando';

        // ¡LA MAGIA DE INICIAR EL JUEGO!
        // Si la sala se llena, mandamos a todos al GameScreen al mismo tiempo
        if (estado == 'en_curso' && !_navegando) {
          _navegando = true; // Bloqueamos para que no abra mil pantallas
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => GameScreen(juegoId: _juegoId!)),
            );
          });
        }

        return Scaffold(
          backgroundColor: backgroundCream,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: inkBlue),
          ),
          body: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.diversity_3, size: 80, color: matteGold),
                const SizedBox(height: 20),
                Text(
                  "SALA DE ESCRITORES", 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: inkBlue, letterSpacing: 2)
                ),
                const SizedBox(height: 10),
                const Text(
                  "Esperando a que se unan 5 mentes creativas para comenzar la historia...",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5),
                ),
                const SizedBox(height: 40),

                // Contador gigante (Ej: 1/5)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: inkBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${nombres.length} / 5",
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: inkBlue),
                  ),
                ),
                const SizedBox(height: 40),

                // Lista de los que ya están en la sala
                Expanded(
                  child: ListView.builder(
                    itemCount: nombres.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: inkBlue,
                          child: Text(
                            nombres[index].toString().substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(nombres[index], style: TextStyle(fontWeight: FontWeight.bold, color: inkBlue)),
                        subtitle: Text(index == 0 ? "Anfitrión" : "Escritor", style: const TextStyle(fontSize: 11)),
                        trailing: index == nombres.length - 1 
                          ? const Text("Acaba de entrar", style: TextStyle(color: Colors.green, fontSize: 10))
                          : null,
                      );
                    },
                  ),
                ),

                // Indicador de espera
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: matteGold)),
                    const SizedBox(width: 10),
                    const Text("Buscando autores...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}