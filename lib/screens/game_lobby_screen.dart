import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'game_screen.dart';
import 'dart:convert'; // <--- ¡Añade esto para que reconozca base64Decode!

class GameLobbyScreen extends StatefulWidget {
  const GameLobbyScreen({super.key});

  @override
  State<GameLobbyScreen> createState() => _GameLobbyScreenState();
}

// ¡AQUÍ ESTÁ LA ÚNICA CLASE! Ya tiene el "with WidgetsBindingObserver"
class _GameLobbyScreenState extends State<GameLobbyScreen> with WidgetsBindingObserver {
  final Color navyNoa = const Color(0xFF111827); 
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  String? _juegoId;
  bool _buscando = true;
  bool _navegando = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 1. Registramos el observador
    _buscarOCrearSala();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 2. Limpiamos al salir
    super.dispose();
  }

  // 3. El detector automático: si minimiza la app, lo sacamos de la sala
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _salirDeSala();
    }
  }

  // --- LIMPIEZA DE SALA (AL SALIR O MINIMIZAR) ---
  Future<void> _salirDeSala() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _juegoId != null) {
      try {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference salaRef = FirebaseFirestore.instance.collection('juegos_colaborativos').doc(_juegoId);
          DocumentSnapshot salaSnap = await transaction.get(salaRef);
          
          if (salaSnap.exists && salaSnap['estado'] == 'esperando') {
            List participantes = List.from(salaSnap['participantes'] ?? []);
            List nombres = List.from(salaSnap['participantesNombres'] ?? []);
            List votos = List.from(salaSnap['votosInicio'] ?? []);

            int index = participantes.indexOf(user.uid);
            if (index != -1) {
              participantes.removeAt(index);
              nombres.removeAt(index);
              votos.remove(user.uid);

              if (participantes.isEmpty) {
                transaction.delete(salaRef); // Si queda vacía, la destruimos
              } else {
                transaction.update(salaRef, {
                  'participantes': participantes,
                  'participantesNombres': nombres,
                  'votosInicio': votos
                });
              }
            }
          }
        });
      } catch (e) {
        debugPrint("Error al limpiar sala: $e");
      }
    }
  }

  // --- LÓGICA DE MATCHMAKING CON FILTRO ANTI-FANTASMAS ---
  Future<void> _buscarOCrearSala() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Solo buscamos salas activas en los últimos 5 minutos
    DateTime haceCincoMinutos = DateTime.now().subtract(const Duration(minutes: 5));

    var query = await FirebaseFirestore.instance
        .collection('juegos_colaborativos')
        .where('estado', isEqualTo: 'esperando')
        .where('ultimaActividad', isGreaterThan: Timestamp.fromDate(haceCincoMinutos))
        .orderBy('ultimaActividad', descending: true)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      _juegoId = query.docs.first.id;
      await _unirseASalaExistente(_juegoId!, user);
    } else {
      await _crearNuevaSala(user);
    }

    if (mounted) setState(() => _buscando = false);
  }

  Future<void> _unirseASalaExistente(String id, User user) async {
    try {
      // 1. Buscamos el nombre configurado en el perfil del usuario en Firestore
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      
      // Si el usuario no tiene nombre en la base de datos, usamos un backup
      final String miNombreReal = userDoc.data()?['nombre'] ?? user.displayName ?? "Escritor";

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference ref = FirebaseFirestore.instance.collection('juegos_colaborativos').doc(id);
        DocumentSnapshot snap = await transaction.get(ref);
        
        if (!snap.exists) return;

        List participantes = List.from(snap['participantes'] ?? []);
        List nombres = List.from(snap['participantesNombres'] ?? []);

        // Verificamos que no estemos ya en la lista y que haya espacio
        if (!participantes.contains(user.uid) && participantes.length < 5) {
          participantes.add(user.uid);
          nombres.add(miNombreReal); // <--- Aquí inyectamos el nombre real

          transaction.update(ref, {
            'participantes': participantes,
            'participantesNombres': nombres,
            'ultimaActividad': FieldValue.serverTimestamp(), 
          });
        }
      });
    } catch (e) {
      debugPrint("Error al unirse a sala: $e");
      // Si algo falla, reintentamos el matchmaking para buscar otra sala
      _buscarOCrearSala();
    }
  }

  Future<void> _crearNuevaSala(User user) async {
  final random = Random();

  // 1. OBTENER EL NOMBRE REAL DEL AUTOR DESDE TU COLECCIÓN
  final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
  final String miNombreReal = userDoc.data()?['nombre'] ?? "Escritor Global";

  // 2. MATRIZ EXPANDIDA PARA TÍTULOS (Variedad infinita)
  final List<String> inicios = [
    "El susurro", "La caída", "El renacer", "La última sombra", "El código", 
    "La danza", "El grito", "El pacto", "La leyenda", "El misterio", 
    "La rebelión", "El eco", "La agonía", "El despertar", "La profecía"
  ];
  
  final List<String> sujetos = [
    "del samurái", "de los neones", "del faraón", "del hacker", "de la IA", 
    "del chamán", "del astronauta", "del viejo violín", "del mapa perdido", 
    "del último tren", "del ángel caído", "del cuervo blanco", "del reloj de arena"
  ];
  
  final List<String> lugares = [
    "en las calles de Tokio", "bajo el cielo de París", "en el desierto de sal", 
    "en una estación espacial", "en lo profundo del Amazonas", "en Nueva York", 
    "bajo el hielo de la Antártida", "en un templo oculto", "en el Barrio Limoncito",
    "en la ciudad de cristal", "en el fin del mundo", "en un sueño lúcido"
  ];

  // 3. POOL DE PERSONAJES Y ELEMENTOS (Para que la misión sea distinta siempre)
  final List<String> personajesPool = [
    "Un nómada", "Una detective", "Un monje", "Un astronauta", "Una chef", 
    "Un cuervo", "Una IA rebelde", "Un espía", "Un coleccionista de almas",
    "Una bailarina mecánica", "Un viajero del tiempo", "Un bibliotecario ciego"
  ];
  
  final List<String> elementosPool = [
    "Un reloj roto", "Una carta antigua", "Un archivo encriptado", "Un arma dorada",
    "Una máscara de gas", "Un girasol azul", "Una llave de plata", "Un frasco de arena"
  ];

  // Lógica de mezcla
  personajesPool.shuffle();
  String p1 = personajesPool[0];
  String p2 = personajesPool[1];
  String elemento = elementosPool[random.nextInt(elementosPool.length)];

  // Generación del título épico
  String tituloGenerado = "${inicios[random.nextInt(inicios.length)]} ${sujetos[random.nextInt(sujetos.length)]} ${lugares[random.nextInt(lugares.length)]}";
  
  // 4. CREACIÓN EN FIRESTORE CON DATOS REALES
  var docRef = await FirebaseFirestore.instance.collection('juegos_colaborativos').add({
    'estado': 'esperando',
    'modo': 'caos',
    'participantes': [user.uid],
    'participantesNombres': [miNombreReal], // <--- Ahora sale el nombre del usuario
    'votosInicio': [], 
    'tituloJuego': tituloGenerado.toUpperCase(), // Se ve más imponente en mayúsculas
    'personajesAsignados': "$p1 y $p2", 
    'elementoObligatorio': elemento,
    'turnoActualIndice': 0,
    'textoAcumulado': "",
    'ultimaActividad': FieldValue.serverTimestamp(),
    'creadoEn': FieldValue.serverTimestamp()
  });
  
  _juegoId = docRef.id;
}

  Future<void> _votarInicio(List votosActuales) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && !votosActuales.contains(uid)) {
      votosActuales.add(uid);
      bool arrancar = votosActuales.length >= 3;
      await FirebaseFirestore.instance.collection('juegos_colaborativos').doc(_juegoId).update({
        'votosInicio': FieldValue.arrayUnion([uid]),
        'ultimaActividad': FieldValue.serverTimestamp(),
        if (arrancar) 'estado': 'en_curso',
        if (arrancar) 'turnoIniciadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_buscando || _juegoId == null) {
      return Scaffold(
        backgroundColor: backgroundCream,
        body: Center(child: CircularProgressIndicator(color: matteGold)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _salirDeSala();
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('juegos_colaborativos').doc(_juegoId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          List nombres = List.from(data['participantesNombres'] ?? []);
          List participantes = List.from(data['participantes'] ?? []);
          List votos = List.from(data['votosInicio'] ?? []);
          String estado = data['estado'] ?? 'esperando';

          if (estado == 'en_curso' && !_navegando) {
            _navegando = true; 
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => GameScreen(juegoId: _juegoId!)));
            });
          }

          bool puedoVotar = participantes.length >= 3;
          bool yaVote = votos.contains(FirebaseAuth.instance.currentUser?.uid);

          return Scaffold(
            backgroundColor: backgroundCream,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: navyNoa),
            ),
            body: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.bolt, size: 80, color: matteGold),
                  const SizedBox(height: 20),
                  Text("MODO CAOS", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: navyNoa, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  const Text("Se requieren al menos 3 autores para iniciar la locura...", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
                  const SizedBox(height: 40),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: navyNoa.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text("${nombres.length} / 5", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: navyNoa)),
                  ),
                  const SizedBox(height: 20),

                  Expanded(
                    child: ListView.builder(
                      itemCount: participantes.length, // Usamos la lista de IDs
                      itemBuilder: (context, index) {
                        String uid = participantes[index];
                        
                        // Consultamos los datos de cada usuario en tiempo real (foto y nombre)
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('usuarios').doc(uid).snapshots(),
                          builder: (context, userSnap) {
                            var userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                            String nombre = userData['nombre'] ?? "Escritor";
                            String foto = userData['fotoPerfilUrl'] ?? userData['fotoBase64'] ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: navyNoa,
                                backgroundImage: foto.isNotEmpty 
                                  ? (foto.startsWith('http') 
                                      ? NetworkImage(foto) 
                                      : MemoryImage(base64Decode(foto)) as ImageProvider)
                                  : null,
                                child: foto.isEmpty 
                                  ? Text(nombre.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white)) 
                                  : null,
                              ),
                              title: Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa)),
                              subtitle: Text(index == 0 ? "Anfitrión" : "Colaborador", style: const TextStyle(fontSize: 11)),
                              trailing: index == nombres.length - 1 && index != 0
                                ? const Text("Nuevo", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold))
                                : null,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  if (puedoVotar) ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yaVote ? Colors.grey : navyNoa,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)
                      ),
                      onPressed: yaVote ? null : () => _votarInicio(votos),
                      child: Text(yaVote ? "ESPERANDO VOTOS (${votos.length}/${participantes.length})" : "VOTAR PARA INICIAR", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: matteGold)),
                        const SizedBox(width: 10),
                        const Text("Esperando a más autores...", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}