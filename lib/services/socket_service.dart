import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  late IO.Socket _socket;

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  void init() {
    _socket = IO.io('https://controlverdebackend.onrender.com', {
      'transports': ['websocket'],
      'autoConnect': true,
    });

    _socket.onConnect((_) {
      print('✅ Conectado: ${_socket.id}');
    });

    _socket.onDisconnect((_) => print('❌ Desconectado'));
  }

  IO.Socket get socket => _socket;
  String get socketId => _socket.id ?? '';
}
