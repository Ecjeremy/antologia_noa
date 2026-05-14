import 'package:flutter/material.dart';
import 'book_details_screen.dart'; 

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color backgroundCream = Color(0xFFFCF6F0);
    const Color inkBlue = Color(0xFF1B3D4D);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: backgroundCream,
          elevation: 0,
          title: const Text('MI ARCHIVO', 
            style: TextStyle(color: inkBlue, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'serif')),
          bottom: const TabBar(
            indicatorColor: Color(0xFFC4A77D),
            labelColor: inkBlue,
            tabs: [Tab(text: "FAVORITOS"), Tab(text: "COMPRADOS")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGrid(context, false), // Pestaña Favoritos
            _buildGrid(context, true),  // Pestaña Comprados
          ],
        ),
      ),
    );
  }

  // ... (Tus imports)

// --- BUSCA _buildGrid Y REEMPLÁZALO ---
Widget _buildGrid(BuildContext context, bool esComprado) {
  return GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, childAspectRatio: 0.65, crossAxisSpacing: 20, mainAxisSpacing: 20),
    itemCount: esComprado ? 2 : 4,
    itemBuilder: (context, index) {
      return InkWell(
        onTap: () => Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (context) => BookDetailsScreen(
              obraId: 'temp_id_$index', 
              autorId: 'temp_autor',
              titulo: esComprado ? "Obra Adquirida" : "Libro Favorito", 
              yaCompradoInicial: esComprado, // NOMBRE CORREGIDO
            )
          )
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3D4D),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(4, 4))]
                ),
                child: const Center(child: Icon(Icons.menu_book, color: Colors.white12, size: 50)),
              ),
            ),
            const SizedBox(height: 10),
            Text(esComprado ? "Obra Adquirida" : "Libro Favorito", 
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3D4D), fontFamily: 'serif')),
          ],
        ),
      );
    },
  );
}
}