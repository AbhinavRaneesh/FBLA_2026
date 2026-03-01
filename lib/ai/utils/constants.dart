const List<String> availableModels = [
  "llama3.2:1b",
  "llama3.2:3b",
];

const String defaultModel = "llama3.2:1b";

const String ollamaBaseUrl = String.fromEnvironment(
  'OLLAMA_BASE_URL',
  defaultValue: 'http://192.168.0.105:11434',
);

final List<String> apiEndpoints = [
  if (ollamaBaseUrl.isNotEmpty) "$ollamaBaseUrl/api/chat",
  "http://10.0.2.2:11434/api/chat",
  "http://127.0.0.1:11434/api/chat",
  "http://localhost:11434/api/chat",
];

final List<String> ollamaTagsEndpoints = [
  if (ollamaBaseUrl.isNotEmpty) "$ollamaBaseUrl/api/tags",
  "http://10.0.2.2:11434/api/tags",
  "http://127.0.0.1:11434/api/tags",
  "http://localhost:11434/api/tags",
];
