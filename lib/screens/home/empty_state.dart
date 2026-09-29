import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/chat_providers.dart';

class EmptyState extends ConsumerWidget {
  const EmptyState({
    super.key,
    required this.suggestions,
    required this.onSuggestion,
    required this.onBrowse,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloaded = ref.watch(downloadedModelsProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.offline_bolt_outlined,
                color: scheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'How can I help?',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Runs fully offline on your device.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in suggestions)
                  ActionChip(label: Text(s), onPressed: () => onSuggestion(s)),
              ],
            ),
            const SizedBox(height: 24),
            if (downloaded.isEmpty)
              FilledButton.tonal(
                onPressed: onBrowse,
                child: const Text('Browse models'),
              ),
          ],
        ),
      ),
    );
  }
}
