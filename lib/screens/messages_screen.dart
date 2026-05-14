import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';


import 'chat_screen.dart'; // Importamos la pantalla que creamos en el Paso 1

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final Color navyNoa = const Color(0xFF111827);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final String miId = FirebaseAuth.instance.currentUser?.uid ?? "";

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.isEmpty) return const AssetImage('assets/images/placeholder.png');
    if (imageData.startsWith('http')) {
      return CachedNetworkImageProvider(imageData);
    } else {
      return MemoryImage(base64Decode(imageData));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: Text("MENSAJES", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: navyNoa),
      ),
      body: miId.isEmpty 
        ? const Center(child: Text("Inicia sesión para ver tus mensajes"))
        : StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('usuarios', arrayContains: miId)
                .orderBy('ultimaFecha', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text("Falta crear índice en Firebase para los chats.", style: TextStyle(color: Colors.red[300])));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 60, color: navyNoa.withOpacity(0.2)),
                      const SizedBox(height: 15),
                      Text("Aún no tienes mensajes", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold)),
                      const Text("Ve al perfil de alguien para iniciar una charla.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var chatData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  String chatId = snapshot.data!.docs[index].id;
                  
                  // Averiguar el ID del OTRO usuario
                  List usuarios = chatData['usuarios'] ?? [];
                  String otroUsuarioId = usuarios.firstWhere((id) => id != miId, orElse: () => "");

                  if (otroUsuarioId.isEmpty) return const SizedBox();

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('usuarios').doc(otroUsuarioId).snapshots(),
                    builder: (context, userSnap) {
                      if (!userSnap.hasData) return const SizedBox();
                      
                      var otroUsuarioData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                      String nombre = otroUsuarioData['nombre'] ?? "Usuario NOA";
                      String foto = otroUsuarioData['fotoPerfilUrl'] ?? otroUsuarioData['fotoBase64'] ?? "";
                      
                      String ultimoMsj = chatData['ultimoMensaje'] ?? "";
                      DateTime? fecha = (chatData['ultimaFecha'] as Timestamp?)?.toDate();
                      String tiempoAtras = fecha != null ? DateFormat('dd MMM').format(fecha) : '';

                      bool yoFuiUltimo = chatData['emisorUltimoMensaje'] == miId;

                      return ListTile(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                            chatId: chatId,
                            otroUsuarioId: otroUsuarioId,
                            otroUsuarioNombre: nombre,
                            otroUsuarioFoto: foto,
                          )));
                        },
                        leading: CircleAvatar(
                          radius: 25,
                          backgroundColor: navyNoa,
                          backgroundImage: foto.isNotEmpty ? _obtenerImagenInteligente(foto) : null,
                          child: foto.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa, fontSize: 15)),
                        subtitle: Text(
                          yoFuiUltimo ? "Tú: $ultimoMsj" : ultimoMsj,
                          style: TextStyle(color: yoFuiUltimo ? Colors.grey : navyNoa.withOpacity(0.8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(tiempoAtras, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      );
                    }
                  );
                },
              );
            },
          ),
    );
  }
}