import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/author_info.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/models/subreddit_info.dart';
import 'package:savedex/features/library/library_viewmodel.dart';

class SubredditUserMetadataState {
  final bool isRetryingSubIcons;
  final bool isRetryingSubInfo;
  final bool isForceRefreshingSubs;
  final bool isRetryingUserAvatars;
  final bool isRetryingUserInfo;
  final bool isForceRefreshingUsers;
  final String? feedbackMessage;
  final int feedbackId;

  const SubredditUserMetadataState({
    this.isRetryingSubIcons = false,
    this.isRetryingSubInfo = false,
    this.isForceRefreshingSubs = false,
    this.isRetryingUserAvatars = false,
    this.isRetryingUserInfo = false,
    this.isForceRefreshingUsers = false,
    this.feedbackMessage,
    this.feedbackId = 0,
  });

  bool get isSubBusy =>
      isRetryingSubIcons || isRetryingSubInfo || isForceRefreshingSubs;

  bool get isUserBusy =>
      isRetryingUserAvatars || isRetryingUserInfo || isForceRefreshingUsers;

  bool get isAnyBusy => isSubBusy || isUserBusy;

  SubredditUserMetadataState copyWith({
    bool? isRetryingSubIcons,
    bool? isRetryingSubInfo,
    bool? isForceRefreshingSubs,
    bool? isRetryingUserAvatars,
    bool? isRetryingUserInfo,
    bool? isForceRefreshingUsers,
    String? feedbackMessage,
    int? feedbackId,
  }) {
    return SubredditUserMetadataState(
      isRetryingSubIcons: isRetryingSubIcons ?? this.isRetryingSubIcons,
      isRetryingSubInfo: isRetryingSubInfo ?? this.isRetryingSubInfo,
      isForceRefreshingSubs:
          isForceRefreshingSubs ?? this.isForceRefreshingSubs,
      isRetryingUserAvatars:
          isRetryingUserAvatars ?? this.isRetryingUserAvatars,
      isRetryingUserInfo: isRetryingUserInfo ?? this.isRetryingUserInfo,
      isForceRefreshingUsers:
          isForceRefreshingUsers ?? this.isForceRefreshingUsers,
      feedbackMessage: feedbackMessage ?? this.feedbackMessage,
      feedbackId: feedbackId ?? this.feedbackId,
    );
  }
}

final subredditUserMetadataProvider =
    NotifierProvider<SubredditUserMetadataNotifier, SubredditUserMetadataState>(
      SubredditUserMetadataNotifier.new,
    );

class SubredditUserMetadataNotifier
    extends Notifier<SubredditUserMetadataState> {
  @override
  SubredditUserMetadataState build() => const SubredditUserMetadataState();

  void _emitFeedback(String message) {
    state = state.copyWith(
      feedbackMessage: message,
      feedbackId: state.feedbackId + 1,
    );
  }

  Future<void> retrySubredditIcons(List<SubredditInfo> subs) async {
    if (state.isSubBusy) return;
    final repo = ref.read(savedItemRepositoryProvider);
    final skippedCount = subs
        .where(
          (s) =>
              (s.iconUrl == null || s.iconUrl!.isEmpty) &&
              repo.isSubredditFailing(s.name),
        )
        .length;
    final targets = [
      for (final s in subs)
        if ((s.iconUrl == null || s.iconUrl!.isEmpty) &&
            !repo.isSubredditFailing(s.name))
          s.name,
    ];

    if (targets.isEmpty) {
      _emitFeedback(
        skippedCount > 0
            ? 'All $skippedCount failing subreddits are skipped. Use Force Refresh to retry them.'
            : 'No missing subreddit icons to retry.',
      );
      return;
    }

    state = state.copyWith(isRetryingSubIcons: true);
    try {
      await repo.enrichSubreddits(
        targets,
        includeMissingIcons: true,
        isRetry: true,
      );
      ref.invalidate(rawSubredditsWithCountsProvider);
      _emitFeedback(
        skippedCount > 0
            ? 'Retried ${targets.length} subreddit icons ($skippedCount failing skipped).'
            : 'Retried ${targets.length} missing subreddit icons.',
      );
    } catch (e) {
      _emitFeedback('Failed to fetch subreddit icons: $e');
    } finally {
      state = state.copyWith(isRetryingSubIcons: false);
    }
  }

  Future<void> retrySubredditInfo(List<SubredditInfo> subs) async {
    if (state.isSubBusy) return;
    final repo = ref.read(savedItemRepositoryProvider);
    final skippedCount = subs
        .where((s) => !s.isVerified && repo.isSubredditFailing(s.name))
        .length;
    final targets = [
      for (final s in subs)
        if (!s.isVerified && !repo.isSubredditFailing(s.name)) s.name,
    ];

    if (targets.isEmpty) {
      _emitFeedback(
        skippedCount > 0
            ? 'All $skippedCount failing subreddits are skipped. Use Force Refresh to retry them.'
            : 'No unverified subreddits to retry.',
      );
      return;
    }

    state = state.copyWith(isRetryingSubInfo: true);
    try {
      await repo.enrichSubreddits(targets, isRetry: true);
      ref.invalidate(rawSubredditsWithCountsProvider);
      _emitFeedback(
        skippedCount > 0
            ? 'Retried ${targets.length} subreddits ($skippedCount failing skipped).'
            : 'Verified ${targets.length} unverified subreddits.',
      );
    } catch (e) {
      _emitFeedback('Failed to fetch subreddit info: $e');
    } finally {
      state = state.copyWith(isRetryingSubInfo: false);
    }
  }

  Future<void> forceRefreshSubreddits(List<SubredditInfo> subs) async {
    if (state.isSubBusy) return;
    final targets = [for (final s in subs) s.name];
    if (targets.isEmpty) {
      _emitFeedback('No subreddits to refresh.');
      return;
    }

    state = state.copyWith(isForceRefreshingSubs: true);
    try {
      await ref
          .read(savedItemRepositoryProvider)
          .enrichSubreddits(
            targets,
            forceRefetch: true,
            includeMissingIcons: true,
          );
      ref.invalidate(rawSubredditsWithCountsProvider);
      _emitFeedback('Force refreshed all ${targets.length} subreddits.');
    } catch (e) {
      _emitFeedback('Failed to force refresh subreddits: $e');
    } finally {
      state = state.copyWith(isForceRefreshingSubs: false);
    }
  }

  Future<void> retryUserAvatars(List<AuthorInfo> authors) async {
    if (state.isUserBusy) return;
    final repo = ref.read(savedItemRepositoryProvider);
    final skippedCount = authors
        .where(
          (a) =>
              (a.iconUrl == null || a.iconUrl!.isEmpty) &&
              repo.isAuthorFailing(a.name),
        )
        .length;
    final targets = [
      for (final a in authors)
        if ((a.iconUrl == null || a.iconUrl!.isEmpty) &&
            !repo.isAuthorFailing(a.name))
          a.name,
    ];

    if (targets.isEmpty) {
      _emitFeedback(
        skippedCount > 0
            ? 'All $skippedCount failing users are skipped. Use Force Refresh to retry them.'
            : 'No missing user avatars to retry.',
      );
      return;
    }

    state = state.copyWith(isRetryingUserAvatars: true);
    try {
      await repo.enrichAuthors(
        targets,
        includeMissingIcons: true,
        isRetry: true,
      );
      ref.invalidate(rawAuthorsWithCountsProvider);
      _emitFeedback(
        skippedCount > 0
            ? 'Retried ${targets.length} user avatars ($skippedCount failing skipped).'
            : 'Retried ${targets.length} missing user avatars.',
      );
    } catch (e) {
      _emitFeedback('Failed to fetch user avatars: $e');
    } finally {
      state = state.copyWith(isRetryingUserAvatars: false);
    }
  }

  Future<void> retryUserInfo(List<AuthorInfo> authors) async {
    if (state.isUserBusy) return;
    final repo = ref.read(savedItemRepositoryProvider);
    final skippedCount = authors
        .where((a) => !a.isVerified && repo.isAuthorFailing(a.name))
        .length;
    final targets = [
      for (final a in authors)
        if (!a.isVerified && !repo.isAuthorFailing(a.name)) a.name,
    ];

    if (targets.isEmpty) {
      _emitFeedback(
        skippedCount > 0
            ? 'All $skippedCount failing users are skipped. Use Force Refresh to retry them.'
            : 'No unverified users to retry.',
      );
      return;
    }

    state = state.copyWith(isRetryingUserInfo: true);
    try {
      await repo.enrichAuthors(targets, isRetry: true);
      ref.invalidate(rawAuthorsWithCountsProvider);
      _emitFeedback(
        skippedCount > 0
            ? 'Retried ${targets.length} users ($skippedCount failing skipped).'
            : 'Verified ${targets.length} unverified users.',
      );
    } catch (e) {
      _emitFeedback('Failed to fetch user info: $e');
    } finally {
      state = state.copyWith(isRetryingUserInfo: false);
    }
  }

  Future<void> forceRefreshUsers(List<AuthorInfo> authors) async {
    if (state.isUserBusy) return;
    final targets = [for (final a in authors) a.name];
    if (targets.isEmpty) {
      _emitFeedback('No users to refresh.');
      return;
    }

    state = state.copyWith(isForceRefreshingUsers: true);
    try {
      await ref
          .read(savedItemRepositoryProvider)
          .enrichAuthors(
            targets,
            forceRefetch: true,
            includeMissingIcons: true,
          );
      ref.invalidate(rawAuthorsWithCountsProvider);
      _emitFeedback('Force refreshed all ${targets.length} users.');
    } catch (e) {
      _emitFeedback('Failed to force refresh users: $e');
    } finally {
      state = state.copyWith(isForceRefreshingUsers: false);
    }
  }
}

class SubredditUserMetadataView extends ConsumerWidget {
  const SubredditUserMetadataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<SubredditUserMetadataState>(subredditUserMetadataProvider, (
      previous,
      next,
    ) {
      if (next.feedbackId != previous?.feedbackId &&
          next.feedbackMessage != null) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(next.feedbackMessage!),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
      }
    });

    final colorScheme = Theme.of(context).colorScheme;
    final actionState = ref.watch(subredditUserMetadataProvider);
    final notifier = ref.read(subredditUserMetadataProvider.notifier);
    final repo = ref.watch(savedItemRepositoryProvider);
    final subsAsync = ref.watch(rawSubredditsWithCountsProvider);
    final authorsAsync = ref.watch(rawAuthorsWithCountsProvider);

    final rawSubs = subsAsync.value ?? const <SubredditInfo>[];
    final subs = [
      for (final s in rawSubs)
        if (!SavedItem.isUserSubreddit(s.name)) s,
    ];
    final totalSubs = subs.length;
    final missingSubIcons = subs
        .where((s) => s.iconUrl == null || s.iconUrl!.isEmpty)
        .length;
    final failedSubIcons = subs
        .where(
          (s) =>
              (s.iconUrl == null || s.iconUrl!.isEmpty) &&
              repo.isSubredditFailing(s.name),
        )
        .length;
    final retryableSubIcons = missingSubIcons - failedSubIcons;
    final unverifiedSubs = subs.where((s) => !s.isVerified).length;
    final failedSubInfo = subs
        .where((s) => !s.isVerified && repo.isSubredditFailing(s.name))
        .length;
    final retryableSubInfo = unverifiedSubs - failedSubInfo;
    final totalFailedSubs = subs
        .where((s) => repo.isSubredditFailing(s.name))
        .length;
    final isSubBusy = actionState.isSubBusy;

    final authors = authorsAsync.value ?? const <AuthorInfo>[];
    final totalAuthors = authors.length;
    final missingUserAvatars = authors
        .where((a) => a.iconUrl == null || a.iconUrl!.isEmpty)
        .length;
    final failedUserAvatars = authors
        .where(
          (a) =>
              (a.iconUrl == null || a.iconUrl!.isEmpty) &&
              repo.isAuthorFailing(a.name),
        )
        .length;
    final retryableUserAvatars = missingUserAvatars - failedUserAvatars;
    final unverifiedAuthors = authors.where((a) => !a.isVerified).length;
    final failedUserInfo = authors
        .where((a) => !a.isVerified && repo.isAuthorFailing(a.name))
        .length;
    final retryableUserInfo = unverifiedAuthors - failedUserInfo;
    final totalFailedAuthors = authors
        .where((a) => repo.isAuthorFailing(a.name))
        .length;
    final isUserBusy = actionState.isUserBusy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subreddit & User Metadata'),
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // Subreddits Section
          _buildSectionHeader('Subreddits', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.image_outlined,
                  title: 'Subreddit Icons',
                  subtitle: missingSubIcons > 0
                      ? '$missingSubIcons missing of $totalSubs subreddits${failedSubIcons > 0 ? ' ($failedSubIcons failing - skipped)' : ''}'
                      : 'All $totalSubs subreddit icons cached',
                  isBusy: actionState.isRetryingSubIcons,
                  buttonLabel: 'Retry',
                  onTap: (!isSubBusy && retryableSubIcons > 0)
                      ? () => notifier.retrySubredditIcons(subs)
                      : null,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _buildActionTile(
                  icon: Icons.info_outline_rounded,
                  title: 'Subreddit Info',
                  subtitle: unverifiedSubs > 0
                      ? '$unverifiedSubs unverified of $totalSubs subreddits${failedSubInfo > 0 ? ' ($failedSubInfo failing - skipped)' : ''}'
                      : 'All $totalSubs subreddits verified',
                  isBusy: actionState.isRetryingSubInfo,
                  buttonLabel: 'Retry',
                  onTap: (!isSubBusy && retryableSubInfo > 0)
                      ? () => notifier.retrySubredditInfo(subs)
                      : null,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _buildActionTile(
                  icon: Icons.refresh_rounded,
                  title: 'Force Refresh All',
                  subtitle: totalFailedSubs > 0
                      ? 'Re-fetches all $totalSubs subreddits (resets $totalFailedSubs failing)'
                      : 'Re-queries Reddit API for all $totalSubs subreddits regardless',
                  isBusy: actionState.isForceRefreshingSubs,
                  buttonLabel: 'Force',
                  onTap: (!isSubBusy && totalSubs > 0)
                      ? () => notifier.forceRefreshSubreddits(subs)
                      : null,
                ),
              ],
            ),
          ),

          // Users Section
          _buildSectionHeader('Users', colorScheme),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildActionTile(
                  icon: Icons.account_circle_outlined,
                  title: 'User Avatars',
                  subtitle: missingUserAvatars > 0
                      ? '$missingUserAvatars missing of $totalAuthors users${failedUserAvatars > 0 ? ' ($failedUserAvatars failing - skipped)' : ''}'
                      : 'All $totalAuthors user avatars cached',
                  isBusy: actionState.isRetryingUserAvatars,
                  buttonLabel: 'Retry',
                  onTap: (!isUserBusy && retryableUserAvatars > 0)
                      ? () => notifier.retryUserAvatars(authors)
                      : null,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _buildActionTile(
                  icon: Icons.badge_outlined,
                  title: 'User Info',
                  subtitle: unverifiedAuthors > 0
                      ? '$unverifiedAuthors unverified of $totalAuthors users${failedUserInfo > 0 ? ' ($failedUserInfo failing - skipped)' : ''}'
                      : 'All $totalAuthors users verified',
                  isBusy: actionState.isRetryingUserInfo,
                  buttonLabel: 'Retry',
                  onTap: (!isUserBusy && retryableUserInfo > 0)
                      ? () => notifier.retryUserInfo(authors)
                      : null,
                ),
                const Divider(height: 1, indent: 56, endIndent: 16),
                _buildActionTile(
                  icon: Icons.refresh_rounded,
                  title: 'Force Refresh All',
                  subtitle: totalFailedAuthors > 0
                      ? 'Re-fetches all $totalAuthors users (resets $totalFailedAuthors failing)'
                      : 'Re-queries Reddit API for all $totalAuthors users regardless',
                  isBusy: actionState.isForceRefreshingUsers,
                  buttonLabel: 'Force',
                  onTap: (!isUserBusy && totalAuthors > 0)
                      ? () => notifier.forceRefreshUsers(authors)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isBusy,
    required String buttonLabel,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
      subtitle: Text(subtitle),
      trailing: isBusy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : FilledButton.tonal(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: onTap,
              child: Text(buttonLabel),
            ),
    );
  }
}
