import 'dart:math';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import '../components/tank.dart';
import '../components/enemy_tank.dart';
import '../components/wall.dart';
import '../components/bullet.dart';
import '../components/loot_box.dart';
import '../network/network_service.dart';

class ScoreboardHUD extends PositionComponent with HasGameRef<TankGame> {
  bool isVisible = false;
  final Paint bgPaint = Paint()..color = Colors.black87;
  final TextPaint titlePaint = TextPaint(style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold));
  final TextPaint scorePaint = TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20));

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), bgPaint);
    titlePaint.render(canvas, "ÖLDÜN! BEKLE...", Vector2(gameRef.size.x / 2 - 130, 40));
    double yPos = 100;
    for (var p in gameRef.networkService.lobbyPlayers) {
      scorePaint.render(canvas, "${p['name']} : ${p['score'] ?? 0} Skor", Vector2(gameRef.size.x / 2 - 100, yPos));
      yPos += 35;
    }
  }
}

class EndGameHUD extends PositionComponent with HasGameRef<TankGame> {
  final Paint bgPaint = Paint()..color = Colors.black87;
  final TextPaint titlePaint = TextPaint(style: const TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold));
  final TextPaint scorePaint = TextPaint(style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold));
  final TextPaint btnTextPaint = TextPaint(style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold));

  final Paint btnContinuePaint = Paint()..color = Colors.blue.shade700;
  final Paint btnLeavePaint = Paint()..color = Colors.red.shade700;

  @override
  void render(Canvas canvas) {
    final cx = gameRef.size.x / 2;
    final cy = gameRef.size.y / 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), bgPaint);
    titlePaint.render(canvas, "SÜRE BİTTİ - LİDERLİK TABLOSU", Vector2(cx - 280, 40));

    List<Map<String, dynamic>> sortedPlayers = List.from(gameRef.networkService.lobbyPlayers);
    sortedPlayers.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    double yPos = 120;
    for (int i = 0; i < sortedPlayers.length; i++) {
      var p = sortedPlayers[i];
      scorePaint.render(canvas, "${i + 1}. ${p['name']} - ${p['score']} Puan", Vector2(cx - 150, yPos));
      yPos += 45;
    }

    canvas.drawRRect(RRect.fromRectAndRadius(gameRef.continueRect, const Radius.circular(8)), btnContinuePaint);
    btnTextPaint.render(canvas, "Devam Et (Lobi)", Vector2(gameRef.continueRect.left + 20, gameRef.continueRect.top + 15));

    canvas.drawRRect(RRect.fromRectAndRadius(gameRef.exitRect, const Radius.circular(8)), btnLeavePaint);
    btnTextPaint.render(canvas, "Odadan Çık", Vector2(gameRef.exitRect.left + 35, gameRef.exitRect.top + 15));
  }
}

class TankGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  final NetworkService networkService;
  final VoidCallback onContinue;
  final VoidCallback onLeave;

  late JoystickComponent joystick;
  late Tank playerTank;
  late PositionComponent fireButton;
  late TextComponent ammoText;
  late TextComponent timerText;

  final ScoreboardHUD _scoreboardHUD = ScoreboardHUD();
  late EndGameHUD _endGameHUD;
  
  final Map<String, EnemyTank> enemies = {};
  final Map<String, LootBox> loots = {};
  
  double _lootTimer = 0;
  late double remainingTime;
  bool isGameOver = false;

  late Rect continueRect;
  late Rect exitRect;

  TankGame({required this.networkService, required this.onContinue, required this.onLeave});

  @override
  Color backgroundColor() {
    if (networkService.selectedMap == 1) return const Color(0xFFD2B48C);
    if (networkService.selectedMap == 2) return const Color(0xFFE0F7FA); // YENİ: Buzul arkaplanı
    return Colors.blueGrey.shade900;
  }

  Vector2 getSpawnPoint(int index) {
    switch (index % 4) {
      case 0: return Vector2(100, 100);
      case 1: return Vector2(1400, 100);
      case 2: return Vector2(100, 900);
      case 3: return Vector2(1400, 900);
      default: return Vector2(750, 500);
    }
  }

  void showScoreboard() => _scoreboardHUD.isVisible = true;
  void hideScoreboard() => _scoreboardHUD.isVisible = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    remainingTime = networkService.selectedTime.toDouble();
    _endGameHUD = EndGameHUD();

    networkService.onPlayerMove = (playerId, x, y, angle) {
      if (!enemies.containsKey(playerId)) {
        int enemySpawnIndex = 0;
        String enemyName = "Bilinmeyen";
        for (var p in networkService.lobbyPlayers) {
          if (p['id'] == playerId) { enemySpawnIndex = p['spawnIndex']; enemyName = p['name']; }
        }
        final newEnemy = EnemyTank(playerName: enemyName, position: getSpawnPoint(enemySpawnIndex));
        enemies[playerId] = newEnemy;
        world.add(newEnemy);
      }
      enemies[playerId]?.updatePosition(x, y, angle);
    };

    networkService.onPlayerShoot = (playerId, x, y, angle) {
      _spawnBullet(x, y, angle, ownerId: playerId, isEnemy: true);
    };

    networkService.onHealthUpdate = (playerId, newHealth) => enemies[playerId]?.updateHealth(newHealth);
    networkService.onPlayerRespawn = (playerId, x, y, angle) => enemies[playerId]?.respawn(x, y, angle);
    networkService.onLootSpawned = (id, type, x, y) {
      final loot = LootBox(id: id, type: type, position: Vector2(x, y));
      loots[id] = loot;
      world.add(loot);
    };
    networkService.onLootCollected = (id) {
      if (loots.containsKey(id)) {
        loots[id]?.removeFromParent();
        loots.remove(id);
      }
    };

    final knobPaint = BasicPalette.blue.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.blue.withAlpha(100).paint();

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );

    fireButton = CircleComponent(radius: 40, paint: Paint()..color = Colors.red.withAlpha(150), position: Vector2(size.x - 100, size.y - 100));

    ammoText = TextComponent(
      text: '',
      textRenderer: TextPaint(style: TextStyle(color: networkService.selectedMap == 2 ? Colors.black : Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      position: Vector2(size.x - 180, size.y - 150),
    );

    timerText = TextComponent(
      text: '',
      textRenderer: TextPaint(style: TextStyle(color: networkService.selectedMap == 2 ? Colors.black : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
      position: Vector2(size.x / 2 - 40, 20),
    );

    _createBorders();

    playerTank = Tank(
      playerName: networkService.myName,
      spawnPosition: getSpawnPoint(networkService.mySpawnIndex),
      joystick: joystick,
      networkService: networkService,
    );

    world.add(playerTank);
    camera.follow(playerTank);
    camera.viewport.add(joystick);
    camera.viewport.add(fireButton);
    camera.viewport.add(ammoText);
    camera.viewport.add(timerText);
    camera.viewport.add(_scoreboardHUD);
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isGameOver) {
      if (continueRect.contains(event.canvasPosition.toOffset())) onContinue();
      else if (exitRect.contains(event.canvasPosition.toOffset())) onLeave();
      return;
    }
    if (fireButton.containsPoint(event.canvasPosition)) _shoot();
  }

  void _shoot() {
    if (playerTank.isDead) return;
    if (playerTank.ammo == 0) return; 
    if (playerTank.ammo > 0) playerTank.ammo--;

    _spawnBullet(playerTank.position.x, playerTank.position.y, playerTank.angle, ownerId: networkService.myId, isEnemy: false);
    networkService.sendShoot(playerTank.position.x, playerTank.position.y, playerTank.angle);
  }

  void _spawnBullet(double x, double y, double angle, {required String ownerId, required bool isEnemy}) {
    final offset = Vector2(sin(angle) * 25, -cos(angle) * 25);
    world.add(Bullet(position: Vector2(x, y) + offset, angle: angle, ownerId: ownerId, isEnemy: isEnemy));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    continueRect = Rect.fromLTWH(size.x / 2 - 180, size.y / 2 + 100, 170, 50);
    exitRect = Rect.fromLTWH(size.x / 2 + 10, size.y / 2 + 100, 170, 50);
    
    fireButton.position = Vector2(size.x - 100, size.y - 100);
    ammoText.position = Vector2(size.x - 180, size.y - 160);
    timerText.position = Vector2(size.x / 2 - 40, 20);

    ammoText.text = networkService.selectedMap == 1 ? "Mermi: ${playerTank.ammo}" : "Mermi: Sınırsız";

    if (!isGameOver) {
      remainingTime -= dt;
      if (remainingTime <= 0) {
        remainingTime = 0;
        isGameOver = true;
        playerTank.isDead = true; 
        for (var enemy in enemies.values) enemy.isDead = true;
        camera.viewport.add(_endGameHUD); 
      }
    }

    int mins = (remainingTime / 60).floor();
    int secs = (remainingTime % 60).floor();
    timerText.text = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    if (!isGameOver && networkService.isHost && networkService.selectedMap == 1) {
      _lootTimer += dt;
      if (_lootTimer > 7.0) {
        _lootTimer = 0;
        final rand = Random();
        double x = 150 + rand.nextDouble() * 1200;
        double y = 150 + rand.nextDouble() * 700;
        int type = rand.nextBool() ? 0 : 1; 
        String id = "loot_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(100)}";
        
        networkService.sendSpawnLoot(id, type, x, y);
        
        final loot = LootBox(id: id, type: type, position: Vector2(x, y));
        loots[id] = loot;
        world.add(loot);
      }
    }
  }

  void _createBorders() {
    final double thickness = 20.0;
    final double w = 1500.0;
    final double h = 1000.0;
    
    Color wallColor;
    if (networkService.selectedMap == 1) wallColor = Colors.brown.shade800;
    else if (networkService.selectedMap == 2) wallColor = Colors.cyan.shade700; // YENİ: Buzul Duvarı
    else wallColor = Colors.grey.shade800;

    world.add(Wall(position: Vector2(0, 0), size: Vector2(w, thickness), color: wallColor));
    world.add(Wall(position: Vector2(0, h - thickness), size: Vector2(w, thickness), color: wallColor));
    world.add(Wall(position: Vector2(0, 0), size: Vector2(thickness, h), color: wallColor));
    world.add(Wall(position: Vector2(w - thickness, 0), size: Vector2(thickness, h), color: wallColor));

    List<List<int>> mapLayout;
    
    if (networkService.selectedMap == 1) {
      mapLayout = [ 
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
        [0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        [0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
        [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
      ];
    } else if (networkService.selectedMap == 2) { // YENİ: BUZUL HARİTASI
      mapLayout = [
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0],
        [0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        [0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
        [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0],
        [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0],
      ];
    } else {
      mapLayout = [ 
        [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
        [0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1],
        [0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0],
        [1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 1, 1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0],
        [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0],
      ];
    }

    double tileWidth = w / mapLayout[0].length;
    double tileHeight = h / mapLayout.length;
    for (int row = 0; row < mapLayout.length; row++) {
      for (int col = 0; col < mapLayout[row].length; col++) {
        if (mapLayout[row][col] == 1) {
          world.add(Wall(
            position: Vector2(col * tileWidth + 20, row * tileHeight + 20),
            size: Vector2(tileWidth * 0.6, tileHeight * 0.4),
            color: wallColor,
          ));
        }
      }
    }
  }
}