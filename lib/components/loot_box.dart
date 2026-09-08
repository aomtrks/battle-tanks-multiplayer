import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import 'tank.dart';

class LootBox extends PositionComponent with CollisionCallbacks {
  final String id;
  final int type; // 0: Can Kutu, 1: Mermi Kutu
  
  late final Paint _boxPaint;
  final Paint _iconPaint = Paint()..color = Colors.white..strokeWidth = 3;

  LootBox({required this.id, required this.type, required Vector2 position}) 
      : super(position: position, size: Vector2(24, 24), anchor: Anchor.center) {
    _boxPaint = Paint()..color = type == 0 ? Colors.green.shade600 : Colors.orange.shade700;
  }

  @override
  Future<void> onLoad() async {
    add(RectangleHitbox());
  }

  @override
  void render(Canvas canvas) {
    // Kutunun kendisi
    canvas.drawRRect(RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)), _boxPaint);
    
    // Üzerindeki simge
    if (type == 0) {
      // Artı işareti (Can)
      canvas.drawLine(Offset(size.x/2, 6), Offset(size.x/2, size.y - 6), _iconPaint);
      canvas.drawLine(Offset(6, size.y/2), Offset(size.x - 6, size.y/2), _iconPaint);
    } else {
      // Mermi Simgesi (Daireler)
      canvas.drawCircle(Offset(size.x/2, size.y/2), 4, _iconPaint);
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    
    // Eğer çarpan şey bir Tank ise ve bu BİZİM tankımızsa
    if (other is Tank) {
      final game = other.gameRef;
      if (other == game.playerTank) {
        if (type == 0) {
          game.playerTank.health = game.playerTank.maxHealth;
          game.networkService.sendHealth(game.playerTank.health);
        } else {
          game.playerTank.ammo += 10;
        }
        
        // Kutunun alındığını tüm ağa yay, herkesin ekranından silinsin
        game.networkService.sendCollectLoot(id);
        
        // Kendinden de anında sil
        removeFromParent();
        game.loots.remove(id);
      }
    }
  }
}