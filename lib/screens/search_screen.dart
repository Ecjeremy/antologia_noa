import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart'; // <-- IMPORTANTE

import 'book_details_screen.dart';
import 'other_profile_screen.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  
  String _categoriaSeleccionada = "Todos"; 
  final List<String> _categorias = [
    "Todos", "Romance", "Terror", "Fantasía", "Suspenso", "Drama", "Poesía"
  ];

  final Color inkBlue = const Color(0xFF1B3D4D);
  final Color matteGold = const Color(0xFFC4A77D);
  final Color backgroundCream = const Color(0xFFFCF6F0);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, 
      child: Scaffold(
        backgroundColor: backgroundCream,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: inkBlue),
          title: TextField(
            controller: _searchController,
            autofocus: false, 
            style: TextStyle(color: inkBlue),
            decoration: InputDecoration(
              hintText: "Buscar historias o personas...",
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.8)),
              border: InputBorder.none,
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
          bottom: TabBar(
            indicatorColor: inkBlue,
            labelColor: inkBlue,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            tabs: const [
              Tab(text: "OBRAS"),
              Tab(text: "ESCRITORES"),
            ],
          ),
        ),
        
        body: TabBarView(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 10),
                  child: Text(
                    "EXPLORAR CATEGORÍAS",
                    style: TextStyle(color: matteGold, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),
                _buildCategoriasBar(),
                const Divider(height: 1, indent: 20, endIndent: 20, color: Colors.black12),
                Expanded(child: _buildBookSearchResults()),
              ],
            ),
            _buildUserSearchResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriasBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _categorias.length,
        itemBuilder: (context, index) {
          String cat = _categorias[index];
          bool seleccionada = _categoriaSeleccionada == cat;
          
          return GestureDetector(
            onTap: () => setState(() => _categoriaSeleccionada = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: seleccionada ? inkBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: seleccionada ? inkBlue : inkBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  cat.toUpperCase(),
                  style: TextStyle(
                    color: seleccionada ? Colors.white : inkBlue.withOpacity(0.6),
                    fontWeight: seleccionada ? FontWeight.bold : FontWeight.normal,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBookSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var resultados = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String titulo = (data['titulo'] ?? '').toString().toLowerCase();
          String autor = (data['autorNombre'] ?? '').toString().toLowerCase();
          String categoriaLibro = (data['categoria'] ?? 'General').toString();

          bool coincideTexto = titulo.contains(_searchQuery) || autor.contains(_searchQuery);
          bool coincideCategoria = _categoriaSeleccionada == "Todos" || 
                                   categoriaLibro.toLowerCase() == _categoriaSeleccionada.toLowerCase();

          return coincideTexto && coincideCategoria;
        }).toList();

        if (resultados.isEmpty) {
          return _emptyState("No encontramos libros o categorías.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: resultados.length,
          itemBuilder: (context, index) {
            var doc = resultados[index];
            var libro = doc.data() as Map<String, dynamic>;
            String id = doc.id; // Extraemos el ID del documento
            return _buildBookCard(libro, id, context);
          },
        );
      },
    );
  }

  Widget _buildBookCard(Map<String, dynamic> libro, String id, BuildContext context) {
  return GestureDetector(
    onTap: () {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => BookDetailsScreen(
          obraId: id, // OBLIGATORIO
          autorId: libro['autorId'] ?? '', // OBLIGATORIO
          titulo: libro['titulo'] ?? "Sin título",
          autor: libro['autorNombre'] ?? "Escritor",
          sinopsis: libro['sinopsis'] ?? "Sin sinopsis",
          contenido: libro['contenido'] ?? "",
          yaCompradoInicial: false,
          esGratis: libro['esGratis'] ?? true,
          precioNoaCoins: libro['precioNoaCoins'] ?? 0,
          monetizacionTipo: libro['monetizacionTipo'] ?? "libro_completo",
        ),
      ));
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            height: 90, width: 65,
            decoration: BoxDecoration(
              color: const Color(0xFF1B3D4D),
              borderRadius: BorderRadius.circular(8),
              image: libro['portadaUrl'] != null && libro['portadaUrl'].toString().isNotEmpty
                ? DecorationImage(image: CachedNetworkImageProvider(libro['portadaUrl']), fit: BoxFit.cover)
                : null,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libro['titulo'] ?? "Sin título", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text("por ${libro['autorNombre'] ?? 'Escritor'}", style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    ),
  );
}

  Widget _buildUserSearchResults() {
    final miUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var resultados = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String nombre = (data['nombre'] ?? '').toString().toLowerCase();
          return nombre.contains(_searchQuery) && doc.id != miUid;
        }).toList();

        if (resultados.isEmpty) {
          return _emptyState("No encontramos escritores con ese nombre.");
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: resultados.length,
          itemBuilder: (context, index) {
            var userData = resultados[index].data() as Map<String, dynamic>;
            String userId = resultados[index].id;
            String fotoPerfil = userData['fotoPerfilUrl'] ?? userData['fotoBase64'] ?? '';

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: inkBlue.withOpacity(0.1),
                backgroundImage: fotoPerfil.isNotEmpty 
                  ? (fotoPerfil.startsWith('http') 
                      ? CachedNetworkImageProvider(fotoPerfil) 
                      : MemoryImage(base64Decode(fotoPerfil)) as ImageProvider)
                  : null,
                child: fotoPerfil.isEmpty ? Icon(Icons.person, color: inkBlue) : null,
              ),
              title: Text(
                userData['nombre'] ?? "Usuario",
                style: TextStyle(fontWeight: FontWeight.bold, color: inkBlue, fontSize: 16),
              ),
              subtitle: Text(
                userData['bio'] ?? "Escritor en NOA",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Icon(Icons.person_add_alt_1, color: matteGold),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OtherProfileScreen(userId: userId)),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState(String mensaje) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(mensaje, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}