import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:staylocal/data/repositories/chat_history_repository.dart';
import 'package:staylocal/data/repositories/device_capability_repository.dart';
import 'package:staylocal/data/repositories/model_catalog_repository.dart';
import 'package:staylocal/main.dart';
import 'package:staylocal/models/chat.dart';
import 'package:staylocal/models/conversation.dart';
import 'package:staylocal/models/device_capabilities.dart';
import 'package:staylocal/models/model_download.dart';
import 'package:staylocal/providers/chat_history_providers.dart';
import 'package:staylocal/providers/device_capability_providers.dart';
import 'package:staylocal/providers/inference_providers.dart';
import 'package:staylocal/providers/model_catalog_providers.dart';
import 'package:staylocal/providers/model_download_providers.dart';
import 'package:staylocal/screens/home/message_list.dart';
import 'package:staylocal/utils/format.dart';

import 'fakes/fake_chat_history_repository.dart';
import 'fakes/fake_inference_repository.dart';
import 'fakes/fake_model_download_repository.dart';

const int _gb = 1024 * 1024 * 1024;

class _MidRangeDeviceCapabilityRepository
    implements DeviceCapabilityRepository {
  const _MidRangeDeviceCapabilityRepository();

  @override
  Future<MemoryInfo> memory() async =>
      MemoryInfo(totalBytes: 8 * _gb, availableBytes: 4 * _gb);

  @override
  Future<StorageInfo> storage() async =>
      StorageInfo(freeBytes: 32 * _gb, totalBytes: 128 * _gb);

  @override
  Future<GpuProbe> gpu() async =>
      const GpuProbe(renderer: 'Adreno (TM) 810', vulkanVersion: '1.1');

  @override
  Future<DeviceIdentity> identity() async => const DeviceIdentity(
        manufacturer: 'Samsung',
        model: 'SM-A366B',
        board: 'A36XQ',
        hardware: 'qcom',
        abis: ['arm64-v8a'],
        osVersion: 'Android 16',
      );
}

const String _fixtureCatalog = '''
[
  {
    "id": "llama-3.2-1b",
    "name": "Llama 3.2 1B",
    "parameter_count_label": "1B",
    "parameter_count_in_billions": 1,
    "quantization": "Q4_K_M",
    "context_length": 8192,
    "size_mb": 808,
    "min_ram_gb": 4,
    "description": "Test fixture",
    "download_url": "https://example.com/a.gguf"
  },
  {
    "id": "qwen2.5-1.5b",
    "name": "Qwen 2.5 1.5B",
    "parameter_count_label": "1.5B",
    "parameter_count_in_billions": 1.5,
    "quantization": "Q4_K_M",
    "context_length": 8192,
    "size_mb": 1000,
    "min_ram_gb": 6,
    "description": "Test fixture",
    "download_url": "https://example.com/b.gguf"
  }
]
''';

ModelDownloadState _ready(String path, int bytes) => ModelDownloadState(
      stage: DownloadStage.ready,
      receivedBytes: bytes,
      totalBytes: bytes,
      filePath: path,
    );

Future<void> _pumpApp(
  WidgetTester tester, {
  required FakeModelDownloadRepository downloads,
  required FakeInferenceRepository inference,
  FakeChatHistoryRepository? history,
  bool useRealHistory = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deviceCapabilityRepositoryProvider.overrideWithValue(
          const _MidRangeDeviceCapabilityRepository(),
        ),
        modelCatalogRepositoryProvider.overrideWithValue(
          StaticModelCatalogRepository(
            readCatalogJson: () async => _fixtureCatalog,
          ),
        ),
        modelDownloadRepositoryProvider.overrideWithValue(downloads),
        inferenceRepositoryProvider.overrideWithValue(inference),
        // Real repository = SharedPreferences-backed, using the mock
        // store shared across scopes inside one test (relaunch tests).
        if (!useRealHistory && history != null)
          chatHistoryRepositoryProvider.overrideWithValue(history),
      ],
      child: const StayLocalApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

/// Top-bar power icon that loads/unloads the active model.
Finder _powerButton(String verb) => find.byWidgetPredicate(
      (widget) =>
          widget is IconButton &&
          (widget.tooltip ?? '').startsWith('$verb ') &&
          widget.onPressed != null,
    );

/// Inline Load action above the composer (needsLoad state).
Finder _loadCta(String modelName) => find.ancestor(
      of: find.textContaining('Load $modelName'),
      matching: find.byType(FilledButton),
    );

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

/// Taps the per-chat ⋮ menu and picks the [item] entry.
Future<void> _chatMenuAction(
  WidgetTester tester,
  String item, {
  int menuIndex = 0,
}) async {
  // Keyboard hygiene for route transitions: popping the menu/dialog while
  // a TextField is focused trips scheduler assertions in tests (the caret
  // timer fires on a detached render object). Real devices are unaffected.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.tap(find.byTooltip('Chat options').at(menuIndex));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

/// Fully unmounts the app, disposing every provider container — the
/// test stand-in for a force-close. Only the mock SharedPreferences
/// store survives, exactly like real disk storage.
Future<void> _killApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('conversation model', () {
    Conversation conversation({
      String? title,
      List<ChatMessage> messages = const [],
    }) =>
        Conversation(
          id: 'c1',
          title: title,
          modelId: 'llama-3.2-1b',
          createdAt: DateTime(2026, 1, 2, 3, 4, 5),
          updatedAt: DateTime(2026, 1, 3, 4, 5, 6),
          messages: messages,
        );

    test('displayName prefers the explicit rename', () {
      expect(
        conversation(
          title: 'Trip plan',
          messages: const [ChatMessage(role: ChatRole.user, text: 'Hello')],
        ).displayName,
        'Trip plan',
      );
    });

    test('displayName derives from the first user message', () {
      expect(
        conversation(
          messages: const [
            ChatMessage(role: ChatRole.user, text: '  What is  a   llama? '),
            ChatMessage(role: ChatRole.assistant, text: 'An animal.'),
          ],
        ).displayName,
        'What is a llama?',
      );
    });

    test('displayName truncates long first messages', () {
      final long = 'x' * 60;
      expect(
        conversation(
          messages: [ChatMessage(role: ChatRole.user, text: long)],
        ).displayName,
        '${'x' * Conversation.maxTitleLength}…',
      );
    });

    test('displayName falls back to New chat', () {
      expect(conversation().displayName, 'New chat');
      expect(
        conversation(
          messages: const [ChatMessage(role: ChatRole.assistant, text: 'Hi')],
        ).displayName,
        'New chat',
      );
    });

    test('json round-trips every field', () {
      final conversation = Conversation(
        id: 'abc',
        title: 'Renamed',
        modelId: 'llama-3.2-1b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
        messages: const [
          ChatMessage(role: ChatRole.user, text: 'Hello'),
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Hi there',
            tokensPerSecond: 21.5,
          ),
        ],
        generating: true,
        interrupted: true,
      );
      final restored = Conversation.fromJson(
        jsonDecode(jsonEncode(conversation.toJson()))
            as Map<String, Object?>,
      );
      expect(restored.id, 'abc');
      expect(restored.title, 'Renamed');
      expect(restored.modelId, 'llama-3.2-1b');
      expect(
        restored.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(
        restored.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000001000),
      );
      expect(restored.messages.length, 2);
      expect(restored.messages[0].role, ChatRole.user);
      expect(restored.messages[0].text, 'Hello');
      expect(restored.messages[1].text, 'Hi there');
      expect(restored.messages[1].tokensPerSecond, 21.5);
      expect(restored.generating, isTrue);
      expect(restored.interrupted, isTrue);
    });

    test('fromJson rejects conversations without identity', () {
      expect(
        () => Conversation.fromJson(const {'modelId': 'x'}),
        throwsFormatException,
      );
      expect(
        () => Conversation.fromJson(const {'id': 'x'}),
        throwsFormatException,
      );
    });
  });

  group('shared preferences repository', () {
    test('saves and loads newest-first', () async {
      final repository = SharedPreferencesChatHistoryRepository();
      final older = Conversation(
        id: 'older',
        modelId: 'llama-3.2-1b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        messages: const [ChatMessage(role: ChatRole.user, text: 'First')],
      );
      final newer = Conversation(
        id: 'newer',
        title: 'Second',
        modelId: 'qwen2.5-1.5b',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(3000),
        messages: const [
          ChatMessage(role: ChatRole.user, text: 'Second chat'),
          ChatMessage(
            role: ChatRole.assistant,
            text: 'Reply',
            tokensPerSecond: 10.0,
          ),
        ],
      );
      await repository.saveConversation(older);
      await repository.saveConversation(newer);

      final loaded = await SharedPreferencesChatHistoryRepository()
          .loadConversations();
      expect(loaded.map((c) => c.id), ['newer', 'older']);
      expect(loaded.first.displayName, 'Second');
      expect(loaded.first.messages[1].tokensPerSecond, 10.0);

      // Updating an existing conversation keeps a single entry.
      await repository.saveConversation(
        older.copyWith(
          messages: const [
            ChatMessage(role: ChatRole.user, text: 'First'),
            ChatMessage(role: ChatRole.assistant, text: 'Answered'),
          ],
          updatedAt: DateTime.fromMillisecondsSinceEpoch(9999),
        ),
      );
      final reloaded =
          await repository.loadConversations();
      expect(reloaded.map((c) => c.id), ['older', 'newer']);
      expect(reloaded.first.messages.length, 2);
    });

    test('a mid-generation conversation loads as interrupted', () async {
      final repository = SharedPreferencesChatHistoryRepository();
      await repository.saveConversation(
        Conversation(
          id: 'cut',
          modelId: 'llama-3.2-1b',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          messages: const [ChatMessage(role: ChatRole.user, text: 'Hi')],
          generating: true,
        ),
      );

      final loaded = await repository.loadConversations();
      expect(loaded.length, 1);
      expect(loaded.first.generating, isFalse);
      expect(loaded.first.interrupted, isTrue);
      expect(loaded.first.messages.single.text, 'Hi');
    });

    test('delete removes exactly that conversation', () async {
      final repository = SharedPreferencesChatHistoryRepository();
      for (final id in ['a', 'b', 'c']) {
        await repository.saveConversation(
          Conversation(
            id: id,
            modelId: 'llama-3.2-1b',
            createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
          ),
        );
      }
      await repository.deleteConversation('b');
      // Deleting twice is a quiet no-op.
      await repository.deleteConversation('b');
      final loaded = await repository.loadConversations();
      expect(loaded.map((c) => c.id), ['a', 'c']);
    });

    test('corrupt storage degrades instead of crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_conversations': 'not json at all',
      });
      expect(
        await SharedPreferencesChatHistoryRepository().loadConversations(),
        isEmpty,
      );

      SharedPreferences.setMockInitialValues(<String, Object>{
        'chat_conversations': jsonEncode([
          {'id': '', 'modelId': 'x'},
          {
            'id': 'good',
            'modelId': 'llama-3.2-1b',
            'createdAt': 1000,
            'updatedAt': 1000,
            'messages': [
              {'role': 'user', 'text': 'Survivor'},
            ],
          },
        ]),
      });
      final loaded =
          await SharedPreferencesChatHistoryRepository().loadConversations();
      expect(loaded.map((c) => c.id), ['good']);
      expect(loaded.first.displayName, 'Survivor');
    });
  });

  group('relative time', () {
    final now = DateTime(2026, 9, 29, 12, 0, 0);

    test('recent buckets', () {
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 5)), now: now),
        'just now',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 3)), now: now),
        '3m ago',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 5)), now: now),
        '5h ago',
      );
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 2)), now: now),
        '2d ago',
      );
    });

    test('older dates fall back to calendar labels', () {
      expect(
        formatRelativeTime(DateTime(2026, 8, 1), now: now),
        'Aug 1',
      );
      expect(
        formatRelativeTime(DateTime(2025, 12, 31), now: now),
        'Dec 31 2025',
      );
    });
  });

  group('drawer flows', () {
    testWidgets('sent chats appear in the drawer and resume on tap',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi'];
      final history = FakeChatHistoryRepository();
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        history: history,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/a.gguf', 808000000));
      downloads.emit('qwen2.5-1.5b', _ready('/cache/b.gguf', 1000000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();

      await _send(tester, 'First question');
      await _send(tester, 'Follow up');
      expect(history.all.length, 1);

      // A new chat starts a second conversation.
      await _openDrawer(tester);
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await _send(tester, 'Second topic');
      expect(history.all.length, 2);

      // Newest first.
      await _openDrawer(tester);
      final tiles = tester.widgetList<ListTile>(find.byType(ListTile));
      final titles = [
        for (final tile in tiles) (tile.title as Text?)?.data,
      ].whereType<String>().toList();
      expect(titles.first, 'Second topic');
      expect(titles, contains('First question'));

      // Resuming restores the old messages on screen.
      await tester.tap(find.text('First question'));
      await tester.pumpAndSettle();
      expect(find.text('First question'), findsOneWidget);
      expect(find.text('Follow up'), findsOneWidget);
      expect(find.text('Hi'), findsWidgets);
    });

    testWidgets('rename sticks across further sends',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi'];
      final history = FakeChatHistoryRepository();
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        history: history,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      await _send(tester, 'Original title');

      await _openDrawer(tester);
      await _chatMenuAction(tester, 'Rename');
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'Trip plan');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Trip plan'), findsOneWidget);

      // Sending more must not revert the rename (regression guard: the
      // controller would otherwise persist its stale working copy).
      await tester.tap(find.text('Trip plan'));
      await tester.pumpAndSettle();
      await _send(tester, 'Another message');
      await _openDrawer(tester);
      expect(find.text('Trip plan'), findsOneWidget);
      expect(history.all.single.title, 'Trip plan');
    });

    testWidgets('delete removes exactly that conversation',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi'];
      final history = FakeChatHistoryRepository();
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        history: history,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      await _send(tester, 'Keep me');
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await _send(tester, 'Delete me');
      expect(history.all.length, 2);

      // Delete the newest (first ⋮ menu) and confirm.
      await _openDrawer(tester);
      await _chatMenuAction(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete'),
        ),
      );
      await tester.pumpAndSettle();

      expect(history.all.length, 1);
      expect(history.all.single.displayName, 'Keep me');
      expect(find.text('Delete me'), findsNothing);
      expect(find.text('Keep me'), findsOneWidget);
    });

    testWidgets('deleting the active conversation clears the screen',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Hi'];
      final history = FakeChatHistoryRepository();
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        history: history,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/model.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      await _send(tester, 'Only chat');

      await _openDrawer(tester);
      await _chatMenuAction(tester, 'Delete');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Delete'),
        ),
      );
      await tester.pumpAndSettle();
      expect(history.all, isEmpty);

      // The screen drops back to the empty state.
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      expect(find.text('How can I help?'), findsOneWidget);
      expect(find.text('Only chat'), findsNothing);
    });
  });

  group('force-close and relaunch (real storage)', () {
    testWidgets('history intact and last chat restored',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..tokenScript = const <String>['Done'];
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        useRealHistory: true,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/a.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();
      await _send(tester, 'Remember this');
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New chat'));
      await tester.pumpAndSettle();
      await _send(tester, 'Second one');

      // Relaunch: kill the process, then boot fresh. Only the mock
      // SharedPreferences survives; downloads are re-scanned from cache
      // (fresh fake, re-emitted ready), exactly like a real force-close.
      await _killApp(tester);
      final relaunchedDownloads = FakeModelDownloadRepository();
      await _pumpApp(
        tester,
        downloads: relaunchedDownloads,
        inference: FakeInferenceRepository(),
        useRealHistory: true,
      );
      relaunchedDownloads.emit(
        'llama-3.2-1b',
        _ready('/cache/a.gguf', 808000000),
      );
      await tester.pumpAndSettle();

      // Last active chat is back on screen, no model loaded yet. The
      // bubble is scoped: the offstage drawer lists the same title.
      expect(
        find.descendant(
          of: find.byType(UserBubble),
          matching: find.text('Second one'),
        ),
        findsOneWidget,
      );
      expect(find.text('Done'), findsOneWidget);
      expect(_loadCta('Llama 3.2 1B'), findsOneWidget);

      // Both conversations survived in the drawer.
      await _openDrawer(tester);
      expect(find.text('Remember this'), findsOneWidget);
      expect(find.text('Second one'), findsNWidgets(2));
    });

    testWidgets('killed mid-reply restores as interrupted and resumes',
        (WidgetTester tester) async {
      final downloads = FakeModelDownloadRepository();
      final inference = FakeInferenceRepository()
        ..chatGate = Completer<void>()
        ..tokenScript = const <String>['partial reply'];
      await _pumpApp(
        tester,
        downloads: downloads,
        inference: inference,
        useRealHistory: true,
      );
      downloads.emit('llama-3.2-1b', _ready('/cache/a.gguf', 808000000));
      await tester.pumpAndSettle();
      await tester.tap(_powerButton('Load'));
      await tester.pumpAndSettle();

      // Start a generation and "kill" the app while it is gated: unmount
      // fully without completing the gate, then boot fresh.
      await tester.enterText(find.byType(TextField), 'Doomed question');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();

      await _killApp(tester);
      final relaunchedDownloads = FakeModelDownloadRepository();
      final resumedInference = FakeInferenceRepository()
        ..tokenScript = const <String>['finally'];
      await _pumpApp(
        tester,
        downloads: relaunchedDownloads,
        inference: resumedInference,
        useRealHistory: true,
      );
      relaunchedDownloads.emit(
        'llama-3.2-1b',
        _ready('/cache/a.gguf', 808000000),
      );
      await tester.pumpAndSettle();

      // Never silent: the user message survived, the interruption is
      // labeled in the status area and under the cut-off bubble.
      expect(find.text('Doomed question'), findsOneWidget);
      expect(
        find.textContaining('interrupted when the app closed'),
        findsOneWidget,
      );
      expect(find.text('Interrupted'), findsOneWidget);

      // Resume: load, send, and the engine gets the full history without
      // the empty stump bubble.
      await tester.tap(_loadCta('Llama 3.2 1B'));
      await tester.pumpAndSettle();
      await _send(tester, 'Follow up');
      expect(find.textContaining('finally'), findsOneWidget);
      expect(resumedInference.chatHistories.single.length, 2);
      expect(
        resumedInference.chatHistories.single.map((m) => m.text),
        ['Doomed question', 'Follow up'],
      );
      // A completed reply clears the interrupted state.
      expect(find.text('Interrupted'), findsNothing);
      expect(
        find.textContaining('interrupted when the app closed'),
        findsNothing,
      );
    });
  });
}
