
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  IO.Socket? _socket;
  String? _currentSalaId;

  Function()? onReconectado;

  factory SocketService() => _instance;
  SocketService._internal();

  void init() {
    if (_socket != null && _socket!.connected) {
      print('⚠️ Ya hay un socket conectado: ${_socket!.id}');
      return;
    }

    _socket = IO.io('https://controlverdebackend.onrender.com', {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
    });

    _socket!.onConnect((_) {
      print('🟢 Socket conectado: ${_socket?.id}');
      if (_currentSalaId != null) {
        _socket!.emit('joinSala', _currentSalaId);
      }
    });

    _socket!.onReconnect((_) {
      print('🔄 Reconectado');
      if (_currentSalaId != null) {
        _socket!.emit('joinSala', _currentSalaId);
      }

      onReconectado?.call();
    });

    _socket!.onDisconnect((_) => print('❌ Desconectado'));
    _socket!.onError((e) => print('❌ Socket error: $e'));
  }

  void joinSala(String salaId) {
    _currentSalaId = salaId;
    if (_socket != null && _socket!.connected) {
      _socket!.emit('joinSala', salaId);
    }
  }

  void leaveSala() {
    if (_currentSalaId != null && _socket != null) {
      _socket!.emit('leaveSala', _currentSalaId);
      _currentSalaId = null;
    }
  }

  void dispose() {
    leaveSala();
  }

  IO.Socket get socket => _socket!;
  String? get socketId => _socket?.id;
}