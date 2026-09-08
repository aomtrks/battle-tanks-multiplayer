import 'dart:convert';
import 'dart:io';

class NetworkService {
  RawDatagramSocket? _socket;
  final int port = 4444;

  bool isHost = false;
  String? hostIp;

  final String myId = DateTime.now().millisecondsSinceEpoch.toString();
  String myName = "Oyuncu";
  int mySpawnIndex = 0;

  List<Map<String, dynamic>> lobbyPlayers = [];
  final Map<String, _ClientInfo> _clients = {};

  Function(List<Map<String, dynamic>> players)? onLobbyUpdated;
  Function()? onGameStarted;
  Function(String playerId, double x, double y, double angle)? onPlayerMove;
  Function(String playerId, double x, double y, double angle)? onPlayerShoot;
  Function(String playerId, int health)? onHealthUpdate;
  Function(String playerId, double x, double y, double angle)? onPlayerRespawn;

  Future<String> startHosting(String name) async {
    isHost = true;
    myName = name;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket!.readEventsEnabled = true;
    _listen();

    lobbyPlayers = [{'id': myId, 'name': myName, 'spawnIndex': 0, 'score': 0}];

    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (var interface in interfaces) {
      for (var addr in interface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
    return 'IP Bulunamadı';
  }

  Future<void> joinRoom(String targetIp, String name) async {
    isHost = false;
    hostIp = targetIp;
    myName = name;

    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _socket!.readEventsEnabled = true;
    _listen();

    _sendToHost({'action': 'join_lobby', 'id': myId, 'name': myName});
  }

  void startGame() {
    if (isHost) {
      for (int i = 0; i < 3; i++) {
        _broadcast(utf8.encode(jsonEncode({'action': 'start_game'})));
      }
      if (onGameStarted != null) onGameStarted!();
    }
  }

  void _listen() {
    _socket?.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? datagram = _socket?.receive();
        if (datagram == null) return;

        try {
          String message = utf8.decode(datagram.data);
          Map<String, dynamic> data = jsonDecode(message);

          String senderId = data['id'] ?? '';
          if (senderId == myId) return;

          // --- HOST MANTIĞI ---
          if (isHost) {
            String clientKey = '${datagram.address.address}:${datagram.port}';

            if (data['action'] == 'join_lobby') {
              if (!_clients.containsKey(clientKey)) {
                _clients[clientKey] = _ClientInfo(datagram.address, datagram.port);
              }
              int newSpawnIndex = lobbyPlayers.length % 4;
              lobbyPlayers.add({'id': senderId, 'name': data['name'], 'spawnIndex': newSpawnIndex, 'score': 0});
              _broadcastLobby();
            }

            if (data['action'] == 'died') {
              String killerId = data['killerId'];
              _processKill(killerId);
            }

            if (data['action'] != 'join_lobby') {
              _broadcast(datagram.data, excludeKey: clientKey);
            }
          }

          // --- HERKES İÇİN ORTAK (İstemci ve Host) ---
          if (data['action'] == 'lobby_update') {
            lobbyPlayers = List<Map<String, dynamic>>.from(data['players']);
            for (var p in lobbyPlayers) {
              if (p['id'] == myId) mySpawnIndex = p['spawnIndex'];
            }
            if (onLobbyUpdated != null) {
              try {
                onLobbyUpdated!(lobbyPlayers);
              } catch (_) {}
            }
          } else if (data['action'] == 'start_game') {
            if (onGameStarted != null) onGameStarted!();
          } else if (data['action'] == 'move' && onPlayerMove != null) {
            onPlayerMove!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          } else if (data['action'] == 'shoot' && onPlayerShoot != null) {
            onPlayerShoot!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          } else if (data['action'] == 'health' && onHealthUpdate != null) {
            onHealthUpdate!(senderId, data['h']);
          } else if (data['action'] == 'respawn' && onPlayerRespawn != null) {
            onPlayerRespawn!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          }
        } catch (e) {
          print("UDP Hata: $e");
        }
      }
    });
  }

  void _processKill(String killerId) {
    if (!isHost) return;
    for (var p in lobbyPlayers) {
      if (p['id'] == killerId) {
        p['score'] = (p['score'] ?? 0) + 1;
      }
    }
    _broadcastLobby();
  }

  void _broadcastLobby() {
    _broadcast(utf8.encode(jsonEncode({'action': 'lobby_update', 'players': lobbyPlayers})));
    if (onLobbyUpdated != null) {
      try {
        onLobbyUpdated!(lobbyPlayers);
      } catch (_) {}
    }
  }

  void sendPosition(double x, double y, double angle) => _routeMessage({'action': 'move', 'id': myId, 'x': x, 'y': y, 'a': angle});

  void sendShoot(double x, double y, double angle) => _routeMessage({'action': 'shoot', 'id': myId, 'x': x, 'y': y, 'a': angle});

  void sendHealth(int health) => _routeMessage({'action': 'health', 'id': myId, 'h': health});

  void sendRespawn(double x, double y, double angle) => _routeMessage({'action': 'respawn', 'id': myId, 'x': x, 'y': y, 'a': angle, 'h': 5});

  void sendDied(String killerId) {
    _routeMessage({'action': 'died', 'id': myId, 'killerId': killerId});
    if (isHost) {
      _processKill(killerId);
    }
  }

  void _routeMessage(Map<String, dynamic> msg) {
    List<int> bytes = utf8.encode(jsonEncode(msg));
    if (isHost) {
      _broadcast(bytes);
    } else if (hostIp != null) {
      _sendToHost(msg);
    }
  }

  void _sendToHost(Map<String, dynamic> msg) {
    if (_socket != null && hostIp != null) {
      _socket!.send(utf8.encode(jsonEncode(msg)), InternetAddress(hostIp!), port);
    }
  }

  void _broadcast(List<int> bytes, {String? excludeKey}) {
    if (_socket == null) return;
    _clients.forEach((key, clientInfo) {
      if (key != excludeKey) _socket!.send(bytes, clientInfo.address, clientInfo.port);
    });
  }
}

class _ClientInfo {
  final InternetAddress address;
  final int port;
  _ClientInfo(this.address, this.port);
}