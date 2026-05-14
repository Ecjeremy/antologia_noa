import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'connections_screen.dart'; 
import 'book_details_screen.dart';
import 'wallet_screen.dart';
import 'other_profile_screen.dart';
import 'publish_book_screen.dart'; 
import 'notifications_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- PALETA OFICIAL NOA ---
  final Color navyNoa = const Color(0xFF111827); // Azul oscuro exigido
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  void _irAlPerfil(BuildContext context, String autorId) {
    final miId = FirebaseAuth.instance.currentUser?.uid;
    if (autorId.isNotEmpty && autorId != miId) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: autorId)));
    }
  }

  Future<void> _toggleCommentLike(String hId, String cId, bool l, String? u) async {
    if (u == null) return;
    try {
      DocumentReference r = FirebaseFirestore.instance.collection('hilos').doc(hId).collection('comentarios').doc(cId);
      l ? await r.update({'likedBy': FieldValue.arrayRemove([u])}) : await r.update({'likedBy': FieldValue.arrayUnion([u])});
    } catch (e) {
      debugPrint("Error actualizando like: $e");
    }
  }

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.startsWith('http')) {
      return CachedNetworkImageProvider(imageData);
    } else {
      return MemoryImage(base64Decode(imageData));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Inicia sesión para continuar")));

    return DefaultTabController(
      length: 3, 
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: Colors.transparent, elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.notifications_none_outlined, color: navyNoa), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()))
            ),
            IconButton(
              icon: Icon(Icons.settings_outlined, color: navyNoa), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))
            )
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            String fotoPerfil = userData['fotoPerfilUrl'] ?? userData['fotoBase64'] ?? '';
            
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeader(userData, fotoPerfil),
                        const SizedBox(height: 20),
                        _buildStats(userData, user.uid),
                        const SizedBox(height: 15),
                      ],
                    ),
                  ),
                  SliverAppBar(
                    backgroundColor: backgroundCream,
                    pinned: true,
                    elevation: innerBoxIsScrolled ? 2 : 0, 
                    toolbarHeight: 0, 
                    bottom: TabBar(
                      indicatorColor: navyNoa, 
                      indicatorWeight: 2, 
                      labelColor: navyNoa, 
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
                      tabs: const [Tab(text: "ACTIVIDAD"), Tab(text: "MI LIBRERÍA"), Tab(text: "FAVORITOS")],
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  _buildFeedActividad(user.uid), 
                  _buildLibreriaVenta(user.uid, userData),
                  _buildFavoritos(user.uid)
                ]
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> userData, String foto) {
    int saldoCoins = userData['noaCoins'] ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 0),
          child: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => _abrirBilletera(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: matteGold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: matteGold, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.toll, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text("$saldoCoins", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
        CircleAvatar(
          radius: 45, backgroundColor: navyNoa,
          backgroundImage: foto.isNotEmpty ? _obtenerImagenInteligente(foto) : null,
          child: foto.isEmpty ? const Icon(Icons.person, size: 45, color: Colors.white) : null,
        ),
        const SizedBox(height: 12),
        // OPTIMIZACIÓN: Null Safety robusto
        Text(userData['nombre'] ?? "Usuario NOA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navyNoa, fontFamily: 'serif')),
        Text("${userData['bio'] ?? 'Escritor'} • ${userData['ubicacion'] ?? 'Zaruma, Ecuador'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.black12)), child: Text("EDITAR PERFIL", style: TextStyle(color: navyNoa, fontSize: 11, fontWeight: FontWeight.bold))),
      ],
    );
  }

  Widget _buildStats(Map<String, dynamic> userData, String userId) {
    int o = userData['obras'] ?? 0; int s1 = userData['seguidores'] ?? 0; int s2 = userData['siguiendo'] ?? 0;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _statItem(o < 0 ? "0" : "$o", "OBRAS", null),
      _statItem(s1 < 0 ? "0" : "$s1", "SEGUIDORES", () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectionsScreen(userId: userId, initialIndex: 0)))),
      _statItem(s2 < 0 ? "0" : "$s2", "SIGUIENDO", () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectionsScreen(userId: userId, initialIndex: 1)))),
    ]);
  }

  Widget _statItem(String v, String e, VoidCallback? t) => GestureDetector(onTap: t, child: Container(color: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Column(children: [Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyNoa)), Text(e, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))])));

  Widget _buildFeedActividad(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hilos').where('autorId', isEqualTo: userId).orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No hay publicaciones aún."));
        
        // OPTIMIZACIÓN: RefreshIndicator en el feed
        return RefreshIndicator(
          color: matteGold,
          onRefresh: () async {
            // El stream se actualiza solo, pero esto da feedback visual al usuario
            await Future.delayed(const Duration(seconds: 1)); 
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 50), 
            itemCount: docs.length, 
            itemBuilder: (context, index) => _buildThreadsItem(docs[index].data() as Map<String, dynamic>, userId, docs[index].id)
          ),
        );
      },
    );
  }

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
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
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

  // OPTIMIZACIÓN: runTransaction como un banco real
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
          throw Exception("SaldoInsuficiente"); // Throw especial para capturarlo abajo
        }

        // Restamos al emisor y sumamos al receptor en una sola operación blindada
        transaction.update(miRef, {'noaCoins': FieldValue.increment(-cantidad)});
        transaction.update(autorRef, {'noaCoins': FieldValue.increment(cantidad)});
        
        // Notificación
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

  Widget _buildThreadsItem(Map<String, dynamic> data, String autorId, String docId) {
    final user = FirebaseAuth.instance.currentUser;
    List likedBy = data['likedBy'] ?? [];
    bool isLiked = user != null && likedBy.contains(user.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(autorId).snapshots(),
      builder: (context, userSnap) {
        var userMap = userSnap.data?.data() as Map<String, dynamic>? ?? {};
        String nombreActual = userMap['nombre'] ?? data['autorNombre'] ?? "Usuario";
        String fotoActual = userMap['fotoPerfilUrl'] ?? userMap['fotoBase64'] ?? data['autorFoto'] ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18, backgroundColor: navyNoa,
                backgroundImage: fotoActual.isNotEmpty ? _obtenerImagenInteligente(fotoActual) : null,
                child: fotoActual.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombreActual, style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa, fontSize: 13)),
                    const SizedBox(height: 4),
                    if (data['texto'] != null) Text(data['texto'], style: const TextStyle(fontSize: 14, height: 1.3)),
                    if (data['imagenAdjunta'] != null && data['imagenAdjunta'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(data['imagenAdjunta']), fit: BoxFit.cover),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => FirebaseFirestore.instance.collection('hilos').doc(docId).update({ 'likedBy': isLiked ? FieldValue.arrayRemove([user?.uid]) : FieldValue.arrayUnion([user?.uid]) }),
                          child: Row(children: [Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 18, color: isLiked ? Colors.red : Colors.grey), const SizedBox(width: 5), Text("${likedBy.length}", style: const TextStyle(color: Colors.grey, fontSize: 12))]),
                        ),
                        const SizedBox(width: 25),
                        GestureDetector(onTap: () => _mostrarComentarios(context, docId, navyNoa), child: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey)),
                        const SizedBox(width: 25),
                        GestureDetector(onTap: () => Share.share("${data['texto']}\n\nEscrito por: $nombreActual en NOA"), child: const Icon(Icons.share_outlined, size: 18, color: Colors.grey)),
                        const SizedBox(width: 25),
                        GestureDetector(
                          onTap: () => _mostrarDialogoPropina(context, autorId, nombreActual, docId), 
                          child: const Icon(Icons.volunteer_activism_outlined, size: 18, color: Colors.orange)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildLibreriaVenta(String userId, Map<String, dynamic> userData) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').where('autorId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final libros = snapshot.data!.docs;
        if (libros.isEmpty) return const Center(child: Text("Aún no tienes obras publicadas.", style: TextStyle(color: Colors.grey)));
        return GridView.builder(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 50), 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 10, mainAxisSpacing: 15),
          itemCount: libros.length, 
          itemBuilder: (context, index) {
            var libroData = libros[index].data() as Map<String, dynamic>;
            return _buildLibroCard(libroData, libros[index].id, userId, userData);
          },
        );
      },
    );
  }

  Widget _buildLibroCard(Map<String, dynamic> libro, String obraId, String userId, Map<String, dynamic> userData) {
    String fotoPortada = libro['portadaUrl'] ?? libro['portada'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => BookDetailsScreen(
            obraId: obraId,                                 
            autorId: userId,                                
            titulo: libro['titulo'] ?? "Sin título", 
            autor: userData['nombre'] ?? "Escritor", 
            sinopsis: libro['sinopsis'] ?? "Sin sinopsis", 
            contenido: libro['contenido'] ?? "", 
            yaCompradoInicial: true,                        
            esGratis: libro['esGratis'] ?? true, 
            precioNoaCoins: libro['precioNoaCoins'] ?? 0, 
            monetizacionTipo: libro['monetizacionTipo'] ?? "libro_completo"
          )
        )
      ),
      onLongPress: () => _mostrarOpcionesObra(obraId, userId, libro['titulo'] ?? "esta obra"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: navyNoa, 
                    borderRadius: BorderRadius.circular(6), 
                    image: fotoPortada.isNotEmpty ? DecorationImage(image: _obtenerImagenInteligente(fotoPortada), fit: BoxFit.cover) : null
                  ), 
                  child: fotoPortada.isEmpty ? const Center(child: Icon(Icons.book, color: Colors.white24, size: 20)) : null
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => PublishBookScreen(obraId: obraId))); },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            )
          ),
          const SizedBox(height: 5),
          Text(libro['titulo'] ?? "Sin título", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildFavoritos(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').where('favoritosList', arrayContains: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final libros = snapshot.data!.docs;

        if (libros.isEmpty) return const Center(child: Text("No tienes obras en favoritos.", style: TextStyle(color: Colors.grey)));

        return GridView.builder(
          padding: const EdgeInsets.only(left: 15, right: 15, top: 15, bottom: 50), 
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 10, mainAxisSpacing: 15),
          itemCount: libros.length, 
          itemBuilder: (context, index) {
            var libroData = libros[index].data() as Map<String, dynamic>;
            return _buildFavoritoCard(libroData, libros[index].id);
          },
        );
      },
    );
  }

  Widget _buildFavoritoCard(Map<String, dynamic> libro, String obraId) {
    String fotoPortada = libro['portadaUrl'] ?? libro['portada'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => BookDetailsScreen(
            obraId: obraId, autorId: libro['autorId'] ?? '', titulo: libro['titulo'] ?? "Sin título", autor: libro['autorNombre'] ?? "Escritor", 
            sinopsis: libro['sinopsis'] ?? "Sin sinopsis", contenido: libro['contenido'] ?? "", yaCompradoInicial: false,                        
            esGratis: libro['esGratis'] ?? true, precioNoaCoins: libro['precioNoaCoins'] ?? 0, monetizacionTipo: libro['monetizacionTipo'] ?? "libro_completo"
          )
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: navyNoa, borderRadius: BorderRadius.circular(6), image: fotoPortada.isNotEmpty ? DecorationImage(image: _obtenerImagenInteligente(fotoPortada), fit: BoxFit.cover) : null), 
              child: fotoPortada.isEmpty ? const Center(child: Icon(Icons.book, color: Colors.white24, size: 20)) : null
            ),
          ),
          const SizedBox(height: 5),
          Text(libro['titulo'] ?? "Sin título", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, height: 1.1), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  void _mostrarOpcionesObra(String obraId, String userId, String titulo) {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), 
        title: const Text("Opciones de obra", style: TextStyle(fontWeight: FontWeight.bold)), 
        content: Text("¿Qué deseas hacer con '$titulo'?"), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), 
          TextButton(onPressed: () { Navigator.pop(context); _eliminarObra(obraId, userId); }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () { 
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (context) => PublishBookScreen(obraId: obraId)));
            }, 
            child: Text("EDITAR OBRA", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }

  Future<void> _eliminarObra(String obraId, String userId) async {
    try {
      await FirebaseFirestore.instance.collection('obras').doc(obraId).delete();
      final querySnapshot = await FirebaseFirestore.instance.collection('obras').where('autorId', isEqualTo: userId).get();
      await FirebaseFirestore.instance.collection('usuarios').doc(userId).update({'obras': querySnapshot.docs.length});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Obra eliminada")));
    } catch (e) { debugPrint(e.toString()); }
  }

  void _mostrarComentarios(BuildContext context, String docId, Color colorPrimario) {
    final TextEditingController ctrl = TextEditingController();
    final miId = FirebaseAuth.instance.currentUser?.uid;
    
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true, 
      backgroundColor: backgroundCream, 
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
      builder: (context) {
        String? rId; 
        String? rNombre;
        bool estaEnviando = false; // OPTIMIZACIÓN: Bloqueo anti-spam
        
        return StatefulBuilder(builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6, 
            padding: const EdgeInsets.all(20), 
            child: Column(children: [
              const Text("COMENTARIOS", style: TextStyle(fontWeight: FontWeight.bold)), 
              const Divider(),
              
              Expanded(child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('hilos').doc(docId).collection('comentarios').orderBy('fecha', descending: false).snapshots(), 
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final coms = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: coms.length, 
                    itemBuilder: (context, index) {
                      var d = coms[index].data() as Map<String, dynamic>;
                      String cId = coms[index].id;
                      String cAutorId = d['autorId'] ?? "";
                      bool esRespuesta = d['respondiendoANombre'] != null;
                      List likedBy = d['likedBy'] ?? [];
                      bool isLiked = miId != null && likedBy.contains(miId);

                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('usuarios').doc(cAutorId).snapshots(),
                        builder: (context, uSnap) {
                          String nombreParaMostrar = d['autorNombre'] ?? "Usuario";
                          String fotoParaMostrar = "";

                          if (uSnap.hasData && uSnap.data!.exists) {
                            var uData = uSnap.data!.data() as Map<String, dynamic>;
                            nombreParaMostrar = uData['nombre'] ?? nombreParaMostrar;
                            fotoParaMostrar = uData['fotoPerfilUrl'] ?? uData['fotoBase64'] ?? "";
                          }

                          return Padding(
                            padding: EdgeInsets.only(left: esRespuesta ? 30 : 0, bottom: 10), 
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: GestureDetector(
                                onTap: () => _irAlPerfil(context, cAutorId),
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: colorPrimario.withOpacity(0.1),
                                  backgroundImage: fotoParaMostrar.isNotEmpty 
                                    ? _obtenerImagenInteligente(fotoParaMostrar)
                                    : null,
                                  child: fotoParaMostrar.isEmpty ? Icon(Icons.person, size: 16, color: colorPrimario) : null,
                                ),
                              ),
                              title: Row(children: [
                                GestureDetector(
                                  onTap: () => _irAlPerfil(context, cAutorId),
                                  child: Text(nombreParaMostrar, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ), 
                                const SizedBox(width: 8), 
                                GestureDetector(
                                  onTap: () => setMState(() { rId = cAutorId; rNombre = nombreParaMostrar; }), 
                                  child: const Text("Responder", style: TextStyle(fontSize: 10, color: Colors.grey))
                                )
                              ]), 
                              subtitle: Text(d['texto'] ?? ""),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () => _toggleCommentLike(docId, cId, isLiked, miId),
                                    child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: isLiked ? Colors.red : Colors.grey),
                                  ),
                                  Text("${likedBy.length}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            )
                          );
                        }
                      );
                    }
                  );
                }
              )),
              
              if (rNombre != null) 
                Container(
                  color: colorPrimario.withOpacity(0.1), 
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                    children: [
                      Text("Respondiendo a @$rNombre", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)), 
                      IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setMState(() { rId = null; rNombre = null; }))
                    ]
                  )
                ),
                
              TextField(
                controller: ctrl, 
                decoration: InputDecoration(
                  hintText: "Escribe tu comentario...", 
                  suffixIcon: estaEnviando 
                    ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(icon: Icon(Icons.send, color: colorPrimario), onPressed: () async {
                        if (ctrl.text.trim().isEmpty || miId == null) return;
                        
                        setMState(() => estaEnviando = true); // Bloqueamos el botón
                        try {
                          final uDoc = await FirebaseFirestore.instance.collection('usuarios').doc(miId).get();
                          final miNombreActual = uDoc.data()?['nombre'] ?? "Usuario NOA";

                          await FirebaseFirestore.instance.collection('hilos').doc(docId).collection('comentarios').add({
                            'texto': ctrl.text.trim(), 
                            'autorNombre': miNombreActual, 
                            'autorId': miId, 
                            'fecha': FieldValue.serverTimestamp(), 
                            'respondiendoAId': rId, 
                            'respondiendoANombre': rNombre,
                            'likedBy': []
                          });
                          
                          ctrl.clear(); 
                          rId = null; rNombre = null;
                        } catch (e) {
                          debugPrint("Error al enviar comentario: $e");
                        } finally {
                          setMState(() => estaEnviando = false); // Liberamos el botón
                        }
                    })
                )
              )
            ])
          )
        ));
      }
    );
  }

  void _abrirBilletera(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
  }
}