import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:palette_generator/palette_generator.dart';

void main() {
  runApp(KemPlayerApp());
}

class KemPlayerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KemPlayer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
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

  // Media Info
  String title = 'Waiting for music...';
  String artist = 'KemPlayer';
  String albumArtUri = '';
  String albumArt = '';
  String displayIconUri = '';
  String packageName = '';
  bool isPlaying = false;

  // Progress & Timing
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  int lastUpdateTime = 0;
  double playbackSpeed = 1.0;
  Timer? _progressTimer;
  bool _isDraggingSlider = false;

  // Colors & UI
  Color accentColor = Color(0xFF1DB954); // Default Green
  Color? imageMutedColor;
  bool _isDialogShowing = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    
    platform.setMethodCallHandler(_platformCallHandler);
    WidgetsBinding.instance.addObserver(this);
    
    _updateMediaInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration(milliseconds: 500), _updateMediaInfo);
    }
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    if (isPlaying) {
      _progressTimer = Timer.periodic(Duration(milliseconds: 1000), (_) {
        if (!_isDraggingSlider && mounted) setState(() {});
      });
    }
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      if (!mounted) return;

      // Check if art changed to update palette
      String newAlbumArt = info['albumArt'] ?? '';
      String newUri = info['albumArtUri'] ?? '';
      bool artChanged = (newAlbumArt != albumArt) || (newUri != albumArtUri);

      setState(() {
        title = info['title'] ?? 'Waiting for music...';
        artist = info['artist'] ?? 'KemPlayer';
        albumArtUri = newUri;
        albumArt = newAlbumArt;
        displayIconUri = info['displayIconUri'] ?? '';
        isPlaying = info['isPlaying'] ?? false;
        packageName = info['packageName'] ?? '';
        
        duration = Duration(milliseconds: (info['duration'] ?? 0).toInt());
        position = Duration(milliseconds: (info['position'] ?? 0).toInt());
        lastUpdateTime = (info['lastUpdateTime'] ?? 0).toInt();
        playbackSpeed = (info['playbackSpeed'] ?? 1.0).toDouble();
      });

      if (artChanged) _updatePalette();
      _startProgressTimer();
      
    } on PlatformException catch (e) {
      print("Failed: '${e.message}'.");
    }
  }

  Future<void> _updatePalette() async {
    ImageProvider? provider = _getImageProvider();
    if (provider == null) {
      setState(() => accentColor = Color(0xFF1DB954));
      return;
    }

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        maximumColorCount: 20,
      );
      if (mounted) {
        setState(() {
          // Try to get a vibrant color, fallback to light vibrant, then default
          accentColor = palette.vibrantColor?.color ?? 
                        palette.lightVibrantColor?.color ?? 
                        palette.dominantColor?.color ?? 
                        Color(0xFF1DB954);
          
          // Get a muted color for background tint if needed
          imageMutedColor = palette.mutedColor?.color;
        });
      }
    } catch (e) {
      print("Error generating palette: $e");
    }
  }

  Future<void> _sendMediaControl(String command) async {
    await platform.invokeMethod('mediaControl', {'command': command});
    // Optimistic update for UI responsiveness
    if (command == 'play_pause') {
      setState(() {
        isPlaying = !isPlaying;
        lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
      });
      _startProgressTimer();
    }
  }

  Future<dynamic> _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'mediaInfoUpdated':
        _updateMediaInfo(); // Refresh all data
        break;
      case 'requestPermission':
        if (!_isDialogShowing && mounted) {
          _isDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Color(0xFF1A1A1A),
              title: Text("Permission Required", style: TextStyle(color: Colors.white)),
              content: Text(
                "KemPlayer needs 'Notification Access' to see music info.",
                style: TextStyle(color: Colors.white70)
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _isDialogShowing = false;
                    Navigator.of(ctx).pop();
                    platform.invokeMethod('openSettings'); 
                  },
                  child: Text("Open Settings", style: TextStyle(color: accentColor)),
                )
              ],
            ),
          );
        }
        break;
    }
  }

  ImageProvider? _getImageProvider() {
    if (albumArt.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(albumArt.replaceAll(RegExp(r'\s+'), '')));
      } catch (e) { return null; }
    } else if (displayIconUri.isNotEmpty) {
      return NetworkImage(displayIconUri);
    } else if (albumArtUri.isNotEmpty) {
      return NetworkImage(albumArtUri);
    }
    return null;
  }

  // --- UI WIDGETS ---

  Widget _buildBlurredBackground() {
    final imageProvider = _getImageProvider();
    return Stack(
      children: [
        Container(color: Color(0xFF0A0A0A)),
        if (imageProvider != null)
          Positioned.fill(
            child: Image(
              image: imageProvider,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
            child: Container(
              // Tint the dark background slightly with the image's muted color
              color: Colors.black.withOpacity(0.6), 
            ),
          ),
        ),
        // Add a gradient fade for better text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    // Calculate current position
    int currentMs = position.inMilliseconds;
    if (isPlaying && lastUpdateTime > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = now - lastUpdateTime;
      currentMs += (diff * playbackSpeed).toInt();
    }
    
    // Clamp values
    final durationMs = duration.inMilliseconds;
    if (currentMs > durationMs) currentMs = durationMs;
    if (currentMs < 0) currentMs = 0;

    double value = currentMs.toDouble();
    double max = durationMs > 0 ? durationMs.toDouble() : 1.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: accentColor, // Dynamic Color
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: accentColor.withOpacity(0.2),
          ),
          child: Slider(
            value: value.clamp(0.0, max),
            min: 0.0,
            max: max,
            onChangeStart: (_) => _isDraggingSlider = true,
            onChangeEnd: (newValue) {
              _isDraggingSlider = false;
              platform.invokeMethod('seekTo', {'position': newValue.toInt()});
              setState(() {
                position = Duration(milliseconds: newValue.toInt());
                lastUpdateTime = DateTime.now().millisecondsSinceEpoch;
              });
            },
            onChanged: (newValue) {
              setState(() {}); // Visual update only
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(Duration(milliseconds: currentMs)), 
                   style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_formatDuration(duration), 
                   style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    }
    return "${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
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
        width: isPrimary ? 75 : 55,
        height: isPrimary ? 75 : 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPrimary ? accentColor : Colors.transparent, // Dynamic Color
          boxShadow: isPrimary ? [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 20,
              offset: Offset(0, 8),
            )
          ] : null,
        ),
        child: Icon(
          icon,
          size: size,
          color: isPrimary ? Colors.black : Colors.white,
        ),
      ),
    );
  }

  Widget _buildAlbumArt({double? width, double? height}) {
    final imageProvider = _getImageProvider();
    
    return GestureDetector(
      onTap: () => platform.invokeMethod('openApp', {'packageName': packageName}),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: Offset(0, 15),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: imageProvider != null 
            ? Image(image: imageProvider, fit: BoxFit.cover)
            : Container(
                color: Color(0xFF2A2A2A),
                child: Icon(Icons.music_note_rounded, size: 80, color: Colors.white12),
              ),
        ),
      ),
    );
  }

  // --- LAYOUTS ---

  Widget _buildPortraitLayout() {
    return Stack(
      children: [
        _buildBlurredBackground(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Spacer(flex: 3),
                Hero(
                  tag: 'albumArt',
                  child: _buildAlbumArt(width: 300, height: 300),
                ),
                Spacer(flex: 2),
                
                // Song Info
                GestureDetector(
                  onTap: () => platform.invokeMethod('openApp', {'packageName': packageName}),
                  child: Column(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                        ),
                        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Text(
                        artist,
                        style: TextStyle(
                          fontSize: 18, color: Colors.white70, fontWeight: FontWeight.w500,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                        ),
                        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                Spacer(flex: 2),
                _buildProgressBar(), // New Progress Bar
                SizedBox(height: 20),
                
                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildControlButton(
                      icon: Icons.skip_previous_rounded,
                      onTap: () => _sendMediaControl('previous'),
                      size: 32,
                    ),
                    SizedBox(width: 25),
                    _buildControlButton(
                      icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      onTap: () => _sendMediaControl('play_pause'),
                      size: 40,
                      isPrimary: true,
                    ),
                    SizedBox(width: 25),
                    _buildControlButton(
                      icon: Icons.skip_next_rounded,
                      onTap: () => _sendMediaControl('next'),
                      size: 32,
                    ),
                  ],
                ),
                Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Simple Landscape Layout
  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        _buildBlurredBackground(),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Row(
              children: [
                Center(child: _buildAlbumArt(width: 240, height: 240)),
                SizedBox(width: 40),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                      SizedBox(height: 8),
                      Text(artist, style: TextStyle(fontSize: 20, color: Colors.white70)),
                      Spacer(),
                      _buildProgressBar(),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(icon: Icons.skip_previous_rounded, onTap: () => _sendMediaControl('previous'), size: 32),
                          SizedBox(width: 20),
                          _buildControlButton(icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, onTap: () => _sendMediaControl('play_pause'), size: 40, isPrimary: true),
                          SizedBox(width: 20),
                          _buildControlButton(icon: Icons.skip_next_rounded, onTap: () => _sendMediaControl('next'), size: 32),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: OrientationBuilder(
        builder: (context, orientation) {
          return orientation == Orientation.landscape 
              ? _buildLandscapeLayout() 
              : _buildPortraitLayout();
        },
      ),
    );
  }
}
