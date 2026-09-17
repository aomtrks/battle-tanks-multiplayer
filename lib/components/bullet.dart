import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import 'tank.dart';
import 'wall.dart';

class Bullet extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  late double speed;
  late Vector2 velocity;
  final bool isEnemy;
  final String ownerId;
  final bool isArena; 
  final int bulletType; 

  late final Paint _bulletPaint;
  bool _hasHitTank = false; 
  
  int _bounceCount = 0;
  static const int _maxBounces = 3; 
  double _lifeTime = 0.0;
  double _homingTimer = 0.0;

  Bullet({required Vector2 position, required double angle, required this.ownerId, this.isEnemy = false, this.isArena = false, this.bulletType = 0})
      : super(position: position, anchor: Anchor.center) {
    this.angle = angle;
    
    if (bulletType == 4) {
      size = Vector2(28, 28);
      _bulletPaint = Paint()..color = Colors.cyanAccent;
      speed = 800.0;
    } else if (bulletType == 3) {
      size = Vector2(16, 16);
      _bulletPaint = Paint()..color = Colors.purpleAccent;
      speed = 350.0;
    } else {
      size = isArena ? Vector2(12, 12) : Vector2(8, 8);
      _bulletPaint = isArena ? (Paint()..color = Colors.black) : (Paint()..color = isEnemy ? Colors.orange : Colors.yellow..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2));
      speed = 400.0;
    }
    
    velocity = Vector2(sin(angle), -cos(angle)) * speed; 
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

    if (bulletType != 3) {
      double maxLife = (gameRef.networkService.selectedMap == 3) ? 10.0 : 3.5;
      if (_lifeTime >= maxLife) {
        removeFromParent();
        return;
      }
    }

    if (bulletType == 3) {
      _homingTimer += dt;
      if (_homingTimer > 2.0) {
        PositionComponent? target;
        double minDist = double.infinity;
        
        if (!gameRef.playerTank.isDead) {
          double d = position.distanceTo(gameRef.playerTank.position);
          if (d < minDist) { minDist = d; target = gameRef.playerTank; }
        }
        for (var e in gameRef.enemies.values) {
          if (!e.isDead) {
            double d = position.distanceTo(e.position);
            if (d < minDist) { minDist = d; target = e; }
          }
        }
        
        if (target != null) {
          Vector2 desiredVelocity = (target.position - position).normalized() * speed;
          double turnRate = 2.0 + ((_homingTimer - 2.0) * 1.5); 
          velocity.lerp(desiredVelocity, dt * turnRate); 
          angle = atan2(velocity.y, velocity.x) + pi/2;
        }
      }
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
      if (bulletType == 4) return; 

      if (bulletType != 3 && _bounceCount >= _maxBounces) {
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
      
      if (minDist == leftDist || minDist == rightDist) velocity.x = -velocity.x; 
      else velocity.y = -velocity.y; 
      
      angle = atan2(velocity.y, velocity.x) + pi/2;
      return; 
    }

    if (other is Tank) {
      if (_hasHitTank) return;

      // YENİ: DOST ATEŞİ KORUMASI (Futbol ve Boya Savaşı için)
      if (gameRef.networkService.selectedMap == 4 || gameRef.networkService.selectedMap == 5) {
        int ownerTeam = -1;
        if (ownerId == gameRef.networkService.myId) {
          ownerTeam = gameRef.networkService.myTeam;
        } else {
          final enemyOwner = gameRef.enemies[ownerId];
          if (enemyOwner != null) {
            ownerTeam = enemyOwner.team;
          } else {
            for (var p in gameRef.networkService.lobbyPlayers) {
              if (p['id'] == ownerId) {
                ownerTeam = p['team'] ?? 0;
                break;
              }
            }
          }
        }
        
        // Eğer mermiyi atan takım ile vurulan (local) tankın takımı aynıysa mermi içinden geçer (hasar vermez)
        if (ownerTeam != -1 && ownerTeam == other.team) {
          return;
        }
      }

      if (ownerId == other.networkService.myId) {
        if (gameRef.networkService.selectedMap == 3 && (_bounceCount > 0 || _lifeTime > 0.2 || bulletType == 3)) {
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