import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'reader_screen.dart';

class BookDetailsScreen extends StatefulWidget {
  final String obraId;   
  final String autorId;  
  final String titulo;
  final String autor;
  final String sinopsis;
  final String contenido;
  final bool yaCompradoInicial;
  final bool esGratis;
  final int precioNoaCoins;
  final String monetizacionTipo;

  const BookDetailsScreen({
    super.key, 
    required this.obraId, 
    required this.autorId, 
    required this.titulo, 
    this.autor = "Escritor",
    this.sinopsis = "Sin sinopsis disponible.",
    this.contenido = "",
    this.yaCompradoInicial = false, 
    this.esGratis = false, 
    this.precioNoaCoins = 0,
    this.monetizacionTipo = "libro_completo",
  });

  @override
  State<BookDetailsScreen> createState() => _BookDetailsScreenState();
}

class _BookDetailsScreenState extends State<BookDetailsScreen> {
  final Color navyNoa = const Color(0xFF111827); // Tu color oficial
  final Color matteGold = const Color(0xFFC4A77D);
  final Color tealNoa = const Color(0xFF009688);

  bool _yaComprado = false;
  bool _procesandoCompra = false;

  @override
  void initState() {
    super.initState();
    _yaComprado = widget.yaCompradoInicial;
    _verificarSiYaLoCompre();
    _incrementarVista(); 
  }

  // --- LÓGICA DE ESTADÍSTICAS ---
  Future<void> _incrementarVista() async {
    try {
      await FirebaseFirestore.instance
          .collection('obras')
          .doc(widget.obraId)
          .update({'vistas': FieldValue.increment(1)});
    } catch (e) {
      // Ignorar si el documento se borró o no hay conexión
    }
  }

  // --- NUEVO: FAVORITOS CON NOTIFICACIÓN AL AUTOR ---
  Future<void> _toggleFavorito(bool isFav) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarMensaje("Inicia sesión para guardar en favoritos.");
      return;
    }
    
    final ref = FirebaseFirestore.instance.collection('obras').doc(widget.obraId);
    
    try {
      if (isFav) {
        // Quitar de favoritos
        await ref.update({
          'favoritosList': FieldValue.arrayRemove([user.uid]),
          'favoritos': FieldValue.increment(-1)
        });
      } else {
        // Agregar a favoritos
        await ref.update({
          'favoritosList': FieldValue.arrayUnion([user.uid]),
          'favoritos': FieldValue.increment(1)
        });

        // Enviar notificación solo si no soy el autor de mi propio libro
        if (user.uid != widget.autorId) {
          final miDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
          final miNombre = miDoc.data()?['nombre'] ?? "Un usuario";

          await FirebaseFirestore.instance.collection('usuarios').doc(widget.autorId).collection('notificaciones').add({
            'titulo': '¡A alguien le encantó tu obra! 🌟',
            'mensaje': '$miNombre ha añadido "${widget.titulo}" a sus favoritos.',
            'fecha': FieldValue.serverTimestamp(),
            'leida': false,
            'tipo': 'favorito_obra',
          });
        }
      }
    } catch (e) {
      debugPrint("Error al actualizar favorito: $e");
    }
  }

  Future<void> _verificarSiYaLoCompre() async {
    if (widget.esGratis || widget.monetizacionTipo == "por_capitulo") return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final doc = await FirebaseFirestore.instance
        .collection('compras')
        .doc("${user.uid}_${widget.obraId}")
        .get();
        
    if (doc.exists && mounted) {
      setState(() => _yaComprado = true);
    }
  }

  Future<void> _ejecutarCompraCompleta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _mostrarMensaje("Debes iniciar sesión para comprar.");
      return;
    }

    setState(() => _procesandoCompra = true);

    try {
      final miRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final autorRef = FirebaseFirestore.instance.collection('usuarios').doc(widget.autorId);
      final compraRef = FirebaseFirestore.instance.collection('compras').doc("${user.uid}_${widget.obraId}");
      final obraRef = FirebaseFirestore.instance.collection('obras').doc(widget.obraId); 

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(miRef);
        int miSaldo = snapshot.get('noaCoins') ?? 0;

        if (miSaldo < widget.precioNoaCoins) {
          throw Exception("Saldo insuficiente. Ve a tu Perfil a recargar Noa Coins.");
        }

        transaction.update(miRef, {'noaCoins': miSaldo - widget.precioNoaCoins});
        
        if (user.uid != widget.autorId) {
          transaction.update(autorRef, {'noaCoins': FieldValue.increment(widget.precioNoaCoins)});
        }
        
        transaction.set(compraRef, {
          'usuarioId': user.uid,
          'obraId': widget.obraId,
          'fecha': FieldValue.serverTimestamp()
        });
        
        transaction.set(FirebaseFirestore.instance.collection('transacciones').doc(), {
          'usuarioId': user.uid,
          'tipo': 'gasto',
          'monto': widget.precioNoaCoins,
          'detalle': "Compra: ${widget.titulo}",
          'fecha': FieldValue.serverTimestamp(),
        });

        transaction.update(obraRef, {'ventas': FieldValue.increment(1)});
      });

      if (mounted) {
        setState(() => _yaComprado = true);
        _mostrarMensaje("¡Compra exitosa! Ya puedes disfrutar la obra.");
      }
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _procesandoCompra = false);
    }
  }

  void _mostrarConfirmacionCompra() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirmar Compra", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("¿Deseas desbloquear la obra completa '${widget.titulo}' por 🪙 ${widget.precioNoaCoins} Noa Coins?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); 
              _ejecutarCompraCompleta(); 
            },
            style: ElevatedButton.styleFrom(backgroundColor: navyNoa),
            child: const Text("COMPRAR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _mostrarMensaje(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _irAlLector() {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ReaderScreen(
        obraId: widget.obraId, 
        titulo: widget.titulo,
        precioNoaCoins: widget.precioNoaCoins, 
        isPurchased: _yaComprado,
        isFree: widget.esGratis,
        contenido: widget.contenido,
      )
    ));
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('obras').doc(widget.obraId).snapshots(),
      builder: (context, snapshot) {
        
        if (!snapshot.hasData) return const Scaffold(backgroundColor: Color(0xFFFCF6F0), body: Center(child: CircularProgressIndicator()));
        
        Map<String, dynamic> data = {};
        if (snapshot.data!.exists && snapshot.data!.data() != null) {
          data = snapshot.data!.data() as Map<String, dynamic>;
        }
        
        List favList = data['favoritosList'] ?? [];
        bool isFav = user != null && favList.contains(user.uid);
        String portadaUrl = data['portadaUrl'] ?? '';

        return Scaffold(
          backgroundColor: const Color(0xFFFCF6F0),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: navyNoa),
            actions: [
              IconButton(
                icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? Colors.amber : navyNoa, size: 28),
                onPressed: () => _toggleFavorito(isFav),
                tooltip: "Añadir a favoritos",
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 200, height: 300,
                    decoration: BoxDecoration(
                      color: navyNoa, 
                      borderRadius: BorderRadius.circular(10),
                      image: portadaUrl.isNotEmpty 
                          ? DecorationImage(image: CachedNetworkImageProvider(portadaUrl), fit: BoxFit.cover) 
                          : null,
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))]
                    ),
                    child: portadaUrl.isEmpty ? const Icon(Icons.book, size: 80, color: Colors.white24) : null,
                  ),
                ),
                const SizedBox(height: 30),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(data['titulo'] ?? widget.titulo, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: navyNoa, fontFamily: 'serif')),
                ),
                Text("por ${data['autorNombre'] ?? widget.autor}", style: const TextStyle(fontSize: 16, color: Colors.grey, fontStyle: FontStyle.italic, fontFamily: 'serif')),
                const SizedBox(height: 20),

                _buildStatsBar(data),
                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    data['sinopsis'] ?? widget.sinopsis,
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.5, color: navyNoa),
                  ),
                ),
                const SizedBox(height: 40),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: _buildBotonAccion(),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black12, width: 0.5),
          bottom: BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(Icons.visibility_outlined, "${data['vistas'] ?? 1}", "Vistas", navyNoa),
          _statItem(Icons.star_outline, "${data['favoritos'] ?? 0}", "Favoritos", Colors.amber),
          if (widget.precioNoaCoins > 0 && !widget.esGratis)
            _statItem(Icons.shopping_bag_outlined, "${data['ventas'] ?? 0}", "Ventas", tealNoa),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String valor, String etiqueta, Color colorIcono) {
    return Column(
      children: [
        Icon(icon, color: colorIcono, size: 22),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyNoa)),
        Text(etiqueta, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBotonAccion() {
    if (widget.esGratis || _yaComprado) {
      return _botonBase("LEER AHORA", navyNoa, _irAlLector);
    }

    if (widget.monetizacionTipo == "por_capitulo") {
      return Column(
        children: [
          _botonBase("LEER CAPÍTULOS GRATIS", navyNoa, _irAlLector),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.toll, color: Colors.orange, size: 14),
              const SizedBox(width: 5),
              Text("Capítulos extra: ${widget.precioNoaCoins} Noa Coins", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ],
      );
    }

    return _procesandoCompra 
      ? const Center(child: CircularProgressIndicator())
      : _botonBase("DESBLOQUEAR POR 🪙 ${widget.precioNoaCoins}", matteGold, _mostrarConfirmacionCompra);
  }

  Widget _botonBase(String texto, Color color, VoidCallback accion) {
    return ElevatedButton(
      onPressed: accion,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 0,
      ),
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }
}