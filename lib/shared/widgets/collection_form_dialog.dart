import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:savedex/core/providers/providers.dart';
import 'package:savedex/data/models/saved_item_model.dart';
import 'package:savedex/shared/widgets/collection_picker_sheet.dart';

Future<int?> showCollectionFormDialog(
  BuildContext context, {
  Collection? initialCollection,
  String? assignItemId,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => CollectionFormDialog(
      initialCollection: initialCollection,
      assignItemId: assignItemId,
    ),
  );
}

class CollectionFormDialog extends ConsumerStatefulWidget {
  final Collection? initialCollection;
  final String? assignItemId;

  const CollectionFormDialog({
    super.key,
    this.initialCollection,
    this.assignItemId,
  });

  @override
  ConsumerState<CollectionFormDialog> createState() =>
      _CollectionFormDialogState();
}

class _CollectionFormDialogState extends ConsumerState<CollectionFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late int _selectedColor;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.initialCollection != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialCollection?.name ?? '',
    );
    _descController = TextEditingController(
      text: widget.initialCollection?.description ?? '',
    );
    _selectedColor =
        widget.initialCollection?.colorValue ?? kCollectionPresetColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a collection name');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(collectionRepositoryProvider);
      final desc = _descController.text.trim();
      final descVal = desc.isNotEmpty ? desc : null;

      if (_isEditing) {
        await repo.updateCollection(
          widget.initialCollection!.id,
          name,
          _selectedColor,
          description: descVal,
        );

        if (mounted) {
          Navigator.of(context).pop(widget.initialCollection!.id);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('Updated collection "$name"'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
        }
      } else {
        final id = await repo.createCollection(
          name,
          _selectedColor,
          description: descVal,
        );

        if (id <= 0) {
          setState(() {
            _isSaving = false;
            _errorMessage = 'Collection with this name may already exist';
          });
          return;
        }

        if (widget.assignItemId != null) {
          await repo.addToCollection(widget.assignItemId!, id);
        }

        if (mounted) {
          Navigator.of(context).pop(id);
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  widget.assignItemId != null
                      ? 'Added to collection "$name"'
                      : 'Created collection "$name"',
                ),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Error saving collection: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(
            _isEditing
                ? Icons.edit_note_rounded
                : Icons.create_new_folder_rounded,
            color: Color(_selectedColor),
          ),
          const SizedBox(width: 10),
          Text(_isEditing ? 'Edit Collection' : 'New Collection'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Collection Name',
                border: const OutlineInputBorder(),
                errorText: _errorMessage,
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            Text(
              'Color Tag',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCollectionPresetColors.map((colorVal) {
                final isSelected = colorVal == _selectedColor;
                final color = Color(colorVal);

                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = colorVal),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
