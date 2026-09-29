import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/conversation.dart';
import '../../providers/chat_history_providers.dart';
import '../../providers/chat_providers.dart';
import '../../utils/format.dart';

class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({
    super.key,
    required this.onNewChat,
    required this.onOpenConversation,
    required this.onRenameConversation,
    required this.onDeleteConversation,
    required this.onModels,
    required this.onSettings,
  });

  final VoidCallback onNewChat;
  final ValueChanged<String> onOpenConversation;
  final ValueChanged<Conversation> onRenameConversation;
  final ValueChanged<Conversation> onDeleteConversation;
  final VoidCallback onModels;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final downloadedCount = ref.watch(downloadedModelsProvider).length;
    final conversations = ref.watch(conversationsProvider);
    final activeId = ref.watch(
      chatControllerProvider.select((chat) => chat.activeConversationId),
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'StayLocal',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: FilledButton.tonalIcon(
                onPressed: onNewChat,
                icon: const Icon(Icons.edit_square, size: 18),
                label: const Text('New chat'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'CONVERSATIONS',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No chats yet', style: textTheme.titleSmall),
                              const SizedBox(height: 4),
                              Text(
                                'Start a conversation to see it here.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return ListTile(
                          title: Text(
                            conversation.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            formatRelativeTime(conversation.updatedAt),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          selected: conversation.id == activeId,
                          selectedTileColor: scheme.secondaryContainer,
                          onTap: () => onOpenConversation(conversation.id),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Chat options',
                            icon: const Icon(Icons.more_vert, size: 20),
                            onSelected: (value) {
                              if (value == 'rename') {
                                onRenameConversation(conversation);
                              } else if (value == 'delete') {
                                onDeleteConversation(conversation);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.layers_outlined),
              title: const Text('Models'),
              trailing: downloadedCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$downloadedCount',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
              onTap: onModels,
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}
