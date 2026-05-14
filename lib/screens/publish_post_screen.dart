import 'package:flutter/material.dart';
import '../data_store.dart';

class PublishPostScreen extends StatefulWidget {
  const PublishPostScreen({super.key});

  @override
  State<PublishPostScreen> createState() => _PublishPostScreenState();
}

class _PublishPostScreenState extends State<PublishPostScreen> {
  final TextEditingController _captionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    const Color inkBlue = Color(0xFF1B3D4D);
    const Color backgroundCream = Color(0xFFFCF6F0);

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: inkBlue),
        title: const Text(
          "NUEVO MOMENTO",
          style: TextStyle(color: inkBlue, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            // ÁREA DE LA FOTO (Simulada)
            GestureDetector(
              onTap: () {
                // Aquí irá la lógica para abrir la galería más adelante
              },
              child: Container(
                width: double.infinity,
                height: 350,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: inkBlue.withOpacity(0.1)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 60, color: inkBlue),
                    SizedBox(height: 10),
                    Text("Toca para seleccionar foto", style: TextStyle(color: inkBlue, fontSize: 12)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 25),

            // CAMPO PARA EL PIE DE FOTO (Caption)
            TextField(
              controller: _captionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Escribe un pie de foto...",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),

            const SizedBox(height: 40),

            // BOTÓN DE COMPARTIR
            ElevatedButton(
              onPressed: () {
                if (_captionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Escribe una descripción para tu post")),
                  );
                  return;
                }

                // Guardamos en la lista de comunidad
                DataStore.postsComunidad.add({
                  "usuario": "Angel",
                  "caption": _captionController.text,
                  // Imagen aleatoria de autoría para simular el post
                  "imagen": "https://images.unsplash.com/photo-1455390582262-044cdead277a?q=80&w=500&auto=format&fit=crop"
                });

                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("¡Compartido en Comunidad!")),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: inkBlue,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "COMPARTIR",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}