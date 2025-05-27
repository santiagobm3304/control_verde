// import 'package:control_verde/database/database_helper.dart';
// import 'package:control_verde/model/division_model.dart';
// import 'package:flutter/material.dart';

// class UbicacionesScreen extends StatefulWidget {
//   @override
//   _UbicacionesScreenState createState() => _UbicacionesScreenState();
// }

// class _UbicacionesScreenState extends State<UbicacionesScreen> {
//   late Future<List<Ubicacion>> ubicaciones;

//   @override
//   void initState() {
//     super.initState();
//     // ubicaciones = DatabaseHelper.instance.getUbicaciones();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Ubicaciones'),
//       ),
//       body: FutureBuilder<List<Ubicacion>>(
//         future: ubicaciones,
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return Center(child: CircularProgressIndicator());
//           } else if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//             return Center(child: Text('No hay ubicaciones disponibles.'));
//           } else {
//             final ubicaciones = snapshot.data!;
//             return ListView.builder(
//               itemCount: ubicaciones.length,
//               itemBuilder: (context, index) {
//                 final ubicacion = ubicaciones[index];
//                 return ListTile(
//                   title: Text(
//                       '${index + 1}._${ubicacion.division} - ${ubicacion.departamento}'),
//                   subtitle: Text(
//                       '${ubicacion.subdpto} | ${ubicacion.clase} - ${ubicacion.subclase}'),
//                   onTap: () {
//                   },
//                 );
//               },
//             );
//           }
//         },
//       ),
//     );
//   }
// }
