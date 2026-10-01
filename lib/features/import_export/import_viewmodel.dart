import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/features/enrichment/enrichment_viewmodel.dart';
import 'package:savedex/features/search/search_viewmodel.dart';
import 'package:savedex/features/settings/settings_viewmodel.dart';

class ImportExportState {
  final bool isImporting;
  final bool isExporting;
  final String? statusMessage;
  final ImportSummary? lastImportSummary;
  final String? errorMessage;

  const ImportExportState({
    this.isImporting = false,
    this.isExporting = false,
    this.statusMessage,
    this.lastImportSummary,
    this.errorMessage,
  });

  ImportExportState copyWith({
    bool? isImporting,
    bool? isExporting,
    String? statusMessage,
    ImportSummary? lastImportSummary,
    String? errorMessage,
    bool clearStatus = false,
    bool clearError = false,
  }) {
    return ImportExportState(
      isImporting: isImporting ?? this.isImporting,
      isExporting: isExporting ?? this.isExporting,
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

  Future<ImportSummary?> pickAndImportFiles() async {
    try {
      final files = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'zip'],
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

        ImportSummary summary;
        if (pickedFile.path != null) {
          final file = File(pickedFile.path!);
          final bytes = await file.readAsBytes();
          if (pickedFile.name.toLowerCase().endsWith('.zip')) {
            summary = await repo.importFromZip(bytes);
          } else {
            final content = utf8.decode(bytes, allowMalformed: true);
            summary = await repo.importFromCsvContent(content, pickedFile.name);
          }
        } else {
          continue;
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
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  //TODO
  Future<String?> exportLibrary({
    required bool asJson,
    bool includeArchived = true,
  }) async {
    state = state.copyWith(
      isExporting: true,
      statusMessage: 'Generating export...',
    );
    try {
      final repo = ref.read(savedItemRepositoryProvider);
      final exportService = ref.read(backupExportServiceProvider);

      final filter = includeArchived
          ? const FilterCriteria(isArchived: null)
          : const FilterCriteria(isArchived: false);
      final allItems = await repo.watchSavedItems(filter).first;

      String output;
      if (asJson) {
        output = exportService.exportToJson(allItems);
      } else {
        output = exportService.exportToCsv(allItems);
      }

      state = state.copyWith(isExporting: false, clearStatus: true);
      return output;
    } catch (e) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: 'Export failed: $e',
      );
      return null;
    }
  }
}
