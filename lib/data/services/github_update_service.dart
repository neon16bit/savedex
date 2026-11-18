import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:savedex/core/constants/constants.dart';

const kLastDismissedUpdateKey = 'last_dismissed_update_version';

final _leadingVersionPrefix = RegExp(r'^[vV]');
final _digitsOnly = RegExp(r'^\d+$');
final _semVerIdent = RegExp(r'^[0-9A-Za-z-]+$');

String normalizeVersionString(String raw) =>
    raw.trim().replaceFirst(_leadingVersionPrefix, '').trim();

({List<BigInt> core, List<String> pre})? _parseSemVer(String raw) =>
    _parseNormalizedSemVer(normalizeVersionString(raw));

({List<BigInt> core, List<String> pre})? _parseNormalizedSemVer(
  String normalized,
) {
  if (normalized.isEmpty) return null;

  final plus = normalized.indexOf('+');
  final versionPart = plus >= 0 ? normalized.substring(0, plus) : normalized;
  if (plus >= 0) {
    final buildPart = normalized.substring(plus + 1);
    if (buildPart.isEmpty ||
        buildPart.split('.').any((s) => !_semVerIdent.hasMatch(s))) {
      return null;
    }
  }

  final dash = versionPart.indexOf('-');
  final corePart = dash >= 0 ? versionPart.substring(0, dash) : versionPart;
  final prePart = dash >= 0 ? versionPart.substring(dash + 1) : null;

  final core = <BigInt>[];
  for (final s in corePart.split('.')) {
    final n = _digitsOnly.hasMatch(s) ? BigInt.tryParse(s) : null;
    if (n == null) return null;
    core.add(n);
  }

  final pre = prePart == null ? const <String>[] : prePart.split('.');
  if (prePart != null &&
      (prePart.isEmpty || pre.any((id) => !_semVerIdent.hasMatch(id)))) {
    return null;
  }

  return (core: core, pre: pre);
}

bool isVersionNewer(String latest, String current) {
  final l = _parseSemVer(latest);
  final c = _parseSemVer(current);
  if (l == null || c == null) return false;

  final coreLen = l.core.length > c.core.length ? l.core.length : c.core.length;
  for (var i = 0; i < coreLen; i++) {
    final lv = i < l.core.length ? l.core[i] : BigInt.zero;
    final cv = i < c.core.length ? c.core[i] : BigInt.zero;
    if (lv != cv) return lv > cv;
  }
  if (l.pre.isEmpty || c.pre.isEmpty) return l.pre.isEmpty && c.pre.isNotEmpty;

  final shared = l.pre.length < c.pre.length ? l.pre.length : c.pre.length;
  for (var i = 0; i < shared; i++) {
    final li = l.pre[i];
    final ci = c.pre[i];
    if (li == ci) continue;
    final ln = _digitsOnly.hasMatch(li) ? BigInt.tryParse(li) : null;
    final cn = _digitsOnly.hasMatch(ci) ? BigInt.tryParse(ci) : null;
    if (ln != null && cn != null) {
      if (ln != cn) return ln > cn;
      continue;
    }
    if (ln != null || cn != null) return cn != null;
    return li.compareTo(ci) > 0;
  }
  return l.pre.length > c.pre.length;
}

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? changelog;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    this.changelog,
  });
}

enum UpdateCheckStatus { updateAvailable, upToDate, noReleases, error }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppUpdateInfo? update;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.update,
    this.errorMessage,
  });
}

class GithubUpdateService {
  static Future<UpdateCheckResult>? _inFlightCheck;

  static UpdateCheckResult _err(String message) =>
      UpdateCheckResult(status: UpdateCheckStatus.error, errorMessage: message);

  static bool _isRateLimit403(http.Response res) {
    for (final entry in res.headers.entries) {
      if (entry.key.toLowerCase() == 'x-ratelimit-remaining' &&
          entry.value.trim() == '0') {
        return true;
      }
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true).toLowerCase();
    return body.contains('rate limit');
  }

  static Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
    http.Client? client,
    String? releaseApiUrl,
  }) {
    final cleanCurrent = normalizeVersionString(currentVersion);
    if (cleanCurrent.isEmpty) {
      return Future.value(_err('Current app version is unavailable.'));
    }
    if (_parseNormalizedSemVer(cleanCurrent) == null) {
      return Future.value(_err('Current app version is invalid.'));
    }

    if (client != null || releaseApiUrl != null) {
      return _performCheck(
        cleanCurrent: cleanCurrent,
        client: client,
        releaseApiUrl: releaseApiUrl,
      );
    }

    final inFlight = _inFlightCheck;
    if (inFlight != null) return inFlight;

    final check = _runSingleFlightCheck(cleanCurrent);
    _inFlightCheck = check;
    return check;
  }

  static Future<UpdateCheckResult> _runSingleFlightCheck(
    String cleanCurrent,
  ) async {
    try {
      return await _performCheck(cleanCurrent: cleanCurrent);
    } finally {
      _inFlightCheck = null;
    }
  }

  static Future<UpdateCheckResult> _performCheck({
    required String cleanCurrent,
    http.Client? client,
    String? releaseApiUrl,
  }) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final res = await httpClient
          .get(
            Uri.parse(releaseApiUrl ?? AppConstants.githubLatestReleaseUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2026-03-10',
              'User-Agent': '${AppConstants.appName}/$cleanCurrent',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) {
        return const UpdateCheckResult(status: UpdateCheckStatus.noReleases);
      }
      if (res.statusCode == 429 ||
          (res.statusCode == 403 && _isRateLimit403(res))) {
        return _err('GitHub API rate limit exceeded. Try again later.');
      }
      if (res.statusCode != 200) {
        return _err('GitHub returned HTTP ${res.statusCode}.');
      }
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! Map) {
        return _err('Unexpected response format from GitHub.');
      }
      final json = Map<String, dynamic>.from(decoded);
      if (json['draft'] == true || json['prerelease'] == true) {
        return const UpdateCheckResult(status: UpdateCheckStatus.noReleases);
      }
      final rawTag = json['tag_name'];
      final latestVersion = rawTag is String
          ? normalizeVersionString(rawTag)
          : '';
      if (latestVersion.isEmpty ||
          _parseNormalizedSemVer(latestVersion) == null) {
        return _err('Release metadata has an invalid version tag.');
      }
      final rawUrl = json['html_url'];
      final urlStr = rawUrl is String ? rawUrl.trim() : '';
      final url = Uri.tryParse(urlStr);
      final host = url?.host.toLowerCase() ?? '';
      final releaseUrl =
          url != null &&
              url.isScheme('https') &&
              url.userInfo.isEmpty &&
              (host == 'github.com' ||
                  (host.endsWith('.github.com') && !host.startsWith('.')))
          ? urlStr
          : AppConstants.githubReleasesPageUrl;
      final rawBody = json['body'];
      final changelog = rawBody is String && rawBody.trim().isNotEmpty
          ? rawBody.trim()
          : null;
      final hasUpdate = isVersionNewer(latestVersion, cleanCurrent);
      return UpdateCheckResult(
        status: hasUpdate
            ? UpdateCheckStatus.updateAvailable
            : UpdateCheckStatus.upToDate,
        update: AppUpdateInfo(
          currentVersion: cleanCurrent,
          latestVersion: latestVersion,
          releaseUrl: releaseUrl,
          changelog: changelog,
        ),
      );
    } on FormatException {
      return _err('Invalid response received from GitHub.');
    } on Object {
      return _err('Could not check for updates. Check your connection.');
    } finally {
      if (ownsClient) httpClient.close();
    }
  }
}
