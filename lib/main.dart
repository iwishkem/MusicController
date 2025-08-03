import 'package:flutter/material.dart';
import 'package:media_notification_listener/media_notification_listener.dart';

void main() => runApp(KemPlayerApp());

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
  MediaNotification? _notification;

  @override
  void initState() {
    super.initState();
    MediaNotificationListener().stream.listen((notification) {
      setState(() {
        _notification = notification;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final artwork = _notification?.artUri != null
        ? NetworkImage(_notification!.artUri!)
        : AssetImage('assets/placeholder.png') as ImageProvider;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 100,
              backgroundImage: artwork,
              backgroundColor: Colors.grey[800],
            ),
            SizedBox(height: 20),
            Text(
              _notification?.title ?? 'Şarkı Adı',
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              _notification?.artist ?? 'Sanatçı',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.skip_previous),
                  onPressed: () => MediaNotificationListener().prev(),
                ),
                IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: () => MediaNotificationListener().play(),
                ),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: () => MediaNotificationListener().next(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
