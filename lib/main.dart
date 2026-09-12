import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/tank_game.dart';
import 'network/network_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MainMenu()));
}

class MainMenu extends StatefulWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final NetworkService _networkService = NetworkService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  
  bool _inLobby = false;
  String _hostIp = '';
  List<Map<String, dynamic>> _players = [];

  @override
  void initState() {
    super.initState();
    _bindLobbyListeners();
  }

  void _bindLobbyListeners() {
    _networkService.onLobbyUpdated = (players) {
      if (!mounted) return;
      setState(() {
        _players = players;
      });
    };

    _networkService.onGameStarted = () {
      if (!mounted) return;
      _launchGame();
    };
  }

  Future<void> _launchGame() async {
    // Oyuna geçerken dinleyicileri iptal ediyoruz ki arka planda setState hatası fırlatmasın
    _networkService.onLobbyUpdated = null;
    _networkService.onGameStarted = null;
    
    // pushReplacement yerine push kullanarak oyun bittiğinde bu ekrana geri dönülmesini sağlıyoruz
    final exitCompletely = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: GameWidget(
            game: TankGame(
              networkService: _networkService,
              onContinue: () => Navigator.pop(context, false), // Lobiye dön
              onLeave: () => Navigator.pop(context, true),     // Tamamen çık
            ),
          ),
        ),
      ),
    );

    if (exitCompletely == true) {
      _networkService.disconnect();
      if (mounted) {
        setState(() {
          _inLobby = false;
          _players.clear();
        });
      }
    } else {
      // Devam et denilmişse, dinleyicileri tekrar bağla ve lobiyi yenile
      _bindLobbyListeners();
      if (mounted) setState(() {});
    }
  }

  Future<void> _hostRoom() async {
    if (_nameController.text.trim().isEmpty) return;
    String ip = await _networkService.startHosting(_nameController.text.trim());
    if (!mounted) return;
    setState(() {
      _hostIp = ip;
      _inLobby = true;
      _players = _networkService.lobbyPlayers;
    });
  }

  Future<void> _joinRoom() async {
    if (_nameController.text.trim().isEmpty || _ipController.text.trim().isEmpty) return;
    await _networkService.joinRoom(_ipController.text.trim(), _nameController.text.trim());
    if (!mounted) return;
    setState(() => _inLobby = true);
  }

  @override
  void dispose() {
    _networkService.disconnect();
    _nameController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade900,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: !_inLobby ? _buildJoinScreen() : _buildLobbyScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("BATTLE TANKS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Adın", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _hostRoom,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: const Text("Oda Kur (Host)"),
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text("- VEYA -")),
        TextField(controller: _ipController, decoration: const InputDecoration(labelText: "Kurucunun IP Adresi", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        ElevatedButton(
          onPressed: _joinRoom,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green),
          child: const Text("Odaya Katıl"),
        ),
      ],
    );
  }

  Widget _buildLobbyScreen() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("BEKLEME LOBİSİ", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
        
        if (_networkService.isHost) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Oda IP: $_hostIp", style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              DropdownButton<int>(
                value: _networkService.selectedMap,
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Klasik Harita")),
                  DropdownMenuItem(value: 1, child: Text("Çöl Haritası")),
                ],
                onChanged: (val) {
                  _networkService.updateLobbySettings(val ?? 0, _networkService.selectedTime);
                  setState((){});
                }
              ),
              DropdownButton<int>(
                value: _networkService.selectedTime,
                items: const [
                  DropdownMenuItem(value: 60, child: Text("1 Dakika")),
                  DropdownMenuItem(value: 120, child: Text("2 Dakika")),
                  DropdownMenuItem(value: 300, child: Text("5 Dakika")),
                ],
                onChanged: (val) {
                  _networkService.updateLobbySettings(_networkService.selectedMap, val ?? 60);
                  setState((){});
                }
              ),
            ],
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Kurucu IP: ${_networkService.hostIp}\n"
              "Harita: ${_networkService.selectedMap == 1 ? 'Çöl' : 'Klasik'} | "
              "Süre: ${_networkService.selectedTime ~/ 60} Dk", 
              textAlign: TextAlign.center, 
              style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        ],

        const Divider(),
        SizedBox(
          height: 150,
          child: ListView.builder(
            itemCount: _players.length,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(_players[index]['name']),
              trailing: Text("${_players[index]['score']} Puan", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        
        if (_networkService.isHost)
          ElevatedButton(
            onPressed: () => _networkService.startGame(),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.redAccent),
            child: const Text("OYUNU BAŞLAT", style: TextStyle(color: Colors.white, fontSize: 18)),
          )
        else
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Kurucunun oyunu başlatması bekleniyor...", style: TextStyle(fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}