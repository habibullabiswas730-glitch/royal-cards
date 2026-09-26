import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  FirebaseService();

  static final FirebaseService instance = FirebaseService();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  User? get currentUser => auth.currentUser;
  String get uid => auth.currentUser?.uid ?? '';

  Future<User> ensureSignedIn() async {
    final current = auth.currentUser;

    if (current != null) {
      return current;
    }

    final result = await auth.signInAnonymously();

    final user = result.user;
    if (user == null) {
      throw Exception('Firebase login failed');
    }

    return user;
  }

  Future<void> saveUser({
    required String name,
    String email = '',
    String phone = '',
  }) async {
    if (uid.isEmpty) {
      throw Exception('User is not signed in');
    }

    final ref = db.collection('users').doc(uid);
    final snap = await ref.get();

    await ref.set(
      {
        'uid': uid,
        'playerName': name.trim().isEmpty ? 'Player' : name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'online': true,
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> setOnline(bool online) async {
    if (uid.isEmpty) return;

    await db.collection('users').doc(uid).set(
      {
        'online': online,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ---------------- INVITES ----------------

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingInvites() {
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return db
        .collection('invites')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> invite({
    required String toUid,
    required String roomId,
    required String game,
  }) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    if (toUid.trim().isEmpty) {
      throw Exception('Friend UID is empty');
    }

    if (roomId.trim().isEmpty) {
      throw Exception('Room ID is empty');
    }

    if (toUid == uid) {
      throw Exception('You cannot invite yourself');
    }

    final roomRef = db.collection('rooms').doc(roomId.trim());
    final roomSnap = await roomRef.get();

    if (!roomSnap.exists) {
      throw Exception('Room not found');
    }

    final room = roomSnap.data() ?? {};
    final members = List<String>.from(room['memberUids'] ?? const []);

    if (!members.contains(uid)) {
      throw Exception('You are not a member of this room');
    }

    final seats = (room['seats'] ?? 6) as int;

    if (members.length >= seats) {
      throw Exception('Room is full');
    }

    final friendRef = db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .doc(toUid);

    final friendSnap = await friendRef.get();

    if (!friendSnap.exists) {
      throw Exception('This user is not your friend');
    }

    final meSnap = await db.collection('users').doc(uid).get();
    final me = meSnap.data() ?? {};

    final inviteRef = db.collection('invites').doc();

    await inviteRef.set({
      'inviteId': inviteRef.id,
      'fromUid': uid,
      'fromName': me['playerName'] ?? 'Player',
      'toUid': toUid,
      'roomId': roomId.trim(),
      'game': game,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateInvite(String inviteId, String status) async {
    if (inviteId.trim().isEmpty) return;

    await db.collection('invites').doc(inviteId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------- FRIENDS ----------------

  Stream<QuerySnapshot<Map<String, dynamic>>> friends() {
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots();
  }

  Future<String?> findUser(String query) async {
    final q = query.trim();

    if (q.isEmpty) return null;

    for (final field in ['uid', 'playerName', 'email', 'phone']) {
      final snap = await db
          .collection('users')
          .where(field, isEqualTo: q)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.first.id;
      }
    }

    return null;
  }

  Future<String?> addFriendByQuery(String query) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    final friendUid = await findUser(query);

    if (friendUid == null) {
      return null;
    }

    if (friendUid == uid) {
      return null;
    }

    final meSnap = await db.collection('users').doc(uid).get();
    final otherSnap =
        await db.collection('users').doc(friendUid).get();

    if (!otherSnap.exists) {
      return null;
    }

    final me = meSnap.data() ?? {};
    final other = otherSnap.data() ?? {};

    final requestRef = db.collection('friendRequests').doc();

    await requestRef.set({
      'requestId': requestRef.id,
      'fromUid': uid,
      'fromName': me['playerName'] ?? 'Player',
      'toUid': friendUid,
      'toName': other['playerName'] ?? 'Player',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return friendUid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> incomingFriendRequests() {
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return db
        .collection('friendRequests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptFriend(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    final fromUid = (data['fromUid'] ?? '').toString();

    if (fromUid.isEmpty || fromUid == uid) {
      throw Exception('Invalid friend request');
    }

    final fromName = (data['fromName'] ?? 'Player').toString();

    final mySnap = await db.collection('users').doc(uid).get();
    final myData = mySnap.data() ?? {};
    final myName = (myData['playerName'] ?? 'Player').toString();

    final batch = db.batch();

    batch.set(
      db.collection('users').doc(uid).collection('friends').doc(fromUid),
      {
        'uid': fromUid,
        'name': fromName,
        'online': true,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      db.collection('users').doc(fromUid).collection('friends').doc(uid),
      {
        'uid': uid,
        'name': myName,
        'online': true,
        'addedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(
      db.collection('friendRequests').doc(requestId),
      {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }

  // ---------------- ROOMS ----------------

  Stream<QuerySnapshot<Map<String, dynamic>>> myRooms() {
    if (uid.isEmpty) {
      return const Stream.empty();
    }

    return db
        .collection('rooms')
        .where('memberUids', arrayContains: uid)
        .snapshots();
  }

  Future<String> createRoom({
    required String game,
    int seats = 6,
  }) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    final roomRef = db.collection('rooms').doc();

    final userSnap = await db.collection('users').doc(uid).get();
    final userData = userSnap.data() ?? {};
    final name = (userData['playerName'] ?? 'Player').toString();

    final batch = db.batch();

    batch.set(
      roomRef,
      {
        'roomId': roomRef.id,
        'game': game,
        'ownerId': uid,
        'status': 'waiting',
        'seats': seats,
        'memberUids': [uid],
        'turnIndex': 0,
        'turn': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

    batch.set(
      roomRef.collection('players').doc(uid),
      {
        'uid': uid,
        'name': name,
        'joinedAt': FieldValue.serverTimestamp(),
        'ready': false,
      },
    );

    await batch.commit();

    return roomRef.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> room(String roomId) {
    return db.collection('rooms').doc(roomId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> roomPlayers(String roomId) {
    return db
        .collection('rooms')
        .doc(roomId)
        .collection('players')
        .snapshots();
  }

  Future<String?> joinRoom(String roomId) async {
    if (uid.isEmpty) {
      return 'Please login first';
    }

    final id = roomId.trim();

    if (id.isEmpty) {
      return 'Room ID is empty';
    }

    final roomRef = db.collection('rooms').doc(id);

    final result = await db.runTransaction<String?>((tx) async {
      final snap = await tx.get(roomRef);

      if (!snap.exists) {
        return 'Room not found';
      }

      final data = snap.data() ?? {};

      final members =
          List<String>.from(data['memberUids'] ?? const []);

      final seats = (data['seats'] ?? 6) as int;

      final status = (data['status'] ?? 'waiting').toString();

      if (status == 'closed') {
        return 'Room is closed';
      }

      if (members.contains(uid)) {
        return null;
      }

      if (members.length >= seats) {
        return 'Room is full';
      }

      members.add(uid);

      tx.update(
        roomRef,
        {
          'memberUids': members,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      return null;
    });

    if (result != null) {
      return result;
    }

    final userSnap = await db.collection('users').doc(uid).get();
    final userData = userSnap.data() ?? {};
    final name = (userData['playerName'] ?? 'Player').toString();

    await roomRef.collection('players').doc(uid).set(
      {
        'uid': uid,
        'name': name,
        'joinedAt': FieldValue.serverTimestamp(),
        'ready': false,
      },
      SetOptions(merge: true),
    );

    return null;
  }

  // ---------------- GAME ----------------

  Future<void> startGame({
    required String roomId,
    required Map<String, dynamic> gameState,
  }) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    final ref = db.collection('rooms').doc(roomId);

    final snap = await ref.get();

    if (!snap.exists) {
      throw Exception('Room not found');
    }

    final room = snap.data() ?? {};

    if (room['ownerId'] != uid) {
      throw Exception('Only the host can start the game');
    }

    await ref.update({
      'status': 'playing',
      'gameState': gameState,
      'turnIndex': 0,
      'turn': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateGameState(
    String roomId,
    Map<String, dynamic> gameState, {
    int? turnIndex,
    int? turn,
  }) async {
    if (uid.isEmpty) {
      throw Exception('Please login first');
    }

    final data = <String, dynamic>{
      'gameState': gameState,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (turnIndex != null) {
      data['turnIndex'] = turnIndex;
    }

    if (turn != null) {
      data['turn'] = turn;
    }

    await db.collection('rooms').doc(roomId).update(data);
  }
}
