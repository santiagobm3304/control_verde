class Reporte {
  String id;
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
  double uRecibidas;
  String fechavencimiento;
  String observacion;
  bool fastRegister;

  Reporte({
    required this.id,
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
    required this.uRecibidas,
    required this.fechavencimiento,
    required this.observacion,
    bool? fastRegister,
  }) : fastRegister = fastRegister ?? (uRecibidas != 0);

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
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
      'uRecibidas': uRecibidas,
      'fechavencimiento': fechavencimiento,
      'observacion': observacion,
    };
  }

  factory Reporte.fromMap(Map<String, dynamic> map) {
    return Reporte(
      id: map['_id']?.toString() ?? '',
      tim: map['tim'] as int? ?? 0,
      olpn: map['olpn']?.toString() ?? '',
      subdpto: map['subdpto']?.toString() ?? '  ',
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
      uRecibidas: (map['uRecibidas'] as num?)?.toDouble() ?? 0,
      fechavencimiento:
          map.containsKey('fechavencimiento') && map['fechavencimiento'] != null
              ? map['fechavencimiento'].toString()
              : '',
      observacion: map.containsKey('observacion') && map['observacion'] != null
          ? map['observacion'].toString()
          : '',
    );
  }
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'tim': tim,
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
      'uRecibidas': uRecibidas,
      'fechavencimiento': fechavencimiento,
      'observacion': observacion,
      'fastRegister': fastRegister,
    };
  }

  factory Reporte.fromJson(Map<String, dynamic> json) {
    return Reporte(
      id: json['_id'],
      tim: json['tim'],
      olpn: json['olpn'],
      subdpto: json['subdpto'],
      ean: json['ean'],
      sku: json['sku'],
      descripcion: json['descripcion'],
      casePack: json['casePack'],
      uMedida: json['uMedida'],
      precioVigente: (json['precioVigente'] as num).toDouble(),
      costoPromedio: (json['costoPromedio'] as num).toDouble(),
      uEnviadas: (json['uEnviadas'] as num).toDouble(),
      uRecibidas: (json['uRecibidas'] as num).toDouble(),
      fechavencimiento: json['fechavencimiento'],
      observacion: json['observacion'],
    );
  }
  @override
  String toString() {
    return 'Reporte{id: $id, ean: $ean, tim: $tim, olpn: $olpn, uMedida: $uMedida, subdpto: $subdpto, sku: $sku, descripcion: $descripcion, casePack: $casePack, precioVigente: $precioVigente, costoPromedio: $costoPromedio, uEnviadas: $uEnviadas, uRecibidas: $uRecibidas, fechavencimiento: $fechavencimiento, observacion: $observacion}';
  }
}
