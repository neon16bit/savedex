import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/data/services/backup_export_service.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class ImportExportState {
  final bool isImporting;
  final bool isSyncingReddit;
  final bool isExporting;
  final bool isBackingUp;
  final bool isRestoring;
  final String? statusMessage;
  final ImportSummary? lastImportSummary;
  final String? errorMessage;

  const ImportExportState({
    this.isImporting = false,
    this.isSyncingReddit = false,
    this.isExporting = false,
    this.isBackingUp = false,
    this.isRestoring = false,
    this.statusMessage,
    this.lastImportSummary,
    this.errorMessage,
  });

  bool get isBusy =>
      isImporting ||
      isSyncingReddit ||
      isExporting ||
      isBackingUp ||
      isRestoring;

  ImportExportState copyWith({
    bool? isImporting,
    bool? isSyncingReddit,
    bool? isExporting,
    bool? isBackingUp,
    bool? isRestoring,
    String? statusMessage,
    ImportSummary? lastImportSummary,
    String? errorMessage,
    bool clearStatus = false,
    bool clearError = false,
  }) {
    return ImportExportState(
      isImporting: isImporting ?? this.isImporting,
      isSyncingReddit: isSyncingReddit ?? this.isSyncingReddit,
      isExporting: isExporting ?? this.isExporting,
      isBackingUp: isBackingUp ?? this.isBackingUp,
      isRestoring: isRestoring ?? this.isRestoring,
      statusMessage: clearStatus ? null : (statusMessage ?? this.statusMessage),
      lastImportSummary: lastImportSummary ?? this.lastImportSummary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final importExportViewModelProvider =
    NotifierProvider<ImportExportViewModel, ImportExportState>(() {
      return ImportExportViewModel();
    });

class ImportExportViewModel extends Notifier<ImportExportState> {
  @override
  ImportExportState build() {
    return const ImportExportState();
  }

  Future<String?> createBackup() async {
    state = state.copyWith(
      isBackingUp: true,
      statusMessage: 'Creating backup...',
      clearError: true,
      clearStatus: false,
    );

    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final allItems = await repo
          .watchSavedItems(const FilterCriteria(isArchived: null))
          .first;

      if (allItems.isEmpty) {
        state = state.copyWith(
          isBackingUp: false,
          errorMessage: 'No items in library to backup.',
        );
        return null;
      }

      // background isolate
      final bytes = await Isolate.run(() {
        final service = BackupExportService();
        return service.createBackup(allItems);
      });

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final fileName = 'savedex_backup_$dateStr.savedex';

      final saveUri = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Save Savedex Backup',
        fileName: fileName,
        mimeType: 'application/octet-stream',
        bytes: bytes,
      );

      if (saveUri == null) {
        state = state.copyWith(isBackingUp: false, clearStatus: true);
        return null;
      }

      String savedDisplayPath;
      if (saveUri.scheme == 'file') {
        final filePath = saveUri.toFilePath();
        final file = File(filePath);
        if (!file.existsSync() || file.lengthSync() == 0) {
          await file.writeAsBytes(bytes);
        }
        savedDisplayPath = filePath;
      } else {
        savedDisplayPath = saveUri.pathSegments.isNotEmpty
            ? saveUri.pathSegments.last
            : fileName;
      }

      state = state.copyWith(
        isBackingUp: false,
        statusMessage: 'Backup saved successfully!',
      );
      return savedDisplayPath;
    } catch (e) {
      state = state.copyWith(
        isBackingUp: false,
        errorMessage: 'Backup failed: $e',
      );
      return null;
    }
  }

  Future<ImportSummary?> restoreBackup() async {
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
          isRestoring: false,
          errorMessage: 'Please select a valid .savedex, .json, or .csv file.',
        );
        return null;
      }

      state = state.copyWith(
        isRestoring: true,
        statusMessage: 'Restoring library...',
        clearError: true,
      );

      if (pickedFile.path == null) {
        state = state.copyWith(
          isRestoring: false,
          errorMessage: 'Could not access file path.',
        );
        return null;
      }

      final file = File(pickedFile.path!);
      final bytes = await file.readAsBytes();

      final fileType = BackupExportService.detectFileType(
        filename: pickedFile.name,
        bytes: bytes,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      ImportSummary summary;

      switch (fileType) {
        case BackupFileType.savedex:
        case BackupFileType.json:
          final payload = await Isolate.run(() {
            final service = BackupExportService();
            return service.parseBackup(bytes);
          });
          summary = await repo.restoreFromPayload(
            payload,
            sourceName: pickedFile.name,
          );
          break;

        case BackupFileType.savedexCsv:
          final content = utf8.decode(bytes, allowMalformed: true);
          final payload = await Isolate.run(() {
            final service = BackupExportService();
            return service.parseSavedexCsv(content);
          });
          summary = await repo.restoreFromPayload(
            payload,
            sourceName: pickedFile.name,
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
        isRestoring: false,
        statusMessage: 'Restore completed successfully!',
        lastImportSummary: summary,
      );

      ref.invalidate(availableSubredditsProvider);
      ref.invalidate(availableAuthorsProvider);
      ref.invalidate(availableAuthorsWithCountsProvider);
      ref.invalidate(availableFlairsProvider);

      final settings = ref.read(settingsViewModelProvider);
      if (settings.autoEnrichOnImport && summary.newItemsImported > 0) {
        ref.read(enrichmentViewModelProvider.notifier).startEnrichment();
      }

      return summary;
    } catch (e) {
      final msg = e
          .toString()
          .replaceFirst('FormatException: ', '')
          .replaceFirst('Exception: ', '');
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Restore failed: $msg',
      );
      return null;
    }
  }

  Future<ImportSummary?> pickAndImportFiles() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'zip'],
      );

      if (files.isEmpty) {
        return null;
      }

      state = state.copyWith(
        isImporting: true,
        statusMessage: 'Reading selected files...',
        clearError: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      int totalFound = 0;
      int newImported = 0;
      int updated = 0;
      int skipped = 0;
      final stopwatch = Stopwatch()..start();

      for (final pickedFile in files) {
        state = state.copyWith(statusMessage: 'Parsing ${pickedFile.name}...');

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
        isImporting: false,
        statusMessage: 'Import completed successfully!',
        lastImportSummary: totalSummary,
      );

      ref.invalidate(availableSubredditsProvider);
      ref.invalidate(availableAuthorsProvider);
      ref.invalidate(availableAuthorsWithCountsProvider);
      ref.invalidate(availableFlairsProvider);

      final settings = ref.read(settingsViewModelProvider);
      if (settings.autoEnrichOnImport && newImported > 0) {
        ref.read(enrichmentViewModelProvider.notifier).startEnrichment();
      }

      return totalSummary;
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        errorMessage: 'Import failed: $e',
      );
      return null;
    }
  }

  Future<ImportSummary?> pullSavedFromReddit() async {
    try {
      state = state.copyWith(
        isImporting: true,
        isSyncingReddit: true,
        statusMessage: 'Connecting to Reddit...',
        clearError: true,
      );

      final repo = ref.read(savedItemRepositoryProvider);
      final summary = await repo.pullSavedFromReddit(
        onProgress: (count, status) {
          state = state.copyWith(statusMessage: status);
        },
      );

      state = state.copyWith(
        isImporting: false,
        isSyncingReddit: false,
        statusMessage: 'Sync completed successfully!',
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

      return summary;
    } catch (e) {
      state = state.copyWith(
        isImporting: false,
        isSyncingReddit: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  Future<String?> exportLibrary({
    required bool asJson,
    bool includeArchived = true,
  }) async {
    state = state.copyWith(
      isExporting: true,
      statusMessage: 'Exporting data...',
      clearError: true,
    );
    try {
      final repo = ref.read(savedItemRepositoryProvider);

      final filter = includeArchived
          ? const FilterCriteria(isArchived: null)
          : const FilterCriteria(isArchived: false);
      final allItems = await repo.watchSavedItems(filter).first;

      if (allItems.isEmpty) {
        state = state.copyWith(
          isExporting: false,
          errorMessage: 'No items in library to export.',
        );
        return null;
      }

      final String output = await Isolate.run(() {
        final service = BackupExportService();
        return asJson
            ? service.exportToJson(allItems)
            : service.exportToCsv(allItems);
      });

      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final ext = asJson ? 'json' : 'csv';
      final fileName = 'savedex_export_$dateStr.$ext';
      final bytes = Uint8List.fromList(utf8.encode(output));

      final mimeType = asJson ? 'application/json' : 'text/csv';
      final saveUri = await FilePickerPlatform.instance.saveFile(
        dialogTitle: 'Save ${asJson ? "JSON" : "CSV"} Export',
        fileName: fileName,
        mimeType: mimeType,
        bytes: bytes,
      );

      if (saveUri == null) {
        state = state.copyWith(isExporting: false, clearStatus: true);
        return null;
      }

      String savedDisplayPath;
      if (saveUri.scheme == 'file') {
        final filePath = saveUri.toFilePath();
        final file = File(filePath);
        if (!file.existsSync() || file.lengthSync() == 0) {
          await file.writeAsBytes(bytes);
        }
        savedDisplayPath = filePath;
      } else {
        savedDisplayPath = saveUri.pathSegments.isNotEmpty
            ? saveUri.pathSegments.last
            : fileName;
      }

      state = state.copyWith(isExporting: false, clearStatus: true);
      return savedDisplayPath;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Export failed: $e',
      );
      return null;
    }
  }
}
