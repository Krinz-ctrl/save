import 'database_helper.dart';

class ReelService {
  static final ReelService instance = ReelService._init();
  ReelService._init();

  /// Extract keywords from a caption to use as search tags
  String _extractTags(String? caption) {
    if (caption == null || caption.isEmpty) return "";
    
    // Simple extraction: find words starting with # or words with 4+ characters
    final RegExp tagExp = RegExp(r"(#\w+|\b\w{4,}\b)");
    final matches = tagExp.allMatches(caption.toLowerCase());
    
    final tags = matches
        .map((m) => m.group(0))
        .where((t) => t != null)
        .toSet() // Remove duplicates
        .join(" ");
        
    return tags;
  }

  Future<int> saveReel(String url, {String? caption, String? creator, String? thumbnail}) async {
    // Duplicate check
    final all = await DatabaseHelper.instance.fetchItems();
    if (all.any((r) => r['url'] == url)) {
      return -1; // Already exists
    }

    final tags = _extractTags(caption);
    
    return await DatabaseHelper.instance.insertItem(
      url,
      caption: caption ?? "Shared Reel",
      creator: creator ?? "Unknown",
      thumbnail: thumbnail,
      tags: tags,
      collection: "All", // Default collection
    );
  }

  Future<List<Map<String, dynamic>>> getAllReels() async {
    return await DatabaseHelper.instance.fetchItems();
  }

  Future<List<Map<String, dynamic>>> searchReels(String query) async {
    if (query.isEmpty) return getAllReels();
    
    // Add wildcard for partial matching (e.g. "edit" becomes "edit*")
    final formattedQuery = query.trim().split(' ').map((term) => "$term*").join(' ');
    
    return await DatabaseHelper.instance.searchItems(formattedQuery);
  }
}
