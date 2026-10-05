import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../domain/models/circle.dart';
import 'chat_repository.dart';
import 'circle_repository.dart';

/// In-memory circles for mock mode. Reuses the (mock) chat repository for the
/// persistent circle chat, mirroring the Firestore implementation.
class MockCircleRepository implements CircleRepository {
  MockCircleRepository(this._chats);

  final ChatRepository _chats;
  final _uuid = const Uuid();

  final Map<String, Circle> _circles = {};
  final List<CircleInvite> _invites = [];
  final _myCirclesCtrl = StreamController<List<Circle>>.broadcast();
  final _incomingCtrl = <String, StreamController<List<CircleInvite>>>{};

  void _emitCircles() => _myCirclesCtrl.add(_circles.values.toList());
  void _emitIncoming(String uid) => _incomingCtrl[uid]?.add(_pendingTo(uid));

  List<CircleInvite> _pendingTo(String uid) =>
      _invites.where((i) => i.toId == uid && i.status == 'pending').toList();

  @override
  Future<Circle> createCircle({
    required String name,
    String? emoji,
    required String creatorId,
  }) async {
    final id = _uuid.v4();
    final circle = Circle(
      id: id,
      name: name,
      emoji: (emoji == null || emoji.isEmpty) ? '👥' : emoji,
      creatorId: creatorId,
      memberIds: [creatorId],
      createdAt: DateTime.now(),
    );
    _circles[id] = circle;
    await _chats.ensureChat(id, title: name, memberIds: [creatorId]);
    _emitCircles();
    return circle;
  }

  @override
  Stream<List<Circle>> myCircles(String uid) {
    scheduleMicrotask(_emitCircles);
    return _myCirclesCtrl.stream.map(
      (all) => all.where((c) => c.memberIds.contains(uid)).toList(),
    );
  }

  @override
  Future<Circle?> fetchCircle(String id) async => _circles[id];

  @override
  Future<void> invite({
    required Circle circle,
    required String fromId,
    required String toId,
  }) async {
    if (toId.isEmpty || toId == fromId || circle.memberIds.contains(toId)) {
      return;
    }
    final dup = _invites.any(
      (i) => i.circleId == circle.id && i.toId == toId && i.status == 'pending',
    );
    if (dup) return;
    _invites.add(
      CircleInvite(
        id: _uuid.v4(),
        circleId: circle.id,
        circleName: circle.name,
        fromId: fromId,
        toId: toId,
        status: 'pending',
        createdAt: DateTime.now(),
      ),
    );
    _emitIncoming(toId);
  }

  @override
  Future<void> acceptInvite(CircleInvite invite) async {
    _invites.removeWhere((i) => i.id == invite.id);
    final c = _circles[invite.circleId];
    if (c != null && !c.memberIds.contains(invite.toId)) {
      _circles[invite.circleId] = Circle(
        id: c.id,
        name: c.name,
        emoji: c.emoji,
        creatorId: c.creatorId,
        memberIds: [...c.memberIds, invite.toId],
        createdAt: c.createdAt,
      );
      await _chats.addMember(invite.circleId, invite.toId);
    }
    _emitCircles();
    _emitIncoming(invite.toId);
  }

  @override
  Future<void> declineInvite(CircleInvite invite) async {
    _invites.removeWhere((i) => i.id == invite.id);
    _emitIncoming(invite.toId);
  }

  @override
  Future<void> cancelInvite(CircleInvite invite) async {
    _invites.removeWhere((i) => i.id == invite.id);
    _emitIncoming(invite.toId);
  }

  @override
  Stream<List<CircleInvite>> incomingInvites(String uid) {
    final ctrl = _incomingCtrl.putIfAbsent(
      uid,
      () => StreamController<List<CircleInvite>>.broadcast(),
    );
    scheduleMicrotask(() => ctrl.add(_pendingTo(uid)));
    return ctrl.stream;
  }

  @override
  Future<List<CircleInvite>> outgoingInvitesFor(String circleId) async =>
      _invites
          .where((i) => i.circleId == circleId && i.status == 'pending')
          .toList();

  @override
  Future<void> leaveCircle(String circleId, String uid) async {
    final c = _circles[circleId];
    if (c == null || !c.memberIds.contains(uid)) return;
    _circles[circleId] = Circle(
      id: c.id,
      name: c.name,
      emoji: c.emoji,
      creatorId: c.creatorId,
      memberIds: c.memberIds.where((id) => id != uid).toList(),
      createdAt: c.createdAt,
    );
    _emitCircles();
  }
}
