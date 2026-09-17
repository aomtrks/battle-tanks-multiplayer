import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';

class EnemyTank extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  final String playerName;
  int health = 5;
  late int maxHealth;
  bool isDead = false;
  int team = 0; 
  
  bool isShielded = true; 

  late final TextPaint nameTextPaint;
  late final double nameWidth;

  final Paint trackPaint = Paint()..color = Colors.black87;
  late final Paint bodyPaint; 
  final Paint turretPaint = Paint()..color = const Color.fromARGB(255, 80, 20, 20);
  final Paint barrelPaint = Paint()..color = Colors.grey.shade400..strokeWidth = 4;
  
  final Paint hpBasePaint = Paint()..color = Colors.grey;
  final Paint hpCurrentPaint = Paint()..color = Colors.green;
  final Paint shieldPaint = Paint()..color = Colors.blueAccent.withOpacity(0.4)..style = PaintingStyle.fill;
  final Paint shieldBorderPaint = Paint()..color = Colors.cyanAccent..style = PaintingStyle.stroke..strokeWidth = 2;

  Vector2? targetPosition;
  double? targetAngle;

  EnemyTank({required this.playerName, required Vector2 position, required this.team}) : super(position: position, size: Vector2(28, 32), anchor: Anchor.center) {
    const textStyle = TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 3.0, color: Colors.black, offset: Offset(1.0, 1.0))]);
    nameTextPaint = TextPaint(style: textStyle);
    final tp = TextPainter(text: TextSpan(text: playerName, style: textStyle), textDirection: TextDirection.ltr);
    tp.layout();
    nameWidth = tp.width;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
    maxHealth = gameRef.networkService.selectedMap == 3 ? 1 : 5;
    health = maxHealth;
    
    // YENİ: Aynı takımda (Müttefik) iseler Yeşil, Rakip ise Kırmızı çizilir
    if ((gameRef.networkService.selectedMap == 4 || gameRef.networkService.selectedMap == 5) && team == gameRef.networkService.myTeam) {
      bodyPaint = Paint()..color = Colors.green.shade600;
    } else {
      bodyPaint = Paint()..color = const Color.fromARGB(255, 139, 34, 34); // Kırmızı
    }
  }

  void updateHealth(int newHealth) {
    health = newHealth;
    isDead = health <= 0;
  }
  
  void setShield(bool state) { isShielded = state; }

  void respawn(double newX, double newY, double newAngle) {
    health = maxHealth;
    isDead = false;
    isShielded = true; 
    position = Vector2(newX, newY);
    targetPosition = position.clone();
    angle = newAngle;
    targetAngle = newAngle;
  }

  void updatePosition(double newX, double newY, double newAngle) {
    targetPosition = Vector2(newX, newY);
    targetAngle = newAngle;

    if (isDead && health > 0) isDead = false;
    if (position.isZero()) {
      position = targetPosition!.clone();
      angle = targetAngle!;
    }
  }

  @override
  void update(double dt) {
    if (isDead) return;
    super.update(dt);

    if (targetPosition != null) position.lerp(targetPosition!, dt * 15);
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
}