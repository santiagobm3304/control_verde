class ReporteTim {
  final int? id;
  final int tim;
  final String? placa;
  final String? localOrigen;
  final String? localDestino;
  final String? fechaEnvio;
  final String? creadoPor;
  bool? estado;
  final String? motivo;

  ReporteTim(
      {this.id,
      required this.tim,
      required this.placa,
      required this.localOrigen,
      required this.localDestino,
      required this.creadoPor,
      required this.fechaEnvio,
      this.motivo});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tim': tim,
      'placa': placa,
      'localOrigen': localOrigen,
      'localDestino': localDestino,
      'fechaEnvio': fechaEnvio, 
      'creadoPor': creadoPor,
      'motivo': motivo,
    };
  }

  factory ReporteTim.fromMap(Map<String, dynamic> map) {
    return ReporteTim(
      id: map['id'] as int?,
      tim: map['tim'] as int,
      placa: map['placa'] as String,
      localOrigen: map['localOrigen'] as String,
      localDestino: map['localDestino'] as String,
      fechaEnvio: map['fechaEnvio'] as String,
      creadoPor: map['creadoPor'] as String,
      motivo: map['motivo'] as String,
    );
  }
  factory ReporteTim.fromJson(Map<String, dynamic> json) {
    return ReporteTim(
      id: json['id'],
      tim: json['tim'],
      placa: json['placa'],
      localOrigen: json['origen'],
      localDestino: json['destino'],
      fechaEnvio: json['fechaEnvio'],
      creadoPor: json['creadoPor'],
      motivo: json['motivo'],
    );
  }
}
