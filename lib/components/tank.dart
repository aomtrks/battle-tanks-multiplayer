import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import '../network/network_service.dart';
import 'wall.dart';

class Tank extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  final JoystickComponent joystick;
  final double speed = 150.0;
  final NetworkService networkService;
  final String playerName;

  int health = 5;
  final int maxHealth = 5;
  bool isDead = false;

  late Vector2 _previousPosition;
  final Vector2 spawnPosition;

  late final TextPaint nameTextPaint;
  late final double nameWidth;

  final Paint bodyPaint = Paint()..color = const Color.fromARGB(255, 24, 135, 28);
  final Paint barrelPaint = Paint()..color = Colors.red..strokeWidth = 4;
  final Paint hpBasePaint = Paint()..color = Colors.grey;
  final Paint hpCurrentPaint = Paint()..color = Colors.green;

  double _timeSinceLastSync = 0;
  final double _syncRate = 1.0 / 20.0;
  bool _wasMoving = false;

  Tank({required this.playerName, required this.spawnPosition, required this.joystick, required this.networkService})
      : super(position: spawnPosition, size: Vector2(25, 25), anchor: Anchor.center) {
    _previousPosition = position.clone();

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

    if (health <= 0) {
      dieAndRespawn(killerId);
    }
  }

  void dieAndRespawn(String killerId) {
    if (isDead) return;
    isDead = true;

    networkService.sendDied(killerId);
    gameRef.showScoreboard();

    Future.delayed(const Duration(milliseconds: 1500), () {
      health = maxHealth;
      position = spawnPosition.clone();
      _previousPosition = spawnPosition.clone();
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

    if (isMoving) {
      position.add(joystick.relativeDelta * speed * dt);
      angle = joystick.delta.screenAngle();

      _timeSinceLastSync += dt;
      if (_timeSinceLastSync >= _syncRate) {
        networkService.sendPosition(position.x, position.y, angle);
        _timeSinceLastSync = 0;
      }
    } else if (_wasMoving) {
      networkService.sendPosition(position.x, position.y, angle);
      _timeSinceLastSync = 0;
    }

    _wasMoving = isMoving;
  }

  @override
  void render(Canvas canvas) {
    if (isDead) return;

    canvas.drawRect(size.toRect(), bodyPaint);
    canvas.drawLine(Offset(size.x / 2, size.y / 2), Offset(size.x / 2, -20), barrelPaint);

    _drawHealthBar(canvas);

    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.rotate(-angle);
    nameTextPaint.render(canvas, playerName, Vector2(-nameWidth / 2, -35));
    canvas.restore();
  }

  void _drawHealthBar(Canvas canvas) {
    final barWidth = size.x;
    final barHeight = 5.0;
    final barOffset = Vector2(-size.x / 2, -size.y / 2 - 10);

    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth, barHeight), hpBasePaint);
    canvas.drawRect(Rect.fromLTWH(barOffset.x, barOffset.y, barWidth * (health / maxHealth), barHeight), hpCurrentPaint);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Wall) position = _previousPosition;
  }
}