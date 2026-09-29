import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation.dart';
import '../../providers/chat_providers.dart';
import '../model_catalog_screen.dart';
import '../settings_screen.dart';
import 'chat_input.dart';
import 'empty_state.dart';
import 'home_drawer.dart';
import 'message_list.dart';
import 'model_picker.dart';
import 'status_area.dart';

/// Home screen modeled on Gemini / Claude / ChatGPT mobile apps.
///
/// Layout:
/// - Top bar: menu (left) opens the drawer, tappable model name in the
///   title opens the model picker, download (right) opens the catalog.
/// - Drawer: New chat + conversation list + Settings.
/// - Center: chat bubbles, or the greeting empty state before the first
///   message.
/// - Bottom: status line (loading / tok/s / errors) + rounded composer.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _hasText = false;

  /// Stick-to-bottom: true when the user is already at (or near) the
  /// bottom. Streaming autoscroll respects this so reading history
  /// isn't yanked away; sending a message re-sticks.
  bool _stickToBottom = true;

  static const _suggestions = <String>[
    'Explain a concept',
    'Write a message',
    'Brainstorm ideas',
    'Summarize text',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
    _scroll.addListener(_updateStick);
  }

  void _updateStick() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // maxScrollExtent is 0 when content fits; count that as stuck.
    _stickToBottom =
        !position.hasContentDimensions ||
        position.pixels >= position.maxScrollExtent - 120;
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateStick);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openModels() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelCatalogScreen()),
    );
  }

  void _showModelPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ModelPickerSheet(
        onBrowse: () {
          Navigator.of(context).pop();
          _openModels();
        },
      ),
    );
  }

  void _openSettings() {
    // Close the drawer first when invoked from inside it.
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  void _openModelsFromDrawer() {
    // Close the drawer first when invoked from inside it.
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ModelCatalogScreen()),
    );
  }

  void _newChat() {
    Navigator.of(context).pop();
    _controller.clear();
    ref.read(chatControllerProvider.notifier).newChat();
  }

  void _openConversation(String id) {
    Navigator.of(context).pop();
    _controller.clear();
    // Sync state update inside: the screen swaps conversation immediately.
    ref.read(chatControllerProvider.notifier).openConversation(id);
  }

  Future<void> _renameConversation(Conversation conversation) async {
    final nameController =
        TextEditingController(text: conversation.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          maxLength: 100,
          onSubmitted: (_) =>
              Navigator.of(dialogContext).pop(nameController.text),
          decoration: const InputDecoration(hintText: 'Chat name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(nameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    nameController.dispose();
    final name = result?.trim();
    if (!mounted || name == null || name.isEmpty) return;
    await ref
        .read(chatControllerProvider.notifier)
        .renameConversation(conversation.id, name);
  }

  Future<void> _deleteConversation(Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          '"${conversation.displayName}" will be permanently deleted. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await ref
        .read(chatControllerProvider.notifier)
        .deleteConversation(conversation.id);
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(chatControllerProvider.notifier).send(text);
  }

  void _stop() {
    ref.read(chatControllerProvider.notifier).stop();
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scroll.hasClients) return;
    if (animate) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  void _stickAndScroll() {
    _stickToBottom = true;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animate: true));
  }

  void _scrollIfStuck({bool animate = false}) {
    if (!_stickToBottom) return;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animate: animate));
  }

  @override
  Widget build(BuildContext context) {
    // New message (user send / assistant bubble created): always follow.
    ref.listen(chatControllerProvider.select((chat) => chat.messages.length),
        (_, _) {
      _stickAndScroll();
    });
    // Streaming tokens update the last message text in place — length
    // doesn't change, so follow each chunk while stuck to the bottom.
    // jumpTo (not animateTo) avoids fighting the animation every token.
    ref.listen(
      chatControllerProvider.select(
        (chat) => chat.messages.isEmpty ? 0 : chat.messages.last.text.length,
      ),
      (_, _) {
        if (ref.read(chatControllerProvider).stage != ChatStage.generating) {
          return;
        }
        _scrollIfStuck();
      },
    );
    final chat = ref.watch(chatControllerProvider);

    return Scaffold(
      drawer: HomeDrawer(
        onNewChat: _newChat,
        onOpenConversation: _openConversation,
        onRenameConversation: _renameConversation,
        onDeleteConversation: _deleteConversation,
        onModels: _openModelsFromDrawer,
        onSettings: _openSettings,
      ),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: ModelPickerTitle(onTap: _showModelPicker),
        actions: const [
          ModelLoadButton(),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: chat.messages.isEmpty
                  ? EmptyState(
                      suggestions: _suggestions,
                      onSuggestion: (s) {
                        _controller.text = s;
                        _controller.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: s.length),
                        );
                      },
                      onBrowse: _openModels,
                    )
                  : MessageList(
                      scrollController: _scroll,
                      messages: chat.messages,
                      streaming: chat.stage == ChatStage.generating,
                      showInterrupted: chat.wasInterrupted,
                    ),
            ),
            StatusArea(
              onRetry: () =>
                  ref.read(chatControllerProvider.notifier).retry(),
              onBrowse: _openModels,
              onNewChat: () =>
                  ref.read(chatControllerProvider.notifier).newChat(),
              onLoad: () {
                HapticFeedback.lightImpact();
                ref.read(chatControllerProvider.notifier).loadActiveModel();
              },
            ),
            ChatInput(
              controller: _controller,
              hasText: _hasText,
              busy: chat.isBusy,
              generating: chat.stage == ChatStage.generating,
              isLoaded: ref.watch(isModelLoadedProvider),
              activeModelName: ref.watch(
                activeModelProvider.select((model) => model?.name),
              ),
              onSend: _send,
              onStop: _stop,
            ),
          ],
        ),
      ),
    );
  }
}
