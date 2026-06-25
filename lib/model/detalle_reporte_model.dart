class DetalleReporte {
  String id;
  final int? tim;
  String olpn;
  final String sku;
  double uEnviadas;
  double uRecibidas;
  String fechavencimiento;
  String observacion;
  String? modificadoPor;
  bool fastRegister;

  DetalleReporte({
    required this.id,
    this.tim,
    required this.olpn,
    required this.sku,
    required this.uEnviadas,
    required this.uRecibidas,
    required this.fechavencimiento,
    required this.observacion,
    required this.modificadoPor,
    bool? fastRegister,
  }) : fastRegister = fastRegister ?? (uRecibidas != 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tim': tim,
      'olpn': olpn,
      'sku': sku,
      'uEnviadas': uEnviadas,
      'uRecibidas': uRecibidas,
      'fechavencimiento': fechavencimiento,
      'modificadoPor': modificadoPor,
      'observacion': observacion,
    };
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tim': tim,
        'olpn': olpn,
        'sku': sku,
        'uEnviadas': uEnviadas,
        'uRecibidas': uRecibidas,
        'fechavencimiento': fechavencimiento,
        'modificadoPor': modificadoPor,
        'observacion': observacion,
      };

  factory DetalleReporte.fromMap(Map<String, dynamic> map) {
    return DetalleReporte(
      id: map['_id']?.toString() ?? '',
      tim: map['tim'] as int? ?? 0,
      olpn: map['olpn']?.toString() ?? '',
      sku: map.containsKey('sku') && map['sku'] != null
          ? map['sku'].toString()
          : '',
      uEnviadas: (map['uEnviadas'] as num?)?.toDouble() ?? 0,
      uRecibidas: (map['uRecibidas'] as num?)?.toDouble() ?? 0,
      fechavencimiento:
          map.containsKey('fechavencimiento') && map['fechavencimiento'] != null
              ? map['fechavencimiento'].toString()
              : '',
      modificadoPor:
          map.containsKey('modificadoPor') && map['modificadoPor'] != null
              ? map['modificadoPor'].toString()
              : '',
      observacion: map.containsKey('observacion') && map['observacion'] != null
          ? map['observacion'].toString()
          : '',
    );
  }
  @override
  String toString() {
    return 'Reporte{id: $id, tim: $tim, olpn: $olpn, sku: $sku, uEnviadas: $uEnviadas, uRecibidas: $uRecibidas, fechavencimiento: $fechavencimiento, modificadoPor: $modificadoPor, observacion: $observacion}';
  }
}
