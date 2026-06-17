import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:translator/translator.dart';

import 'audio_bubble.dart';
import 'injection.dart';
import 'message_loading.dart';
import 'methods.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // MediaKit.ensureInitialized();

  await SystemChannels.textInput.invokeMethod('TextInput.hide');
  await init();
  runApp(const ChatBotApp());
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

bool _isComposing = false;
bool _isGenerating = false;
bool _isRecognizing = false;

class _ChatScreenState extends State<ChatScreen> {
  late final AudioRecorder _recorderController;
  String? _audioPath;

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadSystem()
      ..then((_) {
        isLoading = false;
        if (mounted) setState(() {});
      })
      ..catchError((error) {
        print(error);
        this.error = error.toString();
        isLoading = false;
        if (mounted) setState(() {});
      });
    _messageController.addListener(_handleComposerChanged);

    _recorderController = AudioRecorder();
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_handleComposerChanged)
      ..dispose();
    _scrollController.dispose();
    _recorderController.dispose();
    super.dispose();
  }

  void _handleComposerChanged() {
    final isComposing = _messageController.text.trim().isNotEmpty;
    if (isComposing != _isComposing) {
      setState(() => _isComposing = isComposing);
    }
  }

  Future<void> _sendMessage(String prompt, bool isVoice) async {
    bool isEnglish = detectLanguage(prompt) == TextLanguage.english;
    if (!isVoice) {
      _messages.add(ChatMessage.text(author: MessageAuthor.user, text: prompt));
    }
    _messageController.clear();
    _scrollToLatest();
    _isGenerating = true;
    setState(() {});
    await rag(
          isEnglish
              ? (await prompt.translate(from: "en", to: "ar")).text
              : prompt,
        )
        .then((response) async {
          String answer = response;
          if (!mounted) return;
          if (isEnglish) {
            answer = (await response.translate(from: "ar", to: "en")).text;
          }
          _messages.add(
            ChatMessage.text(author: MessageAuthor.assistant, text: answer),
          );
        })
        .catchError((error) {
          print(error);
          _messageController.text = _messages.last.text!;
          _messages.add(
            ChatMessage.text(
              author: MessageAuthor.assistant,
              text: "Unable to replay.",
            ),
          );
        });
    _isGenerating = false;
    setState(() {});
  }

  Future<void> _toggleVoiceInput() async {
    if (_isRecognizing) {
      await stopRecording();
      setState(() {
        _isGenerating = true;
        if (_audioPath != null) {
          _messages.add(ChatMessage.audio(audioPath: _audioPath!));
        }
        _isRecognizing = false;
      });

      String? prompt;
      await asr(_audioPath!)
          .then((response) {
            prompt = response;
          })
          .catchError((error) {
            print(error);
            _messages.add(
              ChatMessage.text(
                author: MessageAuthor.assistant,
                text: "can't read the audio",
              ),
            );
          });
      setState(() {});

      if (prompt == null) return;
      _sendMessage(prompt!, true);
      // setState(() => _isRecognizing = false);
      return;
    }
    await startRecording();
    setState(() => _isRecognizing = true);

    if (!mounted) return;
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


  Future<void> startRecording() async {
    if (!await _recorderController.hasPermission()) return;

    final dir = await getTemporaryDirectory();

    _audioPath =
        '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorderController.start(RecordConfig(

    ), path: _audioPath!);

    setState(() {
      _isRecognizing = true;
    });
  }

  Future<void> stopRecording() async {
    _audioPath = await _recorderController.stop();

    setState(() {
      _isRecognizing = false;
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
                    _messages.clear();
                    setState(() {});
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top,
          bottom: MediaQuery.paddingOf(context).bottom,
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator())
            : error != null
            ? Center(child: Text(error.toString()))
            : Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
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
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                            controller: _scrollController,
                            itemCount: _isGenerating
                                ? _messages.length + 1
                                : _messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index == _messages.length) {
                                return MessageLoading();
                              }
                              return MessageBubble(message: _messages[index]);
                            },
                          ),
                  ),
                  ChatComposer(
                    recorderController: _recorderController,
                    controller: _messageController,
                    isComposing: _isComposing,
                    isRecognizing: _isRecognizing,
                    onSend: () => _sendMessage(_messageController.text, false),
                    onVoicePressed: _toggleVoiceInput,
                  ),
                ],
              ),
      ),
    );
  }
}

class ChatComposer extends StatefulWidget {
  const ChatComposer({
    required this.recorderController,
    required this.controller,
    required this.isComposing,
    required this.isRecognizing,
    required this.onSend,
    required this.onVoicePressed,
    super.key,
  });
  final AudioRecorder recorderController;
  final TextEditingController controller;
  final bool isComposing;
  final bool isRecognizing;
  final VoidCallback onVoicePressed;
  final VoidCallback onSend;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late AudioRecorder _recorderController;
  late TextEditingController _controller;
  late bool isVoice = true;

  @override
  void initState() {
    _controller = widget.controller;
    _recorderController = widget.recorderController;
    _controller.addListener(_messageListener);
    super.initState();
  }

  @override
  void dispose() {
    _controller.removeListener(_messageListener);
    super.dispose();
  }

  void _messageListener() {
    if (_controller.text.isEmpty && !isVoice) {
      isVoice = true;
      setState(() {});
    } else if (_controller.text.isNotEmpty && isVoice) {
      isVoice = false;
      setState(() {});
    }
  }

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
          // Expanded(
          //   child: TextField(
          //     key: const Key('chatComposerField'),
          //     controller: widget.controller,
          //     minLines: 1,
          //     maxLines: 5,
          //     textInputAction: TextInputAction.newline,
          //     decoration: InputDecoration(
          //       hintText: 'Ask anything about your faculty...',
          //       filled: true,
          //       fillColor: const Color(0xFFF1F4F7),
          //       contentPadding: const EdgeInsets.symmetric(
          //         horizontal: 16,
          //         vertical: 13,
          //       ),
          //       border: OutlineInputBorder(
          //         borderRadius: BorderRadius.circular(18),
          //         borderSide: BorderSide.none,
          //       ),
          //     ),
          //   ),
          // ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: widget.isRecognizing
                  ? Container(
                      key: const ValueKey('recording'),
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mic, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text("record"),
                            // AudioWaveforms(
                            //   enableGesture: false,
                            //   size: Size(MediaQuery.of(context).size.width, 50),
                            //   recorderController: _recorderController,
                            //   waveStyle: const WaveStyle(
                            //     waveColor: Colors.blue,
                            //     extendWaveform: true,
                            //     showMiddleLine: false,
                            //   ),
                            // ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      key: const Key('chatComposerField'),
                      controller: widget.controller,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Ask Aleppo University AI...',
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
          ),
          const SizedBox(width: 10),
          _isGenerating
              ? IconButton.filled(
                  onPressed: null,
                  icon: Icon(
                    widget.isRecognizing
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.fastLinearToSlowEaseIn,
                  switchOutCurve: Curves.fastLinearToSlowEaseIn,
                  child: isVoice
                      ? IconButton.filledTonal(
                          tooltip: widget.isRecognizing
                              ? 'Stop voice input'
                              : 'Voice input',
                          onPressed: widget.onVoicePressed,
                          icon: widget.isRecognizing
                              ? const Icon(Icons.stop_rounded)
                              : const Icon(Icons.mic_none_outlined),
                        )
                      : IconButton.filled(
                          key: const Key('sendMessageButton'),
                          tooltip: 'Send message',
                          onPressed: widget.isComposing
                              ? () => widget.onSend()
                              : null,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatefulWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = widget.message.author == MessageAuthor.user;
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: widget.message.type == MessageType.audio
                    ? AudioMessageBubble(
                        path: widget.message.audioPath!,
                        isUser: isUser,
                      )
                    : Text(
                        widget.message.text!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          height: 1.45,
                          fontWeight: isUser
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                // child: Text(
                //   widget.message.text,
                //   style: theme.textTheme.bodyMedium?.copyWith(
                //     color: textColor,
                //     height: 1.45,
                //     fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                //   ),
                // ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum MessageAuthor { user, assistant }

// class ChatMessage {
//   const ChatMessage({
//     required this.author,
//     required this.text,
//     required this.createdAt,
//   });

//   factory ChatMessage.user(String text) {
//     return ChatMessage(
//       author: MessageAuthor.user,
//       text: text,
//       createdAt: DateTime.now(),
//     );
//   }

//   factory ChatMessage.assistant(String text) {
//     return ChatMessage(
//       author: MessageAuthor.assistant,
//       text: text,
//       createdAt: DateTime.now(),
//     );
//   }

//   final MessageAuthor author;
//   final String text;
//   final DateTime createdAt;
// }
enum MessageType { text, audio }

class ChatMessage {
  final MessageAuthor author;
  final MessageType type;

  final String? text;
  final String? audioPath;

  const ChatMessage({
    required this.author,
    required this.type,
    this.text,
    this.audioPath,
  });

  factory ChatMessage.text({
    required MessageAuthor author,
    required String text,
  }) {
    return ChatMessage(author: author, type: MessageType.text, text: text);
  }

  factory ChatMessage.audio({required String audioPath}) {
    return ChatMessage(
      author: MessageAuthor.user,
      type: MessageType.audio,
      audioPath: audioPath,
    );
  }
}

enum TextLanguage { english, arabic, unknown }

TextLanguage detectLanguage(String text) {
  if (text.trim().isEmpty) return TextLanguage.unknown;

  final arabicRegex = RegExp(r'[\u0600-\u06FF]');

  int arabicChars = 0;
  int englishChars = 0;

  for (int i = 0; i < text.length; i++) {
    if (arabicRegex.hasMatch(text[i])) {
      arabicChars++;
    } else if (RegExp(r'[a-zA-Z]').hasMatch(text[i])) {
      englishChars++;
    }
  }

  if (arabicChars > englishChars) {
    return TextLanguage.arabic;
  } else if (englishChars > arabicChars) {
    return TextLanguage.english;
  }

  return TextLanguage.unknown;
}
