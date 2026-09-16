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
import '../components/football.dart';
import '../network/network_service.dart';

class ScoreboardHUD extends PositionComponent with HasGameRef<TankGame> {
  bool isVisible = false;
  final Paint bgPaint = Paint()..color = Colors.black87;
  final TextPaint titlePaint = TextPaint(style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold));
  final TextPaint scorePaint = TextPaint(style: const TextStyle(color: Colors.white, fontSize: 20));

  @override
  void render(Canvas canvas) {
    if (!isVisible || gameRef.networkService.selectedMap == 3) return; 
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), bgPaint);
    titlePaint.render(canvas, "ÖLDÜN! BEKLE...", Vector2(gameRef.size.x / 2 - 130, 40));
    double yPos = 100;
    for (var p in gameRef.networkService.lobbyPlayers) {
      scorePaint.render(canvas, "${p['name']} : ${p['score'] ?? 0} Skor", Vector2(gameRef.size.x / 2 - 100, yPos));
      yPos += 35;
    }
  }
}

class LiveTopScoreHUD extends PositionComponent with HasGameRef<TankGame> {
  final TextPaint textPaint = TextPaint(style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold));
  
  // YENİ: Futbol modu için siyah yazı ve beyaz gölgeli özel stil (Arka plansız)
  final TextPaint footballTextPaint = TextPaint(style: const TextStyle(
    color: Colors.black, 
    fontSize: 22, 
    fontWeight: FontWeight.bold,
    shadows: [Shadow(blurRadius: 2.0, color: Colors.white, offset: Offset(1.0, 1.0))]
  ));
  
  final Paint bgPaint = Paint()..color = Colors.black.withOpacity(0.5);

  @override
  void render(Canvas canvas) {
    if (gameRef.networkService.selectedMap == 3) {
      double yPos = 20;
      textPaint.render(canvas, "El: ${gameRef.currentRound}/${gameRef.networkService.selectedTime}", Vector2(20, yPos));
      yPos += 25;
      for (var p in gameRef.networkService.lobbyPlayers) {
        textPaint.render(canvas, "${p['name']}: ${p['score']}", Vector2(20, yPos));
        yPos += 22;
      }
    } else if (gameRef.networkService.selectedMap == 4) {
      double cx = gameRef.size.x / 2;
      // Arka plan kutusu tamamen kaldırıldı, sadece temiz metin çiziliyor.
      footballTextPaint.render(canvas, "Mavi Takım  ${gameRef.networkService.teamScoreA} - ${gameRef.networkService.teamScoreB}  Kırmızı Takım   |", Vector2(cx - 240, 15));
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
    canvas.drawRect(Rect.fromLTWH(0, 0, gameRef.size.x, gameRef.size.y), bgPaint);
    
    String title = gameRef.networkService.selectedMap == 3 ? "OYUN BİTTİ - LİDERLİK TABLOSU" : "SÜRE BİTTİ - LİDERLİK TABLOSU";
    if (gameRef.networkService.selectedMap == 4) title = "MAÇ BİTTİ - SKOR TABLOSU";

    titlePaint.render(canvas, title, Vector2(cx - 280, 40));

    double yPos = 120;
    if (gameRef.networkService.selectedMap == 4) {
      scorePaint.render(canvas, "Takım A: ${gameRef.networkService.teamScoreA} Gol", Vector2(cx - 100, yPos));
      scorePaint.render(canvas, "Takım B: ${gameRef.networkService.teamScoreB} Gol", Vector2(cx - 100, yPos + 40));
    } else {
      List<Map<String, dynamic>> sortedPlayers = List.from(gameRef.networkService.lobbyPlayers);
      sortedPlayers.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      for (int i = 0; i < sortedPlayers.length; i++) {
        var p = sortedPlayers[i];
        scorePaint.render(canvas, "${i + 1}. ${p['name']} - ${p['score']} Puan", Vector2(cx - 150, yPos));
        yPos += 45;
      }
    }

    canvas.drawRRect(RRect.fromRectAndRadius(gameRef.continueRect, const Radius.circular(8)), btnContinuePaint);
    btnTextPaint.render(canvas, "Devam Et (Lobi)", Vector2(gameRef.continueRect.left + 20, gameRef.continueRect.top + 15));
    canvas.drawRRect(RRect.fromRectAndRadius(gameRef.exitRect, const Radius.circular(8)), btnLeavePaint);
    btnTextPaint.render(canvas, "Odadan Çık", Vector2(gameRef.exitRect.left + 35, gameRef.exitRect.top + 15));
  }
}

class MazeCell {
  int x, y;
  bool top = true, right = true, bottom = true, left = true, visited = false;
  MazeCell(this.x, this.y);
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
  final LiveTopScoreHUD _liveTopHUD = LiveTopScoreHUD();
  late EndGameHUD _endGameHUD;
  
  Football? ball; 

  final Map<String, EnemyTank> enemies = {};
  final Map<String, LootBox> loots = {};
  final List<Wall> currentWalls = []; 
  
  double _lootTimer = 0;
  late double remainingTime;
  int currentRound = 1;
  bool isGameOver = false;
  bool _roundEndingTriggered = false; 
  double _gracePeriod = 2.5;

  late Rect continueRect;
  late Rect exitRect;
  int? currentArenaSeed; 

  TankGame({required this.networkService, required this.onContinue, required this.onLeave});

  @override
  Color backgroundColor() {
    if (networkService.selectedMap == 1) return const Color(0xFFD2B48C);
    if (networkService.selectedMap == 2) return const Color(0xFFE0F7FA);
    if (networkService.selectedMap == 3) return const Color(0xFFEEEEEE); 
    if (networkService.selectedMap == 4) return const Color(0xFF1976D2); // YENİ: Mavi Futbol Sahası
    return Colors.blueGrey.shade900;
  }

  Vector2 getSpawnPoint(int index, {int? seed}) {
    if (networkService.selectedMap == 4) {
      Random rng = Random();
      // YENİ: Genişletilmiş saha koordinatlarına göre (1400 genişlik)
      if (networkService.myTeam == 0) return Vector2(150, 300 + rng.nextDouble() * 200); 
      return Vector2(1250, 300 + rng.nextDouble() * 200); 
    }

    if (networkService.selectedMap == 3) {
      int r = 5, c = 7;
      if (seed != null) { Random rng = Random(seed); r = 5 + rng.nextInt(3); c = 7 + rng.nextInt(4); }
      double cellW = 1000.0 / c; double cellH = 750.0 / r;
      int targetRow = 0, targetCol = 0;
      switch (index % 8) { 
        case 0: targetRow = 0; targetCol = 0; break; 
        case 1: targetRow = r - 1; targetCol = c - 1; break; 
        case 2: targetRow = 0; targetCol = c - 1; break; 
        case 3: targetRow = r - 1; targetCol = 0; break; 
        case 4: targetRow = 0; targetCol = c ~/ 2; break; 
        case 5: targetRow = r - 1; targetCol = c ~/ 2; break; 
        case 6: targetRow = r ~/ 2; targetCol = 0; break; 
        case 7: targetRow = r ~/ 2; targetCol = c - 1; break; 
      }
      return Vector2(targetCol * cellW + cellW / 2, targetRow * cellH + cellH / 2);
    }
    
    switch (index % 8) { 
      case 0: return Vector2(100, 100); case 1: return Vector2(1400, 900); case 2: return Vector2(1400, 100); case 3: return Vector2(100, 900); case 4: return Vector2(750, 100); case 5: return Vector2(750, 900); case 6: return Vector2(100, 500); case 7: return Vector2(1400, 500); default: return Vector2(750, 500);
    }
  }

  void showScoreboard() => _scoreboardHUD.isVisible = true;
  void hideScoreboard() => _scoreboardHUD.isVisible = false;

  void handleGoal(int team) {
    if (ball != null) {
      ball!.ownerId = null;
      ball!.velocity = Vector2.zero();
      // YENİ: Top Genişletilmiş Sahanın Tam Merkezine (700x400) Döner
      ball!.position = Vector2(700, 400); 
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    remainingTime = networkService.selectedTime.toDouble();
    _endGameHUD = EndGameHUD();
    _gracePeriod = 2.5; 

    networkService.onPlayerMove = (playerId, x, y, angle) {
      if (!enemies.containsKey(playerId)) {
        int enemySpawnIndex = 0, enemyTeam = 0;
        String enemyName = "Bilinmeyen";
        for (var p in networkService.lobbyPlayers) {
          if (p['id'] == playerId) { enemySpawnIndex = p['spawnIndex']; enemyName = p['name']; enemyTeam = p['team']; }
        }
        final newEnemy = EnemyTank(playerName: enemyName, position: getSpawnPoint(enemySpawnIndex, seed: currentArenaSeed), team: enemyTeam);
        enemies[playerId] = newEnemy;
        world.add(newEnemy);
      }
      enemies[playerId]?.updatePosition(x, y, angle);
    };

    networkService.onPlayerShoot = (playerId, x, y, angle, type) {
      _spawnBullet(x, y, angle, ownerId: playerId, isEnemy: true, type: type);
    };

    networkService.onHealthUpdate = (playerId, newHealth) => enemies[playerId]?.updateHealth(newHealth);
    networkService.onPlayerRespawn = (playerId, x, y, angle) => enemies[playerId]?.respawn(x, y, angle);
    networkService.onShieldUpdate = (playerId, state) => enemies[playerId]?.setShield(state); 
    
    networkService.onCatchBall = (id) => ball?.catchBall(id);
    networkService.onShootBall = (id, x, y, a) { ball?.position = Vector2(x, y); ball?.shootBall(a); };
    networkService.onGoalScored = (team) => handleGoal(team);

    networkService.onLootSpawned = (id, type, x, y) {
      final loot = LootBox(id: id, type: type, position: Vector2(x, y));
      loots[id] = loot;
      world.add(loot);
    };
    networkService.onLootCollected = (id) {
      if (loots.containsKey(id)) { loots[id]?.removeFromParent(); loots.remove(id); }
    };

    networkService.onNewRound = (seed, rows, cols, round) {
      currentArenaSeed = seed; currentRound = round; _roundEndingTriggered = false; _gracePeriod = 2.5; 
      for (var w in currentWalls) w.removeFromParent(); currentWalls.clear();
      for (var l in loots.values) l.removeFromParent(); loots.clear();
      children.whereType<Bullet>().forEach((b) => b.removeFromParent());
      world.children.whereType<Bullet>().forEach((b) => b.removeFromParent());

      _buildArenaMaze(seed, rows, cols);

      playerTank.health = 1; playerTank.isDead = false; playerTank.isShielded = true; 
      playerTank.shieldTimer = 5.0; playerTank.nextShotType = 0; 
      playerTank.position = getSpawnPoint(networkService.mySpawnIndex, seed: seed);
      playerTank.angle = 0;
      networkService.sendRespawn(playerTank.position.x, playerTank.position.y, 0);

      enemies.forEach((k, v) {
        v.health = 1; v.isDead = false; v.isShielded = true;
        int eIdx = 0; for(var p in networkService.lobbyPlayers) if(p['id'] == k) eIdx = p['spawnIndex'];
        v.position = getSpawnPoint(eIdx, seed: seed);
      });
    };

    final knobPaint = BasicPalette.blue.withAlpha(200).paint();
    final backgroundPaint = BasicPalette.blue.withAlpha(100).paint();

    joystick = JoystickComponent(
      knob: CircleComponent(radius: 20, paint: knobPaint),
      background: CircleComponent(radius: 50, paint: backgroundPaint),
      margin: EdgeInsets.only(left: GameSettings.joyLeft, bottom: GameSettings.joyBottom),
    );

    fireButton = CircleComponent(radius: 40, paint: Paint()..color = Colors.red.withAlpha(150));
    ammoText = TextComponent(text: '', textRenderer: TextPaint(style: TextStyle(color: networkService.selectedMap == 2 ? Colors.black : Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1.0, 1.0))])));
    
    // YENİ: Süre yazısının rengi Futbol haritasında (Map 4) da siyah olacak.
    Color timerColor = (networkService.selectedMap == 2 || networkService.selectedMap == 4) ? Colors.black : Colors.white;
    Color shadowColor = (networkService.selectedMap == 2 || networkService.selectedMap == 4) ? Colors.white : Colors.black;

    timerText = TextComponent(
      text: '', 
      textRenderer: TextPaint(style: TextStyle(color: timerColor, fontSize: 30, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2.0, color: shadowColor, offset: const Offset(1.0, 1.0))])), 
      position: Vector2(size.x / 2 - 40, 20)
    );

    if (networkService.selectedMap == 3) {
      if (networkService.isHost) {
        currentArenaSeed = DateTime.now().millisecondsSinceEpoch;
        Random rng = Random(currentArenaSeed!);
        int rows = 5 + rng.nextInt(3); int cols = 7 + rng.nextInt(4);
        networkService.sendNewRound(currentArenaSeed!, rows, cols, 1);
        _buildArenaMaze(currentArenaSeed!, rows, cols); 
      }
    } else if (networkService.selectedMap == 4) {
      _createFootballField(); 
    } else {
      _createBorders(); 
    }

    playerTank = Tank(playerName: networkService.myName, spawnPosition: getSpawnPoint(networkService.mySpawnIndex, seed: currentArenaSeed), joystick: joystick, networkService: networkService);
    world.add(playerTank);
    
    if (networkService.selectedMap == 3) {
      camera.viewfinder.visibleGameSize = Vector2(1000, 750);
      camera.viewfinder.position = Vector2(500, 375); 
      camera.viewfinder.anchor = Anchor.center;
    } else if (networkService.selectedMap == 4) {
      // YENİ: Futbol Sahası Genişliği (1400x800) için Kamera Ayarı
      camera.viewfinder.visibleGameSize = Vector2(1400, 800);
      camera.viewfinder.position = Vector2(700, 400); 
      camera.viewfinder.anchor = Anchor.center;
    } else {
      camera.follow(playerTank);
    }
    
    camera.viewport.add(joystick);
    camera.viewport.add(fireButton);
    if (networkService.selectedMap != 4) camera.viewport.add(ammoText); 
    camera.viewport.add(timerText); 
    camera.viewport.add(_liveTopHUD);
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
    
    if (ball?.ownerId == networkService.myId) {
      ball!.shootBall(playerTank.angle);
      networkService.sendShootBall(playerTank.position.x, playerTank.position.y, playerTank.angle);
      return;
    }
    
    if (playerTank.ammo == 0) return; 
    if (playerTank.ammo > 0) playerTank.ammo--;

    int shotType = playerTank.nextShotType;
    playerTank.nextShotType = 0;
    _spawnBullet(playerTank.position.x, playerTank.position.y, playerTank.angle, ownerId: networkService.myId, isEnemy: false, type: shotType);
    networkService.sendShoot(playerTank.position.x, playerTank.position.y, playerTank.angle, shotType);
  }

  void _spawnBullet(double x, double y, double angle, {required String ownerId, required bool isEnemy, int type = 0}) {
    final offset = Vector2(sin(angle) * 25, -cos(angle) * 25);
    world.add(Bullet(position: Vector2(x, y) + offset, angle: angle, ownerId: ownerId, isEnemy: isEnemy, bulletType: type, isArena: (networkService.selectedMap == 3 || networkService.selectedMap == 4)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    continueRect = Rect.fromLTWH(size.x / 2 - 180, size.y / 2 + 100, 170, 50);
    exitRect = Rect.fromLTWH(size.x / 2 + 10, size.y / 2 + 100, 170, 50);
    
    fireButton.position = Vector2(size.x - GameSettings.fireRight - 80, size.y - GameSettings.fireBottom - 80);
    ammoText.position = Vector2(fireButton.position.x - 80, fireButton.position.y - 40);
    
    ammoText.text = networkService.selectedMap == 1 ? "Mermi: ${playerTank.ammo}" : "Mermi: Sınırsız";

    if (!isGameOver) {
      if (networkService.selectedMap == 3) {
        if (_gracePeriod > 0) {
          _gracePeriod -= dt;
        } else if (networkService.isHost && !_roundEndingTriggered) {
          int aliveCount = 0; String? lastAliveId;
          if (!playerTank.isDead) { aliveCount++; lastAliveId = networkService.myId; }
          enemies.forEach((k, v) { if (!v.isDead) { aliveCount++; lastAliveId = k; } });

          bool roundOver = false;
          if (networkService.lobbyPlayers.length == 1) { if (aliveCount == 0) roundOver = true; } 
          else { if (aliveCount <= 1) roundOver = true; }

          if (roundOver) {
            _roundEndingTriggered = true;
            Future.delayed(const Duration(seconds: 2), () {
              if (aliveCount == 1 && lastAliveId != null) networkService.addScoreToPlayer(lastAliveId!); 
              if (currentRound >= networkService.selectedTime) _triggerGameOver(); 
              else {
                int nextSeed = DateTime.now().millisecondsSinceEpoch;
                Random rng = Random(nextSeed);
                int r = 5 + rng.nextInt(3); int c = 7 + rng.nextInt(4);
                networkService.sendNewRound(nextSeed, r, c, currentRound + 1);
                networkService.onNewRound?.call(nextSeed, r, c, currentRound + 1); 
              }
            });
          }
        }
      } else {
        remainingTime -= dt;
        if (remainingTime <= 0) {
          remainingTime = 0;
          _triggerGameOver();
        }
        int mins = (remainingTime / 60).floor();
        int secs = (remainingTime % 60).floor();
        timerText.text = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
        
        // YENİ: Süre yazısını Futbol modunda skorun sağına taşı
        if (networkService.selectedMap == 4) {
          timerText.position = Vector2(size.x / 2 + 130, 10);
        } else {
          timerText.position = Vector2(size.x / 2 - 40, 20);
        }
      }
    }

    if (!isGameOver && networkService.isHost && networkService.selectedMap != 4) { 
      _lootTimer += dt;
      if (_lootTimer > 7.0) {
        _lootTimer = 0;
        final rand = Random();
        double w = networkService.selectedMap == 3 ? 1000.0 : 1500.0;
        double h = networkService.selectedMap == 3 ? 750.0 : 1000.0;
        double x = 50 + rand.nextDouble() * (w - 100);
        double y = 50 + rand.nextDouble() * (h - 100);
        
        int type;
        if (networkService.selectedMap == 3) type = 2 + rand.nextInt(3); 
        else if (networkService.selectedMap == 1) {
          int chance = rand.nextInt(100);
          if (chance < 60) type = 1; else if (chance < 80) type = 0; else type = 2; 
        } else type = rand.nextBool() ? 0 : 2; 
        
        String id = "loot_${DateTime.now().millisecondsSinceEpoch}_${rand.nextInt(100)}";
        networkService.sendSpawnLoot(id, type, x, y);
        final loot = LootBox(id: id, type: type, position: Vector2(x, y));
        loots[id] = loot;
        world.add(loot);
      }
    }
  }

  void _triggerGameOver() {
    isGameOver = true;
    playerTank.isDead = true; 
    for (var enemy in enemies.values) enemy.isDead = true;
    camera.viewport.add(_endGameHUD); 
  }
  
  // YENİ: Genişletilmiş ve Daha Taktiksel Futbol Sahası (1400x800)
  void _createFootballField() {
    final double thickness = 15.0;
    final double w = 1400.0;
    final double h = 800.0;
    Color lineColor = Colors.white;
    Color obstacleColor = Colors.blue.shade900; // Taktiksel Engel Rengi

    // Dış Sınırlar (Taç çizgileri)
    Wall topWall = Wall(position: Vector2(0, 0), size: Vector2(w, thickness), color: lineColor);
    Wall bottomWall = Wall(position: Vector2(0, h - thickness), size: Vector2(w, thickness), color: lineColor);
    // Sol ve Sağ kenar çizgileri (Kaleler 200px boyunda açık olacak)
    Wall leftWall1 = Wall(position: Vector2(0, 0), size: Vector2(thickness, 300), color: lineColor);
    Wall leftWall2 = Wall(position: Vector2(0, 500), size: Vector2(thickness, 300), color: lineColor);
    Wall rightWall1 = Wall(position: Vector2(w - thickness, 0), size: Vector2(thickness, 300), color: lineColor);
    Wall rightWall2 = Wall(position: Vector2(w - thickness, 500), size: Vector2(thickness, 300), color: lineColor);
    
    // TAKTİKSEL ENGELLER (Kare ve Dikdörtgen Siperler)
    // Orta alanı nispeten açık bırakıp kenarları savunmaya yönelik tasarladık
    Wall obs1 = Wall(position: Vector2(500, 150), size: Vector2(400, 30), color: obstacleColor); // Üst uzun siper
    Wall obs2 = Wall(position: Vector2(500, 620), size: Vector2(400, 30), color: obstacleColor); // Alt uzun siper
    
    Wall obs3 = Wall(position: Vector2(250, 200), size: Vector2(50, 150), color: obstacleColor); // Sol üst kalkan
    Wall obs4 = Wall(position: Vector2(250, 450), size: Vector2(50, 150), color: obstacleColor); // Sol alt kalkan
    
    Wall obs5 = Wall(position: Vector2(1100, 200), size: Vector2(50, 150), color: obstacleColor); // Sağ üst kalkan
    Wall obs6 = Wall(position: Vector2(1100, 450), size: Vector2(50, 150), color: obstacleColor); // Sağ alt kalkan

    Wall obs7 = Wall(position: Vector2(450, 350), size: Vector2(50, 100), color: obstacleColor); // Orta sol kare
    Wall obs8 = Wall(position: Vector2(900, 350), size: Vector2(50, 100), color: obstacleColor); // Orta sağ kare

    // KALELER (İçeri Girilirse Gol)
    Wall goalLeft = Wall(position: Vector2(-40, 300), size: Vector2(50, 200), color: Colors.blue.shade300, isGoal: true, teamId: 0);
    Wall goalRight = Wall(position: Vector2(1390, 300), size: Vector2(50, 200), color: Colors.red.shade300, isGoal: true, teamId: 1);

    currentWalls.addAll([topWall, bottomWall, leftWall1, leftWall2, rightWall1, rightWall2, goalLeft, goalRight, obs1, obs2, obs3, obs4, obs5, obs6, obs7, obs8]);
    world.addAll(currentWalls);
    
    // Topu Sahanın Merkezine (700x400) Ekle
    ball = Football(position: Vector2(700, 400));
    world.add(ball!);
  }

  void _buildArenaMaze(int seed, int rows, int cols) {
    final double thickness = 15.0;
    final double w = 1000.0;
    final double h = 750.0;
    Color wallColor = Colors.grey.shade800;

    Wall topWall = Wall(position: Vector2(0, 0), size: Vector2(w, thickness), color: wallColor);
    Wall bottomWall = Wall(position: Vector2(0, h - thickness), size: Vector2(w, thickness), color: wallColor);
    Wall leftWall = Wall(position: Vector2(0, 0), size: Vector2(thickness, h), color: wallColor);
    Wall rightWall = Wall(position: Vector2(w - thickness, 0), size: Vector2(thickness, h), color: wallColor);
    currentWalls.addAll([topWall, bottomWall, leftWall, rightWall]);
    world.addAll([topWall, bottomWall, leftWall, rightWall]);

    List<List<MazeCell>> grid = List.generate(rows, (y) => List.generate(cols, (x) => MazeCell(x, y)));
    Random rng = Random(seed);
    
    void dfs(int cx, int cy) {
      grid[cy][cx].visited = true;
      List<int> dirs = [0, 1, 2, 3]; 
      dirs.shuffle(rng);
      
      for (int dir in dirs) {
        int nx = cx, ny = cy;
        if (dir == 0) ny -= 1; else if (dir == 1) nx += 1; else if (dir == 2) ny += 1; else if (dir == 3) nx -= 1;
        if (nx >= 0 && nx < cols && ny >= 0 && ny < rows && !grid[ny][nx].visited) {
          if (dir == 0) { grid[cy][cx].top = false; grid[ny][nx].bottom = false; }
          else if (dir == 1) { grid[cy][cx].right = false; grid[ny][nx].left = false; }
          else if (dir == 2) { grid[cy][cx].bottom = false; grid[ny][nx].top = false; }
          else if (dir == 3) { grid[cy][cx].left = false; grid[ny][nx].right = false; }
          dfs(nx, ny);
        }
      }
    }
    dfs(0, 0); 
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (rng.nextDouble() < 0.25) grid[y][x].right = false; 
        if (rng.nextDouble() < 0.25) grid[y][x].bottom = false;
      }
    }
    double cellW = w / cols; double cellH = h / rows;
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        if (grid[y][x].bottom && y < rows - 1) {
          Wall w = Wall(position: Vector2(x * cellW, (y + 1) * cellH), size: Vector2(cellW, thickness), color: wallColor);
          currentWalls.add(w); world.add(w);
        }
        if (grid[y][x].right && x < cols - 1) {
          Wall w = Wall(position: Vector2((x + 1) * cellW, y * cellH), size: Vector2(thickness, cellH), color: wallColor);
          currentWalls.add(w); world.add(w);
        }
      }
    }
  }

  void _createBorders() {
    final double thickness = 20.0;
    final double w = 1500.0;
    final double h = 1000.0;
    
    Color wallColor;
    if (networkService.selectedMap == 1) wallColor = Colors.brown.shade800;
    else if (networkService.selectedMap == 2) wallColor = Colors.cyan.shade700;
    else wallColor = Colors.grey.shade800;

    Wall topWall = Wall(position: Vector2(0, 0), size: Vector2(w, thickness), color: wallColor);
    Wall bottomWall = Wall(position: Vector2(0, h - thickness), size: Vector2(w, thickness), color: wallColor);
    Wall leftWall = Wall(position: Vector2(0, 0), size: Vector2(thickness, h), color: wallColor);
    Wall rightWall = Wall(position: Vector2(w - thickness, 0), size: Vector2(thickness, h), color: wallColor);
    currentWalls.addAll([topWall, bottomWall, leftWall, rightWall]);
    world.addAll([topWall, bottomWall, leftWall, rightWall]);

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
    } else if (networkService.selectedMap == 2) { 
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
          Wall wall = Wall(position: Vector2(col * tileWidth + 20, row * tileHeight + 20), size: Vector2(tileWidth * 0.6, tileHeight * 0.4), color: wallColor);
          currentWalls.add(wall);
          world.add(wall);
        }
      }
    }
  }
}