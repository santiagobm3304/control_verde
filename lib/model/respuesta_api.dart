class RespuestaApi<T> {
  final bool success;
  final String mensaje;
  final T? datos;
  final int status;

  RespuestaApi({
    required this.success,
    required this.mensaje,
    required this.datos,
    required this.status,
  });
}
