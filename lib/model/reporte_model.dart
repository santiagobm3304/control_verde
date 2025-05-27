class Reporte {
  final int? id;
  final int? tim;
  String olpn;
  final String subdpto;
  String ean;
  final String sku;
  final String descripcion;
  final int casePack;
  String uMedida;
  double precioVigente;
  double costoPromedio;
  double uEnviadas;
  double cEnviadas;
  double uRecibidas;
  String fechavencimiento;
  String faltantes;
  bool fastRegister;

  Reporte({
    this.id,
    this.tim,
    required this.olpn,
    required this.subdpto,
    required this.ean,
    required this.sku,
    required this.descripcion,
    required this.casePack,
    required this.uMedida,
    required this.precioVigente,
    required this.costoPromedio,
    required this.uEnviadas,
    required this.cEnviadas,
    required this.uRecibidas,
    required this.fechavencimiento,
    required this.faltantes,
    bool? fastRegister,
  }) : fastRegister = fastRegister ?? (uRecibidas != 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tim': tim ?? 0,
      'olpn': olpn,
      'subdpto': subdpto,
      'ean': ean,
      'sku': sku,
      'descripcion': descripcion,
      'casePack': casePack,
      'uMedida': uMedida,
      'precioVigente': precioVigente,
      'costoPromedio': costoPromedio,
      'uEnviadas': uEnviadas,
      'cEnviadas': cEnviadas,
      'uRecibidas': uRecibidas,
      'fechavencimiento': fechavencimiento,
      'faltantes': faltantes,
    };
  }

  factory Reporte.fromMap(Map<String, dynamic> map) {
    return Reporte(
      id: map['id'] as int?,
      tim: map['tim'] as int? ?? 0,
      olpn: map['olpn']?.toString() ?? '',
      subdpto: map['subdpto']?.toString() ?? '',
      ean: map.containsKey('ean') && map['ean'] != null
          ? map['ean'].toString()
          : '',
      sku: map.containsKey('sku') && map['sku'] != null
          ? map['sku'].toString()
          : '',
      descripcion: map.containsKey('descripcion') && map['descripcion'] != null
          ? map['descripcion'].toString()
          : '',
      casePack: (map['casePack'] as num?)?.toInt() ?? 0,
      uMedida: map['uMedida']?.toString() ?? '',
      precioVigente: (map['precioVigente'] as num?)?.toDouble() ?? 0,
      costoPromedio: (map['costoPromedio'] as num?)?.toDouble() ?? 0,
      uEnviadas: (map['uEnviadas'] as num?)?.toDouble() ?? 0,
      cEnviadas: (map['cEnviadas'] as num?)?.toDouble() ?? 0,
      uRecibidas: (map['uRecibidas'] as num?)?.toDouble() ?? 0,
      fechavencimiento:
          map.containsKey('fechavencimiento') && map['fechavencimiento'] != null
              ? map['fechavencimiento'].toString()
              : '',
      faltantes: map.containsKey('faltantes') && map['faltantes'] != null
          ? map['faltantes'].toString()
          : '',
    );
  }
  @override
  String toString() {
    return 'Reporte{id: $id, ean: $ean, tim: $tim, olpn: $olpn, uMedida: $uMedida, subdpto: $subdpto, sku: $sku, descripcion: $descripcion, casePack: $casePack, precioVigente: $precioVigente, costoPromedio: $costoPromedio, uEnviadas: $uEnviadas, cEnviadas: $cEnviadas, uRecibidas: $uRecibidas, fechavencimiento: $fechavencimiento, faltantes: $faltantes}';
  }
}
