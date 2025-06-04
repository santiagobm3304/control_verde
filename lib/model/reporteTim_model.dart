class ReporteTim {
  final int? id;
  final int tim;
  final String? placa;
  final String? localOrigen;
  final String? localDestino;
  final String? fechaEnvio;
  bool? estado;
  final String? motivo;

  ReporteTim(
      {this.id,
      required this.tim,
      required this.placa,
      required this.localOrigen,
      required this.localDestino,
      required this.fechaEnvio,
      this.motivo});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tim': tim,
      'placa': placa,
      'local_origen': localOrigen,
      'local_destino': localDestino,
      'fecha_envio': fechaEnvio,
      'motivo': motivo,
    };
  }

  factory ReporteTim.fromMap(Map<String, dynamic> map) {
    return ReporteTim(
      id: map['id'] as int?,
      tim: map['tim'] as int,
      placa: map['placa'] as String,
      localOrigen: map['local_origen'] as String,
      localDestino: map['local_destino'] as String,
      fechaEnvio: map['fecha_envio'] as String,
      motivo: map['motivo'] as String,
    );
  }
  factory ReporteTim.fromJson(Map<String, dynamic> json) {
    return ReporteTim(
      id: json['id'],
      tim: json['tim'],
      placa: json['placa'],
      localOrigen: json['localOrigen'],
      localDestino: json['localDestino'],
      fechaEnvio: json['fechaEnvio'],
      motivo: json['motivo'],
    );
  }
}
