import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(KemPlayerApp());
}

class KemPlayerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KemPlayer',
      theme: ThemeData.dark(),
      home: MusicControlScreen(),
    );
  }
}

class MusicControlScreen extends StatefulWidget {
  @override
  _MusicControlScreenState createState() => _MusicControlScreenState();
}

class _MusicControlScreenState extends State<MusicControlScreen> {
  static const platform = MethodChannel('kemplayer/media');

  String title = 'Şarkı Adı';
  String artist = 'Sanatçı';
  String albumArtUri = '';

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_platformCallHandler);
    _updateMediaInfo();
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      setState(() {
        title = info['title'] ?? 'Şarkı Adı';
        artist = info['artist'] ?? 'Sanatçı';
        albumArtUri = info['albumArtUri'] ?? '';
      });
    } on PlatformException catch (e) {
      print("Failed to get media info: '${e.message}'.");
    }
  }

  Future<void> _sendMediaControl(String command) async {
    try {
      await platform.invokeMethod('mediaControl', {'command': command});
    } on PlatformException catch (e) {
      print("Failed to send media control: '${e.message}'.");
    }
  }

  Future<dynamic> _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'mediaInfoUpdated':
        _updateMediaInfo();
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final albumArt = albumArtUri.isNotEmpty
        ? Image.network(albumArtUri, width: 200, height: 200, fit: BoxFit.cover)
        : Image.asset('assets/placeholder.png', width: 200, height: 200);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: albumArt,
            ),
            SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              artist,
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                    icon: Icon(Icons.skip_previous),
                    iconSize: 40,
                    onPressed: () => _sendMediaControl('previous')),
                IconButton(
                    icon: Icon(Icons.play_arrow),
                    iconSize: 50,
                    onPressed: () => _sendMediaControl('play_pause')),
                IconButton(
                    icon: Icon(Icons.skip_next),
                    iconSize: 40,
                    onPressed: () => _sendMediaControl('next')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
