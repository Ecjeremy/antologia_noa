import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final Color navyNoa = const Color(0xFF111827);
  final Color tealNoa = const Color(0xFF009688);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color matteGold = const Color(0xFFC4A77D);
  
  bool _isProcessing = false;

  void _mostrarPaquetesRecarga(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundCream,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("RECARGAR NOA COINS", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _buildOpcionPaquete(100, 1.00),
            const SizedBox(height: 10),
            _buildOpcionPaquete(500, 4.50, esPopular: true),
            const SizedBox(height: 10),
            _buildOpcionPaquete(1000, 8.00),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOpcionPaquete(int cantidad, double precio, {bool esPopular = false}) {
    return InkWell(
      onTap: () => _procesarPago(cantidad, precio),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: esPopular ? Border.all(color: matteGold, width: 2) : Border.all(color: Colors.black12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Icon(Icons.toll, color: matteGold, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Text("$cantidad Coins", style: TextStyle(fontWeight: FontWeight.bold, color: navyNoa, fontSize: 16)),
            ),
            Text("\$${precio.toStringAsFixed(2)}", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarPago(int cantidad, double precio) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    Navigator.pop(context);
    setState(() => _isProcessing = true);

    try {
      await Future.delayed(const Duration(seconds: 2));

      var batch = FirebaseFirestore.instance.batch();
      var userRef = FirebaseFirestore.instance.collection('usuarios').doc(userId);
      batch.update(userRef, {'noaCoins': FieldValue.increment(cantidad)});

      var transRef = FirebaseFirestore.instance.collection('transacciones').doc();
      batch.set(transRef, {
        'usuarioId': userId,
        'tipo': 'ingreso',
        'monto': cantidad,
        'detalle': 'Recarga de paquete',
        'fecha': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("¡Recarga exitosa!"), backgroundColor: tealNoa),
        );
      }
    } catch (e) {
      debugPrint("Error en pago: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: backgroundCream,
      appBar: AppBar(
        title: const Text("MI BILLETERA", style: TextStyle(letterSpacing: 2, fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: navyNoa),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 30),
              StreamBuilder<DocumentSnapshot>(
                stream: userId != null ? FirebaseFirestore.instance.collection('usuarios').doc(userId).snapshots() : null,
                builder: (context, snapshot) {
                  int saldo = 0;
                  if (snapshot.hasData && snapshot.data!.exists) {
                    saldo = (snapshot.data!.data() as Map<String, dynamic>)['noaCoins'] ?? 0;
                  }
                  return Column(
                    children: [
                      const Text("Saldo Disponible", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.toll, color: Colors.orange, size: 30),
                          const SizedBox(width: 8),
                          Text("$saldo", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: navyNoa)),
                        ],
                      ),
                    ],
                  );
                }
              ),
              Text("NOA COINS", style: TextStyle(letterSpacing: 4, fontSize: 10, color: matteGold, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _walletAction(Icons.add_circle_outline, "Recargar", () => _mostrarPaquetesRecarga(context)),
                  _walletAction(Icons.card_giftcard, "Canjear", () {}),
                ],
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("ACTIVIDAD RECIENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: navyNoa, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 10),
              const Divider(indent: 25, endIndent: 25),

              // LISTA DE TRANSACCIONES MEJORADA
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('transacciones')
                      .where('usuarioId', isEqualTo: userId)
                      .orderBy('fecha', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: Falta crear índice en Firebase", style: TextStyle(color: Colors.red[300], fontSize: 12)));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No tienes movimientos aún", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var trans = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return _buildTransactionItem(trans);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: tealNoa),
                      const SizedBox(height: 20),
                      Text("Procesando pago...", style: TextStyle(color: navyNoa, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> trans) {
    bool esIngreso = trans['tipo'] == 'ingreso';
    DateTime fecha = (trans['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
    String fechaFormateada = DateFormat('dd MMM, HH:mm').format(fecha);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: esIngreso ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        child: Icon(esIngreso ? Icons.arrow_downward : Icons.arrow_upward, color: esIngreso ? Colors.green : Colors.red, size: 18),
      ),
      title: Text(trans['detalle'] ?? "Transacción", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: navyNoa)),
      subtitle: Text(fechaFormateada, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Text("${esIngreso ? '+' : '-'} ${trans['monto']} 🪙", style: TextStyle(fontWeight: FontWeight.bold, color: esIngreso ? Colors.green : Colors.red)),
    );
  }

  Widget _walletAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(radius: 22, backgroundColor: Colors.white, child: Icon(icon, color: navyNoa, size: 20)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}