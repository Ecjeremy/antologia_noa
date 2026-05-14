import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Color navyNoa = const Color(0xFF111827);
  final Color tealNoa = const Color(0xFF009688);
  final Color backgroundCream = const Color(0xFFFCF6F0);
  final Color darkInk = const Color(0xFF121212);
  final Color darkCard = const Color(0xFF1E1E1E);

  bool _isDarkMode = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Marcar una notificación como leída al tocarla
  Future<void> _marcarComoLeida(String notifId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser!.uid)
        .collection('notificaciones')
        .doc(notifId)
        .update({'leida': true});
  }

  // Marcar TODAS como leídas
  Future<void> _marcarTodasLeidas() async {
    if (currentUser == null) return;
    var batch = FirebaseFirestore.instance.batch();
    var unread = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(currentUser!.uid)
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }

  // Seleccionar el icono y color según el tipo de notificación
  Widget _obtenerIcono(String tipo) {
    switch (tipo) {
      case 'like_hilo':
        return const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.favorite, color: Colors.white, size: 18));
      case 'nuevo_seguidor':
        return const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.person_add, color: Colors.white, size: 18));
      case 'favorito_obra':
        return const CircleAvatar(backgroundColor: Colors.amber, child: Icon(Icons.star, color: Colors.white, size: 18));
      case 'compra_obra':
        return const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.attach_money, color: Colors.white, size: 18));
      case 'turno_juego':
        return CircleAvatar(backgroundColor: tealNoa, child: const Icon(Icons.edit_note, color: Colors.white, size: 18));
      default:
        return CircleAvatar(backgroundColor: navyNoa, child: const Icon(Icons.notifications, color: Colors.white, size: 18));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Inicia sesión para ver tus notificaciones.")));
    }

    final Color bgColor = _isDarkMode ? darkInk : backgroundCream;
    final Color textColor = _isDarkMode ? Colors.white : navyNoa;
    final Color cardColor = _isDarkMode ? darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text("NOTIFICACIONES", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "Marcar todas como leídas",
            onPressed: _marcarTodasLeidas,
            color: tealNoa,
          ),
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, color: _isDarkMode ? Colors.amber : navyNoa),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(currentUser!.uid)
            .collection('notificaciones')
            .orderBy('fecha', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: tealNoa));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: textColor.withOpacity(0.2)),
                  const SizedBox(height: 15),
                  Text("Aún no tienes notificaciones.", style: TextStyle(color: textColor.withOpacity(0.5))),
                ],
              ),
            );
          }

          final notificaciones = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              var data = notificaciones[index].data() as Map<String, dynamic>;
              String id = notificaciones[index].id;
              bool leida = data['leida'] ?? false;
              String tipo = data['tipo'] ?? 'general';
              
              // Formatear la fecha
              String tiempoHace = "Hace un momento";
              if (data['fecha'] != null) {
                DateTime date = (data['fecha'] as Timestamp).toDate();
                tiempoHace = DateFormat('dd MMM, hh:mm a').format(date);
              }

              return Container(
                color: leida ? Colors.transparent : tealNoa.withOpacity(0.1), // Destaca las no leídas
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: _obtenerIcono(tipo),
                  title: Text(
                    data['titulo'] ?? "Notificación",
                    style: TextStyle(color: textColor, fontWeight: leida ? FontWeight.normal : FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(data['mensaje'] ?? "", style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13)),
                      const SizedBox(height: 5),
                      Text(tiempoHace, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  onTap: () {
                    if (!leida) _marcarComoLeida(id);
                    // Aquí en el futuro puedes agregar lógica para navegar
                    // Ej: si tipo == 'turno_juego', enviarlo a SeriousGameScreen
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}