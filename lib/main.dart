import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';

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
  String albumArt = '';
  String displayIconUri = '';
  String debugInfo = 'Waiting for media info...';

  @override
  void initState() {
    super.initState();
    platform.setMethodCallHandler(_platformCallHandler);
    _updateMediaInfo();
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      print("Received media info: $info"); // Debug logging
      setState(() {
        title = info['title'] ?? 'Şarkı Adı';
        artist = info['artist'] ?? 'Sanatçı';
        albumArtUri = info['albumArtUri'] ?? '';
        albumArt = info['albumArt'] ?? '';
        displayIconUri = info['displayIconUri'] ?? '';
        
        // Create debug info for display
        debugInfo = 'B64: ${albumArt.isNotEmpty ? "✓" : "✗"} | '
                   'URI: ${albumArtUri.isNotEmpty ? "✓" : "✗"} | '
                   'Icon: ${displayIconUri.isNotEmpty ? "✓" : "✗"}';
        
        // Debug logging
        print("Album art (base64): ${albumArt.isNotEmpty ? 'Available' : 'Empty'}");
        print("Album art URI: $albumArtUri");
        print("Display icon URI: $displayIconUri");
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
        final info = call.arguments;
        print("Platform callback received: $info"); // Debug logging
        setState(() {
          title = info['title'] ?? 'Şarkı Adı';
          artist = info['artist'] ?? 'Sanatçı';
          albumArtUri = info['albumArtUri'] ?? '';
          albumArt = info['albumArt'] ?? '';
          displayIconUri = info['displayIconUri'] ?? '';
          
          // Update debug info
          debugInfo = 'B64: ${albumArt.isNotEmpty ? "✓" : "✗"} | '
                     'URI: ${albumArtUri.isNotEmpty ? "✓" : "✗"} | '
                     'Icon: ${displayIconUri.isNotEmpty ? "✓" : "✗"}';
        });
        break;
      default:
        print('Unknown method ${call.method}');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget albumArtWidget;
    
    print("Building UI - albumArt length: ${albumArt.length}"); // Add this debug line
    
    if (albumArt.isNotEmpty) {
      // Use base64 encoded album art from Android
      try {
        // Clean the base64 string (remove any whitespace/newlines)
        String cleanBase64 = albumArt.replaceAll(RegExp(r'\s+'), '');
        print("Original base64 length: ${albumArt.length}");
        print("Cleaned base64 length: ${cleanBase64.length}");
        print("First 100 chars: ${cleanBase64.length > 100 ? cleanBase64.substring(0, 100) : cleanBase64}");
        
        Uint8List bytes = base64Decode(cleanBase64);
        print("Decoded bytes length: ${bytes.length}");
        
        albumArtWidget = Image.memory(
          bytes, 
          width: 200, 
          height: 200, 
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print("Image.memory error: $error");
            print("Stack trace: $stackTrace");
            return Container(
              width: 200,
              height: 200,
              color: Colors.red,
              child: Center(child: Text("Image Error", style: TextStyle(color: Colors.white))),
            );
          },
        );
        print("Successfully created Image.memory widget");
      } catch (e) {
        print("Base64 decode error: $e");
        print("Error type: ${e.runtimeType}");
        print("Base64 string length: ${albumArt.length}");
        print("First 100 chars: ${albumArt.length > 100 ? albumArt.substring(0, 100) : albumArt}");
        albumArtWidget = Container(
          width: 200,
          height: 200,
          color: Colors.yellow,
          child: Center(child: Text("Decode Error", style: TextStyle(color: Colors.black))),
        );
      }
    } else if (displayIconUri.isNotEmpty) {
      // Try display icon URI
      print("Using display icon URI: $displayIconUri");
      albumArtWidget = Image.network(
        displayIconUri, 
        width: 200, 
        height: 200, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Failed to load display icon: $error");
          return Image.asset('assets/placeholder.png', width: 200, height: 200);
        },
      );
    } else if (albumArtUri.isNotEmpty) {
      // Fallback to URI if available
      print("Using album art URI: $albumArtUri");
      albumArtWidget = Image.network(
        albumArtUri, 
        width: 200, 
        height: 200, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print("Failed to load album art URI: $error");
          return Image.asset('assets/placeholder.png', width: 200, height: 200);
        },
      );
    } else {
      // Default placeholder
      print("Using placeholder image - no art data available");
      albumArtWidget = Container(
        width: 200,
        height: 200,
        color: Colors.grey,
        child: Center(child: Text("No Art", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: albumArtWidget,
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
            SizedBox(height: 10),
            Text(
              debugInfo,
              style: TextStyle(fontSize: 12, color: Colors.orange),
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
