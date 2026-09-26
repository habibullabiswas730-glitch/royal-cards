// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart' as firebase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final state = AppState();
  await state.load();
  runApp(RoyalCardsApp(state: state));
}

class C {
  static const red = Color(0xFF9D1018), redDark = Color(0xFF62060A), redSoft = Color(0xFFFFF0F1);
  static const green = Color(0xFF159447), gold = Color(0xFFFFC52E), ink = Color(0xFF202124), bg = Color(0xFFF7F7F8);
}

enum GameType { rummy, teenPatti, poker, andarBahar }
extension GameTypeX on GameType {
  String get title => ['Rummy','Teen Patti','Poker','Andar Bahar'][index];
  String get subtitle => ['13-card multiplayer','3-card table game','Texas Hold’em practice','Classic prediction table'][index];
  IconData get icon => [Icons.style,Icons.layers,Icons.casino,Icons.compare_arrows][index];
  String get key => name;
  static GameType from(String v) => GameType.values.firstWhere((e)=>e.name==v, orElse:()=>GameType.rummy);
}

class PlayingCard {
  final String rank, suit;
  const PlayingCard(this.rank,this.suit);
  String get label => '$rank$suit';
  bool get red => suit == '♥' || suit == '♦';
}

class Deck {
  static const suits = ['♠','♥','♦','♣'];
  static const ranks = ['A','2','3','4','5','6','7','8','9','10','J','Q','K'];
  static List<String> fresh() => [for(final s in suits) for(final r in ranks) '$r$s'];
  static List<String> shuffled() { final d=fresh(); d.shuffle(Random()); return d; }
  static Map<String,dynamic> deal(GameType game,List<String> players) {
    final deck=shuffled(); final hands=<String,List<String>>{for(final p in players) p:[]};
    final count = game==GameType.rummy ? 13 : game==GameType.teenPatti ? 3 : game==GameType.poker ? 2 : 1;
    for(int i=0;i<count;i++) { for(final p in players) { if(deck.isNotEmpty) hands[p]!.add(deck.removeLast()); } }
    final state=<String,dynamic>{'deck':deck,'hands':hands,'community':<String>[],'started':true};
    if(game==GameType.poker) { state['community']=deck.take(5).toList(); deck.removeRange(0, min(5, deck.length)); }
    if(game==GameType.andarBahar) { state['joker']=deck.isNotEmpty?deck.removeLast():''; state['side']='Andar'; }
    return state;
  }
}

class AppState extends ChangeNotifier {
  final FirebaseService fb = FirebaseService.instance;
  int coins=517, points=1280; String player='player'; String email='', phone=''; bool loggedIn=false, admin=false;
  final List<String> activity=['Welcome bonus +517'];
  String? uid;
  Future<void> load() async {
    final p=await SharedPreferences.getInstance(); coins=p.getInt('coins')??517; points=p.getInt('points')??1280;
    player=p.getString('player')??'player'; email=p.getString('email')??''; phone=p.getString('phone')??''; loggedIn=p.getBool('loggedIn')??false;
    if(loggedIn) { try { final u=await fb.ensureSignedIn(); uid=u.uid; await fb.saveUser(name:player,email:email,phone:phone); } catch(_) { loggedIn=false; } }
  }
  Future<String?> login({required String name,String email='',String phone=''}) async {
    try { final u=await fb.ensureSignedIn(); uid=u.uid; player=name.trim().isEmpty?'player':name.trim(); this.email=email.trim(); this.phone=phone.trim(); loggedIn=true;
      final p=await SharedPreferences.getInstance(); await p.setString('player',player); await p.setString('email',this.email); await p.setString('phone',this.phone); await p.setBool('loggedIn',true);
      await fb.saveUser(name:player,email:this.email,phone:this.phone); await fb.setOnline(true); notifyListeners(); return null;
    } on FirebaseAuthException catch(e) { return e.message??e.code; } catch(e) { return e.toString(); }
  }
  Future<void> logout() async { try { await fb.setOnline(false); } catch(_){}; loggedIn=false; final p=await SharedPreferences.getInstance(); await p.setBool('loggedIn',false); notifyListeners(); }
  Future<void> addCoins(int n,String reason) async { coins+=n; activity.insert(0,'$reason +$n'); await _save(); notifyListeners(); }
  Future<void> removeCoins(int n,String reason) async { if(coins<n)return; coins-=n; activity.insert(0,'$reason -$n'); await _save(); notifyListeners(); }
  Future<void> reward(int n) async { coins+=n; points+=n*2; activity.insert(0,'Game reward +$n'); await _save(); notifyListeners(); }
  Future<void> _save() async { final p=await SharedPreferences.getInstance(); await p.setInt('coins',coins); await p.setInt('points',points); }
}

class RoyalCardsApp extends StatelessWidget { final AppState state; const RoyalCardsApp({super.key,required this.state});
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:state,builder:(_,__)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Royal Cards',theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:C.bg,colorScheme:ColorScheme.fromSeed(seedColor:C.red),appBarTheme:const AppBarTheme(backgroundColor:C.red,foregroundColor:Colors.white,elevation:0)),home:state.loggedIn?MainShell(state:state):LoginPage(state:state)));
}

class LoginPage extends StatefulWidget { final AppState state; const LoginPage({super.key,required this.state}); @override State<LoginPage> createState()=>_LoginPageState(); }
class _LoginPageState extends State<LoginPage> { final name=TextEditingController(),email=TextEditingController(),phone=TextEditingController(); bool busy=false;
  @override void dispose(){name.dispose();email.dispose();phone.dispose();super.dispose();}
  Future<void> submit() async { setState(()=>busy=true); final err=await widget.state.login(name:name.text,email:email.text,phone:phone.text); if(mounted&&err!=null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err))); if(mounted)setState(()=>busy=false); }
  @override Widget build(BuildContext context)=>Scaffold(body:Container(decoration:const BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[C.redDark,C.red,Color(0xFFB9121C),C.redDark])),child:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:Column(children:[const Icon(Icons.style_rounded,color:C.gold,size:72),const Text('ROYAL',style:TextStyle(color:Colors.white,fontSize:38,fontWeight:FontWeight.w900,letterSpacing:5)),const Text('CARDS',style:TextStyle(color:C.gold,fontSize:40,fontWeight:FontWeight.w900,letterSpacing:5)),const SizedBox(height:28),Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(26)),child:Column(children:[const Align(alignment:Alignment.centerLeft,child:Text('Create / Login',style:TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.bold))),const SizedBox(height:16),TextField(controller:name,decoration:const InputDecoration(prefixIcon:Icon(Icons.person_outline),hintText:'Player name')),const SizedBox(height:12),TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(prefixIcon:Icon(Icons.email_outlined),hintText:'Email ID (optional)')),const SizedBox(height:12),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(prefixIcon:Icon(Icons.phone_outlined),hintText:'Phone number (optional)')),const SizedBox(height:16),SizedBox(width:double.infinity,height:54,child:ElevatedButton(onPressed:busy?null:submit,style:ElevatedButton.styleFrom(backgroundColor:C.green,foregroundColor:Colors.white),child:Text(busy?'CONNECTING...':'CONTINUE')))])),const SizedBox(height:14),const Text('Firebase online • Virtual coins only • No real-money wagering',textAlign:TextAlign.center,style:TextStyle(color:Colors.white70,fontSize:12))]))))));
}

class MainShell extends StatefulWidget { final AppState state; const MainShell({super.key,required this.state}); @override State<MainShell> createState()=>_MainShellState(); }
class _MainShellState extends State<MainShell>{int index=0;@override Widget build(BuildContext context){final pages=[LobbyPage(state:widget.state),LeaderboardPage(state:widget.state),OnlinePage(state:widget.state),FriendsPage(state:widget.state),MenuPage(state:widget.state)];return Scaffold(body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const[NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Lobby'),NavigationDestination(icon:Icon(Icons.emoji_events_outlined),selectedIcon:Icon(Icons.emoji_events),label:'Rank'),NavigationDestination(icon:Icon(Icons.public_outlined),selectedIcon:Icon(Icons.public),label:'Online'),NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Friends'),NavigationDestination(icon:Icon(Icons.menu),selectedIcon:Icon(Icons.menu_open),label:'Menu')]));}}

class TopBar extends StatelessWidget{final AppState state;const TopBar({super.key,required this.state});@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(18,52,14,16),color:C.red,child:Row(children:[const CircleAvatar(radius:25,backgroundColor:Colors.white,child:Icon(Icons.person,color:C.red,size:30)),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(state.player,style:const TextStyle(color:Colors.white70,fontSize:11)),const Text('Royal Cards',style:TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:17))])),InkWell(onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>WalletPage(state:state))),child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:9),decoration:BoxDecoration(color:C.redDark,borderRadius:BorderRadius.circular(22)),child:Row(children:[const Icon(Icons.monetization_on,color:C.gold,size:21),const SizedBox(width:6),Text('${state.coins}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold))]))) ]));}

class LobbyPage extends StatelessWidget{final AppState state;const LobbyPage({super.key,required this.state});@override Widget build(BuildContext context)=>SingleChildScrollView(child:Column(children:[TopBar(state:state),const SizedBox(height:14),Container(height:118,margin:const EdgeInsets.symmetric(horizontal:18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[C.redDark,Color(0xFFD82131)])),child:const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text('ROYAL ONLINE',style:TextStyle(color:C.gold,fontSize:26,fontWeight:FontWeight.w900)),SizedBox(height:4),Text('Play with friends using virtual coins',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w600))]))),const SizedBox(height:15),Row(children:[Expanded(child:QuickTile(icon:Icons.public,label:'ONLINE',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OnlinePage(state:state))))),Expanded(child:QuickTile(icon:Icons.people,label:'INVITE',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>FriendsPage(state:state))))),Expanded(child:QuickTile(icon:Icons.account_balance_wallet_outlined,label:'WALLET',onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>WalletPage(state:state)))))]),const SizedBox(height:18),const Padding(padding:EdgeInsets.symmetric(horizontal:18),child:Align(alignment:Alignment.centerLeft,child:Text('Choose a game',style:TextStyle(fontSize:22,fontWeight:FontWeight.w900)))),const SizedBox(height:10),...GameType.values.map((g)=>GameModeCard(game:g,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OnlineGamePage(state:state,game:g)))))]));}
class QuickTile extends StatelessWidget{final IconData icon;final String label;final VoidCallback onTap;const QuickTile({super.key,required this.icon,required this.label,required this.onTap});@override Widget build(BuildContext context)=>InkWell(onTap:onTap,child:Container(margin:const EdgeInsets.symmetric(horizontal:5),padding:const EdgeInsets.all(14),child:Column(children:[Icon(icon,color:C.red,size:30),const SizedBox(height:6),Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))])));}
class GameModeCard extends StatelessWidget{final GameType game;final VoidCallback onTap;const GameModeCard({super.key,required this.game,required this.onTap});@override Widget build(BuildContext context)=>Card(margin:const EdgeInsets.symmetric(horizontal:18,vertical:6),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),leading:CircleAvatar(backgroundColor:C.redSoft,child:Icon(game.icon,color:C.red)),title:Text(game.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17)),subtitle:Text(game.subtitle),trailing:FilledButton(onPressed:onTap,child:const Text('PLAY'))));}

class OnlinePage extends StatelessWidget{final AppState state;const OnlinePage({super.key,required this.state});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Online Games')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:state.fb.myRooms(),builder:(context,snap){final docs=snap.data?.docs??[];return ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:C.redSoft,borderRadius:BorderRadius.circular(18)),child:const Text('Firebase real-time rooms are connected. Create a room, invite a friend, then start when players join.',style:TextStyle(fontWeight:FontWeight.w600))),const SizedBox(height:18),const Text('Games',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),...GameType.values.map((g)=>GameModeCard(game:g,onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>OnlineGamePage(state:state,game:g))))),const SizedBox(height:14),const Text('Your rooms',style:TextStyle(fontSize:21,fontWeight:FontWeight.w900)),if(docs.isEmpty)const Card(child:ListTile(title:Text('No online rooms'),subtitle:Text('Create one above.'))),...docs.map((d)=>RoomTile(state:state,data:d.data()))]);}));}
class RoomTile extends StatelessWidget{final AppState state;final Map<String,dynamic> data;const RoomTile({super.key,required this.state,required this.data});@override Widget build(BuildContext context){final game=GameTypeX.from(data['game']??'rummy');final id=data['roomId']??'';final members=List<String>.from(data['memberUids']??[]);return Card(child:ListTile(leading:CircleAvatar(child:Icon(game.icon)),title:Text('${game.title} • $id'),subtitle:Text('${members.length}/${data['seats']??6} players • ${data['status']??'waiting'}'),trailing:FilledButton(onPressed:()async{final err=await state.fb.joinRoom(id);if(context.mounted&&err!=null)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(err)));else if(context.mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>RoomPage(state:state,roomId:id)));},child:const Text('JOIN'))));}}

class OnlineGamePage extends StatefulWidget{final AppState state;final GameType game;const OnlineGamePage({super.key,required this.state,required this.game});@override State<OnlineGamePage> createState()=>_OnlineGamePageState();}
class _OnlineGamePageState extends State<OnlineGamePage>{String? roomId;Future<void> create()async{final id=await widget.state.fb.createRoom(game:widget.game.key,seats:widget.game==GameType.rummy?4:6);if(mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>RoomPage(state:widget.state,roomId:id)));} @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.game.title)),body:ListView(padding:const EdgeInsets.all(18),children:[GameModeCard(game:widget.game,onTap:(){}),const SizedBox(height:10),SizedBox(height:54,child:FilledButton.icon(onPressed:create,icon:const Icon(Icons.add_circle_outline),label:const Text('CREATE ONLINE ROOM'))),const SizedBox(height:12),OutlinedButton.icon(onPressed:()async{final id=await widget.state.fb.createRoom(game:widget.game.key,seats:widget.game==GameType.rummy?4:6);if(mounted)Navigator.push(context,MaterialPageRoute(builder:(_)=>RoomPage(state:widget.state,roomId:id)));},icon:const Icon(Icons.flash_on),label:const Text('QUICK MATCH'))]));}

class RoomPage extends StatelessWidget {
  final AppState state;
  final String roomId;
  const RoomPage({super.key, required this.state, required this.roomId});

  Future<void> invite(BuildContext context, Map<String, dynamic> room) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite a friend'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: state.fb.friends(),
            builder: (context, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) return const Text('Add a friend first.');
              return ListView(
                shrinkWrap: true,
                children: docs.map((d) {
                  final f = d.data();
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(f['name'] ?? 'Player'),
                    subtitle: Text(f['online'] == true ? 'Online' : 'Offline'),
                    trailing: FilledButton(
                      onPressed: () async {
                        await state.fb.invite(toUid: d.id, roomId: roomId, game: room['game'] ?? 'rummy');
                        if (context.mounted) Navigator.pop(context);
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
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: state.fb.room(roomId),
        builder: (context, roomSnap) {
          if (!roomSnap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final room = roomSnap.data!.data();
          if (room == null) return const Scaffold(body: Center(child: Text('Room closed')));
          final game = GameTypeX.from(room['game'] ?? 'rummy');
          return Scaffold(
            appBar: AppBar(title: Text('${game.title} Room')),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: state.fb.roomPlayers(roomId),
              builder: (context, pSnap) {
                final players = pSnap.data?.docs ?? [];
                final isHost = room['ownerId'] == state.uid;
                return ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [C.redDark, C.red]), borderRadius: BorderRadius.circular(20)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(roomId, style: const TextStyle(color: Colors.white70)),
                        Text(game.title, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                        Text('${players.length}/${room['seats'] ?? 6} players • ${room['status'] ?? 'waiting'}', style: const TextStyle(color: Colors.white70)),
                      ]),
                    ),
                    const SizedBox(height: 18),
                    const Text('Players', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ...players.map((d) {
                      final p = d.data();
                      return Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(p['name'] ?? 'Player'), subtitle: Text(d.id == room['ownerId'] ? 'Host' : 'Player'), trailing: const Icon(Icons.check_circle, color: C.green)));
                    }),
                    const SizedBox(height: 14),
                    if (isHost)
                      FilledButton.icon(
                        onPressed: players.isEmpty ? null : () async {
                          final uids = players.map((d) => d.id).toList();
                          final gs = Deck.deal(game, uids);
                          await state.fb.startGame(roomId: roomId, gameState: gs);
                        },
                        icon: const Icon(Icons.style),
                        label: const Text('DEAL CARDS & START'),
                      )
                    else
                      const Text('Waiting for host to deal cards…'),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: roomId));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room code copied')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('COPY ROOM CODE'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: () => invite(context, room), icon: const Icon(Icons.share), label: const Text('INVITE A FRIEND')),
                    if ((room['status'] ?? '') == 'playing')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TablePage(state: state, roomId: roomId))), child: const Text('OPEN GAME TABLE')),
                      ),
                  ],
                );
              },
            ),
          );
        },
      );
}

class TablePage extends StatefulWidget {
  final AppState state;
  final String roomId;
  const TablePage({super.key, required this.state, required this.roomId});
  @override State<TablePage> createState() => _TablePageState();
}

class _TablePageState extends State<TablePage> {
  int selected = -1;

  Future<void> play(DocumentSnapshot<Map<String, dynamic>> snap) async {
    final data = snap.data() ?? {};
    final gs = Map<String, dynamic>.from(data['gameState'] ?? {});
    final hands = Map<String, dynamic>.from(gs['hands'] ?? {});
    final mine = List<String>.from(hands[widget.state.uid] ?? []);
    if (selected < 0 || selected >= mine.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a card first')));
      return;
    }
    mine.removeAt(selected);
    hands[widget.state.uid!] = mine;
    final members = List<String>.from(data['memberUids'] ?? []);
    final ti = (data['turnIndex'] ?? 0) as int;
    final next = members.isEmpty ? 0 : (ti + 1) % members.length;
    await widget.state.fb.updateGameState(
      widget.roomId,
      {
        'deck': List<String>.from(gs['deck'] ?? []),
        'hands': hands,
        'community': List<String>.from(gs['community'] ?? []),
        'joker': gs['joker'] ?? '',
        'side': gs['side'] ?? 'Andar',
        'started': true,
      },
      turnIndex: next,
      turn: ((data['turn'] ?? 0) as int) + 1,
    );
    if (mounted) setState(() => selected = -1);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.state.fb.room(widget.roomId),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final data = snap.data!.data() ?? {};
        final game = GameTypeX.from(data['game'] ?? 'rummy');
        final gs = Map<String, dynamic>.from(data['gameState'] ?? {});
        final hands = Map<String, dynamic>.from(gs['hands'] ?? {});
        final mine = List<String>.from(hands[widget.state.uid] ?? []);
        final community = List<String>.from(gs['community'] ?? []);
        final members = List<String>.from(data['memberUids'] ?? []);
        final turnIndex = (data['turnIndex'] ?? 0) as int;
        final myTurn = members.isEmpty || members[turnIndex % members.length] == widget.state.uid;

        return Scaffold(
          appBar: AppBar(title: Text(game.title)),
          body: Column(
            children: [
              Container(
                color: C.redSoft,
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Room ${widget.roomId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(myTurn ? 'YOUR TURN' : 'PLAYER TURN ${turnIndex + 1}', style: const TextStyle(color: C.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (community.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(spacing: 8, children: community.map((c) => CardView(label: c)).toList()),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  game == GameType.rummy
                      ? '13 cards dealt'
                      : game == GameType.teenPatti
                          ? '3 cards dealt'
                          : game == GameType.poker
                              ? '2 hole cards + community cards'
                              : 'Andar/Bahar cards dealt',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: mine.isEmpty
                    ? const Center(child: Text('No cards for this player yet.'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: List.generate(
                            mine.length,
                            (i) => GestureDetector(
                              onTap: myTurn ? () => setState(() => selected = i) : null,
                              child: CardView(label: mine[i], selected: selected == i),
                            ),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: myTurn && mine.isNotEmpty ? () => play(snap.data!) : null,
                    child: const Text('PLAY / DISCARD CARD'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CardView extends StatelessWidget{final String label;final bool selected;const CardView({super.key,required this.label,this.selected=false});@override Widget build(BuildContext context){final red=label.contains('♥')||label.contains('♦');return AnimatedContainer(duration:const Duration(milliseconds:120),width:64,height:92,alignment:Alignment.center,decoration:BoxDecoration(color:selected?C.redSoft:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:selected?C.red:Colors.black12,width:2),boxShadow:[BoxShadow(color:Colors.black.withOpacity(.08),blurRadius:5)]),child:Text(label,style:TextStyle(fontSize:21,fontWeight:FontWeight.bold,color:red?Colors.red:C.ink)));}}

class FriendsPage extends StatelessWidget {
  final AppState state;
  const FriendsPage({super.key, required this.state});

  Future<void> add(BuildContext context) async {
    final c = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add friend'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Player name / Email / Phone / UID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              try {
                final id = await state.fb.addFriendByQuery(c.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(id == null ? 'Player not found' : 'Friend request sent')));
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('SEND'),
          ),
        ],
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Friends & Invite')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            SizedBox(height: 52, child: FilledButton.icon(onPressed: () => add(context), icon: const Icon(Icons.person_add), label: const Text('ADD FRIEND'))),
            const SizedBox(height: 16),
            const Text('Your friends', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: state.fb.friends(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return Column(
                  children: docs.map((d) {
                    final f = d.data();
                    return Card(child: ListTile(leading: CircleAvatar(child: Text((f['name'] ?? 'P').toString().substring(0, 1))), title: Text(f['name'] ?? 'Player'), subtitle: Text(f['online'] == true ? 'Online' : 'Offline')));
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text('Incoming friend requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: state.fb.incomingFriendRequests(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return Column(
                  children: docs.map((d) {
                    final x = d.data();
                    return Card(child: ListTile(title: Text(x['fromName'] ?? 'Player'), subtitle: const Text('Wants to be your friend'), trailing: FilledButton(onPressed: () => state.fb.acceptFriend(d.id, x), child: const Text('ACCEPT'))));
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text('Game invites', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: state.fb.incomingInvites(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return Column(
                  children: docs.map((d) {
                    final x = d.data();
                    return Card(
                      child: ListTile(
                        title: Text('${x['fromName'] ?? 'Player'} invited you'),
                        subtitle: Text('${x['game'] ?? 'Game'} • Room ${x['roomId'] ?? ''}'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(onPressed: () => state.fb.updateInvite(d.id, 'declined'), child: const Text('DECLINE')),
                            FilledButton(
                              onPressed: () async {
                                final err = await state.fb.joinRoom(x['roomId'] ?? '');
                                await state.fb.updateInvite(d.id, err == null ? 'accepted' : 'declined');
                                if (context.mounted && err == null) Navigator.push(context, MaterialPageRoute(builder: (_) => RoomPage(state: state, roomId: x['roomId'])));
                              },
                              child: const Text('JOIN'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
}

class LeaderboardPage extends StatelessWidget{final AppState state;const LeaderboardPage({super.key,required this.state});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Leaderboard')),body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('leaderboard').orderBy('points',descending:true).limit(50).snapshots(),builder:(context,snap){final docs=snap.data?.docs??[];if(docs.isEmpty)return const Center(child:Text('Leaderboard will appear after players earn points.'));return ListView.builder(padding:const EdgeInsets.all(18),itemCount:docs.length,itemBuilder:(_,i){final d=docs[i].data();return Card(child:ListTile(leading:CircleAvatar(child:Text('${i+1}')),title:Text(d['playerName']??'Player'),trailing:Text('${d['points']??0} pts',style:const TextStyle(fontWeight:FontWeight.bold,color:C.red))));});}));}

class WalletPage extends StatelessWidget{final AppState state;const WalletPage({super.key,required this.state});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Virtual Wallet')),body:ListView(padding:const EdgeInsets.all(18),children:[Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(gradient:const LinearGradient(colors:[C.redDark,C.red]),borderRadius:BorderRadius.circular(22)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Virtual balance',style:TextStyle(color:Colors.white70)),Text('${state.coins} coins',style:const TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900))])),const SizedBox(height:18),Row(children:[Expanded(child:FilledButton.icon(onPressed:()=>state.addCoins(100,'Demo add'),icon:const Icon(Icons.add),label:const Text('ADD 100'))),const SizedBox(width:10),Expanded(child:OutlinedButton.icon(onPressed:()=>state.removeCoins(50,'Demo use'),icon:const Icon(Icons.remove),label:const Text('USE 50')))]),const SizedBox(height:20),const Text('Activity',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold)),...state.activity.take(12).map((x)=>ListTile(leading:const Icon(Icons.history),title:Text(x))) ]));}

class MenuPage extends StatelessWidget{final AppState state;const MenuPage({super.key,required this.state});@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Menu')),body:ListView(padding:const EdgeInsets.all(18),children:[ListTile(leading:const Icon(Icons.person),title:Text(state.player),subtitle:Text(state.uid??'')),ListTile(leading:const Icon(Icons.logout),title:const Text('Logout'),onTap:()=>state.logout())]));}
