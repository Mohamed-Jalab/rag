import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

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

Future<String> rag(String question) async {
  String giminiApiKey = 'AQ.Ab8RN6KoDw_I5tDq9t0cKLG1PrvKtbgXC0GV9IMwYf7kBc4wWQ';

  // 1. Create a vector store and add documents to it
  final vectorStore = MemoryVectorStore(
    embeddings: GoogleGenerativeAIEmbeddings(apiKey: giminiApiKey),
  );

  await vectorStore.addDocuments(
    documents: [
      Document(pageContent: 'LangChain was created by Harrison'),
      Document(
        pageContent: 'Mahmoud ported LangChain to Dart in LangChain.dart',
      ),
    ],
  );

  List<double> questionEmbedding = await vectorStore.embeddings.embedQuery(
    question,
  );

  final results = await vectorStore.similaritySearchByVectorWithScores(
    embedding: questionEmbedding,
    config: VectorStoreSimilaritySearch(k: 3, scoreThreshold: 0.80),
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

  // 4. Define the final chain
  final model = ChatGoogleGenerativeAI(
    apiKey: giminiApiKey,
    defaultOptions: ChatGoogleGenerativeAIOptions(model: 'gemini-2.5-flash'),
  );
  const outputParser = StringOutputParser<ChatResult>();

  var res = await promptTemplate.pipe(model).pipe(outputParser).invoke({
    'question': question,
  });

  return res;
}

Future<void> asr() async {
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

    final wavePath = await _copyAssetToTempFile('assets/4_pcm.wav');

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

    final wave = readWave(wavePath);

    if (wave.samples.isEmpty || wave.sampleRate <= 0) {
      throw StateError('Failed to load WAV file');
    }

    log('sampleRate=${wave.sampleRate}');
    log('numSamples=${wave.samples.length}');

    final text = await recognizeWholeFile(recognizer, wave);

    log('Recognized text: $text');
  } catch (e, st) {
    log('ASR failed', error: e, stackTrace: st);
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
