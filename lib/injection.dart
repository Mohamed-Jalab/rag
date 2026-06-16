import 'package:get_it/get_it.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_google/langchain_google.dart';

import 'secrets.dart';

GetIt sl = GetIt.I;

Future<void> init() async {
  final vectorStore = MemoryVectorStore(
    embeddings: GoogleGenerativeAIEmbeddings(apiKey: Secrets.geminiApiKey),
  );
  sl.registerLazySingleton(() => vectorStore);
  
}
