import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReaderScreen extends StatefulWidget {
  final String obraId; 
  final String titulo;
  final int precioNoaCoins; 
  final bool isPurchased; 
  final bool isFree;
  final String contenido;

  const ReaderScreen({
    super.key,
    required this.obraId,
    required this.titulo,
    this.precioNoaCoins = 150,
    this.isPurchased = false,
    this.isFree = false,
    this.contenido = "", // Removido el ";" de aquí
  }); // El punto y coma va AQUÍ, después del paréntesis de cierre.

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final Color inkBlue = const Color(0xFF1B3D4D);
  final Color matteGold = const Color(0xFFC4A77D);
  
  int _indiceCapituloActual = 0;
  List<DocumentSnapshot> _capitulos = [];
  bool _cargando = true;
  bool _procesandoDesbloqueo = false;

  @override
  void initState() {
    super.initState();
    _obtenerCapitulos();
  }

  Future<void> _obtenerCapitulos() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('obras')
          .doc(widget.obraId)
          .collection('capitulos')
          .orderBy('orden', descending: false)
          .get();

      if (mounted) {
        setState(() {
          _capitulos = snap.docs;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _desbloquearConCoins(String capituloId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _procesandoDesbloqueo = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnap = await transaction.get(userRef);
        int saldo = userSnap.get('noaCoins') ?? 0;

        if (saldo < widget.precioNoaCoins) {
          throw Exception("No tienes suficientes Noa Coins. Recarga en tu billetera.");
        }

        transaction.update(userRef, {'noaCoins': saldo - widget.precioNoaCoins});
        
        transaction.set(
          userRef.collection('desbloqueos').doc(capituloId),
          {'fecha': FieldValue.serverTimestamp(), 'obraId': widget.obraId, 'metodo': 'coins'}
        );
      });

      _notificar("¡Capítulo desbloqueado exitosamente!");
    } catch (e) {
      _notificar(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _procesandoDesbloqueo = false);
    }
  }

  Future<void> _verPublicidad(String capituloId) async {
    setState(() => _procesandoDesbloqueo = true);
    
    _notificar("Cargando anuncio...");
    await Future.delayed(const Duration(seconds: 3)); 

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .collection('desbloqueos')
          .doc(capituloId)
          .set({'metodo': 'publicidad', 'fecha': FieldValue.serverTimestamp(), 'obraId': widget.obraId});
    }

    _notificar("¡Gracias por el apoyo! Capítulo libre.");
    if (mounted) setState(() => _procesandoDesbloqueo = false);
  }

  void _notificar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_capitulos.isEmpty) return Scaffold(appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: inkBlue)), body: const Center(child: Text("Esta obra no tiene capítulos aún.")));

    var capActual = _capitulos[_indiceCapituloActual].data() as Map<String, dynamic>;
    String capId = _capitulos[_indiceCapituloActual].id;
    bool esGratis = capActual['esGratis'] ?? true;
    String contenidoCapitulo = capActual['contenido'] ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFFCF6F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        iconTheme: IconThemeData(color: inkBlue),
        title: Text(widget.titulo.toUpperCase(), style: TextStyle(color: inkBlue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('desbloqueos')
            .doc(capId)
            .snapshots(),
        builder: (context, snapshot) {
          bool yaDesbloqueado = snapshot.hasData && snapshot.data!.exists;
          bool tieneAccesoTotal = widget.isFree || widget.isPurchased || esGratis || yaDesbloqueado;

          String textoVisible = tieneAccesoTotal 
              ? contenidoCapitulo 
              : (contenidoCapitulo.length > 300 ? "${contenidoCapitulo.substring(0, 300)}..." : contenidoCapitulo);

          return Column(
            children: [
              LinearProgressIndicator(value: (_indiceCapituloActual + 1) / _capitulos.length, backgroundColor: Colors.black12, color: matteGold),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capActual['titulo'] ?? "Capítulo ${_indiceCapituloActual + 1}", 
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: inkBlue, fontFamily: 'serif', letterSpacing: 1.5)
                          ),
                          const SizedBox(height: 25),
                          Text(
                            textoVisible,
                            style: TextStyle(fontSize: 18, height: 1.8, color: inkBlue.withOpacity(0.9), fontFamily: 'serif'),
                          ),
                          const SizedBox(height: 120), 
                        ],
                      ),
                    ),

                    if (!tieneAccesoTotal)
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: Container(
                          height: 400,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFFFCF6F0).withOpacity(0.0), 
                                const Color(0xFFFCF6F0).withOpacity(0.95), 
                                const Color(0xFFFCF6F0)
                              ],
                              stops: const [0.0, 0.3, 1.0],
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(Icons.lock_outline, size: 50, color: matteGold),
                              const SizedBox(height: 15),
                              const Text("CAPÍTULO BLOQUEADO", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 40),
                                child: Text("Has llegado al límite de la muestra gratuita. Puedes usar tus Noa Coins o ver un anuncio para continuar leyendo.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                              ),
                              const SizedBox(height: 25),
                              if (_procesandoDesbloqueo)
                                const CircularProgressIndicator()
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: ElevatedButton(
                                    onPressed: () => _desbloquearConCoins(capId),
                                    style: ElevatedButton.styleFrom(backgroundColor: inkBlue, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                    child: Text("DESBLOQUEAR POR 🪙 ${widget.precioNoaCoins}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _verPublicidad(capId),
                                    icon: const Icon(Icons.play_circle_outline, size: 20),
                                    label: const Text("VER ANUNCIO GRATIS"),
                                    style: OutlinedButton.styleFrom(foregroundColor: inkBlue, minimumSize: const Size(double.infinity, 50), side: BorderSide(color: inkBlue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: _indiceCapituloActual > 0 ? () => setState(() => _indiceCapituloActual--) : null, icon: const Icon(Icons.arrow_back_ios)),
                    Text("Capítulo ${_indiceCapituloActual + 1} de ${_capitulos.length}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: (_indiceCapituloActual < _capitulos.length - 1 && tieneAccesoTotal) ? () => setState(() => _indiceCapituloActual++) : null, 
                      icon: const Icon(Icons.arrow_forward_ios)
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}