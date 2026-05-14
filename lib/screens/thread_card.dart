// Archivo: lib/thread_card.dart
import 'dart:convert';
import 'package:flutter/material.dart';

class ThreadCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const ThreadCard({
    super.key, 
    required this.data,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final String nombreAutor = data['autorNombre'] ?? "Usuario";
    final String fotoAutor = data['autorFoto'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5))
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AVATAR
          Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1B3D4D),
                backgroundImage: fotoAutor.isNotEmpty ? MemoryImage(base64Decode(fotoAutor)) : null,
                child: fotoAutor.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 18) : null,
              ),
              // Pequeña línea estilo Threads
              Container(width: 1, height: 30, color: Colors.transparent), 
            ],
          ),
          const SizedBox(width: 12),
          
          // CONTENIDO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombreAutor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B3D4D))),
                const SizedBox(height: 4),
                if (data['texto'] != null && data['texto'].isNotEmpty) 
                  Text(data['texto'], style: const TextStyle(fontSize: 14)),
                
                // IMAGEN
                if (data['imagenAdjunta'] != null && data['imagenAdjunta'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(data['imagenAdjunta']), 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                
                // BOTONES CON TUS FUNCIONES
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border, size: 20, color: Colors.grey),
                      onPressed: onLike,
                      constraints: const BoxConstraints(), // Evita espacios muertos
                      padding: const EdgeInsets.only(right: 20, top: 10),
                    ),
                    IconButton(
                      icon: const Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey),
                      onPressed: onComment,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 20, top: 10),
                    ),
                    IconButton(
                      icon: const Icon(Icons.repeat, size: 20, color: Colors.grey),
                      onPressed: () {}, // Repost
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 20, top: 10),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 20, color: Colors.grey),
                      onPressed: onShare,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.only(right: 20, top: 10),
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
}