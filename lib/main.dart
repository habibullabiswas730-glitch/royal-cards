// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  runApp(RoyalCardsApp(state: state));
}

class C {
  static const red = Color(0xFF9D1018);
  static const redDark = Color(0xFF62060A);
  static const redSoft = Color(0xFFFFF0F1);
  static const green = Color(0xFF159447);
  static const gold = Color(0xFFFFC52E);
  static const ink = Color(0xFF202124);
  static const muted = Color(0xFF747474);
  static const bg = Color(0xFFF7F7F8);
  static const blue = Color(0xFF2563EB);
}

enum GameType { rummy, teenPatti, poker, andarBahar }

extension GameTypeX on GameType {
  String get title {
    switch (this) {
      case GameType.rummy: return 'Rummy';
      case GameType.teenPatti: return 'Teen Patti';
      case GameType.poker: return 'Poker';
      case GameType.andarBahar: return 'Andar Bahar';
    }
  }
  String get subtitle {
    switch (this) {
      case GameType.rummy: return '13-card multiplayer practice';
      case GameType.teenPatti: return '3-card table game';
      case GameType.poker: return 'Texas Hold’em practice';
      case GameType.andarBahar: return 'Classic prediction table';
    }
  }
  IconData get icon {
    switch (this) {
      case GameType.rummy: return Icons.style;
      case GameType.teenPatti: return Icons.layers;
      case GameType.poker: return Icons.casino;
      case GameType.andarBahar: return Icons.compare_arrows;
    }
  }
}

class Friend {
  String name;
  bool online;
  Friend(this.name, {this.online = true});
}

class Room {
  final String id;
  final GameType game;
  final String host;
  int seats;
  final List<String> players;
  Room({required this.id, required this.game, required this.host, this.seats = 6, List<String>? players})
      : players = players ?? [host];
}

class AppState extends ChangeNotifier {
  int coins = 517;
  int points = 1280;
  String player = 'player15291';
  String email = '';
  String phone = '';
  bool loggedIn = false;
  bool notifications = true;
  bool sound = true;
  bool admin = false;
  final List<String> activity = ['Welcome bonus +517'];
  final List<Friend> friends = [Friend('LuckyPlayer'), Friend('RoyalAce', online: false)];
  final List<Room> rooms = [];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    coins = p.getInt('coins') ?? 517;
    points = p.getInt('points') ?? 1280;
    player = p.getString('player') ?? 'player15291';
    email = p.getString('email') ?? '';
    phone = p.getString('phone') ?? '';
    loggedIn = p.getBool('loggedIn') ?? false;
    admin = p.getBool('admin') ?? false;
    notifyListeners();
  }

  Future<void> login({required String name, String email = '', String phone = '', bool admin = false}) async {
    player = name.trim().isEmpty ? 'player15291' : name.trim();
    this.email = email.trim();
    this.phone = phone.trim();
    loggedIn = true;
    this.admin = admin;
    final p = await SharedPreferences.getInstance();
    await p.setString('player', player);
    await p.setString('email', this.email);
    await p.setString('phone', this.phone);
    await p.setBool('loggedIn', true);
    await p.setBool('admin', this.admin);
    notifyListeners();
  }

  Future<void> logout() async {
    loggedIn = false;
    final p = await SharedPreferences.getInstance();
    await p.setBool('loggedIn', false);
    notifyListeners();
  }

  Future<void> addCoins(int amount, String reason) async {
    coins += amount;
    activity.insert(0, '$reason +$amount');
    await _save();
    notifyListeners();
  }

  Future<void> removeCoins(int amount, String reason) async {
    if (coins < amount) return;
    coins -= amount;
    activity.insert(0, '$reason -$amount');
    await _save();
    notifyListeners();
  }

  Future<void> reward(int amount) async {
    coins += amount;
    points += amount * 2;
    activity.insert(0, 'Game reward +$amount');
    await _save();
    notifyListeners();
  }

  Room createRoom(GameType game) {
    final id = 'RC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final room = Room(id: id, game: game, host: player);
    rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  void joinRoom(Room room) {
    if (!room.players.contains(player) && room.players.length < room.seats) room.players.add(player);
    notifyListeners();
  }

  void addFriend(String name) {
    final clean = name.trim();
    if (clean.isEmpty || friends.any((f) => f.name.toLowerCase() == clean.toLowerCase())) return;
    friends.add(Friend(clean));
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('coins', coins);
    await p.setInt('points', points);
  }
}

class RoyalCardsApp extends StatelessWidget {
  final AppState state;
  const RoyalCardsApp({super.key, required this.state});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Royal Cards',
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: C.bg, colorScheme: ColorScheme.fromSeed(seedColor: C.red), appBarTheme: const AppBarTheme(backgroundColor: C.red, foregroundColor: Colors.white, elevation: 0)),
      home: state.loggedIn ? MainShell(state: state) : LoginPage(state: state),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  @override void dispose() { name.dispose(); email.dispose(); phone.dispose(); super.dispose(); }
  Future<void> submit() async => widget.state.login(name: name.text, email: email.text, phone: phone.text);
  @override Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.redDark, C.red, Color(0xFFB9121C), C.redDark])),
      child: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(22), child: Column(children: [
        const Icon(Icons.style_rounded, color: C.gold, size: 72),
        const Text('ROYAL', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 5)),
        const Text('CARDS', style: TextStyle(color: C.gold, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 5)),
        const SizedBox(height: 6), const Text('ONLINE CARD GAMES • VIRTUAL COINS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11)),
        const SizedBox(height: 28),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white24)), child: Column(children: [
          const Align(alignment: Alignment.centerLeft, child: Text('Create / Login', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          TextField(controller: name, style: const TextStyle(color: C.ink), decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'Player name')),
          const SizedBox(height: 12),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: C.ink), decoration: const InputDecoration(prefixIcon: Icon(Icons.email_outlined), hintText: 'Email ID (optional)')),
          const SizedBox(height: 12),
          TextField(controller: phone, keyboardType: TextInputType.phone, style: const TextStyle(color: C.ink), decoration: const InputDecoration(prefixIcon: Icon(Icons.phone_outlined), hintText: 'Phone number (optional)')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: submit, style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('CONTINUE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
          const SizedBox(height: 10), const Text('Email/phone are saved on this build. Firebase verification can be connected to the same fields.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
        const SizedBox(height: 14), const Text('Virtual coins only • No real-money wagering', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]))),
    ),
  ));
}

class MainShell extends StatefulWidget {
  final AppState state;
  const MainShell({super.key, required this.state});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  @override Widget build(BuildContext context) {
    final pages = [LobbyPage(state: widget.state), LeaderboardPage(state: widget.state), OnlinePage(state: widget.state), FriendsPage(state: widget.state), MenuPage(state: widget.state)];
    return Scaffold(body: IndexedStack(index: index, children: pages), bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Lobby'),
      NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Rank'),
      NavigationDestination(icon: Icon(Icons.public_outlined), selectedIcon: Icon(Icons.public), label: 'Online'),
      NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Friends'),
      NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'Menu'),
    ]));
  }
}

class TopBar extends StatelessWidget {
  final AppState state; final String title;
  const TopBar({super.key, required this.state, this.title = 'Welcome back'});
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.fromLTRB(18, 52, 14, 16), color: C.red, child: Row(children: [
    const CircleAvatar(radius: 25, backgroundColor: Colors.white, child: Icon(Icons.person, color: C.red, size: 30)),
    const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('player', style: TextStyle(color: Colors.white70, fontSize: 11)), SizedBox(height: 2), Text('Royal Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))])),
    InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state))), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: C.redDark, borderRadius: BorderRadius.circular(22)), child: Row(children: [const Icon(Icons.monetization_on, color: C.gold, size: 21), const SizedBox(width: 6), Text('${state.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
    IconButton(onPressed: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Notifications'), content: Text('No new notifications.'))), icon: const Icon(Icons.notifications_none, color: Colors.white)),
  ]));
}

class LobbyPage extends StatelessWidget {
  final AppState state; const LobbyPage({super.key, required this.state});
  @override Widget build(BuildContext context) => SingleChildScrollView(child: Column(children: [
    TopBar(state: state),
    const SizedBox(height: 14),
    Container(height: 118, margin: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [C.redDark, Color(0xFFD82131)])), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('ROYAL ONLINE', style: TextStyle(color: C.gold, fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Play with friends using virtual coins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]))),
    const SizedBox(height: 15),
    Row(children: [Expanded(child: QuickTile(icon: Icons.public, label: 'ONLINE', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlinePage(state: state))))), Expanded(child: QuickTile(icon: Icons.people, label: 'INVITE', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FriendsPage(state: state))))), Expanded(child: QuickTile(icon: Icons.account_balance_wallet_outlined, label: 'WALLET', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state)))))]),
    const SizedBox(height: 18),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 18), child: Align(alignment: Alignment.centerLeft, child: Text('Choose a game', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)))),
    const SizedBox(height: 10),
    ...GameType.values.map((g) => GameModeCard(game: g, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGamePage(state: state, game: g))))),
    const SizedBox(height: 20),
  ]));
}

class QuickTile extends StatelessWidget { final IconData icon; final String label; final VoidCallback onTap; const QuickTile({super.key, required this.icon, required this.label, required this.onTap}); @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(margin: const EdgeInsets.symmetric(horizontal: 5), padding: const EdgeInsets.all(14), child: Column(children: [Icon(icon, color: C.red, size: 30), const SizedBox(height: 6), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]))); }
class GameModeCard extends StatelessWidget { final GameType game; final VoidCallback onTap; const GameModeCard({super.key, required this.game, required this.onTap}); @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), leading: CircleAvatar(backgroundColor: C.redSoft, child: Icon(game.icon, color: C.red)), title: Text(game.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), subtitle: Text(game.subtitle), trailing: FilledButton(onPressed: onTap, child: const Text('PLAY')))); }

class OnlinePage extends StatelessWidget {
  final AppState state; const OnlinePage({super.key, required this.state});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Online Games')), body: ListView(padding: const EdgeInsets.all(18), children: [
    Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(18)), child: const Row(children: [Icon(Icons.wifi, color: C.green), SizedBox(width: 10), Expanded(child: Text('Online room system is ready in the app. Rooms and player lists are managed here; cross-device real-time service requires the Firebase project connection.', style: TextStyle(fontWeight: FontWeight.w600)))])),
    const SizedBox(height: 18),
    const Text('Games', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    ...GameType.values.map((g) => GameModeCard(game: g, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineGamePage(state: state, game: g))))),
    const SizedBox(height: 14),
    const Text('Your rooms', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    if (state.rooms.isEmpty) const Card(child: ListTile(title: Text('No rooms yet'), subtitle: Text('Create a room from any game above.'))),
    ...state.rooms.map((r) => RoomTile(state: state, room: r)),
  ]));
}

class RoomTile extends StatelessWidget { final AppState state; final Room room; const RoomTile({super.key, required this.state, required this.room}); @override Widget build(BuildContext context) => Card(child: ListTile(leading: CircleAvatar(child: Icon(room.game.icon)), title: Text('${room.game.title} • ${room.id}'), subtitle: Text('${room.players.length}/${room.seats} players • Host: ${room.host}'), trailing: FilledButton(onPressed: () { state.joinRoom(room); Navigator.push(context, MaterialPageRoute(builder: (_) => RoomPage(state: state, room: room))); }, child: const Text('JOIN')))); }

class OnlineGamePage extends StatelessWidget {
  final AppState state;
  final GameType game;

  const OnlineGamePage({super.key, required this.state, required this.game});

  @override
  Widget build(BuildContext context) {
    final friendCards = state.friends.map((friend) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(child: Text(friend.name.substring(0, 1))),
          title: Text(friend.name),
          subtitle: Text(friend.online ? 'Online' : 'Offline'),
          trailing: FilledButton(
            onPressed: () => _invite(context, friend.name),
            child: const Text('INVITE'),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(game.title)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          GameModeCard(game: game, onTap: () {}),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () {
                final room = state.createRoom(game);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomPage(state: state, room: room),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('CREATE ONLINE ROOM'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: OutlinedButton.icon(
              onPressed: () {
                final room = state.createRoom(game);
                state.joinRoom(room);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoomPage(state: state, room: room),
                  ),
                );
              },
              icon: const Icon(Icons.flash_on),
              label: const Text('QUICK MATCH'),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Invite a friend',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          ...friendCards,
        ],
      ),
    );
  }

  void _invite(BuildContext context, String friend) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invite sent to $friend for ${game.title}')),
    );
  }
}

class RoomPage extends StatefulWidget {
  final AppState state;
  final Room room;

  const RoomPage({super.key, required this.state, required this.room});

  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  @override
  Widget build(BuildContext context) {
    final playerCards = widget.room.players.map((player) {
      return Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(player),
          trailing: const Icon(Icons.check_circle, color: C.green),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${widget.room.game.title} Room')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.redDark, C.red]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.room.id, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                Text(
                  widget.room.game.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.room.players.length}/${widget.room.seats} players',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Players',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          ...playerCards,
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: () => _start(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('START GAME'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Room invite link copied')),
              );
            },
            icon: const Icon(Icons.share),
            label: const Text('INVITE / SHARE ROOM'),
          ),
        ],
      ),
    );
  }

  void _start(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TablePage(state: widget.state, room: widget.room),
      ),
    );
  }
}

class TablePage extends StatefulWidget {
  final AppState state;
  final Room room;

  const TablePage({super.key, required this.state, required this.room});

  @override
  State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  int turn = 0;
  int selected = -1;
  bool ended = false;

  final cards = const [
    'A♠', 'K♥', '7♦', 'Q♣', '3♠', '10♥', '9♦',
    'J♣', '2♥', '8♠', '4♦', '6♣', '5♥',
  ];

  Future<void> action() async {
    if (selected < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a card first')),
      );
      return;
    }

    await widget.state.reward(10);
    setState(() {
      turn++;
      ended = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardWidgets = List.generate(cards.length, (i) {
      final isRed = [1, 3, 5, 8, 12].contains(i);
      final isSelected = selected == i;

      return GestureDetector(
        onTap: () => setState(() {
          selected = i;
          ended = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 72,
          height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? C.redSoft : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? C.red : Colors.black12,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 5,
              ),
            ],
          ),
          child: Text(
            cards[i],
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isRed ? Colors.red : C.ink,
            ),
          ),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: Text(widget.room.game.title)),
      body: Column(
        children: [
          Container(
            color: C.redSoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Room ${widget.room.id}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Turn $turn',
                  style: const TextStyle(
                    color: C.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.room.players
                .map(
                  (player) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Chip(
                      avatar: const Icon(Icons.person, size: 16),
                      label: Text(player),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            ended
                ? 'Turn complete • +10 virtual coins'
                : 'Your turn — select a card',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cardWidgets,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: action,
                child: const Text('PLAY TURN'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FriendsPage extends StatefulWidget { final AppState state; const FriendsPage({super.key, required this.state}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> { final search = TextEditingController(); @override void dispose() { search.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Friends & Invite')), body: ListView(padding: const EdgeInsets.all(18), children: [TextField(controller: search, decoration: const InputDecoration(hintText: 'Player name / Email / Phone', prefixIcon: Icon(Icons.search))), const SizedBox(height: 12), SizedBox(height: 52, child: FilledButton.icon(onPressed: () { widget.state.addFriend(search.text); search.clear(); setState(() {}); }, icon: const Icon(Icons.person_add), label: const Text('ADD FRIEND'))), const SizedBox(height: 10), SizedBox(height: 52, child: OutlinedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Invite a friend'), content: const Text('Share your room invite from any online game. Your invite code is ROYAL517.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))])), icon: const Icon(Icons.share), label: const Text('INVITE A FRIEND'))), const SizedBox(height: 22), const Text('Your friends', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), ...widget.state.friends.map((f) => Card(child: ListTile(leading: CircleAvatar(child: Text(f.name.substring(0,1))), title: Text(f.name), subtitle: Text(f.online ? 'Online' : 'Offline'), trailing: Icon(Icons.circle, color: f.online ? C.green : Colors.grey, size: 12))))])); }

class LeaderboardPage extends StatelessWidget { final AppState state; const LeaderboardPage({super.key, required this.state}); @override Widget build(BuildContext context) { final names = [state.player, 'RoyalAce', 'LuckyPlayer', 'CardKing', 'AceMaster']; return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: ListView.builder(padding: const EdgeInsets.all(18), itemCount: names.length, itemBuilder: (_, i) => Card(child: ListTile(leading: CircleAvatar(child: Text('${i+1}')), title: Text(names[i]), trailing: Text('${state.points - i * 75} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: C.red)))))); } }

class WalletPage extends StatelessWidget { final AppState state; const WalletPage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Virtual Wallet')), body: ListView(padding: const EdgeInsets.all(18), children: [Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.redDark, C.red]), borderRadius: BorderRadius.circular(22)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Virtual balance', style: TextStyle(color: Colors.white70)), const SizedBox(height: 5), Text('${state.coins} coins', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900))])), const SizedBox(height: 18), Row(children: [Expanded(child: FilledButton.icon(onPressed: () => state.addCoins(100, 'Demo add'), icon: const Icon(Icons.add), label: const Text('ADD 100'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () => state.removeCoins(50, 'Demo use'), icon: const Icon(Icons.remove), label: const Text('USE 50')))]), const SizedBox(height: 20), const Text('Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), ...state.activity.take(12).map((x) => ListTile(leading: const Icon(Icons.history), title: Text(x)))])); }

class MenuPage extends StatelessWidget { final AppState state; const MenuPage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Menu')), body: ListView(children: [const SizedBox(height: 10), ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(state.player, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${state.coins} virtual coins')), const Divider(), MenuItem(icon: Icons.person_outline, text: 'Profile & Account', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(state: state)))), MenuItem(icon: Icons.public, text: 'Online Games', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlinePage(state: state)))), MenuItem(icon: Icons.account_balance_wallet_outlined, text: 'Wallet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state)))), MenuItem(icon: Icons.admin_panel_settings_outlined, text: 'Admin', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminPage(state: state)))), MenuItem(icon: Icons.settings_outlined, text: 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(state: state)))), MenuItem(icon: Icons.logout, text: 'Log out', onTap: () async => state.logout())])); }
class MenuItem extends StatelessWidget { final IconData icon; final String text; final VoidCallback onTap; const MenuItem({super.key, required this.icon, required this.text, required this.onTap}); @override Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: C.red), title: Text(text), trailing: const Icon(Icons.chevron_right), onTap: onTap); }

class ProfilePage extends StatelessWidget {
  final AppState state;

  const ProfilePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Account')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 16),
          const CircleAvatar(
            radius: 45,
            backgroundColor: C.redSoft,
            child: Icon(Icons.person, color: C.red, size: 52),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              state.player,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email ID'),
              subtitle: Text(state.email.isEmpty ? 'Not added' : state.email),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone number'),
              subtitle: Text(state.phone.isEmpty ? 'Not added' : state.phone),
            ),
          ),
          StatTile(label: 'Virtual Coins', value: '${state.coins}'),
          StatTile(label: 'Leaderboard Points', value: '${state.points}'),
          const SizedBox(height: 10),
          const Text('Account fields are stored locally in this build.'),
        ],
      ),
    );
  }
}
class StatTile extends StatelessWidget { final String label, value; const StatTile({super.key, required this.label, required this.value}); @override Widget build(BuildContext context) => Card(child: ListTile(title: Text(label), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: C.red)))); }

class AdminPage extends StatefulWidget { final AppState state; const AdminPage({super.key, required this.state}); @override State<AdminPage> createState() => _AdminPageState(); }
class _AdminPageState extends State<AdminPage> { final code = TextEditingController(); bool unlocked = false; @override void dispose() { code.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Admin')), body: ListView(padding: const EdgeInsets.all(18), children: [if (!unlocked) ...[const Text('Admin access', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('Enter the admin access code for this demo build.'), const SizedBox(height: 16), TextField(controller: code, obscureText: true, decoration: const InputDecoration(prefixIcon: Icon(Icons.lock_outline), hintText: 'Admin code')), const SizedBox(height: 12), FilledButton(onPressed: () { if (code.text.trim() == 'ROYAL-ADMIN') setState(() => unlocked = true); else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid admin code'))); }, child: const Text('UNLOCK ADMIN'))] else ...[Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(18)), child: const Text('Admin dashboard • virtual/demo controls only', style: TextStyle(fontWeight: FontWeight.bold))), const SizedBox(height: 12), _AdminTile(icon: Icons.people, title: 'Users', value: '${widget.state.friends.length + 1}'), _AdminTile(icon: Icons.public, title: 'Rooms', value: '${widget.state.rooms.length}'), _AdminTile(icon: Icons.monetization_on, title: 'Player coins', value: '${widget.state.coins}'), _AdminTile(icon: Icons.emoji_events, title: 'Leaderboard points', value: '${widget.state.points}'), const SizedBox(height: 10), FilledButton.icon(onPressed: () => widget.state.addCoins(500, 'Admin demo bonus'), icon: const Icon(Icons.add), label: const Text('ADD 500 VIRTUAL COINS TO CURRENT USER'))]])); }
class _AdminTile extends StatelessWidget { final IconData icon; final String title, value; const _AdminTile({required this.icon, required this.title, required this.value}); @override Widget build(BuildContext context) => Card(child: ListTile(leading: Icon(icon, color: C.red), title: Text(title), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)))); }

class SettingsPage extends StatefulWidget { final AppState state; const SettingsPage({super.key, required this.state}); @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(children: [SwitchListTile(title: const Text('Notifications'), value: widget.state.notifications, onChanged: (v) => setState(() => widget.state.notifications = v)), SwitchListTile(title: const Text('Sound'), value: widget.state.sound, onChanged: (v) => setState(() => widget.state.sound = v)), const ListTile(title: Text('App version'), trailing: Text('2.0.0')), const Padding(padding: EdgeInsets.all(18), child: Text('Virtual coins only. No real-money deposits, withdrawals, or wagering.', style: TextStyle(color: C.muted, fontSize: 12))) ])); }
