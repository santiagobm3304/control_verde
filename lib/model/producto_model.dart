
class Producto {
  final int? id;
  final String subdpto;
  final String proveedor;
  final String ean;
  final String sku;
  final String descripcion;
  final String marca;
  final double costoPromedio;
  final double precioVigente;
  final int casePack;
  final String uMedida; 

  Producto({
    this.id,
    required this.sku,
    required this.ean,
    required this.subdpto,
    required this.descripcion,
    required this.marca,
    required this.proveedor,
    required this.casePack,
    required this.costoPromedio,
    required this.precioVigente,
    required this.uMedida,
  });

  Map<String, dynamic> toMap() {//toMap
    return {
      'id': id,
      'sku': sku,
      'ean': ean,
      'subdpto': subdpto,
      'descripcion': descripcion,
      'marca': marca,
      'proveedor': proveedor,
      'casePack': casePack,
      'costoPromedio': costoPromedio,
      'precioVigente': precioVigente,
      'uMedida': uMedida,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] as int?,
      sku: map['sku'] ?? '',
      ean: map['ean'] ?? '',
      subdpto: map['subdpto'] ?? '',
      descripcion: map['descripcion'] ?? '',
      marca: map['marca'] ?? '',
      proveedor: map['proveedor'] ?? '',
      casePack: map['casePack'] ?? 1,
      costoPromedio: map['costoPromedio'] ?? 0,
      precioVigente: map['precioVigente'] ?? 0,
      uMedida: map['uMedida'] ?? '',
    );
  }
   factory Producto.fromJson(Map<String, dynamic> json) {
    return Producto(
      id: json['id'],
      subdpto: json['subdpto'],
      proveedor: json['proveedor'],
      ean: json['ean'],
      sku: json['sku'],
      descripcion: json['descripcion'],
      marca: json['marca'],
      costoPromedio: (json['costoPromedio'] as num).toDouble(),
      precioVigente: (json['precioVigente'] as num).toDouble(),
      casePack: json['casePack'],
      uMedida: json['uMedida'],
    );
  }
}
