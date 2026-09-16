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
  final int maxHealth = 5;
  bool isDead = false;
  int ammo = -1;

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

  double _timeSinceLastSync = 0;
  final double _syncRate = 1.0 / 20.0;
  
  // YENİ: Buzul haritası için fizik ve hız değişkenleri
  Vector2 _currentVelocity = Vector2.zero();

  Tank({required this.playerName, required this.spawnPosition, required this.joystick, required this.networkService})
      : super(position: spawnPosition, size: Vector2(28, 32), anchor: Anchor.center) {
    _previousPosition = position.clone();

    if (networkService.selectedMap == 1) ammo = 10; // Çölde 10 mermi, diğerlerinde sınırsız (-1)

    const textStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold);
    nameTextPaint = TextPaint(style: textStyle);
    final tp = TextPainter(text: TextSpan(text: playerName, style: textStyle), textDirection: TextDirection.ltr);
    tp.layout();
    nameWidth = tp.width;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  void takeDamage(String killerId) {
    if (isDead) return;
    health--;
    networkService.sendHealth(health);
    if (health <= 0) dieAndRespawn(killerId);
  }

  void dieAndRespawn(String killerId) {
    if (isDead) return;
    isDead = true;

    networkService.sendDied(killerId);
    gameRef.showScoreboard();

    Future.delayed(const Duration(milliseconds: 1500), () {
      health = maxHealth;
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

    bool isMoving = !joystick.delta.isZero();
    bool isIce = networkService.selectedMap == 2;
    double maxSpeed = isIce ? 220.0 : 150.0; // Buzda daha hızlı

    if (isMoving) {
      Vector2 targetVelocity = joystick.relativeDelta * maxSpeed;
      if (isIce) {
        _currentVelocity.lerp(targetVelocity, dt * 2.0); // Kayarak hızlan/dön
      } else {
        _currentVelocity = targetVelocity; // Anında dön
      }
    } else {
      if (isIce) {
        _currentVelocity.lerp(Vector2.zero(), dt * 2.5); // Kayarak dur
      } else {
        _currentVelocity = Vector2.zero(); // Anında dur
      }
    }

    if (_currentVelocity.length > 5.0) { // Tank çok yavaşlayana kadar dönmeye ve gitmeye devam etsin
      angle = atan2(_currentVelocity.y, _currentVelocity.x) + pi / 2;
      position.add(_currentVelocity * dt);
      
      _timeSinceLastSync += dt;
      if (_timeSinceLastSync >= _syncRate) {
        networkService.sendPosition(position.x, position.y, angle);
        _timeSinceLastSync = 0;
      }
    } else {
      // Durduğunda son pozisyonu ağa bildir
      if (_currentVelocity.length > 0) {
        _currentVelocity = Vector2.zero();
        networkService.sendPosition(position.x, position.y, angle);
      }
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

    canvas.rotate(-angle);

    final barWidth = size.x;
    final barHeight = 5.0;
    final barOffset = Vector2(-size.x / 2, -size.y / 2 - 20);

    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth, barHeight), hpBasePaint);
    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth * (health / maxHealth), barHeight), hpCurrentPaint);

    // İsim yazısı rengini buzul haritasında siyah yapalım ki okunsun
    if (networkService.selectedMap == 2) {
      TextPaint blackText = TextPaint(style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold));
      blackText.render(canvas, playerName, Vector2(-nameWidth / 2, -40));
    } else {
      nameTextPaint.render(canvas, playerName, Vector2(-nameWidth / 2, -40));
    }

    canvas.restore();
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Wall) {
      position = _previousPosition;
      if (networkService.selectedMap == 2) _currentVelocity = Vector2.zero(); // Duvara çarpınca kayma dursun
    }
  }
}