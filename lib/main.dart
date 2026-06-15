import 'package:flutter/material.dart';

import 'injection.dart';
import 'methods.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await init();
  runApp(const ChatBotApp());
}

class ChatBotApp extends StatelessWidget {
  const ChatBotApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1D6F8F);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Faculty Assistant',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.transparent,
        ),
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool _isComposing = false;
  final bool _isGenerating = false;
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChanged);
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final isComposing = _messageController.text.trim().isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() => _isComposing = isComposing);
    }
  }

  Future<void> _sendMessage([String? prompt]) async {
    // var response = await rag(
    //   'what is the name of person hwo created LangChain',
    // );

    // log(response);

    asr();

    // final text = (prompt ?? _messageController.text).trim();
    // if (text.isEmpty || _isGenerating) return;

    // setState(() {
    //   _messages.add(ChatMessage.user(text));
    //   _isGenerating = true;
    // });
    // _messageController.clear();
    // _scrollToLatest();

    // await Future<void>.delayed(const Duration(milliseconds: 650));

    // if (!mounted) return;
    // setState(() {
    //   _messages.add(ChatMessage.assistant(_draftAssistantReply(text)));
    //   _isGenerating = false;
    // });
    // _scrollToLatest();
  }

  Future<void> _toggleVoiceInput() async {
    if (_isRecognizing) {
      setState(() => _isRecognizing = false);
      return;
    }

    setState(() => _isRecognizing = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() {
      _isRecognizing = false;
      _messageController.text = 'When is the next faculty registration date?';
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
    });
  }

  String _draftAssistantReply(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('registration')) {
      return 'Registration questions usually need the academic year and department. Tell me your faculty and semester, and I will format a clear answer.';
    }
    if (normalized.contains('schedule') || normalized.contains('lecture')) {
      return 'I can help organize lecture schedules, exam times, and room details. Share the course name or upload the schedule text.';
    }
    if (normalized.contains('arabic') || normalized.contains('عربي')) {
      return 'أكيد. يمكنني الرد بالعربية وتنسيق الإجابة بشكل مناسب للطلاب.';
    }
    return 'Good question. Connect me to your RAG or Gemini service next, and this UI is ready to display the real answer here.';
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const _AssistantTitle(),
        actions: [
          IconButton(
            tooltip: 'New chat',
            onPressed: _isGenerating
                ? null
                : () {
                    setState(() {
                      _messages
                        ..clear()
                        ..add(
                          ChatMessage.assistant(
                            'New chat started. What do you need help with?',
                          ),
                        );
                    });
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 40,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            "Hello, How can I help you today?",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      itemCount: _messages.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return MessageBubble(message: _messages[index]);
                      },
                    ),
            ),
            QuickPromptBar(
              prompts: const [
                'Registration steps',
                'Lecture schedule',
                'Answer in Arabic',
              ],
              onSelected: _sendMessage,
            ),
            ChatComposer(
              controller: _messageController,
              isComposing: _isComposing,
              isRecognizing: _isRecognizing,
              onSend: () => _sendMessage(),
              onVoicePressed: _toggleVoiceInput,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantTitle extends StatelessWidget {
  const _AssistantTitle();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.school_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Faculty Assistant',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Online and ready',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.isComposing,
    required this.isRecognizing,
    required this.onSend,
    required this.onVoicePressed,
    super.key,
  });

  final TextEditingController controller;
  final bool isComposing;
  final bool isRecognizing;
  final VoidCallback onVoicePressed;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton.filledTonal(
            tooltip: isRecognizing ? 'Stop voice input' : 'Voice input',
            onPressed: onVoicePressed,
            icon: isRecognizing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.mic_none_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('chatComposerField'),
              controller: controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Ask anything about your faculty...',
                filled: true,
                fillColor: const Color(0xFFF1F4F7),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            key: const Key('sendMessageButton'),
            tooltip: 'Send message',
            onPressed: isComposing ? () => onSend() : null,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class QuickPromptBar extends StatelessWidget {
  const QuickPromptBar({
    required this.prompts,
    required this.onSelected,
    super.key,
  });

  final List<String> prompts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            avatar: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: Text(prompts[index]),
            onPressed: () => onSelected(prompts[index]),
          );
        },
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.author == MessageAuthor.user;
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final textColor = isUser ? Colors.white : theme.colorScheme.onSurface;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isUser ? 20 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 20),
    );

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            boxShadow: [
              if (!isUser)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: textColor,
                height: 1.45,
                fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Thinking...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum MessageAuthor { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.author,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.user(String text) {
    return ChatMessage(
      author: MessageAuthor.user,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  factory ChatMessage.assistant(String text) {
    return ChatMessage(
      author: MessageAuthor.assistant,
      text: text,
      createdAt: DateTime.now(),
    );
  }

  final MessageAuthor author;
  final String text;
  final DateTime createdAt;
}
