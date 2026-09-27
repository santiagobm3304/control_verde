class AppConfig {
  /// Cambia esto para usar PROD o DEV
  static const bool isProd = false;

  static const String urlProd = "https://controlverdebackendprobar.onrender.com/api";
  static const String urlDev = "https://controlverdebackend-ryut.onrender.com/api";

  /// Devuelve la URL activa según la bandera
  static String get apiBaseUrl => isProd ? urlProd : urlDev;
}
