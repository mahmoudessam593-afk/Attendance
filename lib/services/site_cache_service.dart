import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Caches the employee's assigned sites locally so repeated GPS refreshes
/// don't need to re-fetch them from the server. The cache is written once
/// at splash/login time and refreshed opportunistically whenever a live
/// server response (e.g. attendance validate) includes up-to-date site
/// data - that's the only place stale data (like an admin-changed radius)
/// actually matters, since check-in/check-out always re-check against the
/// server's live site row regardless of what's cached here.
class SiteCacheService {
  static const _key = 'cached_sites';

  Future<void> saveSites(List<Site> sites) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(sites.map((s) => s.toMap()).toList());
    await prefs.setString(_key, encoded);
  }

  Future<List<Site>> loadSites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((m) => Site.fromMap(m as Map<String, dynamic>)).toList();
  }

  /// Updates just one cached site's fields in place (used after a live
  /// validate response returns the authoritative, current site row).
  Future<void> updateSite(Site updated) async {
    final sites = await loadSites();
    final index = sites.indexWhere((s) => s.id == updated.id);
    if (index == -1) {
      sites.add(updated);
    } else {
      sites[index] = updated;
    }
    await saveSites(sites);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
