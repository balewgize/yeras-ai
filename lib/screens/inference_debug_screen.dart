import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/inference.dart';
import '../providers/inference_providers.dart';
import '../utils/format.dart';
import '../widgets/section_header.dart';

class InferenceDebugScreen extends ConsumerStatefulWidget {
  const InferenceDebugScreen({super.key, required this.modelId});

  final String modelId;

  @override
  ConsumerState<InferenceDebugScreen> createState() =>
      _InferenceDebugScreenState();
}

class _InferenceDebugScreenState extends ConsumerState<InferenceDebugScreen> {
  @override
  void initState() {
    super.initState();
    // Defer past the first frame: run() updates provider state, which is
    // illegal synchronously inside initState while the tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(inferenceDebugControllerProvider(widget.modelId).notifier).run();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inferenceDebugControllerProvider(widget.modelId));
    final controller = ref.read(
      inferenceDebugControllerProvider(widget.modelId).notifier,
    );
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final model = state.model;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug inference')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          const SectionHeader('Model'),
          const SizedBox(height: 8),
          Text(
            model?.modelName ?? 'Loading…',
            style: textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (model != null) ...[
            const SizedBox(height: 4),
            Text(
              '${formatBytes(model.fileBytes)} · ${model.filePath}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const SectionHeader('Engine'),
          const SizedBox(height: 8),
          Text(
            model?.acceleratorLabel ?? 'Detecting accelerator…',
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            model == null
                ? 'Context windows are set at load time.'
                : 'Context ${model.contextSize} tokens · max 128 output tokens',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Prompt'),
          const SizedBox(height: 8),
          _Box(child: SelectableText(debugPrompt, style: textTheme.bodySmall)),
          const SizedBox(height: 20),
          const SectionHeader('Output'),
          const SizedBox(height: 8),
          _Box(
            minHeight: 120,
            child: state.output.isEmpty && state.stage != InferenceStage.error
                ? Text(
                    _statusText(state),
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : SelectableText(
                    state.output.isEmpty
                        ? (state.errorMessage ?? 'No output.')
                        : state.output,
                    style: textTheme.bodySmall?.copyWith(
                      color: state.output.isEmpty ? scheme.error : null,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            _summaryText(state),
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (state.stage == InferenceStage.generating)
                TextButton(
                  onPressed: controller.stop,
                  child: const Text('Stop'),
                )
              else if (state.stage == InferenceStage.done ||
                  state.stage == InferenceStage.error)
                FilledButton.tonal(
                  onPressed: controller.run,
                  child: const Text('Run again'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(InferenceDebugState state) {
    return switch (state.stage) {
      InferenceStage.loading => 'Loading model…',
      InferenceStage.generating => 'Generating…',
      InferenceStage.done => 'Done.',
      _ => 'Waiting to run.',
    };
  }

  String _summaryText(InferenceDebugState state) {
    if (state.stage == InferenceStage.done) {
      final speed = state.tokensPerSecond;
      final tokens = state.completionTokens;
      if (speed != null && tokens != null) {
        return 'Done · $tokens tokens · ${speed.toStringAsFixed(1)} tok/s';
      }
      return 'Done.';
    }
    if (state.stage == InferenceStage.generating) return 'Generating…';
    if (state.stage == InferenceStage.loading) return 'Loading model…';
    return '';
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.child, this.minHeight});

  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
