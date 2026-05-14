import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Para las horas de publicación

class ComunidadFeed extends StatelessWidget {
  const ComunidadFeed({super.key});

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);
    const Color matteGold = Color(0xFFC4A77D);

    return StreamBuilder<QuerySnapshot>(
      // 1. Escuchamos la colección 'hilos' en tiempo real
      stream: FirebaseFirestore.instance
          .collection('hilos')
          .orderBy('fecha', descending: true) 
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: inkBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("Aún no hay hilos. ¡Sé el primero!", 
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          );
        }

        final hilos = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(15),
          itemCount: hilos.length,
          separatorBuilder: (context, index) => const Divider(height: 30, color: Colors.black12),
          itemBuilder: (context, index) {
            var data = hilos[index].data() as Map<String, dynamic>;
            
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. AVATAR (DECODIFICADO DE BASE64)
                CircleAvatar(
                  radius: 20,
                  backgroundColor: inkBlue,
                  backgroundImage: (data['autorFoto'] != null && data['autorFoto'].isNotEmpty)
                      ? MemoryImage(base64Decode(data['autorFoto']))
                      : null,
                  child: (data['autorFoto'] == null || data['autorFoto'].isEmpty)
                      ? const Icon(Icons.person, size: 20, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                
                // 3. CUERPO DEL HILO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(data['autorNombre'] ?? "Escritor", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: inkBlue)),
                          Text(
                            data['fecha'] != null 
                              ? DateFormat('HH:mm').format((data['fecha'] as Timestamp).toDate())
                              : "Recién",
                            style: const TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(data['texto'] ?? "", 
                        style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.3)),
                      
                      // Si el hilo tiene una imagen adjunta, la mostramos
                      if (data['imagenAdjunta'] != null && data['imagenAdjunta'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(data['imagenAdjunta']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // 4. INTERACCIONES (LIKE, COMENTARIO, COMPARTIR)
                      Row(
                        children: [
                          const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text("${data['likes'] ?? 0}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(width: 20),
                          const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                          const SizedBox(width: 5),
                          const Text("0", style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const Spacer(),
                          const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}