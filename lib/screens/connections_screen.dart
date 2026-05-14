import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'other_profile_screen.dart'; // Para poder visitar los perfiles

class ConnectionsScreen extends StatelessWidget {
  final String userId; // Necesitamos saber de quién es el perfil
  final int initialIndex;

  const ConnectionsScreen({
    super.key, 
    required this.userId, 
    this.initialIndex = 0
  });

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);

    return DefaultTabController(
      initialIndex: initialIndex,
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFCF6F0),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: inkBlue),
          title: const Text("COMUNIDAD", style: TextStyle(color: inkBlue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFC4A77D),
            labelColor: inkBlue,
            tabs: [Tab(text: "SEGUIDORES"), Tab(text: "SIGUIENDO")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRealList(context, "seguidores"),
            _buildRealList(context, "siguiendo"),
          ],
        ),
      ),
    );
  }

  Widget _buildRealList(BuildContext context, String tipo) {
    // Definimos qué buscar en Firebase dependiendo de la pestaña
    String campoABuscar = tipo == "seguidores" ? 'seguidoId' : 'seguidorId';
    String campoQueQueremos = tipo == "seguidores" ? 'seguidorId' : 'seguidoId';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('seguimientos')
          .where(campoABuscar, isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              tipo == "seguidores" ? "Aún no tienes seguidores." : "Aún no sigues a nadie.", 
              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.black12),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String idUsuarioObjetivo = data[campoQueQueremos];

            // Consultamos los datos de ese usuario específico (nombre, foto, etc.)
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('usuarios').doc(idUsuarioObjetivo).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) return const SizedBox.shrink();
                
                var userData = userSnap.data!.data() as Map<String, dynamic>?;
                if (userData == null) return const SizedBox.shrink();

                String fotoBase64 = userData['fotoBase64'] ?? '';
                String nombre = userData['nombre'] ?? "Usuario";
                String bio = userData['bio'] ?? "Escritor en LIVRO";

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1B3D4D),
                    backgroundImage: fotoBase64.isNotEmpty ? MemoryImage(base64Decode(fotoBase64)) : null,
                    child: fotoBase64.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                  ),
                  title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(bio, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: OutlinedButton(
                    onPressed: () => _irAlPerfil(context, idUsuarioObjetivo),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B3D4D)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text("VER", style: TextStyle(fontSize: 10, color: Color(0xFF1B3D4D))),
                  ),
                  onTap: () => _irAlPerfil(context, idUsuarioObjetivo), // Hace que toda la fila sea tocable
                );
              },
            );
          },
        );
      },
    );
  }

  // Función auxiliar para navegar
  void _irAlPerfil(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: id)),
    );
  }
}