import 'package:flutter/material.dart';
import 'dart:convert'; 
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'book_details_screen.dart';
import 'messages_screen.dart';
import 'create_thread_screen.dart';
import 'game_screen.dart';
import 'game_lobby_screen.dart';
import 'search_screen.dart';
import 'other_profile_screen.dart'; 
import 'serious_game_screen.dart';
import 'serious_lobby_screen.dart'; // NAVEGACIÓN A LA SALA DE ESPERA

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- PALETA OFICIAL NOA ---
  final Color navyNoa = const Color(0xFF111827); // Tu color oficial
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color matteGold = const Color(0xFFC4A77D);
  final Color tealNoa = const Color(0xFF009688);

  final ScrollController _scrollController = ScrollController();
  final List<DocumentSnapshot> _hilos = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _ultimoDocumento;
  final int _limitePorPagina = 10; 

  @override
  void initState() {
    super.initState();
    _cargarHilos();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _cargarHilos();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _irAlPerfil(BuildContext context, String autorId) {
    final miId = FirebaseAuth.instance.currentUser?.uid;
    if (autorId.isNotEmpty && autorId != miId) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: autorId)));
    }
  }

  // OPTIMIZACIÓN: Carga inteligente de imágenes BLINDADA (No crashea si hay error)
  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.isEmpty) return const AssetImage('assets/images/logoNOA.png');
    if (imageData.startsWith('http')) {
      return CachedNetworkImageProvider(imageData);
    } else {
      try {
        // El .trim() es vital para que no dé error por espacios invisibles
        return MemoryImage(base64Decode(imageData.trim()));
      } catch (e) {
        return const AssetImage('assets/images/logoNOA.png');
      }
    }
  }

  Future<void> _toggleCommentLike(String hId, String cId, bool l, String? u) async {
    if (u == null) return;
    try {
      DocumentReference r = FirebaseFirestore.instance.collection('hilos').doc(hId).collection('comentarios').doc(cId);
      l ? await r.update({'likedBy': FieldValue.arrayRemove([u])}) : await r.update({'likedBy': FieldValue.arrayUnion([u])});
    } catch (e) {
      debugPrint("Error al dar like: $e");
    }
  }

  Future<void> _cargarHilos() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance.collection('hilos').orderBy('fecha', descending: true).limit(_limitePorPagina);
      if (_ultimoDocumento != null) query = query.startAfterDocument(_ultimoDocumento!);
      QuerySnapshot snapshot = await query.get();
      if (snapshot.docs.length < _limitePorPagina) _hasMore = false;
      if (snapshot.docs.isNotEmpty) {
        _ultimoDocumento = snapshot.docs.last;
        _hilos.addAll(snapshot.docs);
      }
    } catch (e) { 
      debugPrint("Error cargando hilos: $e"); 
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refrescarFeed() async {
    setState(() { _hilos.clear(); _ultimoDocumento = null; _hasMore = true; });
    await _cargarHilos();
  }

  // --- SISTEMA DE PROPINAS BLINDADO ---
  void _mostrarDialogoPropina(BuildContext context, String autorId, String autorNombre, String hiloId) {
    final miId = FirebaseAuth.instance.currentUser?.uid;
    if (miId == null) return;
    
    if (miId == autorId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No puedes darte propina a ti mismo.")));
      return;
    }

    int cantidadElegida = 10; 
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: !isProcessing,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: backgroundCream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text("Dar propina a $autorNombre", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 16)),
              content: isProcessing
                ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("¡Apoya a este autor regalándole Noa Coins!", style: TextStyle(fontSize: 13)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [10, 50, 100].map((valor) {
                          return ChoiceChip(
                            label: Text("$valor", style: TextStyle(color: cantidadElegida == valor ? Colors.white : navyNoa, fontWeight: FontWeight.bold)),
                            selected: cantidadElegida == valor,
                            selectedColor: matteGold,
                            backgroundColor: Colors.transparent,
                            side: BorderSide(color: matteGold),
                            onSelected: (selected) {
                              if (selected) setStateDialog(() => cantidadElegida = valor);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
              actions: isProcessing ? [] : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: navyNoa, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    setStateDialog(() => isProcessing = true);
                    await _procesarPropina(miId, autorId, autorNombre, cantidadElegida);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("ENVIAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  // OPTIMIZACIÓN: runTransaction para que no se pierdan monedas
  Future<void> _procesarPropina(String miId, String autorId, String autorNombre, int cantidad) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference miRef = FirebaseFirestore.instance.collection('usuarios').doc(miId);
        DocumentReference autorRef = FirebaseFirestore.instance.collection('usuarios').doc(autorId);

        DocumentSnapshot miDoc = await transaction.get(miRef);
        if (!miDoc.exists) throw Exception("Usuario emisor no encontrado");
        
        int miSaldo = miDoc.get('noaCoins') ?? 0;
        String miNombre = miDoc.get('nombre') ?? "Un usuario";

        if (miSaldo < cantidad) {
          throw Exception("SaldoInsuficiente"); 
        }

        transaction.update(miRef, {'noaCoins': FieldValue.increment(-cantidad)});
        transaction.update(autorRef, {'noaCoins': FieldValue.increment(cantidad)});
        
        DocumentReference notifRef = FirebaseFirestore.instance.collection('usuarios').doc(autorId).collection('notificaciones').doc();
        transaction.set(notifRef, {
          'titulo': '¡Recibiste una propina! 🪙',
          'mensaje': '$miNombre te ha enviado $cantidad Noa Coins en uno de tus hilos.',
          'fecha': FieldValue.serverTimestamp(),
          'leida': false,
          'tipo': 'compra_obra',
        });
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡Enviaste $cantidad coins a $autorNombre!"), backgroundColor: matteGold));
    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString().contains("SaldoInsuficiente") 
          ? "No tienes suficientes Noa Coins." 
          : "Error al enviar propina.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
      }
    }
  }
  // ------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: backgroundCream, elevation: 0, centerTitle: true,
          title: Image.asset(
            'assets/images/logoNOA.png',
            height: 150, 
            fit: BoxFit.contain,
          ),
          leading: Builder(
            builder: (BuildContext context) {
              final TabController tabController = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: tabController,
                builder: (context, child) {
                  bool esComunidad = tabController.index == 0;
                  return IconButton(
                    icon: Icon(esComunidad ? Icons.add_comment_outlined : Icons.search, color: navyNoa, size: 20), 
                    onPressed: () async {
                      if (esComunidad) {
                        bool? publicoAlgo = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateThreadScreen()));
                        if (publicoAlgo == true) _refrescarFeed();
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen()));
                      }
                    },
                  );
                },
              );
            },
          ),
          actions: [
            IconButton(icon: Icon(Icons.chat_bubble_outline, color: navyNoa, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MessagesScreen()))),
          ],
          bottom: TabBar(
            indicatorColor: matteGold, labelColor: navyNoa, unselectedLabelColor: tealNoa,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 11),
            tabs: const [Tab(text: "COMUNIDAD"), Tab(text: "OBRAS")],
          ),
        ),
        body: TabBarView(children: [_buildComunidadTab(context), _buildLibreriaGlobal()]),
      ),
    );
  }

  Widget _buildComunidadTab(BuildContext context) {
    if (_hilos.isEmpty && _isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _refrescarFeed, color: navyNoa,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _hilos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _hilos.length) return Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: matteGold)));
          var data = _hilos[index].data() as Map<String, dynamic>;
          return _buildHiloItem(context, data, _hilos[index].id);
        },
      ),
    );
  }

  Widget _buildHiloItem(BuildContext context, Map<String, dynamic> data, String docId) {
    final user = FirebaseAuth.instance.currentUser;
    List likedBy = data['likedBy'] ?? [];
    bool isLiked = user != null && likedBy.contains(user.uid);
    String autorId = data['autorId'] ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(autorId).snapshots(),
      builder: (context, userSnap) {
        var userMap = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        String foto = userMap['fotoPerfilUrl'] ?? 
              userMap['fotoBase64'] ?? 
              userMap['foto'] ?? // <-- ESTE ES EL QUE TE FALTA EN EL HOME
              userMap['fotoPerfil'] ?? 
              '';
        String nombreActual = userMap['nombre'] ?? data['autorNombre'] ?? "Usuario";
        
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _irAlPerfil(context, autorId),
                child: CircleAvatar(
                  radius: 18, 
                  backgroundColor: const Color(0xFF111827), // Tu color oficial
                  // La función inteligente ahora se encarga de todo de forma segura
                  backgroundImage: _obtenerImagenInteligente(foto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(onTap: () => _irAlPerfil(context, autorId), child: Text(nombreActual, style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 5),
                    Text(data['texto'] ?? ""),
                    
                    // --- AQUÍ ESTÁ EL ARREGLO FINAL DE LA IMAGEN DE LOS HILOS ---
                    // Busca donde muestras la imagen del hilo y pon esto:
                      // ESTO REEMPLAZA TU LÍNEA 235
                      // REEMPLAZA LA LÍNEA 231 POR ESTA SEGURA:
                      if (data['imagenAdjunta'] != null && data['imagenAdjunta'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10), 
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              image: _obtenerImagenInteligente(data['imagenAdjunta']), 
                              fit: BoxFit.cover
                            ),
                          ),
                        ),
                    // -------------------------------------------------------------

                    const SizedBox(height: 12),
                    
                    Row(children: [
                      GestureDetector(
                        onTap: () async {
                          try {
                            await FirebaseFirestore.instance.collection('hilos').doc(docId).update({ 'likedBy': isLiked ? FieldValue.arrayRemove([user?.uid]) : FieldValue.arrayUnion([user?.uid]) });
                          } catch (e) { debugPrint("Error: $e"); }
                        }, 
                        child: Row(children: [Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.red : Colors.grey, size: 20), const SizedBox(width: 5), Text("${likedBy.length}", style: const TextStyle(fontSize: 12, color: Colors.grey))])
                      ),
                      const SizedBox(width: 25),
                      GestureDetector(onTap: () => _mostrarComentarios(context, docId, navyNoa), child: const Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey)),
                      const SizedBox(width: 25),
                      GestureDetector(onTap: () => Share.share("${data['texto']}\n\nEscrito por: $nombreActual en NOA"), child: const Icon(Icons.share_outlined, size: 20, color: Colors.grey)),
                      const SizedBox(width: 25),
                      GestureDetector(
                        onTap: () => _mostrarDialogoPropina(context, autorId, nombreActual, docId), 
                        child: const Icon(Icons.volunteer_activism_outlined, size: 20, color: Colors.orange)
                      ),
                      
                      // --- EL BOTÓN MÁGICO CON SEGURIDAD ---
                      if (autorId == user?.uid) ...[
                        const SizedBox(width: 25),
                        GestureDetector(
                          onTap: () => _mostrarConfirmacionEliminar(docId),
                          child: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                        ),
                      ]
                    ])
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  // OPTIMIZACIÓN: Comentarios Anti-Spam
  void _mostrarComentarios(BuildContext context, String docId, Color colorPrimario) {
    final ctrl = TextEditingController();
    final miId = FirebaseAuth.instance.currentUser?.uid;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        bool estaEnviando = false; 

        return StatefulBuilder(builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: 450, padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text("COMENTARIOS", style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('hilos').doc(docId).collection('comentarios').orderBy('fecha').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var d = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      String cId = snapshot.data!.docs[index].id;
                      String cAutorId = d['autorId'] ?? "";
                      List lBy = d['likedBy'] ?? [];
                      bool liked = miId != null && lBy.contains(miId);

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('usuarios').doc(cAutorId).snapshots(),
                        builder: (context, uSnap) {
                          var uData = uSnap.data?.data() as Map<String, dynamic>? ?? {};
                          String f = uData['fotoPerfilUrl'] ?? uData['fotoBase64'] ?? "";
                          String n = uData['nombre'] ?? "Usuario";
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: GestureDetector(
                              onTap: () => _irAlPerfil(context, cAutorId), 
                              child: CircleAvatar(
                                radius: 15, backgroundColor: colorPrimario,
                                backgroundImage: f.isNotEmpty ? _obtenerImagenInteligente(f) : null, 
                                child: f.isEmpty ? const Icon(Icons.person, size: 15, color: Colors.white) : null
                              )
                            ),
                            title: GestureDetector(onTap: () => _irAlPerfil(context, cAutorId), child: Text(n, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            subtitle: Text(d['texto'] ?? ""),
                            trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              GestureDetector(onTap: () => _toggleCommentLike(docId, cId, liked, miId), child: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.red : Colors.grey, size: 16)),
                              Text("${lBy.length}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ]),
                          );
                        }
                      );
                    }
                  );
                }
              )),
              TextField(
                controller: ctrl, 
                decoration: InputDecoration(
                  hintText: "Escribe un comentario...", 
                  suffixIcon: estaEnviando
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: const Icon(Icons.send), onPressed: () async {
                        if (ctrl.text.trim().isNotEmpty && miId != null) {
                          setMState(() => estaEnviando = true);
                          try {
                            final uDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miId).get();
                            await FirebaseFirestore.instance.collection('hilos').doc(docId).collection('comentarios').add({
                              'texto': ctrl.text.trim(), 
                              'autorId': miId, 
                              'autorNombre': uDoc.data()?['nombre'] ?? "Usuario",
                              'fecha': FieldValue.serverTimestamp(), 
                              'likedBy': []
                            });
                            ctrl.clear();
                          } catch (e) {
                            debugPrint("Error al comentar: $e");
                          } finally {
                            setMState(() => estaEnviando = false);
                          }
                        }
                      })
                )
              )
            ]),
          ),
        ));
      }
    );
  }

  Widget _buildLibreriaGlobal() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final libros = snapshot.data!.docs;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 20), 
          children: [
            _buildBannerCaos(),   
            _buildBannerSerio(),  
            const SizedBox(height: 30),
            _buildSeccionHorizontal("Las mejores selecciones para ti", libros),
          ]
        );
      }
    );
  }

  Widget _buildSeccionHorizontal(String t, List<DocumentSnapshot> l) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
      const SizedBox(height: 15),
      SizedBox(height: 240, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: l.length, itemBuilder: (context, i) {
        var d = l[i].data() as Map<String, dynamic>;
        return _buildLibroCardHome(d, l[i].id);
      }))
    ]);
  }

  Widget _buildLibroCardHome(Map<String, dynamic> libro, String id) {
    String fotoPortada = libro['portadaUrl'] ?? libro['portada'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BookDetailsScreen(
        obraId: id, 
        autorId: libro['autorId'] ?? '', 
        titulo: libro['titulo'] ?? "",
        autor: libro['autorNombre'] ?? "Escritor", 
        sinopsis: libro['sinopsis'] ?? "",
        precioNoaCoins: libro['precioNoaCoins'] ?? 0, 
        monetizacionTipo: libro['monetizacionTipo'] ?? "libro_completo",
        esGratis: libro['esGratis'] ?? true,
        yaCompradoInicial: false, 
      ))),
      child: Container(
        width: 120, 
        margin: const EdgeInsets.only(right: 15), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Container(
              height: 180, 
              width: 120, 
              decoration: BoxDecoration(
                color: navyNoa, 
                borderRadius: BorderRadius.circular(8), 
                image: fotoPortada.isNotEmpty
                  ? DecorationImage(image: _obtenerImagenInteligente(fotoPortada), fit: BoxFit.cover) 
                  : null
              ), 
              child: fotoPortada.isEmpty ? const Icon(Icons.book, color: Colors.white24) : null
            ),
            const SizedBox(height: 8),
            Text(
              libro['titulo'] ?? "", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: navyNoa), 
              maxLines: 2, 
              overflow: TextOverflow.ellipsis
            ),
          ]
        )
      ),
    );
  }

  Widget _buildBannerCaos() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1B3D4D), Color(0xFF2A5A70)]), 
        borderRadius: BorderRadius.circular(15)
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("MODO CAOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const Text("Escribe rápido y sin filtros con otros.", style: TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GameLobbyScreen())), 
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B3D4D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("JUGAR AHORA")
          )
        ])),
        const Icon(Icons.bolt, color: Colors.white24, size: 50)
      ]),
    );
  }

  Widget _buildBannerSerio() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF009688), Color(0xFF00695C)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "MODO SERIO",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text(
                  "Crea capítulos coherentes con otros escritores.",
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SeriousLobbyScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF00695C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("INICIAR OBRA"),
                )
              ],
            ),
          ),
          const Icon(Icons.history_edu, color: Colors.white24, size: 50),
        ],
      ),
    );
  }
  // --- FUNCIONES DE ELIMINACIÓN PARA EL HOME ---

  Future<void> _eliminarHilo(String docId) async {
  try {
    // 1. Borrado en la base de datos
    await FirebaseFirestore.instance.collection('hilos').doc(docId).delete();
    
    // 2. Borrado LOCAL e INSTANTÁNEO (Sin pestañeo)
    setState(() {
      _hilos.removeWhere((doc) => doc.id == docId);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Hilo eliminado"), backgroundColor: Colors.redAccent),
    );
  } catch (e) {
    debugPrint("Error: $e");
  }
}

  void _mostrarConfirmacionEliminar(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundCream,
        title: const Text("¿Eliminar hilo?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarHilo(docId);
            },
            child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}