import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart';

import 'connections_screen.dart';
import 'book_details_screen.dart';
import 'chat_screen.dart'; // NUEVO: Importamos la pantalla de chat

class OtherProfileScreen extends StatefulWidget {
  final String userId; 

  const OtherProfileScreen({super.key, required this.userId});

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  // --- PALETA OFICIAL NOA ---
  final Color navyNoa = const Color(0xFF111827); // Ajustado a tu Navy oficial
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  bool _loSigo = false;
  bool _bloqueado = false;
  bool _isLoading = false;
  final String _miId = FirebaseAuth.instance.currentUser!.uid;

  // --- LÓGICA DE CHAT ---
  void _contactarUsuario(String otroNombre, String otroFoto) {
    if (_miId.isEmpty) return;

    // Creamos un ID único de chat combinando ambos UIDs
    List<String> ids = [_miId, widget.userId];
    ids.sort(); 
    String chatId = ids.join("_");

    // Abrimos la pantalla de chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chatId,
          otroUsuarioId: widget.userId,
          otroUsuarioNombre: otroNombre,
          otroUsuarioFoto: otroFoto,
        ),
      ),
    );
  }

  // --- NAVEGACIÓN ENTRE PERFILES ---
  void _irAlPerfil(BuildContext context, String targetId) {
    if (targetId.isEmpty) return;
    if (targetId == _miId) {
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (targetId != widget.userId) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: targetId)));
    }
  }

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.startsWith('http')) return CachedNetworkImageProvider(imageData);
    return MemoryImage(base64Decode(imageData));
  }

  @override
  void initState() { super.initState(); _verificarEstado(); }

  Future<void> _verificarEstado() async {
    final segDoc = await FirebaseFirestore.instance.collection('seguimientos').doc("${_miId}_${widget.userId}").get();
    final bloqDoc = await FirebaseFirestore.instance.collection('bloqueos').doc("${_miId}_${widget.userId}").get();
    if (mounted) setState(() { _loSigo = segDoc.exists; _bloqueado = bloqDoc.exists; });
  }

  Future<void> _confirmarBloqueo() async {
    showDialog(context: context, builder: (context) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), title: const Text("¿Bloquear usuario?", style: TextStyle(fontWeight: FontWeight.bold)), content: const Text("Se eliminará el seguimiento mutuo y no podrán ver sus publicaciones."), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))), TextButton(onPressed: () { Navigator.pop(context); _ejecutarBloqueo(); }, child: const Text("BLOQUEAR", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]));
  }

  Future<void> _ejecutarBloqueo() async {
    setState(() => _isLoading = true);
    final batch = FirebaseFirestore.instance.batch();
    final refBloqueo = FirebaseFirestore.instance.collection('bloqueos').doc("${_miId}_${widget.userId}");
    final refSeguimiento = FirebaseFirestore.instance.collection('seguimientos').doc("${_miId}_${widget.userId}");
    final miDoc = FirebaseFirestore.instance.collection('usuarios').doc(_miId);
    final suDoc = FirebaseFirestore.instance.collection('usuarios').doc(widget.userId);

    try {
      batch.set(refBloqueo, {'fecha': FieldValue.serverTimestamp(), 'bloqueadorId': _miId, 'bloqueadoId': widget.userId});
      if (_loSigo) { batch.delete(refSeguimiento); batch.update(miDoc, {'siguiendo': FieldValue.increment(-1)}); batch.update(suDoc, {'seguidores': FieldValue.increment(-1)}); }
      await batch.commit();
      if (mounted) setState(() { _bloqueado = true; _loSigo = false; });
    } finally { setState(() => _isLoading = false); }
  }

  Future<void> _desbloquear() async {
    await FirebaseFirestore.instance.collection('bloqueos').doc("${_miId}_${widget.userId}").delete();
    setState(() => _bloqueado = false);
  }

  Future<void> _toggleSeguir() async {
    setState(() => _isLoading = true);
    final refSeg = FirebaseFirestore.instance.collection('seguimientos').doc("${_miId}_${widget.userId}");
    final miDoc = FirebaseFirestore.instance.collection('usuarios').doc(_miId);
    final suDoc = FirebaseFirestore.instance.collection('usuarios').doc(widget.userId);
    final batch = FirebaseFirestore.instance.batch();

    try {
      if (_loSigo) { batch.delete(refSeg); batch.update(miDoc, {'siguiendo': FieldValue.increment(-1)}); batch.update(suDoc, {'seguidores': FieldValue.increment(-1)}); setState(() => _loSigo = false); } 
      else { batch.set(refSeg, {'seguidorId': _miId, 'seguidoId': widget.userId, 'fecha': FieldValue.serverTimestamp()}); batch.update(miDoc, {'siguiendo': FieldValue.increment(1)}); batch.update(suDoc, {'seguidores': FieldValue.increment(1)}); setState(() => _loSigo = true); }
      await batch.commit();
    } finally { setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_bloqueado) {
      return Scaffold(backgroundColor: backgroundCream, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: navyNoa)), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.block, size: 80, color: Colors.grey), const SizedBox(height: 20), const Text("Has bloqueado a este usuario", style: TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: _desbloquear, child: const Text("DESBLOQUEAR"))])));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: navyNoa), actions: [PopupMenuButton<String>(onSelected: (val) => val == 'bloquear' ? _confirmarBloqueo() : null, itemBuilder: (context) => [const PopupMenuItem(value: 'bloquear', child: Text("Bloquear usuario", style: TextStyle(color: Colors.red)))])]),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').doc(widget.userId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            String foto = userData['fotoPerfilUrl'] ?? userData['fotoBase64'] ?? '';
            String nombre = userData['nombre'] ?? "Escritor";

            return Column(
              children: [
                CircleAvatar(radius: 45, backgroundColor: navyNoa, backgroundImage: foto.isNotEmpty ? _obtenerImagenInteligente(foto) : null, child: foto.isEmpty ? const Icon(Icons.person, size: 45, color: Colors.white) : null),
                const SizedBox(height: 12),
                Text(nombre, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navyNoa, fontFamily: 'serif')),
                Text("${userData['bio'] ?? 'Escritor'} • ${userData['ubicacion'] ?? 'Zaruma'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 15),
                
                // --- BOTONES: SEGUIR Y MENSAJE ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40), 
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 40, 
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _toggleSeguir, 
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _loSigo ? Colors.grey.shade300 : navyNoa, 
                              foregroundColor: _loSigo ? navyNoa : Colors.white, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                            ), 
                            child: Text(_loSigo ? "Siguiendo" : "Seguir", style: const TextStyle(fontWeight: FontWeight.bold))
                          )
                        )
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 40,
                        width: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.mail_outline, color: navyNoa, size: 22),
                          onPressed: () => _contactarUsuario(nombre, foto),
                        ),
                      ),
                    ],
                  )
                ),
                // ---------------------------------

                const SizedBox(height: 25),
                _buildStats(userData),
                const SizedBox(height: 20),
                TabBar(
                  indicatorColor: navyNoa, labelColor: navyNoa, unselectedLabelColor: Colors.grey,
                  tabs: const [Tab(text: "HILOS"), Tab(text: "OBRAS")],
                ),
                Expanded(
                  child: TabBarView(children: [
                    _buildFeed(nombre, foto),
                    _buildObras(widget.userId, userData),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStats(Map<String, dynamic> userData) {
    int o = userData['obras'] ?? 0; int s1 = userData['seguidores'] ?? 0; int s2 = userData['siguiendo'] ?? 0;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_statItem(o < 0 ? "0" : "$o", "OBRAS", null), _statItem(s1 < 0 ? "0" : "$s1", "SEGUIDORES", () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectionsScreen(userId: widget.userId, initialIndex: 0)))), _statItem(s2 < 0 ? "0" : "$s2", "SIGUIENDO", () => Navigator.push(context, MaterialPageRoute(builder: (context) => ConnectionsScreen(userId: widget.userId, initialIndex: 1))))]);
  }

  Widget _statItem(String v, String e, VoidCallback? t) => GestureDetector(onTap: t, child: Container(color: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Column(children: [Text(v, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: navyNoa)), Text(e, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))])));

  Widget _buildFeed(String nombre, String foto) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('hilos').where('autorId', isEqualTo: widget.userId).orderBy('fecha', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final hilos = snapshot.data!.docs;
        if (hilos.isEmpty) return const Center(child: Text("Sin publicaciones."));
        return ListView.builder(itemCount: hilos.length, itemBuilder: (context, index) => _buildThreadsItem(hilos[index].data() as Map<String, dynamic>, hilos[index].id, nombre, foto));
      },
    );
  }

  Widget _buildThreadsItem(Map<String, dynamic> data, String docId, String n, String f) {
    List lb = data['likedBy'] ?? []; bool isL = lb.contains(_miId);
    return Container(
      padding: const EdgeInsets.all(15), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 18, backgroundColor: navyNoa, backgroundImage: f.isNotEmpty ? _obtenerImagenInteligente(f) : null, child: f.isEmpty ? const Icon(Icons.person, size: 18, color: Colors.white) : null),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa, fontSize: 13)), const SizedBox(height: 4),
          if (data['texto'] != null) Text(data['texto'], style: const TextStyle(fontSize: 14)),
          if (data['imagenAdjunta'] != null && data['imagenAdjunta'].isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: data['imagenAdjunta'].toString().startsWith('http') ? CachedNetworkImage(imageUrl: data['imagenAdjunta']) : Image.memory(base64Decode(data['imagenAdjunta'])))),
          const SizedBox(height: 12),
          Row(children: [
            GestureDetector(onTap: () => _toggleLike(docId, isL), child: Row(children: [Icon(isL ? Icons.favorite : Icons.favorite_border, size: 18, color: isL ? Colors.red : Colors.grey), const SizedBox(width: 5), Text("${lb.length}", style: const TextStyle(color: Colors.grey, fontSize: 12))])), 
            const SizedBox(width: 25), 
            GestureDetector(onTap: () => _mostrarComentarios(context, docId, navyNoa), child: const Icon(Icons.mode_comment_outlined, size: 18, color: Colors.grey)), 
            const SizedBox(width: 25), 
            GestureDetector(onTap: () => Share.share("${data['texto']}\n\nEscrito por: $n en NOA"), child: const Icon(Icons.share_outlined, size: 18, color: Colors.grey))
          ])
        ]))
      ]),
    );
  }

  Widget _buildObras(String userId, Map<String, dynamic> userData) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').where('autorId', isEqualTo: userId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final obras = snapshot.data!.docs;
        if (obras.isEmpty) return const Center(child: Text("Sin obras publicadas.", style: TextStyle(color: Colors.grey)));
        return GridView.builder(
          padding: const EdgeInsets.all(15), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.65, crossAxisSpacing: 10, mainAxisSpacing: 15),
          itemCount: obras.length, 
          itemBuilder: (context, i) {
            var d = obras[i].data() as Map<String, dynamic>;
            String fotoPortada = d['portadaUrl'] ?? d['portada'] ?? '';
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BookDetailsScreen(
                obraId: obras[i].id, autorId: userId, titulo: d['titulo'] ?? "Sin título", autor: userData['nombre'] ?? "Escritor", sinopsis: d['sinopsis'] ?? "",
                esGratis: d['esGratis'] ?? true, precioNoaCoins: d['precioNoaCoins'] ?? 0, monetizacionTipo: d['monetizacionTipo'] ?? "libro_completo"
              ))),
              child: Container(decoration: BoxDecoration(color: navyNoa, borderRadius: BorderRadius.circular(6), image: fotoPortada.isNotEmpty ? DecorationImage(image: _obtenerImagenInteligente(fotoPortada), fit: BoxFit.cover) : null)),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLike(String d, bool l) async { DocumentReference r = FirebaseFirestore.instance.collection('hilos').doc(d); l ? await r.update({'likedBy': FieldValue.arrayRemove([_miId])}) : await r.update({'likedBy': FieldValue.arrayUnion([_miId])}); }

  Future<void> _toggleCommentLike(String hId, String cId, bool l, String? u) async {
    if (u == null) return;
    DocumentReference r = FirebaseFirestore.instance.collection('hilos').doc(hId).collection('comentarios').doc(cId);
    l ? await r.update({'likedBy': FieldValue.arrayRemove([u])}) : await r.update({'likedBy': FieldValue.arrayUnion([u])});
  }

  void _mostrarComentarios(BuildContext context, String docId, Color colorPrimario) {
    final TextEditingController ctrl = TextEditingController();
    
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(builder: (context, setMState) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6, padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text("COMENTARIOS", style: TextStyle(fontWeight: FontWeight.bold)), const Divider(),
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
                    List likedBy = d['likedBy'] ?? [];
                    bool isLiked = likedBy.contains(_miId);

                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('usuarios').doc(cAutorId).snapshots(),
                      builder: (context, uSnap) {
                        var uData = uSnap.data?.data() as Map<String, dynamic>? ?? {};
                        String n = uData['nombre'] ?? d['autorNombre'] ?? "Usuario";
                        String f = uData['fotoPerfilUrl'] ?? uData['fotoBase64'] ?? "";

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: GestureDetector(onTap: () => _irAlPerfil(context, cAutorId), child: CircleAvatar(radius: 16, backgroundColor: colorPrimario.withOpacity(0.1), backgroundImage: f.isNotEmpty ? _obtenerImagenInteligente(f) : null, child: f.isEmpty ? Icon(Icons.person, size: 16, color: colorPrimario) : null)),
                          title: GestureDetector(onTap: () => _irAlPerfil(context, cAutorId), child: Text(n, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          subtitle: Text(d['texto'] ?? ""),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            GestureDetector(onTap: () => _toggleCommentLike(docId, cId, isLiked, _miId), child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 16, color: isLiked ? Colors.red : Colors.grey)),
                            Text("${likedBy.length}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ]),
                        );
                      }
                    );
                  }
                );
              }
            )),
            TextField(controller: ctrl, decoration: InputDecoration(hintText: "Escribe tu comentario...", suffixIcon: IconButton(icon: Icon(Icons.send, color: colorPrimario), onPressed: () async {
              if (ctrl.text.isNotEmpty) {
                final uDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_miId).get();
                await FirebaseFirestore.instance.collection('hilos').doc(docId).collection('comentarios').add({
                  'texto': ctrl.text, 'autorId': _miId, 'autorNombre': uDoc.data()?['nombre'] ?? "Usuario",
                  'fecha': FieldValue.serverTimestamp(), 'likedBy': []
                });
                ctrl.clear();
              }
            })))
          ]),
        ),
      )),
    );
  }
}