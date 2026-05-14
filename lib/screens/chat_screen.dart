import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otroUsuarioId;
  final String otroUsuarioNombre;
  final String otroUsuarioFoto;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otroUsuarioId,
    required this.otroUsuarioNombre,
    required this.otroUsuarioFoto,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final Color navyNoa = const Color(0xFF111827);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color tealNoa = const Color(0xFF009688);

  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final String miId = FirebaseAuth.instance.currentUser?.uid ?? "";

  ImageProvider _obtenerImagenInteligente(String imageData) {
    if (imageData.isEmpty) return const AssetImage('assets/images/placeholder.png'); // Usa un placeholder si está vacía
    if (imageData.startsWith('http')) {
      return CachedNetworkImageProvider(imageData);
    } else {
      return MemoryImage(base64Decode(imageData));
    }
  }

  Future<void> _enviarMensaje() async {
    if (_mensajeController.text.trim().isEmpty) return;

    String texto = _mensajeController.text.trim();
    _mensajeController.clear();

    try {
      var batch = FirebaseFirestore.instance.batch();

      // 1. Guardar el mensaje en la subcolección
      var mensajeRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('mensajes')
          .doc();
      
      batch.set(mensajeRef, {
        'emisorId': miId,
        'texto': texto,
        'fecha': FieldValue.serverTimestamp(),
        'leido': false,
      });

      // 2. Actualizar el chat principal para la lista de "Mensajes Recientes"
      var chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
      batch.set(chatRef, {
        'usuarios': [miId, widget.otroUsuarioId],
        'ultimoMensaje': texto,
        'ultimaFecha': FieldValue.serverTimestamp(),
        'emisorUltimoMensaje': miId,
      }, SetOptions(merge: true));

      await batch.commit();

      // Bajar el scroll al último mensaje
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint("Error al enviar mensaje: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: navyNoa),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: navyNoa,
              backgroundImage: widget.otroUsuarioFoto.isNotEmpty 
                ? _obtenerImagenInteligente(widget.otroUsuarioFoto) 
                : null,
              child: widget.otroUsuarioFoto.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 16) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.otroUsuarioNombre,
                style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ÁREA DE MENSAJES
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('mensajes')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text("Escribe el primer mensaje a ${widget.otroUsuarioNombre}", 
                      style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                  );
                }

                return ListView.builder(
                  reverse: true, // Para que los nuevos salgan abajo
                  controller: _scrollController,
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    bool soyYo = data['emisorId'] == miId;
                    DateTime? fecha = (data['fecha'] as Timestamp?)?.toDate();
                    String hora = fecha != null ? DateFormat('HH:mm').format(fecha) : '';

                    return Align(
                      alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10, left: 20, right: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: soyYo ? navyNoa : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: Radius.circular(soyYo ? 15 : 0),
                            bottomRight: Radius.circular(soyYo ? 0 : 15),
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                        ),
                        child: Column(
                          crossAxisAlignment: soyYo ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['texto'] ?? '',
                              style: TextStyle(color: soyYo ? Colors.white : navyNoa, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hora,
                              style: TextStyle(color: soyYo ? Colors.white70 : Colors.grey, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // CAJA DE TEXTO INFERIOR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensajeController,
                    decoration: InputDecoration(
                      hintText: "Escribe un mensaje...",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      filled: true,
                      fillColor: backgroundCream,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: tealNoa,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _enviarMensaje,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}