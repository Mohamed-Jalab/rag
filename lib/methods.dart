import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

import 'secrets.dart';
import 'injection.dart';

Future<String> _copyAssetToTempFile(String assetPath) async {
  final cachedFile = File(
    '${Directory.systemTemp.path}/chatbot_app/$assetPath',
  );
  if (await cachedFile.exists()) {
    return cachedFile.path;
  }

  final bytes = await rootBundle.load(assetPath);

  await cachedFile.parent.create(recursive: true);
  await cachedFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);

  return cachedFile.path;
}

Future<List<Map<String, dynamic>>> _readJsonlFromAssets(
  String assetPath,
) async {
  final List<Map<String, dynamic>> jsonList = [];

  try {
    final String content = await rootBundle.loadString(assetPath);

    const LineSplitter splitter = LineSplitter();
    final List<String> lines = splitter.convert(content);

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      try {
        final dynamic decoded = jsonDecode(line);
        if (decoded is Map<String, dynamic>) {
          jsonList.add(decoded);
        }
      } catch (e) {
        // Log individual malformed line errors without breaking the loop
        print("Error parsing asset line: $e");
      }
    }
  } catch (e) {
    print("Error loading asset file: $e");
    rethrow; // Pass the error up if the asset path is completely wrong
  }

  return jsonList;
}

Future<void> loadSystem() async {
  try {
    List<Map<String, dynamic>> dataset = await _readJsonlFromAssets(
      "assets/faculties.jsonl",
    );
    dataset = dataset.sublist(0, 5);
    print("${dataset.length} records");
    log("start Loading ...");
    await sl<MemoryVectorStore>().addDocuments(
      documents: dataset
          .map<Document>(
            (data) => Document(
              pageContent: data["page_content"],
              metadata: data["metadata"],
            ),
          )
          .toList(),
    );
    log("finish loading");
  } catch (e) {
    return Future.error(e.toString());
  }
}

Future<String> rag(String question) async {
  try {
    List<double> questionEmbedding = await sl<MemoryVectorStore>().embeddings
        .embedQuery(question);

    final results = await sl<MemoryVectorStore>()
        .similaritySearchByVectorWithScores(
          embedding: questionEmbedding,
          config: VectorStoreSimilaritySearch(scoreThreshold: 0.7),
        );

    if (results.isEmpty) {
      return "I don't have enough information to answer that question.";
    }

    String context = '';

    for (var item in results) {
      context += ' , ${item.$1.pageContent} ';
    }

    // 3. Construct a RAG prompt template
    final promptTemplate = ChatPromptTemplate.fromTemplates([
      (
        ChatMessageType.system,
        '''
          You are a faculty assistant.
          Answer the question using only the following Arabic context.
          The context may be Arabic, but your answer must be in the same language as the user's question.
          If the question is Arabic, answer in Arabic.
          If the question is English, answer in English.
          If the answer is not in the context, say that you do not know in the same language as the user's question.

          Context:
          $context
  ''',
      ),
      (ChatMessageType.human, '{question}'),
    ]);

    final model = ChatGoogleGenerativeAI(
      apiKey: Secrets.geminiApiKey,
      defaultOptions: ChatGoogleGenerativeAIOptions(model: 'gemini-2.5-flash'),
    );
    const outputParser = StringOutputParser<ChatResult>();
    var res = await promptTemplate.pipe(model).pipe(outputParser).invoke({
      'question': question,
    });
    return res;
  } catch (e) {
    return Future.error(e.toString());
  }
}

Future<String?> asr(String audioPath) async {
  initBindings();

  OfflineRecognizer? recognizer;

  try {
    final encoderPath = await _copyAssetToTempFile(
      'assets/base-encoder.int8.onnx',
    );

    final decoderPath = await _copyAssetToTempFile(
      'assets/base-decoder.int8.onnx',
    );

    final tokensPath = await _copyAssetToTempFile('assets/base-tokens.txt');

    // final wavePath = await _copyAssetToTempFile('assets/4_pcm.wav');

    recognizer = OfflineRecognizer(
      OfflineRecognizerConfig(
        model: OfflineModelConfig(
          whisper: OfflineWhisperModelConfig(
            encoder: encoderPath,
            decoder: decoderPath,
            language: 'ar',
            task: 'transcribe',
          ),
          tokens: tokensPath,
          provider: 'xnnpack',
          debug: true,
        ),
      ),
    );

    final wave = readWave(audioPath);

    if (wave.samples.isEmpty || wave.sampleRate <= 0) {
      throw StateError('Failed to load WAV file');
    }

    log('sampleRate=${wave.sampleRate}');
    log('numSamples=${wave.samples.length}');

    final text = await recognizeWholeFile(recognizer, wave);
    log('Recognized text: $text');
    return text;
  } catch (e, st) {
    log('ASR failed', error: e, stackTrace: st);
    return null;
  } finally {
    recognizer?.free();
  }
}

Future<String> recognizeWholeFile(
  OfflineRecognizer recognizer,
  WaveData wave,
) async {
  final stream = recognizer.createStream();

  try {
    stream.acceptWaveform(samples: wave.samples, sampleRate: wave.sampleRate);

    recognizer.decode(stream);

    return recognizer.getResult(stream).text;
  } finally {
    stream.free();
  }
}
