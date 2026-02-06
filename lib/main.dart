import 'package:flutter/material.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'database_helper.dart';
import 'reel_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Save Reels',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          surface: Color(0xFF121212),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Color(0xFFA8A8A8)),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late StreamSubscription _intentSub;
  List<Map<String, dynamic>> _reels = [];
  final TextEditingController _searchController = TextEditingController();
  final ReelService _reelService = ReelService.instance;

  @override
  void initState() {
    super.initState();
    _loadReels();

    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        for (var file in value) {
          _processSharedUrl(file.path);
        }
      }
    });

    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        for (var file in value) {
          _processSharedUrl(file.path);
        }
      }
      ReceiveSharingIntent.instance.reset();
    });
  }

  Future<void> _loadReels() async {
    final reels = await _reelService.getAllReels();
    if (mounted) {
      setState(() => _reels = reels);
    }
  }

  Future<void> _processSharedUrl(String url) async {
    String caption = "Reel from ${url.split('/').skip(2).firstOrNull ?? 'Instagram'}";
    await _reelService.saveReel(url, caption: caption);
    _loadReels();
  }

  Future<void> _onSearchChanged(String query) async {
    final results = await _reelService.searchReels(query);
    setState(() => _reels = results);
  }

  @override
  void dispose() {
    _intentSub.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Instagram-Style Search Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  cursorColor: Colors.grey,
                  decoration: const InputDecoration(
                    hintText: "Search saved reels",
                    hintStyle: TextStyle(color: Color(0xFF8E8E8E), fontSize: 16),
                    prefixIcon: Icon(Icons.search, color: Color(0xFF8E8E8E), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 13),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
            
            // Reel Grid
            Expanded(
              child: _reels.isEmpty && _searchController.text.isEmpty
                  ? _buildEmptyState()
                  : _buildReelGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.movie_creation_outlined, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 32),
            const Text(
              "Your saved Reels will appear here",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Share from Instagram to get started",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E8E8E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 1), // Minimal grid gap
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        childAspectRatio: 0.65, // Classic Reels vertical aspect
      ),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reel = _reels[index];
        return GestureDetector(
          onTap: () => _navigateToDetail(reel),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              Container(
                color: const Color(0xFF121212),
                child: reel['thumbnail'] != null
                    ? Image.network(reel['thumbnail'], fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.movie_creation_outlined, color: Colors.white24)),
              ),
              // Subtle Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
              // Creator Name / Icon
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reel['creator'] ?? "Original",
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToDetail(Map<String, dynamic> reel) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetailScreen(reel: reel)),
    );
  }
}

class DetailScreen extends StatelessWidget {
  final Map<String, dynamic> reel;
  const DetailScreen({super.key, required this.reel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("Reels", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Large Preview
            AspectRatio(
              aspectRatio: 0.8,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF121212),
                    child: reel['thumbnail'] != null
                        ? Image.network(reel['thumbnail'], fit: BoxFit.cover)
                        : const Icon(Icons.movie_creation_outlined, size: 80, color: Colors.white24),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reel['creator'] ?? "Unknown Creator",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Interaction & Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reel['caption'] ?? "No caption available",
                    style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
                  ),
                  if (reel['tags'] != null && reel['tags'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reel['tags']
                          .toString()
                          .split(' ')
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF262626),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    "Saved on ${reel['timestamp'].toString().split('T').first}",
                    style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  // Open In IG Button
                  GestureDetector(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF262626)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          "View on Instagram",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
