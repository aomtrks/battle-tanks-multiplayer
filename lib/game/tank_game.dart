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
import '../network/network_service.dart';

class ScoreboardHUD extends PositionComponent with HasGameRef<TankGame> {
  bool isVisible = false;

  final Paint bgPaint = Paint()..color = Colors.black87;
  final TextPaint titlePaint = TextPaint(
    style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold),
  );
  final TextPaint scorePaint = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 20),
  );

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;

    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), bgPaint);
    titlePaint.render(canvas, "ÖLDÜN! SKOR TABLOSU", Vector2(gameRef.size.x / 2 - 160, 40));

    double yPos = 100;
    for (var p in gameRef.networkService.lobbyPlayers) {
      scorePaint.render(canvas, "${p['name']} : ${p['score'] ?? 0} Skor", Vector2(gameRef.size.x / 2 - 100, yPos));
      yPos += 35;
    }
  }
}

class TankGame extends FlameGame with HasCollisionDetection, TapCallbacks {
  final NetworkService networkService;
  late JoystickComponent joystick;
  late Tank playerTank;
  late PositionComponent fireButton;

  final ScoreboardHUD _scoreboardHUD = ScoreboardHUD();
  final Map<String, EnemyTank> enemies = {};

  TankGame({required this.networkService});

  Vector2 getSpawnPoint(int index) {
    switch (index % 4) {
      case 0:
        return Vector2(100, 100);
      case 1:
        return Vector2(1400, 100);
      case 2:
        return Vector2(100, 900);
      case 3:
        return Vector2(1400, 900);
      default:
        return Vector2(750, 500);
    }
  }

  void showScoreboard() => _scoreboardHUD.isVisible = true;
  void hideScoreboard() => _scoreboardHUD.isVisible = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    networkService.onPlayerMove = (playerId, x, y, angle) {
      if (!enemies.containsKey(playerId)) {
        int enemySpawnIndex = 0;
        String enemyName = "Bilinmeyen";
        for (var p in networkService.lobbyPlayers) {
          if (p['id'] == playerId) {
            enemySpawnIndex = p['spawnIndex'];
            enemyName = p['name'];
          }
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

    networkService.onHealthUpdate = (playerId, newHealth) {
      enemies[playerId]?.updateHealth(newHealth);
    };

    networkService.onPlayerRespawn = (playerId, x, y, angle) {
      enemies[playerId]?.respawn(x, y, angle);
    };

    final knobPaint = BasicPalette.blue.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.blue.withAlpha(100).paint();

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );

    fireButton = CircleComponent(
      radius: 40,
      paint: Paint()..color = Colors.red.withAlpha(150),
      position: Vector2(size.x - 100, size.y - 100),
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
    camera.viewport.add(_scoreboardHUD); // Tek seferde eklenir, asla silinmez
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (fireButton.containsPoint(event.canvasPosition)) {
      _shoot();
    }
  }

  void _shoot() {
    if (playerTank.isDead) return;
    _spawnBullet(playerTank.position.x, playerTank.position.y, playerTank.angle, ownerId: networkService.myId, isEnemy: false);
    networkService.sendShoot(playerTank.position.x, playerTank.position.y, playerTank.angle);
  }

  void _spawnBullet(double x, double y, double angle, {required String ownerId, required bool isEnemy}) {
    final offset = Vector2(sin(angle) * 20, -cos(angle) * 20);
    final bullet = Bullet(position: Vector2(x, y) + offset, angle: angle, ownerId: ownerId, isEnemy: isEnemy);
    world.add(bullet);
  }

  @override
  void update(double dt) {
    super.update(dt);
    fireButton.position = Vector2(size.x - 100, size.y - 100);
  }

  void _createBorders() {
    final double thickness = 20.0;
    final double w = 1500.0;
    final double h = 1000.0;

    world.add(Wall(position: Vector2(0, 0), size: Vector2(w, thickness)));
    world.add(Wall(position: Vector2(0, h - thickness), size: Vector2(w, thickness)));
    world.add(Wall(position: Vector2(0, 0), size: Vector2(thickness, h)));
    world.add(Wall(position: Vector2(w - thickness, 0), size: Vector2(thickness, h)));

    final List<List<int>> mapLayout = [
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

    double tileWidth = w / mapLayout[0].length;
    double tileHeight = h / mapLayout.length;
    for (int row = 0; row < mapLayout.length; row++) {
      for (int col = 0; col < mapLayout[row].length; col++) {
        if (mapLayout[row][col] == 1) {
          world.add(Wall(
            position: Vector2(col * tileWidth + 20, row * tileHeight + 20),
            size: Vector2(tileWidth * 0.6, tileHeight * 0.4),
          ));
        }
      }
    }
  }
}