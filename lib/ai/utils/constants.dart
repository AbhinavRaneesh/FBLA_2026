/**
 * API configuration for AI services
 */
const apiKey = "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";

/**
 * List of reliable free models from OpenRouter
 */
const availableModels = [
  "meta-llama/llama-3.2-3b-instruct:free",
  "google/gemma-2-9b-it:free", 
  "microsoft/phi-3-mini-128k-instruct:free",
  "qwen/qwen-2-7b-instruct:free",
  "nousresearch/hermes-3-llama-3.1-8b:free",
];

/**
 * Default model - using the most stable one
 */
const defaultModel = "meta-llama/llama-3.2-3b-instruct:free";
const apiEndpoint = "https://openrouter.ai/api/v1/chat/completions";

/**
 * Example JSON format for API requests.
 * 
 * This shows the expected structure for making requests to the OpenAI API,
 * including the model specification and message format.
 */
const exampleRequestFormat = {
  "model": "openai/gpt-oss-20b:free",
  "messages": [
    {
      "role": "user",
      "content": "What is today's date?"
    }
  ]
};