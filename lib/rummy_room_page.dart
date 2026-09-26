import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RummyRoomPage extends StatefulWidget {
  final String roomId;

  const RummyRoomPage({
    super.key,
    required this.roomId,
  });

  @override
  State<RummyRoomPage> createState() => _RummyRoomPageState();
}

class _RummyRoomPageState extends State<RummyRoomPage> {
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roomSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _handSub;

  Map<String, dynamic> room = {};
  List<String> myHand = [];
  List<String> players = [];

  Timer? _timer;
  int secondsLeft = 30;
  bool loading = true;
  bool busy = false;

  String get uid => auth.currentUser?.uid ?? '';

  String get myName =>
      auth.currentUser?.displayName?.trim().isNotEmpty == true
          ? auth.currentUser!.displayName!.trim()
          : 'Player';

  DocumentReference<Map<String, dynamic>> get roomRef =>
      db.collection('rummy_rooms').doc(widget.roomId);

  @override
  void initState() {
    super.initState();
    _listenRoom();
    _listenMyHand();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roomSub?.cancel();
    _handSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // FIREBASE LISTENERS
  // ------------------------------------------------------------

  void _listenRoom() {
    _roomSub = roomRef.snapshots().listen((snapshot) {
      if (!snapshot.exists) {
        setState(() {
          loading = false;
        });
        return;
      }

      final data = snapshot.data() ?? {};

      final rawPlayers = data['players'];

      List<String> ids = [];

      if (rawPlayers is List) {
        ids = rawPlayers.map((e) => e.toString()).toList();
      }

      setState(() {
        room = data;
        players = ids;
        loading = false;
      });

      _updateTimer();
    });
  }

  void _listenMyHand() {
    if (uid.isEmpty) return;

    _handSub = db
        .collection('rummy_rooms')
        .doc(widget.roomId)
        .collection('hands')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        setState(() {
          myHand = [];
        });
        return;
      }

      final data = snapshot.data() ?? {};
      final cards = data['cards'];

      if (cards is List) {
        setState(() {
          myHand = cards.map((e) => e.toString()).toList();
        });
      }
    });
  }

  // ------------------------------------------------------------
  // TIMER
  // ------------------------------------------------------------

  void _updateTimer() {
    _timer?.cancel();

    final deadline = room['turnDeadline'];

    if (deadline == null) {
      setState(() {
        secondsLeft = 30;
      });
      return;
    }

    DateTime end;

    if (deadline is Timestamp) {
      end = deadline.toDate();
    } else {
      return;
    }

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        final remaining = end.difference(DateTime.now()).inSeconds;

        if (remaining <= 0) {
          timer.cancel();

          setState(() {
            secondsLeft = 0;
          });

          _handleTimeout();
        } else {
          setState(() {
            secondsLeft = remaining;
          });
        }
      },
    );
  }

  bool get myTurn {
    return room['turnPlayer'] == uid;
  }

  // ------------------------------------------------------------
  // CREATE / JOIN ROOM
  // ------------------------------------------------------------

  Future<void> joinRoom() async {
    if (uid.isEmpty) {
      _message('Firebase login required');
      return;
    }

    final ref = roomRef;

    await db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);

      if (!snap.exists) {
        transaction.set(ref, {
          'roomId': widget.roomId,
          'game': 'rummy',
          'status': 'waiting',
          'players': [uid],
          'playerNames': {
            uid: myName,
          },
          'hostId': uid,
          'dealerId': uid,
          'turnPlayer': null,
          'turnDeadline': null,
          'stock': [],
          'discardPile': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final data = snap.data() ?? {};

      final currentPlayers =
          List<String>.from(data['players'] ?? <String>[]);

      if (!currentPlayers.contains(uid)) {
        if (currentPlayers.length >= 4) {
          throw Exception('Room is full');
        }

        currentPlayers.add(uid);

        final names =
            Map<String, dynamic>.from(data['playerNames'] ?? {});

        names[uid] = myName;

        transaction.update(ref, {
          'players': currentPlayers,
          'playerNames': names,
        });
      }
    });

    _message('Joined room');
  }

  // ------------------------------------------------------------
  // START GAME / DEAL CARDS
  // ------------------------------------------------------------

  Future<void> startGame() async {
    if (busy) return;

    if (room['hostId'] != uid) {
      _message('Only the host can start the game');
      return;
    }

    if (players.length < 2) {
      _message('At least 2 players are required');
      return;
    }

    if (players.length > 4) {
      _message('Maximum 4 players');
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final deck = _createDeck();
      deck.shuffle(Random());

      final Map<String, List<String>> hands = {};

      for (final playerId in players) {
        hands[playerId] = [];
      }

      // 13 cards to every player.
      for (int round = 0; round < 13; round++) {
        for (final playerId in players) {
          hands[playerId]!.add(deck.removeLast());
        }
      }

      final discard = <String>[];

      if (deck.isNotEmpty) {
        discard.add(deck.removeLast());
      }

      // Dealer is first player.
      final dealerId = room['dealerId'] ?? players.first;

      final dealerIndex = players.indexOf(dealerId);

      final firstTurnIndex =
          dealerIndex >= 0
              ? (dealerIndex + 1) % players.length
              : 0;

      final firstPlayer = players[firstTurnIndex];

      final batch = db.batch();

      batch.update(roomRef, {
        'status': 'playing',
        'dealerId': dealerId,
        'turnPlayer': firstPlayer,
        'turnDeadline': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
        'stock': deck,
        'discardPile': discard,
        'turnIndex': firstTurnIndex,
        'startedAt': FieldValue.serverTimestamp(),
      });

      for (final entry in hands.entries) {
        final handRef = roomRef
            .collection('hands')
            .doc(entry.key);

        batch.set(handRef, {
          'cards': entry.value,
          'count': entry.value.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      _message('Cards dealt');
    } catch (e) {
      _message(e.toString());
    } finally {
      setState(() {
        busy = false;
      });
    }
  }

  // ------------------------------------------------------------
  // DRAW CARD
  // ------------------------------------------------------------

  Future<void> drawCard() async {
    if (!myTurn || busy) return;

    if (myHand.length >= 14) {
      _message('You already have 14 cards. Discard first.');
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final stock = List<String>.from(room['stock'] ?? []);

      if (stock.isEmpty) {
        _message('No cards left in deck');
        return;
      }

      final card = stock.removeLast();

      final newHand = [...myHand, card];

      await db.runTransaction((transaction) async {
        final currentRoom = await transaction.get(roomRef);

        if (!currentRoom.exists) {
          throw Exception('Room not found');
        }

        final currentData = currentRoom.data() ?? {};

        if (currentData['turnPlayer'] != uid) {
          throw Exception('Not your turn');
        }

        transaction.update(roomRef, {
          'stock': stock,
        });

        transaction.set(
          roomRef.collection('hands').doc(uid),
          {
            'cards': newHand,
            'count': newHand.length,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _message('Card picked');
    } catch (e) {
      _message(e.toString());
    } finally {
      setState(() {
        busy = false;
      });
    }
  }

  // ------------------------------------------------------------
  // DISCARD CARD
  // ------------------------------------------------------------

  Future<void> discardCard(String card) async {
    if (!myTurn || busy) return;

    if (!myHand.contains(card)) return;

    if (myHand.length != 14) {
      _message('Draw one card before discarding');
      return;
    }

    setState(() {
      busy = true;
    });

    try {
      final newHand = [...myHand];

      newHand.remove(card);

      final discardPile =
          List<String>.from(room['discardPile'] ?? []);

      discardPile.add(card);

      final nextPlayer = _nextPlayer();

      await db.runTransaction((transaction) async {
        final currentRoom = await transaction.get(roomRef);

        if (!currentRoom.exists) {
          throw Exception('Room not found');
        }

        final data = currentRoom.data() ?? {};

        if (data['turnPlayer'] != uid) {
          throw Exception('Not your turn');
        }

        final currentIndex =
            data['turnIndex'] ?? players.indexOf(uid);

        final nextIndex =
            ((currentIndex as int) + 1) % players.length;

        transaction.update(roomRef, {
          'discardPile': discardPile,
          'turnPlayer': nextPlayer,
          'turnIndex': nextIndex,
          'turnDeadline': Timestamp.fromDate(
            DateTime.now().add(const Duration(seconds: 30)),
          ),
        });

        transaction.set(
          roomRef.collection('hands').doc(uid),
          {
            'cards': newHand,
            'count': newHand.length,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      _message('Card discarded');
    } catch (e) {
      _message(e.toString());
    } finally {
      setState(() {
        busy = false;
      });
    }
  }

  // ------------------------------------------------------------
  // NEXT PLAYER
  // ------------------------------------------------------------

  String _nextPlayer() {
    if (players.isEmpty) return uid;

    final currentIndex = players.indexOf(uid);

    if (currentIndex == -1) {
      return players.first;
    }

    return players[
        (currentIndex + 1) % players.length
    ];
  }

  // ------------------------------------------------------------
  // TIMEOUT
  // ------------------------------------------------------------

  Future<void> _handleTimeout() async {
    if (!myTurn) return;

    // If player has 14 cards, automatically discard one.
    if (myHand.length == 14) {
      await discardCard(myHand.last);
      return;
    }

    // Otherwise simply move turn.
    if (players.isEmpty) return;

    final nextPlayer = _nextPlayer();

    final nextIndex =
        (players.indexOf(nextPlayer));

    await roomRef.update({
      'turnPlayer': nextPlayer,
      'turnIndex': nextIndex,
      'turnDeadline': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 30)),
      ),
    });
  }

  // ------------------------------------------------------------
  // DECLARE
  // ------------------------------------------------------------

  Future<void> declareGame() async {
    if (!myTurn) {
      _message('It is not your turn');
      return;
    }

    // IMPORTANT:
    // A player cannot declare with more than 13 cards.
    if (myHand.length != 13) {
      _message(
        'Declare is allowed only with exactly 13 cards',
      );
      return;
    }

    if (!_isValidRummyHand(myHand)) {
      _message('Invalid Rummy hand');
      return;
    }

    await roomRef.update({
      'status': 'finished',
      'winnerId': uid,
      'winnerName': myName,
      'finishedAt': FieldValue.serverTimestamp(),
    });

    _message('Congratulations! You won.');
  }

  // ------------------------------------------------------------
  // SIMPLE RUMMY VALIDATION
  // ------------------------------------------------------------

  bool _isValidRummyHand(List<String> cards) {
    if (cards.length != 13) return false;

    final parsed = cards.map(_parseCard).toList();

    // Group by suit.
    final Map<String, List<int>> suitGroups = {};

    for (final card in parsed) {
      suitGroups.putIfAbsent(card.suit, () => []);
      suitGroups[card.suit]!.add(card.rank);
    }

    for (final ranks in suitGroups.values) {
      ranks.sort();
    }

    // Check for at least one sequence.
    bool hasSequence = false;

    for (final ranks in suitGroups.values) {
      if (ranks.length >= 3) {
        for (int i = 0; i <= ranks.length - 3; i++) {
          if (ranks[i + 1] == ranks[i] + 1 &&
              ranks[i + 2] == ranks[i] + 2) {
            hasSequence = true;
          }
        }
      }
    }

    // Basic set check.
    final Map<int, int> rankCount = {};

    for (final card in parsed) {
      rankCount[card.rank] =
          (rankCount[card.rank] ?? 0) + 1;
    }

    bool hasSet = rankCount.values.any(
      (count) => count >= 3,
    );

    return hasSequence && hasSet;
  }

  // ------------------------------------------------------------
  // DECK
  // ------------------------------------------------------------

  List<String> _createDeck() {
    const suits = [
      'S',
      'H',
      'D',
      'C',
    ];

    final List<String> deck = [];

    for (final suit in suits) {
      for (int rank = 1; rank <= 13; rank++) {
        deck.add('$rank$suit');
      }
    }

    return deck;
  }

  _Card _parseCard(String value) {
    final suit = value.substring(value.length - 1);

    final rank = int.parse(
      value.substring(0, value.length - 1),
    );

    return _Card(
      rank: rank,
      suit: suit,
    );
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),
      appBar: AppBar(
        backgroundColor: const Color(0xffa90012),
        foregroundColor: Colors.white,
        title: const Text('Rummy'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _topInfo(),
            _playersView(),
            Expanded(
              child: _gameArea(),
            ),
            _myCards(),
            _controls(),
          ],
        ),
      ),
    );
  }

  Widget _topInfo() {
    final status = room['status'] ?? 'waiting';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0xffa90012),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room ${widget.roomId}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            status == 'playing'
                ? 'Rummy • Playing'
                : status == 'finished'
                    ? 'Rummy • Finished'
                    : 'Rummy • Waiting',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          if (status == 'playing')
            Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '$secondsLeft seconds',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  myTurn
                      ? 'YOUR TURN'
                      : 'WAITING',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _playersView() {
    final names =
        Map<String, dynamic>.from(
      room['playerNames'] ?? {},
    );

    return SizedBox(
      height: 95,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: players.length,
        itemBuilder: (context, index) {
          final id = players[index];

          final name =
              names[id]?.toString() ?? 'Player';

          final active =
              room['turnPlayer'] == id;

          return Container(
            width: 150,
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xffffe0e0)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? Colors.green
                    : Colors.grey.shade300,
                width: active ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  id == room['dealerId']
                      ? 'Dealer'
                      : id == uid
                          ? 'You'
                          : 'Player',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _gameArea() {
    final discard =
        List<String>.from(
      room['discardPile'] ?? [],
    );

    final stock =
        List<String>.from(
      room['stock'] ?? [],
    );

    if (room['status'] != 'playing') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.style,
                size: 70,
                color: Color(0xffa90012),
              ),
              const SizedBox(height: 15),
              const Text(
                'Rummy Room',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${player
