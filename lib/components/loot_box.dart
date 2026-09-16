import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import 'tank.dart';

class LootBox extends PositionComponent with CollisionCallbacks {
  final String id;
  final int type; // 0: Can, 1: Mermi, 2: Kalkan, 3: Roket, 4: Lazer
  
  late final Paint _boxPaint;
  final Paint _iconPaint = Paint()..color = Colors.white..strokeWidth = 3;

  LootBox({required this.id, required this.type, required Vector2 position}) 
      : super(position: position, size: Vector2(24, 24), anchor: Anchor.center) {
    
    if (type == 0) _boxPaint = Paint()..color = Colors.green.shade600;
    else if (type == 1) _boxPaint = Paint()..color = Colors.orange.shade700;
    else if (type == 2) _boxPaint = Paint()..color = Colors.blue.shade500;
    else if (type == 3) _boxPaint = Paint()..color = Colors.purple.shade700; //  Roket
    else if (type == 4) _boxPaint = Paint()..color = Colors.cyan.shade600; //  Lazer
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)), _boxPaint);
    
    if (type == 0) {
      canvas.drawLine(Offset(size.x/2, 6), Offset(size.x/2, size.y - 6), _iconPaint);
      canvas.drawLine(Offset(6, size.y/2), Offset(size.x - 6, size.y/2), _iconPaint);
    } else if (type == 1) {
      canvas.drawCircle(Offset(size.x/2, size.y/2), 4, _iconPaint);
    } else if (type == 2) {
      canvas.drawCircle(Offset(size.x/2, size.y/2), 6, _iconPaint..style = PaintingStyle.stroke);
      _iconPaint.style = PaintingStyle.fill; 
    } else if (type == 3) {
      // Roket İkonu (Üçgen Başlık)
      Path path = Path();
      path.moveTo(size.x/2, 4);
      path.lineTo(size.x - 6, size.y - 6);
      path.lineTo(6, size.y - 6);
      path.close();
      canvas.drawPath(path, _iconPaint);
    } else if (type == 4) {
      // Lazer İkonu (Kalın Çizgi)
      _iconPaint.strokeWidth = 5;
      canvas.drawLine(Offset(size.x/2, 4), Offset(size.x/2, size.y - 4), _iconPaint);
      _iconPaint.strokeWidth = 3;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    
    if (other is Tank) {
      final game = other.gameRef;
      if (other == game.playerTank) {
        
        if (type == 0) {
          game.playerTank.health = game.playerTank.maxHealth;
          game.networkService.sendHealth(game.playerTank.health);
        } else if (type == 1) {
          game.playerTank.ammo += 10;
        } else if (type == 2) {
          game.playerTank.activateShield(); 
        } else if (type == 3 || type == 4) {
          game.playerTank.nextShotType = type; // Özel atışı yükle
        }
        
        game.networkService.sendCollectLoot(id);
        removeFromParent();
        game.loots.remove(id);
      }
    }
  }
}