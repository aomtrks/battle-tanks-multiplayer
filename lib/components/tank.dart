import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import '../network/network_service.dart';
import 'wall.dart';

class Tank extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  final JoystickComponent joystick;
  final NetworkService networkService;
  final String playerName;

  int health = 5;
  late int maxHealth;
  bool isDead = false;
  int ammo = -1;
  
  bool isShielded = true; // YENİ: Başlangıçta Tüm Modlarda Kalkanla Doğ
  double shieldTimer = 5.0; // Kalkan Süresi (dışarıdan da erişilebilir)

  late Vector2 _previousPosition;
  final Vector2 spawnPosition;

  late final TextPaint nameTextPaint;
  late final double nameWidth;

  final Paint trackPaint = Paint()..color = Colors.black87;
  final Paint bodyPaint = Paint()..color = const Color.fromARGB(255, 34, 139, 34);
  final Paint turretPaint = Paint()..color = const Color.fromARGB(255, 20, 80, 20);
  final Paint barrelPaint = Paint()..color = Colors.grey.shade400..strokeWidth = 4;
  
  final Paint hpBasePaint = Paint()..color = Colors.grey;
  final Paint hpCurrentPaint = Paint()..color = Colors.green;

  final Paint shieldPaint = Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.fill;
  final Paint shieldBorderPaint = Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 2;

  double _timeSinceLastSync = 0;
  final double _syncRate = 1.0 / 20.0;
  
  Vector2 _currentVelocity = Vector2.zero();

  Tank({required this.playerName, required this.spawnPosition, required this.joystick, required this.networkService})
      : super(position: spawnPosition, size: Vector2(28, 32), anchor: Anchor.center) {
    _previousPosition = position.clone();

    if (networkService.selectedMap == 3) {
      maxHealth = 1;
      health = 1;
    } else {
      maxHealth = 5;
      health = 5;
    }

    if (networkService.selectedMap == 1) ammo = 10; 

    const textStyle = TextStyle(
      color: Colors.white, 
      fontSize: 12, 
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1.0, 1.0))]
    );
    nameTextPaint = TextPaint(style: textStyle);
    final tp = TextPainter(text: TextSpan(text: playerName, style: textStyle), textDirection: TextDirection.ltr);
    tp.layout();
    nameWidth = tp.width;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    networkService.sendShield(true); // YENİ: Doğduğunda kalkanını diğerlerine bildir
  }
  
  void activateShield() {
    isShielded = true;
    shieldTimer = 5.0; 
    networkService.sendShield(true);
  }

  void takeDamage(String killerId) {
    if (isDead || isShielded) return; 
    health--;
    networkService.sendHealth(health);
    if (health <= 0) dieAndRespawn(killerId);
  }

  void dieAndRespawn(String killerId) {
    if (isDead) return;
    isDead = true;
    networkService.sendDied(killerId);

    if (networkService.selectedMap == 3) return;

    gameRef.showScoreboard();

    Future.delayed(const Duration(milliseconds: 1500), () {
      health = maxHealth;
      isShielded = true; // YENİ: Tekrar doğduğunda yine kalkanla başla
      shieldTimer = 5.0;
      networkService.sendShield(true);
      
      if (networkService.selectedMap == 1) ammo = 10;
      position = spawnPosition.clone();
      _previousPosition = spawnPosition.clone();
      _currentVelocity = Vector2.zero();
      isDead = false;

      networkService.sendRespawn(position.x, position.y, angle);
      gameRef.hideScoreboard();
    });
  }

  @override
  void update(double dt) {
    if (isDead) return;

    _previousPosition = position.clone();
    super.update(dt);
    
    if (isShielded) {
      shieldTimer -= dt;
      if (shieldTimer <= 0) {
        isShielded = false;
        networkService.sendShield(false);
      }
    }

    bool isMoving = !joystick.delta.isZero();
    bool isIce = networkService.selectedMap == 2;
    double maxSpeed = isIce ? 220.0 : 150.0;

    if (isMoving) {
      Vector2 targetVelocity = joystick.relativeDelta * maxSpeed;
      if (isIce) {
        _currentVelocity.lerp(targetVelocity, dt * 2.0); 
      } else {
        _currentVelocity = targetVelocity; 
      }
    } else {
      if (isIce) {
        _currentVelocity.lerp(Vector2.zero(), dt * 2.5); 
      } else {
        _currentVelocity = Vector2.zero(); 
      }
    }

    if (_currentVelocity.length > 2.0) { 
      angle = atan2(_currentVelocity.y, _currentVelocity.x) + pi / 2;
      position.add(_currentVelocity * dt);
      
      _timeSinceLastSync += dt;
      if (_timeSinceLastSync >= _syncRate) {
        networkService.sendPosition(position.x, position.y, angle);
        _timeSinceLastSync = 0;
      }
    } else if (!isMoving && _currentVelocity.length > 0) {
      _currentVelocity = Vector2.zero();
      networkService.sendPosition(position.x, position.y, angle);
    }
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-14, -16, 6, 32), const Radius.circular(2)), trackPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8, -16, 6, 32), const Radius.circular(2)), trackPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9, -12, 18, 24), const Radius.circular(4)), bodyPaint);
    canvas.drawLine(Offset.zero, const Offset(0, -25), barrelPaint);
    canvas.drawCircle(Offset.zero, 7, turretPaint);
    
    if (isShielded) {
      canvas.drawCircle(Offset.zero, 25, shieldPaint);
      canvas.drawCircle(Offset.zero, 25, shieldBorderPaint);
    }

    canvas.rotate(-angle);

    final barWidth = size.x;
    final barHeight = 5.0;
    
    nameTextPaint.render(canvas, playerName, Vector2(-nameWidth / 2, -42)); 
    
    final barOffset = Vector2(-size.x / 2, -size.y / 2 - 10); 
    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth, barHeight), hpBasePaint);
    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth * (health / maxHealth), barHeight), hpCurrentPaint);

    canvas.restore();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Wall) {
      position = _previousPosition;
      if (networkService.selectedMap == 2) _currentVelocity = Vector2.zero(); 
    }
  }
}