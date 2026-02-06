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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
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

    // Listen to shared text (Stream)
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        for (var file in value) {
          _processSharedUrl(file.path);
        }
      }
    });

    // Handle shared text (Initial)
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
    // Basic extraction of caption from URL if possible, or just use URL
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Save Reels",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: "Search captions, creators, tags...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            
            // Reel List
            Expanded(
              child: _reels.isEmpty && _searchController.text.isEmpty
                  ? _buildEmptyState()
                  : _buildReelList(),
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
            Icon(Icons.share_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const Text(
              "“Share Reels from Instagram to find them later.”",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Your saved reels will appear here instantly.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReelList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _reels.length,
      itemBuilder: (context, index) {
        final reel = _reels[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: Colors.grey[200],
                child: reel['thumbnail'] != null
                    ? Image.network(reel['thumbnail'], fit: BoxFit.cover)
                    : const Icon(Icons.movie_creation_outlined, color: Colors.grey),
              ),
            ),
            title: Text(
              reel['caption'] ?? "No Caption",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reel['creator'] ?? "Unknown Creator",
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ),
            onTap: () => _navigateToDetail(reel),
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
      appBar: AppBar(title: const Text("Reel Info")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: reel['thumbnail'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.network(reel['thumbnail'], fit: BoxFit.cover),
                      )
                    : const Icon(Icons.movie_creation_outlined, size: 80, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              reel['creator'] ?? "Unknown Creator",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Saved on ${reel['timestamp'].toString().split('T').first}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              "Caption",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              reel['caption'] ?? "No caption available",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (reel['tags'] != null && reel['tags'].toString().isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                "Tags",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: reel['tags']
                    .toString()
                    .split(' ')
                    .map((tag) => Chip(
                          label: Text(tag),
                          backgroundColor: Colors.grey[100],
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {}, // Future: Open in Instagram
                icon: const Icon(Icons.open_in_new),
                label: const Text("View on Instagram"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
