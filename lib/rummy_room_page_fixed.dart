import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _red = Color(0xFF9D1018);
const Color _redDark = Color(0xFF62060A);
const Color _redSoft = Color(0xFFFFF0F1);
const Color _green = Color(0xFF159447);
const Color _ink = Color(0xFF202124);

String _gameTitle(String game) {
  switch (game) {
    case 'teenPatti':
      return 'Teen Patti';
    case 'poker':
      return 'Poker';
    case 'andarBahar':
      return 'Andar Bahar';
    default:
      return 'Rummy';
  }
}

List<String> _freshDeck() {
  const suits = ['♠', '♥', '♦', '♣'];
  const ranks = [
    'A',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    'J',
    'Q',
    'K'
  ];

  return [
    for (final suit in suits)
      for (final rank in ranks) '$rank$suit'
  ];
}

Map<String, dynamic> _dealCards(
  String game,
  List<String> players,
) {
  final deck = _freshDeck()..shuffle(Random());

  final hands = <String, List<String>>{
    for (final uid in players) uid: [],
  };

  final count = game == 'rummy'
      ? 13
      : game == 'teenPatti'
          ? 3
          : game == 'poker'
              ? 2
              : 1;

  for (var i = 0; i < count; i++) {
    for (final uid in players) {
      if (deck.isNotEmpty) {
        hands[uid]!.add(deck.removeLast());
      }
    }
  }

  final state = <String, dynamic>{
    'deck': deck,
    'hands': hands,
    'community': <String>[],
    'started': true,
  };

  if (game == 'poker') {
    final take = min(5, deck.length);

    state['community'] = deck.take(take).toList();

    if (take > 0) {
      deck.removeRange(0, take);
    }
  }

  if (game == 'andarBahar') {
    state['joker'] =
        deck.isNotEmpty ? deck.removeLast() : '';

    state['side'] = 'Andar';
  }

  return state;
}

/// Online room screen used by the Royal Cards app.
class RoomPage extends StatelessWidget {
  final dynamic state;
  final String roomId;

  const RoomPage({
    super.key,
    required this.state,
    required this.roomId,
  });

  Future<void> _invite(
    BuildContext context,
    Map<String, dynamic> room,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite a friend'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: state.fb.friends(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  'Unable to load friends: ${snap.error}',
                );
              }

              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Text(
                  'Add a friend first.',
                );
              }

              return ListView(
                shrinkWrap: true,
                children: docs.map((doc) {
                  final friend = doc.data();

                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(
                      (
                        friend['name'] ??
                        friend['playerName'] ??
                        'Player'
                      ).toString(),
                    ),
                    subtitle: Text(
                      friend['online'] == true
                          ? 'Online'
                          : 'Offline',
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          await state.fb.invite(
                            toUid: doc.id,
                            roomId: roomId,
                            game: (
                              room['game'] ??
                              'rummy'
                            ).toString(),
                          );

                          if (context.mounted) {
                            Navigator.pop(context);

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Invite sent',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                  e.toString(),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('INVITE'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: state.fb.room(roomId),
      builder: (context, roomSnap) {
        if (roomSnap.connectionState ==
                ConnectionState.waiting &&
            !roomSnap.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (roomSnap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Room error: ${roomSnap.error}',
              ),
            ),
          );
        }

        final room = roomSnap.data?.data();

        if (room == null) {
          return const Scaffold(
            body: Center(
              child: Text('Room closed'),
            ),
          );
        }

        final game =
            (room['game'] ?? 'rummy').toString();

        final title = _gameTitle(game);

        return Scaffold(
          appBar: AppBar(
            title: Text('$title Room'),
          ),
          body: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: state.fb.roomPlayers(roomId),
            builder: (context, playerSnap) {
              if (playerSnap.hasError) {
                return Center(
                  child: Text(
                    'Players error: ${playerSnap.error}',
                  ),
                );
              }

              final players =
                  playerSnap.data?.docs ?? [];

              final isHost =
                  room['ownerId'] == state.uid;

              final seats =
                  (room['seats'] ?? 4).toString();

              final status =
                  (room['status'] ?? 'waiting')
                      .toString();

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          _redDark,
                          _red,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          roomId,
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${players.length}/$seats players • $status',
                          style: const TextStyle(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Players',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  ...players.map((doc) {
                    final player = doc.data();

                    final name = (
                      player['name'] ??
                      player['playerName'] ??
                      'Player'
                    ).toString();

                    final host =
                        doc.id == room['ownerId'];

                    return Card(
                      child: ListTile(
                        leading:
                            const CircleAvatar(
                          child: Icon(
                            Icons.person,
                          ),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          host
                              ? 'Host'
                              : 'Player',
                        ),
                        trailing:
                            const Icon(
                          Icons.check_circle,
                          color: _green,
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 14),

                  if (isHost)
                    FilledButton.icon(
                      onPressed:
                          players.isEmpty ||
                                  status ==
                                      'playing'
                              ? null
                              : () async {
                                  try {
                                    final uids =
                                        players
                                            .map(
                                              (doc) =>
                                                  doc.id,
                                            )
                                            .toList();

                                    final gameState =
                                        _dealCards(
                                      game,
                                      uids,
                                    );

                                    await state.fb
                                        .startGame(
                                      roomId:
                                          roomId,
                                      gameState:
                                          gameState,
                                    );
                                  } catch (e) {
                                    if (context
                                        .mounted) {
                                      ScaffoldMessenger
                                          .of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text(
                                            e.toString(),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                      icon: const Icon(
                        Icons.style,
                      ),
                      label: Text(
                        status == 'playing'
                            ? 'GAME STARTED'
                            : 'DEAL CARDS & START',
                      ),
                    )
                  else
                    const Text(
                      'Waiting for host to deal cards…',
                    ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: roomId,
                        ),
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Room code copied',
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.copy,
                    ),
                    label: const Text(
                      'COPY ROOM CODE',
                    ),
                  ),

                  const SizedBox(height: 8),

                  OutlinedButton.icon(
                    onPressed: () =>
                        _invite(
                      context,
                      room,
                    ),
                    icon: const Icon(
                      Icons.share,
                    ),
                    label: const Text(
                      'INVITE A FRIEND',
                    ),
                  ),

                  if (status == 'playing')
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 12,
                      ),
                      child: FilledButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TablePage(
                                state: state,
                                roomId: roomId,
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'OPEN GAME TABLE',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class TablePage extends StatefulWidget {
  final dynamic state;
  final String roomId;

  const TablePage({
    super.key,
    required this.state,
    required this.roomId,
  });

  @override
  State<TablePage> createState() =>
      _TablePageState();
}

class _TablePageState extends State<TablePage> {
  int selected = -1;

  Timer? _turnTimer;

  int secondsLeft = 30;

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
  }

  void _startTimer(bool myTurn) {
    if (!myTurn) {
      _turnTimer?.cancel();
      return;
    }

    if (_turnTimer?.isActive == true) {
      return;
    }

    secondsLeft = 30;

    _turnTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (secondsLeft <= 1) {
          timer.cancel();

          setState(() {
            secondsLeft = 0;
          });
        } else {
          setState(() {
            secondsLeft--;
          });
        }
      },
    );
  }

  Future<void> _play(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) async {
    final data = snap.data() ?? {};

    final gameState =
        Map<String, dynamic>.from(
      data['gameState'] ?? {},
    );

    final hands =
        Map<String, dynamic>.from(
      gameState['hands'] ?? {},
    );

    final uid =
        widget.state.uid?.toString() ?? '';

    final mine =
        List<String>.from(
      hands[uid] ?? [],
    );

    if (uid.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Player is not connected',
          ),
        ),
      );
      return;
    }

    if (selected < 0 ||
        selected >= mine.length) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Select a card first',
          ),
        ),
      );
      return;
    }

    mine.removeAt(selected);

    hands[uid] = mine;

    final members =
        List<String>.from(
      data['memberUids'] ?? [],
    );

    final turnIndex =
        (data['turnIndex'] ?? 0) as int;

    final next = members.isEmpty
        ? 0
        : (turnIndex + 1) %
            members.length;

    await widget.state.fb.updateGameState(
      widget.roomId,
      {
        'deck': List<String>.from(
          gameState['deck'] ?? [],
        ),
        'hands': hands,
        'community': List<String>.from(
          gameState['community'] ?? [],
        ),
        'joker':
            gameState['joker'] ?? '',
        'side':
            gameState['side'] ?? 'Andar',
        'started': true,
      },
      turnIndex: next,
      turn:
          ((data['turn'] ?? 0) as int) + 1,
    );

    if (mounted) {
      setState(() {
        selected = -1;
      });

      _turnTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          widget.state.fb.room(
        widget.roomId,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(
              child:
                  CircularProgressIndicator(),
            ),
          );
        }

        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Game error: ${snap.error}',
              ),
            ),
          );
        }

        final data =
            snap.data!.data() ?? {};

        final game =
            (data['game'] ?? 'rummy')
                .toString();

        final gameState =
            Map<String, dynamic>.from(
          data['gameState'] ?? {},
        );

        final hands =
            Map<String, dynamic>.from(
          gameState['hands'] ?? {},
        );

        final uid =
            widget.state.uid?.toString() ?? '';

        final mine =
            List<String>.from(
          hands[uid] ?? [],
        );

        final community =
            List<String>.from(
          gameState['community'] ?? [],
        );

        final members =
            List<String>.from(
          data['memberUids'] ?? [],
        );

        final turnIndex =
            (data['turnIndex'] ?? 0) as int;

        final myTurn =
            members.isEmpty ||
            members[
                  turnIndex %
                      members.length
                ] ==
                uid;

        _startTimer(myTurn);

        final String dealtText =
            game == 'rummy'
                ? '13 cards dealt'
                : game == 'teenPatti'
                    ? '3 cards dealt'
                    : 'Cards dealt';

        return Scaffold(
          appBar: AppBar(
            title: Text('${_gameTitle(game)} Table'),
            backgroundColor: _redDark,
            foregroundColor: Colors.white,
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF071B16),
                  Color(0xFF0B5A3C),
                  Color(0xFF063C2A),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(
                    dealtText,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    myTurn ? 'YOUR TURN' : 'WAITING FOR OPPONENT',
                    style: TextStyle(
                      color: myTurn ? Colors.amber : Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (myTurn)
                    Text(
                      'Time: $secondsLeft s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'TABLE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (community.isEmpty)
                                  const Text(
                                    'No cards on table',
                                    style: TextStyle(color: Colors.white54),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: community.map((card) {
                                      return _playingCard(card, false);
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Your Cards (${mine.length})',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (mine.isEmpty)
                                  const Text(
                                    'No cards remaining',
                                    style: TextStyle(color: Colors.white70),
                                  )
                                else
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 10,
                                    alignment: WrapAlignment.center,
                                    children: List.generate(mine.length, (index) {
                                      final isSelected = selected == index;
                                      return GestureDetector(
                                        onTap: myTurn
                                            ? () {
                                                setState(() {
                                                  selected = index;
                                                });
                                              }
                                            : null,
                                        child: _playingCard(
                                          mine[index],
                                          isSelected,
                                        ),
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: myTurn && selected >= 0
                            ? () => _play(snap.data!)
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          selected >= 0 ? 'PLAY SELECTED CARD' : 'SELECT A CARD',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          disabledBackgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _playingCard(String card, bool selectedCard) {
    final isRed = card.contains('♥') || card.contains('♦');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 58,
      height: 82,
      transform: Matrix4.translationValues(0, selectedCard ? -8 : 0, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selectedCard ? Colors.amber : Colors.black26,
          width: selectedCard ? 3 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          card,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isRed ? _red : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
