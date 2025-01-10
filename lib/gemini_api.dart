import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';

class ChatGPTService {
  final String apiKey;
  late OpenAI _openAI;

  ChatGPTService({required this.apiKey}) {
    _openAI = OpenAI.instance.build(
      token: apiKey,
      baseOption: HttpSetup(
        receiveTimeout: const Duration(seconds: 60),
        connectTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<String> generateResponse(String userInput, String role) async {
    final Map<String, String> roleInstructions = {
      "assistant": "You are a helpful AI assistant.",
      "expert": "You are an expert in the field. Provide a detailed response.",
      "friend": "You are a friendly and casual conversationalist.",
    };

    try {
      final request = ChatCompleteText(
        messages: [
          Map.of({"role": "system", "content": roleInstructions[role] ?? roleInstructions["assistant"]}),
          Map.of({"role": "user", "content": userInput}),
        ],
        model: Gpt4O2024ChatModel(), // Use "gptTurbo" or "gpt4" based on your account
        maxToken: 200,
      );

      final response = await _openAI.onChatCompletion(request: request);

      return response?.choices.first.message?.content ?? 'No response';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }
}
