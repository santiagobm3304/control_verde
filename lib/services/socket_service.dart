import 'package:control_verde/database/config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  String? _currentSalaId;
  bool _allowReconnect = true;

  DateTime? _lastReconnect;
  bool _reloading = false;

  String get baseUrl => AppConfig.apiBaseUrl;

  Function()? onReconectado;

  /* ================= INIT ================= */

  void init() {
    if (_socket != null) return;

    final socketUrl = baseUrl.replaceAll('/api', '');
    print('🔌 Conectando socket a: $socketUrl');

    _socket = IO.io(socketUrl, {
      'transports': ['websocket'],
      'autoConnect': true,
      'reconnection': true,
      'reconnectionDelay': 3000,
      'reconnectionAttempts': 5,
    });

    _socket!.onConnect((_) {
      print('🟢 Socket conectado: ${_socket!.id}');
      _rejoinSala();
    });

    _socket!.onReconnect((_) {
      if (!_allowReconnect) {
        print('🚫 Reconexión ignorada (background)');
        return;
      }

      print('🔄 Reconectado');
      _rejoinSala();
      onReconectado?.call();
  
    });

    _socket!.onDisconnect((_) => print('❌ Socket desconectado'));
    _socket!.onError((e) => print('❌ Socket error: $e'));
  }

  /* ================= SALAS ================= */

  void joinSala(String salaId) {
    _currentSalaId = salaId;
    print('📡 Intentando unirse a sala: $salaId');

    if (_socket?.connected ?? false) {
      _socket!.emit('joinSala', salaId);
      print('✅ Emitido joinSala: $salaId');
    } else {
      print('⚠️ No se pudo emitir joinSala: Socket no conectado');
    }
  }

  void leaveSala() {
    if (_currentSalaId != null && _socket != null) {
      print('🚪 Saliendo de sala $_currentSalaId');
      _socket!.emit('leaveSala', _currentSalaId);
      _currentSalaId = null;
    }
  }

  void _rejoinSala() {
    if (_currentSalaId != null && _socket?.connected == true) {
      _socket!.emit('joinSala', _currentSalaId);
    }
  }

  /* ================= LIFECYCLE ================= */

  void pauseSocket() {
    if (_socket != null) {
      print('⏸️ Socket pausado (sin reconexión)');
      _allowReconnect = false;
      _socket!.disconnect();
    }
  }

  void resumeSocket() {
    if (_socket != null && !_socket!.connected) {
      print('▶️ Socket reanudado');
      _allowReconnect = true;
      _socket!.connect();
    }
  }

  /* ================= HELPERS ================= */

  IO.Socket get socket => _socket!;
  String? get socketId => _socket?.id;

  /* ================= DISPOSE ================= */

  void dispose() {
    leaveSala();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
