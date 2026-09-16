import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import 'tank.dart';
import 'wall.dart';

class Bullet extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  final double speed = 400.0;
  late Vector2 velocity;
  final bool isEnemy;
  final String ownerId;
  final bool isArena; // YENİ: Arena modu tetikleyicisi

  late final Paint _bulletPaint;
  bool _hasHitTank = false; 
  
  int _bounceCount = 0;
  static const int _maxBounces = 3; 
  double _lifeTime = 0.0;

  Bullet({required Vector2 position, required double angle, required this.ownerId, this.isEnemy = false, this.isArena = false})
      // Arena modunda mermi boyutu 8'den 12'ye çıkarıldı ve daha belirgin yapıldı
      : super(position: position, size: isArena ? Vector2(12, 12) : Vector2(8, 8), anchor: Anchor.center) {
    this.angle = angle;
    velocity = Vector2(sin(angle), -cos(angle)) * speed; 

    if (isArena) {
      // YENİ: Arena haritasında tamamen siyah ve blursuz net mermi
      _bulletPaint = Paint()..color = Colors.black;
    } else {
      _bulletPaint = Paint()
        ..color = isEnemy ? Colors.orange : Colors.yellow
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    }
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

    double maxLife = (gameRef.networkService.selectedMap == 3) ? 10.0 : 3.5;
    
    if (_lifeTime >= maxLife) {
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
    
    if (other is Wall) {
      if (_bounceCount >= _maxBounces) {
        removeFromParent();
        return;
      }
      
      _bounceCount++;
      position -= velocity.normalized() * 5.0; 

      Rect bulletRect = Rect.fromCenter(center: position.toOffset(), width: size.x, height: size.y);
      Rect wallRect = other.toRect();
      
      double leftDist = (bulletRect.right - wallRect.left).abs();
      double rightDist = (bulletRect.left - wallRect.right).abs();
      double topDist = (bulletRect.bottom - wallRect.top).abs();
      double bottomDist = (bulletRect.top - wallRect.bottom).abs();
      
      double minDist = [leftDist, rightDist, topDist, bottomDist].reduce(min);
      
      if (minDist == leftDist || minDist == rightDist) {
        velocity.x = -velocity.x; 
      } else {
        velocity.y = -velocity.y; 
      }
      
      angle = atan2(velocity.y, velocity.x) + pi/2;
      return; 
    }

    if (other is Tank) {
      if (_hasHitTank) return;

      if (ownerId == other.networkService.myId) {
        if (gameRef.networkService.selectedMap == 3 && (_bounceCount > 0 || _lifeTime > 0.2)) {
          _hasHitTank = true;
          other.takeDamage(ownerId);
          removeFromParent();
        }
      } else {
        _hasHitTank = true;
        other.takeDamage(ownerId);
        removeFromParent();
      }
    }
  }
}