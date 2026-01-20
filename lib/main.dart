import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
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

// --- WIDGET 1: Optimize Edilmiş Arka Plan (Siyah Ekran Sorununu Çözer) ---
class BlurredBackground extends StatelessWidget {
  final ImageProvider? imageProvider;
  final Color mutedColor;

  const BlurredBackground({
    Key? key, 
    required this.imageProvider,
    required this.mutedColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Container(color: Color(0xFF0A0A0A)), // Siyah taban katmanı
          if (imageProvider != null)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 600),
                child: Image(
                  key: ValueKey(imageProvider.hashCode), // Sadece resim değişirse güncelle
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // <--- SİYAH EKRAN TİTREMESİNİ ÖNLER
                  errorBuilder: (_, __, ___) => Container(color: Color(0xFF0A0A0A)),
                ),
              ),
            ),
          // Bulanıklık Katmanı
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Colors.black.withOpacity(0.5), 
              ),
            ),
          ),
          // Okunabilirlik için Gradyan
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.black87],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 2: Ana Ekran ---
class MusicControlScreen extends StatefulWidget {
  @override
  _MusicControlScreenState createState() => _MusicControlScreenState();
}

class _MusicControlScreenState extends State<MusicControlScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('kemplayer/media');

  // Şarkı Verileri
  String title = 'Müzik bekleniyor...';
  String artist = 'KemPlayer';
  String albumArtString = '';
  String albumArtUri = '';
  String displayIconUri = '';
  String packageName = '';
  
  // Oynatma Verileri
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double playbackSpeed = 1.0;
  DateTime lastSyncTime = DateTime.now();

  // Görseller & Önbellek
  Color accentColor = Color(0xFF1DB954);
  Color mutedColor = Colors.black;
  bool _isDialogShowing = false;
  
  // Resim Önbelleği (Gereksiz yeniden oluşturmayı önler)
  ImageProvider? _cachedImageProvider;
  String _lastAlbumArtString = '';

  @override
  void initState() {
    super.initState();
    // DÜZELTME: Tam ekran modu için 'immersiveSticky' kullanıyoruz.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    platform.setMethodCallHandler(_platformCallHandler);
    WidgetsBinding.instance.addObserver(this);
    _updateMediaInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Çıkışta normal moda dön
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Uygulamaya dönüldüğünde tam ekranı tekrar zorla
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      Future.delayed(Duration(milliseconds: 500), _updateMediaInfo);
    }
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      if (!mounted) return;

      String newArt = info['albumArt'] ?? '';
      String newUri = info['albumArtUri'] ?? '';
      
      // Sadece resim gerçekten değiştiyse paleti güncelle
      bool artChanged = (newArt != albumArtString) || (newUri != albumArtUri);

      setState(() {
        title = info['title'] ?? 'Müzik bekleniyor...';
        artist = info['artist'] ?? 'KemPlayer';
        albumArtString = newArt;
        albumArtUri = newUri;
        displayIconUri = info['displayIconUri'] ?? '';
        packageName = info['packageName'] ?? '';
        
        duration = Duration(milliseconds: (info['duration'] ?? 0).toInt());
        position = Duration(milliseconds: (info['position'] ?? 0).toInt());
        isPlaying = info['isPlaying'] ?? false;
        playbackSpeed = (info['playbackSpeed'] ?? 1.0).toDouble();
        
        lastSyncTime = DateTime.now();
      });

      if (artChanged) {
        _updateImageCache(); // Resmi önbelleğe al
        _updatePalette();    // Renkleri güncelle
      }
      
    } on PlatformException catch (e) {
      print("Hata: '${e.message}'.");
    }
  }

  // Önbellek Mantığı: Her karede MemoryImage oluşturmayı engeller
  void _updateImageCache() {
    if (albumArtString.isNotEmpty) {
      try {
        _cachedImageProvider = MemoryImage(base64Decode(albumArtString.replaceAll(RegExp(r'\s+'), '')));
      } catch (e) { _cachedImageProvider = null; }
    } else if (displayIconUri.isNotEmpty) {
      _cachedImageProvider = NetworkImage(displayIconUri);
    } else if (albumArtUri.isNotEmpty) {
      _cachedImageProvider = NetworkImage(albumArtUri);
    } else {
      _cachedImageProvider = null;
    }
  }

  Future<void> _updatePalette() async {
    if (_cachedImageProvider == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(_cachedImageProvider!);
      if (mounted) {
        setState(() {
          accentColor = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? Color(0xFF1DB954);
          mutedColor = palette.mutedColor?.color ?? Colors.black;
        });
      }
    } catch (e) {
      print("Palet Hatası: $e");
    }
  }

  Future<void> _sendMediaControl(String command) async {
    await platform.invokeMethod('mediaControl', {'command': command});
  }

  Future<void> _seekTo(int ms) async {
    // Android'e atlama komutu gönder
    await platform.invokeMethod('seekTo', {'position': ms});
    // Arayüzü anında güncelle
    setState(() {
      position = Duration(milliseconds: ms);
      lastSyncTime = DateTime.now();
    });
  }

  Future<dynamic> _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'mediaInfoUpdated':
        _updateMediaInfo();
        break;
      case 'requestPermission':
        if (!_isDialogShowing && mounted) {
          _isDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              backgroundColor: Color(0xFF1A1A1A),
              title: Text("İzin Gerekli", style: TextStyle(color: Colors.white)),
              content: Text("KemPlayer'ın müziği görebilmesi için 'Bildirim Erişimi' iznine ihtiyacı var.", style: TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                  onPressed: () {
                    _isDialogShowing = false;
                    Navigator.of(ctx).pop();
                    platform.invokeMethod('openSettings'); 
                  },
                  child: Text("Ayarları Aç", style: TextStyle(color: accentColor)),
                )
              ],
            ),
          );
        }
        break;
    }
  }

  // --- ARAYÜZ ---
  
  Widget _buildControlButtons({double size = 32, double playSize = 48}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: size),
          onPressed: () => _sendMediaControl('previous'),
        ),
        SizedBox(width: 20),
        Container(
          width: playSize + 16,
          height: playSize + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 20)],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: playSize),
            onPressed: () => _sendMediaControl('play_pause'),
          ),
        ),
        SizedBox(width: 20),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: size),
          onPressed: () => _sendMediaControl('next'),
        ),
      ],
    );
  }

  Widget _buildAlbumArt({double size = 300}) {
    return GestureDetector(
      onTap: () => platform.invokeMethod('openApp', {'packageName': packageName}),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, 15))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _cachedImageProvider != null 
            ? Image(image: _cachedImageProvider!, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(color: Color(0xFF222222), child: Icon(Icons.music_note, size: 80, color: Colors.white12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Statik Arka Plan (Önbellekli & Optimize)
          BlurredBackground(imageProvider: _cachedImageProvider, mutedColor: mutedColor),
          
          // 2. Aktif İçerik
          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return Padding(
                    padding: EdgeInsets.all(30),
                    child: Row(
                      children: [
                        Center(child: _buildAlbumArt(size: 240)),
                        SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                              Text(artist, style: TextStyle(fontSize: 20, color: Colors.white70), maxLines: 1),
                              Spacer(),
                              LiveProgressBar(
                                duration: duration,
                                position: position,
                                isPlaying: isPlaying,
                                playbackSpeed: playbackSpeed,
                                lastSyncTime: lastSyncTime,
                                accentColor: accentColor,
                                onSeek: _seekTo,
                              ),
                              SizedBox(height: 20),
                              _buildControlButtons(),
                              Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Spacer(flex: 3),
                        Hero(tag: 'art', child: _buildAlbumArt(size: 300)),
                        Spacer(flex: 2),
                        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                        SizedBox(height: 8),
                        Text(artist, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70), maxLines: 1),
                        Spacer(flex: 2),
                        LiveProgressBar(
                          duration: duration,
                          position: position,
                          isPlaying: isPlaying,
                          playbackSpeed: playbackSpeed,
                          lastSyncTime: lastSyncTime,
                          accentColor: accentColor,
                          onSeek: _seekTo,
                        ),
                        SizedBox(height: 20),
                        _buildControlButtons(),
                        Spacer(flex: 3),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 3: İzole Edilmiş İlerleme Çubuğu ---
class LiveProgressBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final double playbackSpeed;
  final DateTime lastSyncTime;
  final Color accentColor;
  final Function(int) onSeek;

  const LiveProgressBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.lastSyncTime,
    required this.accentColor,
    required this.onSeek,
  }) : super(key: key);

  @override
  _LiveProgressBarState createState() => _LiveProgressBarState();
}

class _LiveProgressBarState extends State<LiveProgressBar> {
  late Timer _timer;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (widget.isPlaying && !_isDragging) {
        setState(() {}); // Sadece slider'ı günceller
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Yerel olarak doğru pozisyonu hesapla
    int currentMs;
    
    if (_isDragging) {
      currentMs = _dragValue.toInt();
    } else if (widget.isPlaying) {
      final diff = DateTime.now().difference(widget.lastSyncTime).inMilliseconds;
      currentMs = widget.position.inMilliseconds + (diff * widget.playbackSpeed).toInt();
    } else {
      currentMs = widget.position.inMilliseconds;
    }

    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return SizedBox(height: 30); 
    if (currentMs > totalMs) currentMs = totalMs;
    if (currentMs < 0) currentMs = 0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: widget.accentColor,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: widget.accentColor.withOpacity(0.2),
          ),
          child: Slider(
            value: currentMs.toDouble(),
            min: 0,
            max: totalMs.toDouble(),
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              widget.onSeek(val.toInt());
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(Duration(milliseconds: currentMs)), style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_formatDuration(widget.duration), style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    return "${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }
}
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Stack(
        children: [
          Container(color: Color(0xFF0A0A0A)), // Base black layer
          if (imageProvider != null)
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 600),
                child: Image(
                  key: ValueKey(imageProvider.hashCode), // Only update if image object changes
                  image: imageProvider!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true, // <--- PREVENTS BLACK FLASHING
                  errorBuilder: (_, __, ___) => Container(color: Color(0xFF0A0A0A)),
                ),
              ),
            ),
          // Blur Layer
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: Colors.black.withOpacity(0.5), 
              ),
            ),
          ),
          // Gradient Overlay for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black12, Colors.black87],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 2: Main Screen ---
class MusicControlScreen extends StatefulWidget {
  @override
  _MusicControlScreenState createState() => _MusicControlScreenState();
}

class _MusicControlScreenState extends State<MusicControlScreen> with WidgetsBindingObserver {
  static const platform = MethodChannel('kemplayer/media');

  // Song Data
  String title = 'Waiting for music...';
  String artist = 'KemPlayer';
  String albumArtString = '';
  String albumArtUri = '';
  String displayIconUri = '';
  String packageName = '';
  
  // Playback Data
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double playbackSpeed = 1.0;
  DateTime lastSyncTime = DateTime.now();

  // Visuals & Caching
  Color accentColor = Color(0xFF1DB954);
  Color mutedColor = Colors.black;
  bool _isDialogShowing = false;
  
  // Image Caching to prevent rebuilds
  ImageProvider? _cachedImageProvider;
  String _lastAlbumArtString = '';

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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(Duration(milliseconds: 500), _updateMediaInfo);
    }
  }

  Future<void> _updateMediaInfo() async {
    try {
      final info = await platform.invokeMethod('getMediaInfo');
      if (!mounted) return;

      String newArt = info['albumArt'] ?? '';
      String newUri = info['albumArtUri'] ?? '';
      
      // Only update palette if art actually changed
      bool artChanged = (newArt != albumArtString) || (newUri != albumArtUri);

      setState(() {
        title = info['title'] ?? 'Waiting for music...';
        artist = info['artist'] ?? 'KemPlayer';
        albumArtString = newArt;
        albumArtUri = newUri;
        displayIconUri = info['displayIconUri'] ?? '';
        packageName = info['packageName'] ?? '';
        
        duration = Duration(milliseconds: (info['duration'] ?? 0).toInt());
        position = Duration(milliseconds: (info['position'] ?? 0).toInt());
        isPlaying = info['isPlaying'] ?? false;
        playbackSpeed = (info['playbackSpeed'] ?? 1.0).toDouble();
        
        lastSyncTime = DateTime.now();
      });

      if (artChanged) {
        _updateImageCache(); // Update the cached image
        _updatePalette();    // Update colors
      }
      
    } on PlatformException catch (e) {
      print("Failed: '${e.message}'.");
    }
  }

  // Caching Logic: Prevents recreating MemoryImage every frame
  void _updateImageCache() {
    if (albumArtString.isNotEmpty) {
      try {
        _cachedImageProvider = MemoryImage(base64Decode(albumArtString.replaceAll(RegExp(r'\s+'), '')));
      } catch (e) { _cachedImageProvider = null; }
    } else if (displayIconUri.isNotEmpty) {
      _cachedImageProvider = NetworkImage(displayIconUri);
    } else if (albumArtUri.isNotEmpty) {
      _cachedImageProvider = NetworkImage(albumArtUri);
    } else {
      _cachedImageProvider = null;
    }
  }

  Future<void> _updatePalette() async {
    if (_cachedImageProvider == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(_cachedImageProvider!);
      if (mounted) {
        setState(() {
          accentColor = palette.vibrantColor?.color ?? palette.dominantColor?.color ?? Color(0xFF1DB954);
          mutedColor = palette.mutedColor?.color ?? Colors.black;
        });
      }
    } catch (e) {
      print("Palette Error: $e");
    }
  }

  Future<void> _sendMediaControl(String command) async {
    await platform.invokeMethod('mediaControl', {'command': command});
  }

  Future<void> _seekTo(int ms) async {
    // Send seek command
    await platform.invokeMethod('seekTo', {'position': ms});
    // Optimistic local update
    setState(() {
      position = Duration(milliseconds: ms);
      lastSyncTime = DateTime.now();
    });
  }

  Future<dynamic> _platformCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'mediaInfoUpdated':
        _updateMediaInfo();
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
              content: Text("KemPlayer needs 'Notification Access' to function.", style: TextStyle(color: Colors.white70)),
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

  // --- LAYOUTS ---
  
  Widget _buildControlButtons({double size = 32, double playSize = 48}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: size),
          onPressed: () => _sendMediaControl('previous'),
        ),
        SizedBox(width: 20),
        Container(
          width: playSize + 16,
          height: playSize + 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor,
            boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 20)],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: playSize),
            onPressed: () => _sendMediaControl('play_pause'),
          ),
        ),
        SizedBox(width: 20),
        IconButton(
          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: size),
          onPressed: () => _sendMediaControl('next'),
        ),
      ],
    );
  }

  Widget _buildAlbumArt({double size = 300}) {
    return GestureDetector(
      onTap: () => platform.invokeMethod('openApp', {'packageName': packageName}),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 30, offset: Offset(0, 15))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: _cachedImageProvider != null 
            ? Image(image: _cachedImageProvider!, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(color: Color(0xFF222222), child: Icon(Icons.music_note, size: 80, color: Colors.white12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Static Background (Cached & Optimized)
          BlurredBackground(imageProvider: _cachedImageProvider, mutedColor: mutedColor),
          
          // 2. Active Content
          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                if (orientation == Orientation.landscape) {
                  return Padding(
                    padding: EdgeInsets.all(30),
                    child: Row(
                      children: [
                        Center(child: _buildAlbumArt(size: 240)),
                        SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                              Text(artist, style: TextStyle(fontSize: 20, color: Colors.white70), maxLines: 1),
                              Spacer(),
                              LiveProgressBar(
                                duration: duration,
                                position: position,
                                isPlaying: isPlaying,
                                playbackSpeed: playbackSpeed,
                                lastSyncTime: lastSyncTime,
                                accentColor: accentColor,
                                onSeek: _seekTo,
                              ),
                              SizedBox(height: 20),
                              _buildControlButtons(),
                              Spacer(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Spacer(flex: 3),
                        Hero(tag: 'art', child: _buildAlbumArt(size: 300)),
                        Spacer(flex: 2),
                        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 2),
                        SizedBox(height: 8),
                        Text(artist, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, color: Colors.white70), maxLines: 1),
                        Spacer(flex: 2),
                        LiveProgressBar(
                          duration: duration,
                          position: position,
                          isPlaying: isPlaying,
                          playbackSpeed: playbackSpeed,
                          lastSyncTime: lastSyncTime,
                          accentColor: accentColor,
                          onSeek: _seekTo,
                        ),
                        SizedBox(height: 20),
                        _buildControlButtons(),
                        Spacer(flex: 3),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET 3: Isolated Progress Bar ---
class LiveProgressBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final bool isPlaying;
  final double playbackSpeed;
  final DateTime lastSyncTime;
  final Color accentColor;
  final Function(int) onSeek;

  const LiveProgressBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.lastSyncTime,
    required this.accentColor,
    required this.onSeek,
  }) : super(key: key);

  @override
  _LiveProgressBarState createState() => _LiveProgressBarState();
}

class _LiveProgressBarState extends State<LiveProgressBar> {
  late Timer _timer;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (widget.isPlaying && !_isDragging) {
        setState(() {}); // Updates only the slider
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate accurate position locally
    int currentMs;
    
    if (_isDragging) {
      currentMs = _dragValue.toInt();
    } else if (widget.isPlaying) {
      final diff = DateTime.now().difference(widget.lastSyncTime).inMilliseconds;
      currentMs = widget.position.inMilliseconds + (diff * widget.playbackSpeed).toInt();
    } else {
      currentMs = widget.position.inMilliseconds;
    }

    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return SizedBox(height: 30); 
    if (currentMs > totalMs) currentMs = totalMs;
    if (currentMs < 0) currentMs = 0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: widget.accentColor,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: widget.accentColor.withOpacity(0.2),
          ),
          child: Slider(
            value: currentMs.toDouble(),
            min: 0,
            max: totalMs.toDouble(),
            onChangeStart: (val) {
              setState(() {
                _isDragging = true;
                _dragValue = val;
              });
            },
            onChanged: (val) {
              setState(() {
                _dragValue = val;
              });
            },
            onChangeEnd: (val) {
              widget.onSeek(val.toInt());
              setState(() {
                _isDragging = false;
              });
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(Duration(milliseconds: currentMs)), style: TextStyle(color: Colors.white54, fontSize: 12)),
              Text(_formatDuration(widget.duration), style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return "${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
    return "${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}";
  }
}
