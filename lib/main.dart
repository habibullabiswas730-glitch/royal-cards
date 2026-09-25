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
}

class AppState extends ChangeNotifier {
  int coins = 517;
  int points = 1280;
  String player = 'player15291';
  bool loggedIn = false;
  bool notifications = true;
  bool sound = true;
  final List<String> activity = ['Welcome bonus +517', 'Practice reward +25'];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    coins = p.getInt('coins') ?? 517;
    points = p.getInt('points') ?? 1280;
    player = p.getString('player') ?? 'player15291';
    loggedIn = p.getBool('loggedIn') ?? false;
    notifyListeners();
  }

  Future<void> login(String name) async {
    player = name.trim().isEmpty ? 'player15291' : name.trim();
    loggedIn = true;
    final p = await SharedPreferences.getInstance();
    await p.setString('player', player);
    await p.setBool('loggedIn', true);
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
    activity.insert(0, 'Practice reward +$amount');
    await _save();
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Royal Cards',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: C.bg,
          colorScheme: ColorScheme.fromSeed(seedColor: C.red),
          appBarTheme: const AppBarTheme(backgroundColor: C.red, foregroundColor: Colors.white, elevation: 0),
          inputDecorationTheme: InputDecorationTheme(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        home: state.loggedIn ? MainShell(state: state) : LoginPage(state: state),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final AppState state;
  const LoginPage({super.key, required this.state});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final controller = TextEditingController();
  @override void dispose() { controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [C.redDark, C.red, Color(0xFFB9121C), C.redDark])),
        child: SafeArea(child: Center(child: Column(children: [
          const Icon(Icons.style_rounded, color: C.gold, size: 72),
          const SizedBox(height: 6),
          const Text('ROYAL', style: TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 5)),
          const Text('CARDS', style: TextStyle(color: C.gold, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 5)),
          const SizedBox(height: 8),
          const Text('PLAY • PRACTICE • COMPETE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 42),
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(26), border: Border.all(color: Colors.white24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Create / Login', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            TextField(controller: controller, style: const TextStyle(color: C.ink), decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline), hintText: 'Enter player name')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 54, child: ElevatedButton(onPressed: () async => widget.state.login(controller.text), style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('CONTINUE', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
          ])),
          const SizedBox(height: 18),
          const Text('Virtual coins only • No real-money wagering', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]))),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState state;
  const MainShell({super.key, required this.state});
  @override State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  @override Widget build(BuildContext context) {
    final pages = [
      LobbyPage(state: widget.state),
      LeaderboardPage(state: widget.state),
      PracticePage(state: widget.state),
      FriendsPage(state: widget.state),
      MenuPage(state: widget.state),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Lobby'),
        NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Rank'),
        NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: 'Practice'),
        NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Friends'),
        NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'Menu'),
      ]),
    );
  }
}

class TopBar extends StatelessWidget {
  final AppState state; final String title;
  const TopBar({super.key, required this.state, this.title = 'Welcome back'});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 52, 14, 16), color: C.red,
    child: Row(children: [
      const CircleAvatar(radius: 25, backgroundColor: Colors.white, child: Icon(Icons.person, color: C.red, size: 30)),
      const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('player', style: TextStyle(color: Colors.white70, fontSize: 11)), SizedBox(height: 2), Text('Royal Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17))])),
      InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state))), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: C.redDark, borderRadius: BorderRadius.circular(22)), child: Row(children: [const Icon(Icons.monetization_on, color: C.gold, size: 21), const SizedBox(width: 6), Text('${state.coins}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
      IconButton(onPressed: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Notifications'), content: Text('No new notifications.'))), icon: const Icon(Icons.notifications_none, color: Colors.white)),
    ]),
  );
}

class LobbyPage extends StatelessWidget {
  final AppState state; const LobbyPage({super.key, required this.state});
  @override Widget build(BuildContext context) => SingleChildScrollView(child: Column(children: [
    TopBar(state: state),
    const SizedBox(height: 14),
    Container(height: 118, margin: const EdgeInsets.symmetric(horizontal: 18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(colors: [C.redDark, Color(0xFFD82131)])), child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('WELCOME BONUS', style: TextStyle(color: C.gold, fontSize: 26, fontWeight: FontWeight.w900)), SizedBox(height: 4), Text('Practice more • Climb the leaderboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))]))),
    const SizedBox(height: 15),
    Row(children: [Expanded(child: QuickTile(icon: Icons.account_balance_wallet_outlined, label: 'WALLET', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state))))), Expanded(child: QuickTile(icon: Icons.emoji_events_outlined, label: 'TOURNAMENTS', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TournamentPage(state: state))))), Expanded(child: QuickTile(icon: Icons.style_outlined, label: 'PRACTICE', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PracticePage(state: state)))))]),
    const SizedBox(height: 15),
    Container(color: C.redSoft, padding: const EdgeInsets.symmetric(vertical: 13), child: const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [Text('POINTS', style: TextStyle(color: C.red, fontWeight: FontWeight.bold)), Text('POOL', style: TextStyle(color: C.muted, fontWeight: FontWeight.bold)), Text('DEALS', style: TextStyle(color: C.muted, fontWeight: FontWeight.bold))])),
    const SizedBox(height: 12),
    GameCard(title: 'Classic Practice', players: '2–6 players', entry: '20 coins', icon: Icons.auto_awesome, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Classic Practice', cost: 20)))),
    GameCard(title: 'Quick Practice', players: '2 players', entry: 'Free', icon: Icons.bolt, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Quick Practice')))),
    const SizedBox(height: 90),
  ]));
}

class QuickTile extends StatelessWidget { final IconData icon; final String label; final VoidCallback onTap; const QuickTile({super.key, required this.icon, required this.label, required this.onTap}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(15), child: Container(height: 100, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.07), blurRadius: 8)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: C.red, size: 31), const SizedBox(height: 7), Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))])))); }

class GameCard extends StatelessWidget { final String title, players, entry; final IconData icon; final VoidCallback onTap; const GameCard({super.key, required this.title, required this.players, required this.entry, required this.icon, required this.onTap}); @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6), child: ListTile(contentPadding: const EdgeInsets.all(10), leading: CircleAvatar(backgroundColor: C.redSoft, child: Icon(icon, color: C.red)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('$players • $entry'), trailing: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: C.green, foregroundColor: Colors.white), child: const Text('PLAY')))); }

class WalletPage extends StatelessWidget {
  final AppState state; const WalletPage({super.key, required this.state});
  void msg(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Wallet')), body: ListView(padding: const EdgeInsets.all(18), children: [
    Container(width: double.infinity, padding: const EdgeInsets.all(25), decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.redDark, C.red]), borderRadius: BorderRadius.circular(23)), child: Column(children: [const Text('VIRTUAL COINS', style: TextStyle(color: Colors.white70, letterSpacing: 1)), const SizedBox(height: 8), Text('${state.coins}', style: const TextStyle(color: C.gold, fontSize: 44, fontWeight: FontWeight.w900)), const Text('Practice balance', style: TextStyle(color: Colors.white70))])),
    const SizedBox(height: 16),
    Row(children: [Expanded(child: FilledButton.icon(onPressed: () async { await state.addCoins(100, 'Free coin bonus'); if (context.mounted) msg(context, '100 virtual coins added'); }, icon: const Icon(Icons.add), label: const Text('ADD 100'))), const SizedBox(width: 10), Expanded(child: OutlinedButton.icon(onPressed: () async { if (state.coins < 50) { msg(context, 'Not enough coins'); return; } await state.removeCoins(50, 'Practice spend'); if (context.mounted) msg(context, '50 virtual coins removed'); }, icon: const Icon(Icons.remove), label: const Text('REMOVE 50')))]),
    const SizedBox(height: 24), const Text('Recent activity', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
    ...state.activity.take(8).map((x) => ListTile(leading: const CircleAvatar(backgroundColor: C.redSoft, child: Icon(Icons.history, color: C.red)), title: Text(x), subtitle: const Text('Virtual coin activity'))),
    const SizedBox(height: 20), const Text('This wallet contains virtual practice coins only.', style: TextStyle(color: C.muted, fontSize: 12)),
  ]));
}

class LeaderboardPage extends StatelessWidget { final AppState state; const LeaderboardPage({super.key, required this.state}); @override Widget build(BuildContext context) { final names = ['CardMaster', 'LuckyPlayer', 'RoyalAce', state.player, 'Player120', 'Player121', 'Player122', 'Player123', 'Player124', 'Player125']; return Scaffold(appBar: AppBar(title: const Text('Leaderboard')), body: ListView.builder(padding: const EdgeInsets.all(14), itemCount: names.length, itemBuilder: (_, i) { final pts = i == 3 ? state.points : 2100 - i * 123; return Card(child: ListTile(leading: CircleAvatar(backgroundColor: i < 3 ? C.gold : C.redSoft, child: Text('${i + 1}', style: TextStyle(color: i < 3 ? Colors.white : C.red, fontWeight: FontWeight.bold))), title: Text(names[i], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(i == 3 ? 'Your position' : 'Practice ranking'), trailing: Text('$pts pts', style: const TextStyle(fontWeight: FontWeight.bold)))); })); } }

class PracticePage extends StatelessWidget { final AppState state; const PracticePage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Practice')), body: ListView(padding: const EdgeInsets.all(18), children: [const Text('Choose a practice mode', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)), const SizedBox(height: 16), PracticeCard(title: 'Classic Practice', desc: 'Virtual-coin card session with score rewards.', icon: Icons.style, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Classic Practice', cost: 20)))), PracticeCard(title: 'Quick Match', desc: 'Short session with instant rounds.', icon: Icons.bolt, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Quick Match'))))])); }
class PracticeCard extends StatelessWidget { final String title, desc; final IconData icon; final VoidCallback onTap; const PracticeCard({super.key, required this.title, required this.desc, required this.icon, required this.onTap}); @override Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(contentPadding: const EdgeInsets.all(15), leading: CircleAvatar(radius: 28, backgroundColor: C.redSoft, child: Icon(icon, color: C.red, size: 29)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), subtitle: Text(desc), trailing: const Icon(Icons.arrow_forward_ios, size: 18), onTap: onTap)); }

class FriendsPage extends StatefulWidget { final AppState state; const FriendsPage({super.key, required this.state}); @override State<FriendsPage> createState() => _FriendsPageState(); }
class _FriendsPageState extends State<FriendsPage> { final search = TextEditingController(); final friends = ['LuckyPlayer', 'RoyalAce']; @override void dispose() { search.dispose(); super.dispose(); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Friends & Invite')), body: ListView(padding: const EdgeInsets.all(18), children: [TextField(controller: search, decoration: const InputDecoration(hintText: 'Search player', prefixIcon: Icon(Icons.search))), const SizedBox(height: 14), SizedBox(height: 52, child: FilledButton.icon(onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Invite a friend'), content: const Text('Your invite code: ROYAL517'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))])), icon: const Icon(Icons.share), label: const Text('INVITE A FRIEND'))), const SizedBox(height: 22), const Text('Your friends', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), ...friends.map((x) => ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(x), subtitle: const Text('Online'), trailing: const Icon(Icons.circle, color: C.green, size: 11))),])); }

class TournamentPage extends StatelessWidget { final AppState state; const TournamentPage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Tournaments')), body: ListView(padding: const EdgeInsets.all(18), children: [GameCard(title: 'Daily Practice Cup', players: '128 players', entry: 'Free', icon: Icons.emoji_events, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Daily Practice Cup')))), GameCard(title: 'Weekend Challenge', players: '64 players', entry: '100 coins', icon: Icons.military_tech, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GamePage(state: state, title: 'Weekend Challenge', cost: 100))))])); }

class GamePage extends StatefulWidget { final AppState state; final String title; final int cost; const GamePage({super.key, required this.state, required this.title, this.cost = 0}); @override State<GamePage> createState() => _GamePageState(); }
class _GamePageState extends State<GamePage> { int selected = -1; int score = 0; bool finished = false; final cards = const ['A♠', 'K♥', '7♦', 'Q♣', '3♠', '10♥']; Future<void> play() async { if (selected < 0) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a card first'))); return; } if (widget.cost > 0 && widget.state.coins < widget.cost) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough virtual coins'))); return; } if (widget.cost > 0) await widget.state.removeCoins(widget.cost, 'Match entry'); final reward = 10 + selected * 5; score += reward; await widget.state.reward(reward); setState(() => finished = true); } @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title)), body: Column(children: [Container(width: double.infinity, color: C.redSoft, padding: const EdgeInsets.all(17), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Practice Table', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text('Score: $score', style: const TextStyle(fontWeight: FontWeight.bold, color: C.red))])), const SizedBox(height: 22), Text(finished ? 'Turn complete! Choose again.' : 'Select a card', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 18), Wrap(spacing: 10, runSpacing: 10, children: List.generate(cards.length, (i) => GestureDetector(onTap: () => setState(() { selected = i; finished = false; }), child: AnimatedContainer(duration: const Duration(milliseconds: 160), width: 94, height: 124, alignment: Alignment.center, decoration: BoxDecoration(color: selected == i ? C.redSoft : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: selected == i ? C.red : Colors.black12, width: 2), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 7)]), child: Text(cards[i], style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: [1, 3, 5].contains(i) ? Colors.red : C.ink)))))), const Spacer(), Padding(padding: const EdgeInsets.all(20), child: SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: play, child: Text(widget.cost > 0 ? 'PLAY • ${widget.cost} COINS' : 'PLAY TURN')))),])); }

class MenuPage extends StatelessWidget { final AppState state; const MenuPage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Menu')), body: ListView(children: [const SizedBox(height: 10), ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(state.player, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${state.coins} virtual coins • ${state.points} points')), const Divider(), MenuItem(icon: Icons.person_outline, text: 'Profile', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(state: state)))), MenuItem(icon: Icons.account_balance_wallet_outlined, text: 'Wallet', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WalletPage(state: state)))), MenuItem(icon: Icons.settings_outlined, text: 'Settings', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage(state: state)))), MenuItem(icon: Icons.help_outline, text: 'Help & Support', onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Support'), content: Text('For this demo, support is available through the project owner.')))), MenuItem(icon: Icons.description_outlined, text: 'Terms & Privacy', onTap: () => showDialog(context: context, builder: (_) => const AlertDialog(title: Text('Terms & Privacy'), content: Text('This app uses virtual coins only. No real-money deposits, withdrawals, or wagering are supported.')))), MenuItem(icon: Icons.logout, text: 'Log out', onTap: () async => state.logout())])); }
class MenuItem extends StatelessWidget { final IconData icon; final String text; final VoidCallback onTap; const MenuItem({super.key, required this.icon, required this.text, required this.onTap}); @override Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: C.red), title: Text(text), trailing: const Icon(Icons.chevron_right), onTap: onTap); }

class ProfilePage extends StatelessWidget { final AppState state; const ProfilePage({super.key, required this.state}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: ListView(padding: const EdgeInsets.all(18), children: [const SizedBox(height: 20), const CircleAvatar(radius: 45, backgroundColor: C.redSoft, child: Icon(Icons.person, color: C.red, size: 52)), const SizedBox(height: 12), Center(child: Text(state.player, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold))), const SizedBox(height: 25), StatTile(label: 'Virtual Coins', value: '${state.coins}'), StatTile(label: 'Leaderboard Points', value: '${state.points}'), StatTile(label: 'Invite Code', value: 'ROYAL517')])); }
class StatTile extends StatelessWidget { final String label, value; const StatTile({super.key, required this.label, required this.value}); @override Widget build(BuildContext context) => Card(child: ListTile(title: Text(label), trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: C.red)))); }

class SettingsPage extends StatefulWidget { final AppState state; const SettingsPage({super.key, required this.state}); @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> { @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(children: [SwitchListTile(title: const Text('Notifications'), subtitle: const Text('Show app notifications'), value: widget.state.notifications, onChanged: (v) => setState(() => widget.state.notifications = v)), SwitchListTile(title: const Text('Sound'), subtitle: const Text('Game sound effects'), value: widget.state.sound, onChanged: (v) => setState(() => widget.state.sound = v)), const ListTile(title: Text('App version'), trailing: Text('1.0.0')), const Padding(padding: EdgeInsets.all(18), child: Text('Virtual practice app. Account and wallet data are stored locally on this build.', style: TextStyle(color: C.muted, fontSize: 12))) ])); }
