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
  bool _hasHitTank = false; // Tanklara tek vuruş kontrolü
  
  // YENİ: Sekme (Bounce) Mantığı
  int _bounceCount = 0;
  static const int _maxBounces = 3; // Duvarlardan 3 kere seker, 4.de yok olur

  Bullet({required Vector2 position, required double angle, required this.ownerId, this.isEnemy = false})
      : super(position: position, size: Vector2(8, 8), anchor: Anchor.center) {
    this.angle = angle;
    velocity = Vector2(sin(angle), -cos(angle)) * speed; 

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
      
      // Mermiyi duvarın içinden bir miktar geri çıkart (Yapışmayı/Glitch'i önler)
      position -= velocity.normalized() * 5.0; 

      // Çarpışma yönünü tespit edip vektörü ters çevirme (AABB Kutu Çarpışması)
      Rect bulletRect = Rect.fromCenter(center: position.toOffset(), width: size.x, height: size.y);
      Rect wallRect = other.toRect();
      
      double leftDist = (bulletRect.right - wallRect.left).abs();
      double rightDist = (bulletRect.left - wallRect.right).abs();
      double topDist = (bulletRect.bottom - wallRect.top).abs();
      double bottomDist = (bulletRect.top - wallRect.bottom).abs();
      
      double minDist = [leftDist, rightDist, topDist, bottomDist].reduce(min);
      
      // X veya Y ekseninde sekme (Ricochet)
      if (minDist == leftDist || minDist == rightDist) {
        velocity.x = -velocity.x; 
      } else {
        velocity.y = -velocity.y; 
      }
      
      // Merminin görsel dönüş açısını yeni hıza göre ayarla
      angle = atan2(velocity.y, velocity.x) + pi/2;
      return; 
    }

    // Tank Vurulması
    if (other is Tank && ownerId != other.networkService.myId) {
      if (_hasHitTank) return;
      _hasHitTank = true;
      other.takeDamage(ownerId);
      removeFromParent();
    }
  }
}