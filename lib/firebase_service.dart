import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  User get user => auth.currentUser!;
  String get uid => user.uid;

  Future<User> ensureSignedIn() async {
    final current = auth.currentUser;
    if (current != null) return current;
    final result = await auth.signInAnonymously();
    return result.user!;
  }

  Future<void> saveUser({required String name, String email = '', String phone = ''}) async {
    final ref = db.collection('users').doc(uid);
    final snap = await ref.get();
    await ref.set({
      'uid': uid,
      'playerName': name,
      'email': email,
      'phone': phone,
      'online': true,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setOnline(bool online) async {
    await db.collection('users').doc(uid).set({
      'online': online,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingInvites() => db.collection('invites')
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> myRooms() => db.collection('rooms')
      .where('memberUids', arrayContains: uid)
      .snapshots();

  Future<String?> findUser(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    for (final field in ['uid', 'playerName', 'email', 'phone']) {
      final snap = await db.collection('users').where(field, isEqualTo: q).limit(1).get();
      if (snap.docs.isNotEmpty) return snap.docs.first.id;
    }
    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> friends() => db.collection('users').doc(uid).collection('friends').snapshots();

  Future<String?> addFriendByQuery(String query) async {
    final friendUid = await findUser(query);
    if (friendUid == null || friendUid == uid) return null;
    final me = await db.collection('users').doc(uid).get();
    final other = await db.collection('users').doc(friendUid).get();
    if (!other.exists) return null;
    await db.collection('friendRequests').add({
      'fromUid': uid,
      'fromName': me.data()?['playerName'] ?? 'Player',
      'toUid': friendUid,
      'toName': other.data()?['playerName'] ?? 'Player',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return friendUid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingFriendRequests() => db.collection('friendRequests')
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Future<void> acceptFriend(String requestId, Map<String, dynamic> data) async {
    final fromUid = data['fromUid'] as String;
    final fromName = (data['fromName'] ?? 'Player') as String;
    final myDoc = await db.collection('users').doc(uid).get();
    final myName = (myDoc.data()?['playerName'] ?? 'Player') as String;
    final batch = db.batch();
    batch.set(db.collection('users').doc(uid).collection('friends').doc(fromUid), {
      'uid': fromUid, 'name': fromName, 'online': true, 'addedAt': FieldValue.serverTimestamp()
    });
    batch.set(db.collection('users').doc(fromUid).collection('friends').doc(uid), {
      'uid': uid, 'name': myName, 'online': true, 'addedAt': FieldValue.serverTimestamp()
    });
    batch.update(db.collection('friendRequests').doc(requestId), {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<String> createRoom({required String game, int seats = 6}) async {
    final ref = db.collection('rooms').doc();
    final data = {
      'roomId': ref.id,
      'game': game,
      'ownerId': uid,
      'status': 'waiting',
      'seats': seats,
      'memberUids': [uid],
      'turnIndex': 0,
      'turn': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final batch = db.batch();
    batch.set(ref, data);
    batch.set(ref.collection('players').doc(uid), {
      'uid': uid,
      'name': (await db.collection('users').doc(uid).get()).data()?['playerName'] ?? 'Player',
      'joinedAt': FieldValue.serverTimestamp(),
      'ready': false,
    });
    await batch.commit();
    return ref.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> room(String roomId) => db.collection('rooms').doc(roomId).snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> roomPlayers(String roomId) => db.collection('rooms').doc(roomId).collection('players').snapshots();

  Future<String?> joinRoom(String roomId) async {
    final ref = db.collection('rooms').doc(roomId.trim());
    final snap = await ref.get();
    if (!snap.exists) return 'Room not found';
    final data = snap.data()!;
    final members = List<String>.from(data['memberUids'] ?? const []);
    final seats = (data['seats'] ?? 6) as int;
    if (!members.contains(uid) && members.length >= seats) return 'Room is full';
    final name = (await db.collection('users').doc(uid).get()).data()?['playerName'] ?? 'Player';
    final batch = db.batch();
    if (!members.contains(uid)) members.add(uid);
    batch.update(ref, {'memberUids': members, 'updatedAt': FieldValue.serverTimestamp()});
    batch.set(ref.collection('players').doc(uid), {
      'uid': uid, 'name': name, 'joinedAt': FieldValue.serverTimestamp(), 'ready': false,
    });
    await batch.commit();
    return null;
  }

  Future<void> invite({required String toUid, required String roomId, required String game}) async {
    final me = await db.collection('users').doc(uid).get();
    await db.collection('invites').add({
      'fromUid': uid,
      'fromName': me.data()?['playerName'] ?? 'Player',
      'toUid': toUid,
      'roomId': roomId,
      'game': game,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateInvite(String inviteId, String status) async {
    await db.collection('invites').doc(inviteId).update({'status': status, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> startGame({required String roomId, required Map<String, dynamic> gameState}) async {
    await db.collection('rooms').doc(roomId).update({
      'status': 'playing',
      'gameState': gameState,
      'turnIndex': 0,
      'turn': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGameState(String roomId, Map<String, dynamic> gameState, {int? turnIndex, int? turn}) async {
    final data = <String, dynamic>{'gameState': gameState, 'updatedAt': FieldValue.serverTimestamp()};
    if (turnIndex != null) data['turnIndex'] = turnIndex;
    if (turn != null) data['turn'] = turn;
    await db.collection('rooms').doc(roomId).update(data);
  }
}

