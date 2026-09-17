import 'dart:convert';
import 'dart:io';

class GameSettings {
  static double joyLeft = 40;
  static double joyBottom = 40;
  static double fireRight = 100;
  static double fireBottom = 100;
}

class NetworkService {
  RawDatagramSocket? _socket;
  final int port = 4444;

  bool isHost = false;
  String? hostIp;
  int selectedMap = 0; 
  int selectedTime = 60; 

  final String myId = DateTime.now().millisecondsSinceEpoch.toString();
  String myName = "Oyuncu";
  int mySpawnIndex = 0;
  int myTeam = 0; 

  List<Map<String, dynamic>> lobbyPlayers = [];
  final Map<String, _ClientInfo> _clients = {};
  List<int> spawnPool = [0, 1, 2, 3, 4, 5, 6, 7];
  
  int teamScoreA = 0;
  int teamScoreB = 0;

  Function(List<Map<String, dynamic>> players)? onLobbyUpdated;
  Function()? onGameStarted;
  Function(String playerId, double x, double y, double angle)? onPlayerMove;
  Function(String playerId, double x, double y, double angle, int type)? onPlayerShoot;
  Function(String playerId, int health)? onHealthUpdate;
  Function(String playerId, double x, double y, double angle)? onPlayerRespawn;
  Function(String id, int type, double x, double y)? onLootSpawned;
  Function(String id)? onLootCollected;
  Function(String playerId, bool state)? onShieldUpdate;
  Function(int seed, int rows, int cols, int currentRound)? onNewRound; 
  
  Function(String ownerId)? onCatchBall;
  Function(String ownerId, double x, double y, double angle)? onShootBall;
  Function(int scoringTeam)? onGoalScored;

  Future<String> startHosting(String name) async {
    isHost = true;
    myName = name;
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: true, reusePort: true);
    _socket!.readEventsEnabled = true;
    _listen();
    
    spawnPool.shuffle();
    lobbyPlayers = [{'id': myId, 'name': myName, 'spawnIndex': spawnPool[0], 'score': 0, 'team': 0}];
    
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
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0, reuseAddress: true, reusePort: true);
    _socket!.readEventsEnabled = true;
    _listen();
    _sendToHost({'action': 'join_lobby', 'id': myId, 'name': myName});
  }

  void updateLobbySettings(int map, int time) {
    if (!isHost) return;
    selectedMap = map;
    selectedTime = time;
    _broadcastLobby();
  }

  void toggleTeam(String playerId) {
    if (!isHost) return;
    for (var p in lobbyPlayers) {
      if (p['id'] == playerId) p['team'] = (p['team'] == 0) ? 1 : 0;
    }
    _broadcastLobby();
  }

  void startGame() {
    if (isHost) {
      for (var p in lobbyPlayers) p['score'] = 0; 
      teamScoreA = 0; teamScoreB = 0;
      _broadcastLobby();
      for (int i = 0; i < 3; i++) {
        _broadcast(utf8.encode(jsonEncode({'action': 'start_game'})));
      }
      if (onGameStarted != null) onGameStarted!();
    }
  }

  void disconnect() {
    _socket?.close();
    _socket = null;
    isHost = false;
    hostIp = null;
    lobbyPlayers.clear();
    _clients.clear();
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

          if (isHost) {
            String clientKey = '${datagram.address.address}:${datagram.port}';
            if (data['action'] == 'join_lobby') {
              if (!_clients.containsKey(clientKey)) _clients[clientKey] = _ClientInfo(datagram.address, datagram.port);
              int newSpawnIndex = spawnPool[lobbyPlayers.length % 8];
              int autoTeam = lobbyPlayers.length % 2 == 0 ? 0 : 1; 
              lobbyPlayers.add({'id': senderId, 'name': data['name'], 'spawnIndex': newSpawnIndex, 'score': 0, 'team': autoTeam});
              _broadcastLobby();
            }

            if (data['action'] == 'died') _processKill(data['killerId']);
            if (data['action'] == 'goal') {
               teamScoreA = data['scoreA'];
               teamScoreB = data['scoreB'];
            }
            if (data['action'] != 'join_lobby') _broadcast(datagram.data, excludeKey: clientKey);
          }

          if (data['action'] == 'lobby_update') {
            lobbyPlayers = List<Map<String, dynamic>>.from(data['players']);
            selectedMap = data['map'] ?? 0;
            selectedTime = data['time'] ?? 60;
            teamScoreA = data['scoreA'] ?? 0;
            teamScoreB = data['scoreB'] ?? 0;
            
            for (var p in lobbyPlayers) {
              if (p['id'] == myId) {
                mySpawnIndex = p['spawnIndex'];
                myTeam = p['team'] ?? 0;
              }
            }
            if (onLobbyUpdated != null) {
              try { onLobbyUpdated!(lobbyPlayers); } catch (_) {}
            }
          } else if (data['action'] == 'start_game') {
            if (onGameStarted != null) onGameStarted!();
          } else if (data['action'] == 'new_round' && onNewRound != null) {
            onNewRound!(data['seed'], data['rows'], data['cols'], data['round']);
          } else if (data['action'] == 'move' && onPlayerMove != null) {
            onPlayerMove!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          } else if (data['action'] == 'shoot' && onPlayerShoot != null) {
            onPlayerShoot!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble(), data['t'] ?? 0);
          } else if (data['action'] == 'health' && onHealthUpdate != null) {
            onHealthUpdate!(senderId, data['h']);
          } else if (data['action'] == 'respawn' && onPlayerRespawn != null) {
            onPlayerRespawn!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          } else if (data['action'] == 'spawn_loot' && onLootSpawned != null) {
            onLootSpawned!(data['lootId'], data['type'], (data['x'] as num).toDouble(), (data['y'] as num).toDouble());
          } else if (data['action'] == 'collect_loot' && onLootCollected != null) {
            onLootCollected!(data['lootId']);
          } else if (data['action'] == 'shield' && onShieldUpdate != null) {
            onShieldUpdate!(senderId, data['state']); 
          } else if (data['action'] == 'catch_ball' && onCatchBall != null) { 
            onCatchBall!(senderId);
          } else if (data['action'] == 'shoot_ball' && onShootBall != null) { 
            onShootBall!(senderId, (data['x'] as num).toDouble(), (data['y'] as num).toDouble(), (data['a'] as num).toDouble());
          } else if (data['action'] == 'goal' && onGoalScored != null) {
            teamScoreA = data['scoreA'] ?? teamScoreA;
            teamScoreB = data['scoreB'] ?? teamScoreB;
            onGoalScored!(data['team']);
          }
        } catch (e) {
          print("UDP Hata: $e");
        }
      }
    });
  }

  void _processKill(String killerId) {
    if (!isHost) return;
    if (selectedMap == 3 || selectedMap == 4 || selectedMap == 5) return; 
    for (var p in lobbyPlayers) {
      if (p['id'] == killerId) p['score'] = (p['score'] ?? 0) + 1;
    }
    _broadcastLobby();
  }

  void addScoreToPlayer(String playerId) {
    if (!isHost) return;
    for (var p in lobbyPlayers) {
      if (p['id'] == playerId) p['score'] = (p['score'] ?? 0) + 1;
    }
    _broadcastLobby();
  }

  void _broadcastLobby() {
    _broadcast(utf8.encode(jsonEncode({
      'action': 'lobby_update', 
      'players': lobbyPlayers, 
      'map': selectedMap,
      'time': selectedTime,
      'scoreA': teamScoreA,
      'scoreB': teamScoreB
    })));
    if (onLobbyUpdated != null) {
      try { onLobbyUpdated!(lobbyPlayers); } catch (_) {}
    }
  }

  void sendPosition(double x, double y, double angle) => _routeMessage({'action': 'move', 'id': myId, 'x': x, 'y': y, 'a': angle});
  void sendShoot(double x, double y, double angle, int type) => _routeMessage({'action': 'shoot', 'id': myId, 'x': x, 'y': y, 'a': angle, 't': type});
  void sendHealth(int health) => _routeMessage({'action': 'health', 'id': myId, 'h': health});
  void sendRespawn(double x, double y, double angle) => _routeMessage({'action': 'respawn', 'id': myId, 'x': x, 'y': y, 'a': angle, 'h': 5});
  void sendDied(String killerId) {
    _routeMessage({'action': 'died', 'id': myId, 'killerId': killerId});
    if (isHost) _processKill(killerId);
  }
  void sendSpawnLoot(String lootId, int type, double x, double y) => _routeMessage({'action': 'spawn_loot', 'id': myId, 'lootId': lootId, 'type': type, 'x': x, 'y': y});
  void sendCollectLoot(String lootId) => _routeMessage({'action': 'collect_loot', 'id': myId, 'lootId': lootId});
  void sendShield(bool state) => _routeMessage({'action': 'shield', 'id': myId, 'state': state}); 
  
  // YENİ: Paket kaybına karşı 3 kez yollar (Yükleme hatası engellenir)
  void sendNewRound(int seed, int rows, int cols, int currentRound) {
    for (int i = 0; i < 3; i++) {
      _routeMessage({'action': 'new_round', 'id': myId, 'seed': seed, 'rows': rows, 'cols': cols, 'round': currentRound});
    }
  }
  
  void sendCatchBall() => _routeMessage({'action': 'catch_ball', 'id': myId});
  void sendShootBall(double x, double y, double angle) => _routeMessage({'action': 'shoot_ball', 'id': myId, 'x': x, 'y': y, 'a': angle});
  void sendGoal(int team) {
    if (isHost) {
      if (team == 0) teamScoreA++; else teamScoreB++;
      _routeMessage({'action': 'goal', 'team': team, 'scoreA': teamScoreA, 'scoreB': teamScoreB});
    }
  }

  void _routeMessage(Map<String, dynamic> msg) {
    List<int> bytes = utf8.encode(jsonEncode(msg));
    if (isHost) _broadcast(bytes); else if (hostIp != null) _sendToHost(msg);
  }
  void _sendToHost(Map<String, dynamic> msg) {
    if (_socket != null && hostIp != null) _socket!.send(utf8.encode(jsonEncode(msg)), InternetAddress(hostIp!), port);
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