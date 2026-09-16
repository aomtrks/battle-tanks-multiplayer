import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../game/tank_game.dart';
import 'tank.dart';
import 'wall.dart';

class Football extends PositionComponent with CollisionCallbacks, HasGameRef<TankGame> {
  String? ownerId;
  Vector2 velocity = Vector2.zero();
  final double speed = 500.0; // Top mermiden daha hızlı uçar
  
  final Paint _paint = Paint()..color = Colors.white;
  final Paint _outline = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2;

  Football({required Vector2 position}) : super(position: position, size: Vector2(16, 16), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
  }

  void catchBall(String newOwner) {
    ownerId = newOwner;
    velocity = Vector2.zero();
  }

  void shootBall(double angle) {
    ownerId = null;
    velocity = Vector2(sin(angle), -cos(angle)) * speed;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (ownerId != null) {
      PositionComponent? owner;
      if (gameRef.networkService.myId == ownerId) owner = gameRef.playerTank;
      else owner = gameRef.enemies[ownerId];

      if (owner != null) {
        // Tankın dönüş açısına göre topu namlunun tam ucunda tut
        final offset = Vector2(sin(owner.angle) * 35, -cos(owner.angle) * 35);
        position = owner.position + offset;
      } else {
        ownerId = null; 
      }
    } else {
      position += velocity * dt;
      velocity *= 0.98; // Çimde yavaşlama sürtünmesi
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (ownerId != null) return; // Top birindeyken çarpışma kapatılır

    if (other is Tank) {
      if (other == gameRef.playerTank && !other.isDead) {
        catchBall(gameRef.networkService.myId);
        gameRef.networkService.sendCatchBall();
      }
    } else if (other is Wall && !other.isGoal) {
      // Normal duvarlara çarpıp sekmesi
      position -= velocity.normalized() * 5.0;
      Rect ballRect = Rect.fromCenter(center: position.toOffset(), width: size.x, height: size.y);
      Rect wallRect = other.toRect();

      double leftDist = (ballRect.right - wallRect.left).abs();
      double rightDist = (ballRect.left - wallRect.right).abs();
      double topDist = (ballRect.bottom - wallRect.top).abs();
      double bottomDist = (ballRect.top - wallRect.bottom).abs();

      double minDist = [leftDist, rightDist, topDist, bottomDist].reduce(min);
      if (minDist == leftDist || minDist == rightDist) velocity.x = -velocity.x;
      else velocity.y = -velocity.y;
    } else if (other is Wall && other.isGoal) {
      // GOL!
      if (gameRef.networkService.isHost) {
        int scoringTeam = other.teamId == 0 ? 1 : 0; 
        gameRef.networkService.sendGoal(scoringTeam);
        gameRef.handleGoal(scoringTeam);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, _paint);
    canvas.drawCircle(Offset(size.x/2, size.y/2), size.x/2, _outline);
  }
}