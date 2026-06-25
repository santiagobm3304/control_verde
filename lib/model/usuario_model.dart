class Usuario {
  final String nombre;
  final String rol;
  final String token;
  final String? dni;
  final String? correo;

  Usuario({
    required this.nombre,
    required this.rol,
    required this.token,
    this.dni,
    this.correo,
  });

  // Convertir SQLite → Usuario
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      nombre: map['nombre'],
      rol: map['rol'],
      token: map['token'],
      dni: map['dni'],
      correo: map['correo'],
    );
  }

  // Convertir Usuario → SQLite
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'rol': rol,
      'token': token,
      'dni': dni,
      'correo': correo,
    };
  }
}
