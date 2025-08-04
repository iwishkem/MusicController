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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
        primaryColor: Color(0xFF1DB954),
      ),
      home: MusicControlScreen(),
    );
  }
}

class MusicControlScreen extends StatefulWidget {
  @override
  _MusicControlScreenState createState() => _MusicControlScreenState();
}

class _MusicControlScreenState extends State<MusicControlScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('kemplayer/media');

  String title = 'Şarkı Adı';
  String artist = 'Sanatçı';
  String albumArtUri = '';
  String albumArt = '';
  String displayIconUri = '';
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    platform.setMethodCallHandler(_platformCallHandler);
    
    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);
    
    _updateMediaInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Refresh media info when app becomes active
    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration(milliseconds: 500), () {
        _updateMediaInfo();
      });
    }
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      setState(() {
        title = info['title'] ?? 'Şarkı Adı';
        artist = info['artist'] ?? 'Sanatçı';
        albumArtUri = info['albumArtUri'] ?? '';
        albumArt = info['albumArt'] ?? '';
        displayIconUri = info['displayIconUri'] ?? '';
        isPlaying = info['isPlaying'] ?? false;
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
        setState(() {
          title = info['title'] ?? 'Şarkı Adı';
          artist = info['artist'] ?? 'Sanatçı';
          albumArtUri = info['albumArtUri'] ?? '';
          albumArt = info['albumArt'] ?? '';
          displayIconUri = info['displayIconUri'] ?? '';
          isPlaying = info['isPlaying'] ?? false;
        });
        break;
    }
  }

  Widget _buildAlbumArt({double? width, double? height}) {
    Widget albumArtWidget;
    
    if (albumArt.isNotEmpty) {
      try {
        String cleanBase64 = albumArt.replaceAll(RegExp(r'\s+'), '');
        Uint8List bytes = base64Decode(cleanBase64);
        albumArtWidget = Image.memory(
          bytes, 
          width: width ?? 200, 
          height: height ?? 200, 
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(width: width ?? 200, height: height ?? 200);
          },
        );
      } catch (e) {
        albumArtWidget = _buildPlaceholder(width: width ?? 200, height: height ?? 200);
      }
    } else if (displayIconUri.isNotEmpty) {
      albumArtWidget = Image.network(
        displayIconUri, 
        width: width ?? 200, 
        height: height ?? 200, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(width: width ?? 200, height: height ?? 200);
        },
      );
    } else if (albumArtUri.isNotEmpty) {
      albumArtWidget = Image.network(
        albumArtUri, 
        width: width ?? 200, 
        height: height ?? 200, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(width: width ?? 200, height: height ?? 200);
        },
      );
    } else {
      albumArtWidget = _buildPlaceholder(width: width ?? 200, height: height ?? 200);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: albumArtWidget,
      ),
    );
  }

  Widget _buildPlaceholder({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A2A2A),
            Color(0xFF1A1A1A),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.music_note,
        size: width * 0.3,
        color: Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: isPrimary ? 70 : 60,
        height: isPrimary ? 70 : 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isPrimary 
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1DB954), Color(0xFF1ED760)],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
              ),
          boxShadow: [
            BoxShadow(
              color: isPrimary 
                ? Color(0xFF1DB954).withOpacity(0.4)
                : Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: size,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildControlButtons({double iconSize = 24, double playIconSize = 32}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: Icons.skip_previous_rounded,
          onTap: () => _sendMediaControl('previous'),
          size: iconSize,
        ),
        SizedBox(width: 30),
        _buildControlButton(
          icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onTap: () => _sendMediaControl('play_pause'),
          size: playIconSize,
          isPrimary: true,
        ),
        SizedBox(width: 30),
        _buildControlButton(
          icon: Icons.skip_next_rounded,
          onTap: () => _sendMediaControl('next'),
          size: iconSize,
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF1A1A1A),
            Color(0xFF0A0A0A),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: 1),
              
              // Album Art
              _buildAlbumArt(width: 280, height: 280),
              
              Spacer(flex: 1),
              
              // Song Info Card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color(0xFF1A1A1A).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(0xFF2A2A2A),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Text(
                      artist,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF9E9E9E),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 40),
              
              // Control Buttons
              _buildControlButtons(iconSize: 28, playIconSize: 36),
              
              Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF1A1A1A),
            Color(0xFF0A0A0A),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              // Left side - Album Art
              Expanded(
                flex: 2,
                child: Center(
                  child: _buildAlbumArt(width: 240, height: 240),
                ),
              ),
              
              SizedBox(width: 40),
              
              // Right side - Info and Controls
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Song Info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Color(0xFF1A1A1A).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF2A2A2A),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          Text(
                            artist,
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 32),
                    
                    // Control Buttons
                    _buildControlButtons(iconSize: 32, playIconSize: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          if (orientation == Orientation.landscape) {
            return _buildLandscapeLayout();
          } else {
            return _buildPortraitLayout();
          }
        },
      ),
    );
  }
}
