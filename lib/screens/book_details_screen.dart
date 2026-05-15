import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'reader_screen.dart';
import 'other_profile_screen.dart';

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
  // --- LÓGICA DE PROPINAS COLECTIVAS (SPLIT) ---
  Future<void> _enviarPropinaColectiva(int totalPropina, List autoresUids) async {
    final miId = FirebaseAuth.instance.currentUser?.uid;
    if (miId == null) {
      _mostrarMensaje("Inicia sesión para enviar propinas.");
      return;
    }

    if (autoresUids.isEmpty) {
      // Si por alguna razón no hay array, usamos el autor principal
      autoresUids = [widget.autorId];
    }

    setState(() => _procesandoCompra = true); // Usamos tu variable de carga para bloquear la UI

    // Configuración del Split
    double comisionApp = 0.15; // 15% para Angel (Creador)
    int coinsParaCreador = (totalPropina * comisionApp).round();
    int restanteParaAutores = totalPropina - coinsParaCreador;
    int coinsPorAutor = (restanteParaAutores / autoresUids.length).floor();

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Descontar saldo al emisor
        DocumentReference emisorRef = FirebaseFirestore.instance.collection('usuarios').doc(miId);
        DocumentSnapshot emisorSnap = await transaction.get(emisorRef);
        int saldoActual = emisorSnap.get('noaCoins') ?? 0;

        if (saldoActual < totalPropina) throw Exception("Saldo insuficiente para la propina.");
        transaction.update(emisorRef, {'noaCoins': FieldValue.increment(-totalPropina)});

        // 2. Comisión del Creador (TÚ)
        // REEMPLAZA 'AQUI_TU_UID_REAL' POR TU UID DE FIREBASE DE PRODUCCIÓN
        DocumentReference creadorRef = FirebaseFirestore.instance.collection('usuarios').doc('AQUI_TU_UID_REAL'); 
        transaction.update(creadorRef, {'noaCoins': FieldValue.increment(coinsParaCreador)});

        // 3. Repartir a todos los co-autores
        for (String autorUid in autoresUids) {
          DocumentReference autorRef = FirebaseFirestore.instance.collection('usuarios').doc(autorUid);
          transaction.update(autorRef, {'noaCoins': FieldValue.increment(coinsPorAutor)});
          
          // Enviar notificación a cada autor
          DocumentReference notifRef = autorRef.collection('notificaciones').doc();
          transaction.set(notifRef, {
            'titulo': '¡Propina Colectiva! 🪙',
            'mensaje': 'Has recibido $coinsPorAutor Noa Coins gracias a tu participación en "${widget.titulo}".',
            'fecha': FieldValue.serverTimestamp(),
            'leida': false,
            'tipo': 'propina',
          });
        }
      });

      _mostrarMensaje("¡Propina enviada! Has apoyado a los ${autoresUids.length} autores.");
    } catch (e) {
      _mostrarMensaje(e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => _procesandoCompra = false);
    }
  }

  // Cuadro de diálogo para elegir la cantidad de propina
  void _mostrarDialogoPropina(List autoresUids) {
    int cantidadElegida = 10;
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFCF6F0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: Text("Apoyar a los autores", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("¡Regala Noa Coins a los creadores de esta obra!", style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [10, 50, 100].map((valor) {
                      return ChoiceChip(
                        label: Text("$valor", style: TextStyle(color: cantidadElegida == valor ? Colors.white : navyNoa, fontWeight: FontWeight.bold)),
                        selected: cantidadElegida == valor,
                        selectedColor: matteGold,
                        backgroundColor: Colors.transparent,
                        side: BorderSide(color: matteGold),
                        onSelected: (selected) {
                          if (selected) setStateDialog(() => cantidadElegida = valor);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCELAR", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: navyNoa, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () {
                    Navigator.pop(context);
                    _enviarPropinaColectiva(cantidadElegida, autoresUids);
                  },
                  child: const Text("ENVIAR", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
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
                const SizedBox(height: 20),
                _buildAutores(data),
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
                  child: Column(
                    children: [
                      _buildBotonAccion(),
                      const SizedBox(height: 15),
                      // NUEVO BOTÓN DE PROPINA
                      ElevatedButton.icon(
                        onPressed: () {
                           // Extraemos la lista de UIDs de autores o pasamos el autor principal
                          List autoresUids = data['autoresUids'] ?? [widget.autorId];
                          _mostrarDialogoPropina(autoresUids);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: navyNoa,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30), 
                            side: BorderSide(color: matteGold, width: 1.5)
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(Icons.volunteer_activism, color: matteGold),
                        label: const Text(
                          "DAR PROPINA A AUTORES", 
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                      ),
                    ],
                  ),
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
  // --- NUEVA LÓGICA: NOMBRES DE AUTORES CLIQUEABLES ---
  Widget _buildAutores(Map<String, dynamic> data) {
    List autoresDetalle = data['autoresDetalle'] ?? [];

    // SI ES UN LIBRO DEL MODO CAOS (Tiene múltiples autores guardados)
    if (autoresDetalle.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: autoresDetalle.map((autor) {
            return ActionChip(
              backgroundColor: matteGold.withOpacity(0.15),
              side: BorderSide(color: matteGold.withOpacity(0.5)),
              avatar: Icon(Icons.person_pin, size: 18, color: navyNoa),
              label: Text(
                autor['nombre'] ?? 'Escritor', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: navyNoa)
              ),
              onPressed: () {
                if (autor['id'] != null) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => OtherProfileScreen(userId: autor['id'])
                  ));
                }
              },
            );
          }).toList(),
        ),
      );
    } 
    // SI ES UN LIBRO NORMAL (Un solo autor)
    else {
      String autorId = data['autorId'] ?? widget.autorId;
      String autorNombre = data['autorNombre'] ?? widget.autor;

      return GestureDetector(
        onTap: () {
          // Evitamos navegar si el ID es 'comunidad' (libros huérfanos sin IDs específicos)
          if (autorId.isNotEmpty && autorId != 'comunidad') {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => OtherProfileScreen(userId: autorId)
            ));
          } else {
            _mostrarMensaje("Este libro es de la comunidad global.");
          }
        },
        child: Text(
          "por $autorNombre", 
          style: TextStyle(
            fontSize: 16, 
            color: matteGold, // Un toque dorado para invitar a tocar
            fontStyle: FontStyle.italic, 
            fontFamily: 'serif',
            decoration: TextDecoration.underline, // Subrayado sutil para que sepan que es un link
            decorationColor: matteGold
          )
        ),
      );
    }
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
