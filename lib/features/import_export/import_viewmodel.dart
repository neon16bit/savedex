import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/backup_export_service.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

enum ImportExportType {
  none,
  restore,
  backup,
  takeoutImport,
  redditSync,
  export,
}

enum ImportExportCardStatus { idle, running, completed, failed }

class ImportExportState {
  final String? statusMessage;
  final double? progress;
  final ImportSummary? lastImportSummary;
  final String? errorMessage;
  final ImportExportType activeType;
  final ImportExportCardStatus cardStatus;
  final String? lastSavedFilePath;

  const ImportExportState({
    this.statusMessage,
    this.progress,
    this.lastImportSummary,
    this.errorMessage,
    this.activeType = ImportExportType.none,
    this.cardStatus = ImportExportCardStatus.idle,
    this.lastSavedFilePath,
  });

  bool get isImporting =>
      cardStatus == ImportExportCardStatus.running &&
      (activeType == ImportExportType.takeoutImport ||
          activeType == ImportExportType.redditSync);

  bool get isSyncingReddit =>
      cardStatus == ImportExportCardStatus.running &&
      activeType == ImportExportType.redditSync;

  bool get isExporting =>
      cardStatus == ImportExportCardStatus.running &&
      activeType == ImportExportType.export;

  bool get isBackingUp =>
      cardStatus == ImportExportCardStatus.running &&
      activeType == ImportExportType.backup;

  bool get isRestoring =>
      cardStatus == ImportExportCardStatus.running &&
      activeType == ImportExportType.restore;

  bool get isBusy => cardStatus == ImportExportCardStatus.running;

  ImportExportState copyWith({
    String? statusMessage,
    double? progress,
    ImportSummary? lastImportSummary,
    String? errorMessage,
    ImportExportType? activeType,
    ImportExportCardStatus? cardStatus,
    String? lastSavedFilePath,
    bool clearStatus = false,
    bool clearProgress = false,
    bool clearError = false,
    bool clearSummary = false,
    bool clearSavedFilePath = false,
  }) {
    return ImportExportState(
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      progress: clearProgress ? null : (progress ?? this.progress),
      lastImportSummary: clearSummary
          ? null
          : (lastImportSummary ?? this.lastImportSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeType: activeType ?? this.activeType,
      cardStatus: cardStatus ?? this.cardStatus,
      lastSavedFilePath: clearSavedFilePath
          ? null
          : (lastSavedFilePath ?? this.lastSavedFilePath),
    );
  }
}

final importExportViewModelProvider =
    NotifierProvider<ImportExportViewModel, ImportExportState>(() {
      return ImportExportViewModel();
    });

class ImportExportViewModel extends Notifier<ImportExportState> {
  bool _isOperationBusy = false;

  @override
  ImportExportState build() {
    ref.onDispose(() {
      _isOperationBusy = false;
    });
    return const ImportExportState();
  }

  bool _acquireLock() {
    if (_isOperationBusy || state.isBusy) {
      return false;
    }
    _isOperationBusy = true;
    return true;
  }

  void _releaseLock() {
    _isOperationBusy = false;
  }

  Future<String?> _saveFilePickerResult({
    required String dialogTitle,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final saveUri = await FilePickerPlatform.instance.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes,
    );

    if (saveUri == null) {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.idle,
        activeType: ImportExportType.none,
        clearStatus: true,
      );
      return null;
    }

    if (saveUri.scheme == 'file') {
      final filePath = saveUri.toFilePath();
      final file = File(filePath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        await file.writeAsBytes(bytes);
      }
      return filePath;
    } else {
      return saveUri.pathSegments.isNotEmpty
          ? saveUri.pathSegments.last
          : fileName;
    }
  }

  Future<String?> createBackup() async {
    if (!_acquireLock()) return null;
    try {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.running,
        activeType: ImportExportType.backup,
        statusMessage: 'Creating backup...',
        clearError: true,
        clearProgress: true,
        clearSummary: true,
        clearSavedFilePath: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      final allItems = await repo
          .watchSavedItems(const FilterCriteria(isArchived: null))
          .first;

      if (allItems.isEmpty) {
        state = state.copyWith(
          cardStatus: ImportExportCardStatus.failed,
          errorMessage: 'No items in library to backup.',
        );
        return null;
      }

      final subreddits = await repo.getAllSubreddits();
      final service = ref.read(backupExportServiceProvider);
      final bytes = service.createBackup(allItems, subreddits: subreddits);

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'savedex_backup_$dateStr.savedex';

      final savedDisplayPath = await _saveFilePickerResult(
        dialogTitle: 'Save Savedex Backup',
        fileName: fileName,
        mimeType: 'application/octet-stream',
        bytes: bytes,
      );

      if (savedDisplayPath == null) {
        return null;
      }

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.completed,
        statusMessage: 'Backup saved successfully!',
        lastSavedFilePath: savedDisplayPath,
      );
      return savedDisplayPath;
    } catch (e) {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.failed,
        errorMessage: 'Backup failed: $e',
      );
      return null;
    } finally {
      _releaseLock();
    }
  }

  Future<ImportSummary?> restoreBackup() async {
    if (!_acquireLock()) return null;
    try {
      final isMobile = Platform.isAndroid || Platform.isIOS;
      final files = await FilePickerPlatform.instance.pickFiles(
        type: isMobile ? FileType.any : FileType.custom,
        allowedExtensions: isMobile ? null : const ['savedex', 'json', 'csv'],
      );

      if (files.isEmpty) {
        return null;
      }

      final pickedFile = files.first;
      final ext =
          pickedFile.extension?.toLowerCase() ??
          (pickedFile.name.contains('.')
              ? pickedFile.name.split('.').last.toLowerCase()
              : '');

      if (isMobile && ext != 'savedex' && ext != 'json' && ext != 'csv') {
        state = state.copyWith(
          cardStatus: ImportExportCardStatus.failed,
          activeType: ImportExportType.restore,
          errorMessage: 'Please select a valid .savedex, .json, or .csv file.',
        );
        return null;
      }

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.running,
        activeType: ImportExportType.restore,
        statusMessage: 'Reading backup file...',
        clearProgress: true,
        clearError: true,
        clearSummary: true,
        clearSavedFilePath: true,
      );

      if (pickedFile.path == null) {
        state = state.copyWith(
          cardStatus: ImportExportCardStatus.failed,
          errorMessage: 'Could not access file path.',
          clearProgress: true,
        );
        return null;
      }

      final file = File(pickedFile.path!);
      final bytes = await file.readAsBytes();

      state = state.copyWith(
        statusMessage: 'Decompressing backup...',
        clearProgress: true,
      );

      final fileType = BackupExportService.detectFileType(
        filename: pickedFile.name,
        bytes: bytes,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      ImportSummary summary;

      void onProgress(double p, String msg) {
        state = state.copyWith(
          progress: p,
          statusMessage: msg,
          cardStatus: ImportExportCardStatus.running,
        );
      }

      switch (fileType) {
        case BackupFileType.savedex:
        case BackupFileType.json:
          final service = ref.read(backupExportServiceProvider);
          final payload = service.parseBackup(bytes);
          summary = await repo.restoreFromPayload(
            payload,
            sourceName: pickedFile.name,
            onProgress: onProgress,
          );
          break;

        case BackupFileType.savedexCsv:
          final content = utf8.decode(bytes, allowMalformed: true);
          final service = ref.read(backupExportServiceProvider);
          final payload = service.parseSavedexCsv(content);
          summary = await repo.restoreFromPayload(
            payload,
            sourceName: pickedFile.name,
            onProgress: onProgress,
          );
          break;

        case BackupFileType.redditCsv:
          final content = utf8.decode(bytes, allowMalformed: true);
          summary = await repo.importFromCsvContent(content, pickedFile.name);
          break;

        case BackupFileType.redditZip:
          summary = await repo.importFromZip(bytes);
          break;

        case BackupFileType.unknown:
          throw const FormatException(
            'Unsupported backup file format. Expected .savedex, exported .json or .csv',
          );
      }

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.completed,
        statusMessage: 'Restore completed successfully!',
        progress: 1.0,
        lastImportSummary: summary,
      );

      ref.invalidate(availableSubredditsProvider);
      ref.invalidate(availableAuthorsProvider);
      ref.invalidate(availableAuthorsWithCountsProvider);
      ref.invalidate(availableFlairsProvider);

      final settings = ref.read(settingsViewModelProvider);
      final shouldEnrich =
          settings.autoEnrichOnImport && summary.newItemsImported > 0;
      if (shouldEnrich) {
        ref.read(enrichmentViewModelProvider.notifier).startEnrichment();
      }

      return summary;
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Exception: ', '');
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.failed,
        errorMessage: 'Restore failed: $msg',
        clearProgress: true,
      );
      return null;
    } finally {
      _releaseLock();
    }
  }

  Future<ImportSummary?> pickAndImportFiles() async {
    if (!_acquireLock()) return null;
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'zip'],
      );

      if (files.isEmpty) {
        return null;
      }

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.running,
        activeType: ImportExportType.takeoutImport,
        statusMessage: 'Reading selected files...',
        clearProgress: true,
        clearError: true,
        clearSummary: true,
        clearSavedFilePath: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      int totalFound = 0;
      int newImported = 0;
      int updated = 0;
      int skipped = 0;
      final stopwatch = Stopwatch()..start();

      for (var idx = 0; idx < files.length; idx++) {
        final pickedFile = files[idx];
        final currentFileNum = idx + 1;
        final startProgress = files.length > 1
            ? (idx + 0.1) / files.length
            : 0.1;
        state = state.copyWith(
          statusMessage:
              'Parsing ${pickedFile.name} ($currentFileNum of ${files.length})...',
          progress: startProgress,
        );

        if (pickedFile.path == null) continue;
        final file = File(pickedFile.path!);
        final bytes = await file.readAsBytes();

        ImportSummary summary;
        if (pickedFile.name.toLowerCase().endsWith('.zip')) {
          summary = await repo.importFromZip(bytes);
        } else {
          final content = utf8.decode(bytes, allowMalformed: true);
          summary = await repo.importFromCsvContent(content, pickedFile.name);
        }

        totalFound += summary.totalFound;
        newImported += summary.newItemsImported;
        updated += summary.updatedItems;
        skipped += summary.skippedItems;

        final stepProgress = files.length > 1
            ? (idx + 1.0) / files.length
            : 0.9;
        state = state.copyWith(progress: stepProgress);
      }

      stopwatch.stop();
      final totalSummary = ImportSummary(
        totalFound: totalFound,
        newItemsImported: newImported,
        updatedItems: updated,
        skippedItems: skipped,
        duration: stopwatch.elapsed,
      );

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.completed,
        statusMessage: 'Takeout imported successfully!',
        progress: 1.0,
        lastImportSummary: totalSummary,
      );

      ref.invalidate(availableSubredditsProvider);
      ref.invalidate(availableAuthorsProvider);
      ref.invalidate(availableAuthorsWithCountsProvider);
      ref.invalidate(availableFlairsProvider);

      final settings = ref.read(settingsViewModelProvider);
      final shouldEnrich = settings.autoEnrichOnImport && newImported > 0;
      if (shouldEnrich) {
        ref.read(enrichmentViewModelProvider.notifier).startEnrichment();
      }

      return totalSummary;
    } catch (e) {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.failed,
        errorMessage: 'Import failed: $e',
        clearProgress: true,
      );
      return null;
    } finally {
      _releaseLock();
    }
  }

  Future<ImportSummary?> pullSavedFromReddit() async {
    if (!_acquireLock()) return null;
    try {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.running,
        activeType: ImportExportType.redditSync,
        statusMessage: 'Connecting to Reddit...',
        clearProgress: true,
        clearError: true,
        clearSummary: true,
        clearSavedFilePath: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      final summary = await repo.pullSavedFromReddit(
        onProgress: (count, status) {
          state = state.copyWith(
            statusMessage: status,
            cardStatus: ImportExportCardStatus.running,
          );
        },
      );

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.completed,
        statusMessage: 'Sync completed successfully!',
        progress: 1.0,
        lastImportSummary: summary,
      );

      try {
        final redditApi = ref.read(redditApiServiceProvider);
        final userResult = await redditApi.fetchMyUsername();
        if (userResult.username != null) {
          ref
              .read(settingsViewModelProvider.notifier)
              .setRedditUsername(userResult.username);
        }
      } catch (_) {}

      ref.invalidate(availableSubredditsProvider);
      ref.invalidate(availableAuthorsProvider);
      ref.invalidate(availableAuthorsWithCountsProvider);
      ref.invalidate(availableFlairsProvider);

      final settings = ref.read(settingsViewModelProvider);
      final shouldEnrich =
          settings.autoEnrichOnImport && summary.newItemsImported > 0;
      if (shouldEnrich) {
        ref.read(enrichmentViewModelProvider.notifier).startEnrichment();
      }

      return summary;
    } catch (e) {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.failed,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearProgress: true,
      );
      return null;
    } finally {
      _releaseLock();
    }
  }

  Future<String?> exportLibrary({
    required bool asJson,
    bool includeArchived = true,
  }) async {
    if (!_acquireLock()) return null;
    try {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.running,
        activeType: ImportExportType.export,
        statusMessage: 'Exporting data...',
        clearProgress: true,
        clearError: true,
        clearSummary: true,
        clearSavedFilePath: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);

      final filter = includeArchived
          ? const FilterCriteria(isArchived: null)
          : const FilterCriteria(isArchived: false);
      final allItems = await repo.watchSavedItems(filter).first;

      if (allItems.isEmpty) {
        state = state.copyWith(
          cardStatus: ImportExportCardStatus.failed,
          errorMessage: 'No items in library to export.',
        );
        return null;
      }

      final subreddits = asJson ? await repo.getAllSubreddits() : null;
      final service = ref.read(backupExportServiceProvider);
      final Uint8List bytes = asJson
          ? service.exportToJsonBytes(allItems, subreddits: subreddits)
          : service.exportToCsvBytes(allItems);

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final ext = asJson ? 'json' : 'csv';
      final fileName = 'savedex_export_$dateStr.$ext';
      final mimeType = asJson ? 'application/json' : 'text/csv';

      final savedDisplayPath = await _saveFilePickerResult(
        dialogTitle: 'Save ${asJson ? "JSON" : "CSV"} Export',
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );

      if (savedDisplayPath == null) {
        return null;
      }

      state = state.copyWith(
        cardStatus: ImportExportCardStatus.completed,
        statusMessage: 'Export saved successfully!',
        lastSavedFilePath: savedDisplayPath,
      );
      return savedDisplayPath;
    } catch (e) {
      state = state.copyWith(
        cardStatus: ImportExportCardStatus.failed,
        errorMessage: 'Export failed: $e',
      );
      return null;
    } finally {
      _releaseLock();
    }
  }
}
