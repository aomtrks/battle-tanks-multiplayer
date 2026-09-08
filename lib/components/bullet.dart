import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'tank.dart';
import 'wall.dart';

class Bullet extends PositionComponent with CollisionCallbacks {
  final double speed = 400.0;
  late Vector2 velocity;
  final bool isEnemy;
  final String ownerId;

  late final Paint _bulletPaint;
  bool _hasHit = false;
  double _lifeTime = 0.0;
  static const double _maxLifeTime = 3.5; // Boşa giden mermileri haritadan siler

  Bullet({required Vector2 position, required double angle, required this.ownerId, this.isEnemy = false})
      : super(position: position, size: Vector2(8, 8), anchor: Anchor.center) {
    this.angle = angle;
    velocity = Vector2(cos(angle - pi / 2), sin(angle - pi / 2)) * speed;

    _bulletPaint = Paint()
      ..color = isEnemy ? Colors.orange : Colors.yellow
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
  }

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    _lifeTime += dt;
    if (_lifeTime >= _maxLifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, _bulletPaint);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (_hasHit) return;

    if (other is Wall) {
      _hasHit = true;
      removeFromParent();
    }

    if (other is Tank && ownerId != other.networkService.myId) {
      _hasHit = true;
      other.takeDamage(ownerId);
      removeFromParent();
    }
  }
}