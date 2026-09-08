import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class EnemyTank extends PositionComponent with CollisionCallbacks {
  final String playerName;
  int health = 5;
  final int maxHealth = 5;
  bool isDead = false;

  late final TextPaint nameTextPaint;
  late final double nameWidth;

  final Paint bodyPaint = Paint()..color = const Color.fromARGB(255, 16, 14, 114);
  final Paint barrelPaint = Paint()..color = Colors.blue..strokeWidth = 4;
  final Paint hpBasePaint = Paint()..color = Colors.grey;
  final Paint hpCurrentPaint = Paint()..color = Colors.green;

  Vector2? targetPosition;
  double? targetAngle;

  EnemyTank({required this.playerName, required Vector2 position}) : super(position: position, size: Vector2(25, 25), anchor: Anchor.center) {
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

  void updateHealth(int newHealth) {
    health = newHealth;
    isDead = health <= 0;
  }

  void respawn(double newX, double newY, double newAngle) {
    health = maxHealth;
    isDead = false;
    position = Vector2(newX, newY);
    targetPosition = position.clone();
    angle = newAngle;
    targetAngle = newAngle;
  }

  void updatePosition(double newX, double newY, double newAngle) {
    targetPosition = Vector2(newX, newY);
    targetAngle = newAngle;

    // Paket kaybı nedeniyle öldü sanılan tank hareket paketi alıyorsa görünür yapılır
    if (isDead && health > 0) {
      isDead = false;
    }

    if (position.isZero()) {
      position = targetPosition!.clone();
      angle = targetAngle!;
    }
  }

  @override
  void update(double dt) {
    if (isDead) return;
    super.update(dt);

    if (targetPosition != null) {
      position.lerp(targetPosition!, dt * 15);
    }
    if (targetAngle != null) {
      double diff = (targetAngle! - angle) % (2 * pi);
      if (diff > pi) diff -= 2 * pi;
      if (diff < -pi) diff += 2 * pi;
      angle += diff * dt * 15;
    }
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
}