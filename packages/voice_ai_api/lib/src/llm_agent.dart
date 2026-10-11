// packages/voice_ai_api/lib/src/llm_agent.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class LlmAgent {
  LlmAgent({required this.openRouterApiKey});

  final String openRouterApiKey;
  static const String _endpoint =
      'https://openrouter.ai/api/v1/chat/completions';

  String _getSystemPrompt({Map<String, dynamic>? systemContext}) {
    final now = DateTime.now();
    final contextJson = systemContext != null
        ? jsonEncode(systemContext)
        : '{"tasks":[], "alarms":[], "settings":{}}';

    return '''
You are BeaconOS, an invisible Voice-First operating system for visually impaired users and digital minimalists.
Current System Time: ${now.toIso8601String()}

CURRENT SYSTEM CONTEXT (ACTIVE DATABASE RECORDS):
$contextJson

You MUST output your response ONLY as a single valid JSON object. No markdown wrappers, no introductory or trailing text.

Available Intents & Database Actions:
- "SAVE_TASK": Add a new task.
- "COMPLETE_TASK": Mark an existing task as completed (Match task_id from context).
- "DELETE_TASK": Soft-delete a task (Match task_id from context).
- "UPDATE_TASK": Change due date, priority, or title of an existing task.
- "SAVE_MEMO": Save a voice note.
- "DELETE_MEMO": Delete a voice memo (Match memo_id from context).
- "SET_ALARM": Create a new alarm clock time.
- "TOGGLE_ALARM": Enable or disable an alarm (Match alarm_id from context).
- "DELETE_ALARM": Delete an alarm (Match alarm_id from context).
- "CALL_CONTACT": Dial a phone contact.
- "SAVE_CONTACT": Save a new contact.
- "DELETE_CONTACT": Remove a contact (Match contact_id from context).
- "UPDATE_SETTINGS": Change an OS preference.
- "FLASHLIGHT": Toggle camera torch.
- "LOCK_SCREEN": Put screen to sleep.
- "OPEN_APP": Launch external Android app.
- "VISUAL_QUERY": User is asking about their surroundings or camera view.
- "GENERAL_CHAT": General conversational answer.

Output format:
{
  "intent": "<ONE_OF_THE_ABOVE_INTENTS>",
  "spoken_response": "1-2 short, crisp, natural sentences to read aloud to the user.",
  "parameters": {}
}

Rules:
1. When user asks to complete, edit, or delete a task/alarm/memo, fuzzy-match the title against CURRENT SYSTEM CONTEXT to find the exact "task_id", "alarm_id", or "memo_id".
2. Keep spoken_response strictly to 1 or 2 concise, clear sentences. Never use asterisks or markdown in spoken_response.
''';
  }

  Future<Map<String, dynamic>> processCommand({
    required String userCommand,
    String? base64Image,
    Map<String, dynamic>? systemContext,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': _getSystemPrompt(systemContext: systemContext),
        },
      ];

      if (base64Image != null && base64Image.isNotEmpty) {
        messages.add({
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  userCommand.isEmpty ? 'What is in front of me?' : userCommand,
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
            },
          ],
        });
      } else {
        messages.add({'role': 'user', 'content': userCommand});
      }

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $openRouterApiKey',
              'Content-Type': 'application/json',
              'HTTP-Referer': 'https://github.com/abbassatour/BeaconOS',
              'X-Title': 'BeaconOS',
            },
            body: jsonEncode({
              'model': 'google/gemini-2.0-flash-001',
              'models': [
                'google/gemini-2.0-flash-001',
                'google/gemini-2.5-flash',
                'openai/gpt-4o-mini',
              ],
              'response_format': {'type': 'json_object'},
              'messages': messages,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        log('LlmAgent Server Error: [${response.statusCode}] ${response.body}');
        return <String, dynamic>{
          'intent': 'ERROR',
          'spoken_response': 'Server error. Please try again shortly.',
          'parameters': <String, dynamic>{},
        };
      }

      final data = jsonDecode(response.body);
      final rawContent = data['choices'][0]['message']['content'] as String;

      return _parseSafely(rawContent);
    } on TimeoutException {
      log('LlmAgent Timeout: Request took longer than 15 seconds.');
      return <String, dynamic>{
        'intent': 'ERROR',
        'spoken_response':
            'The network request timed out. Please check your connection and try again.',
        'parameters': <String, dynamic>{},
      };
    } catch (e, st) {
      log('LlmAgent Network Exception: $e', stackTrace: st);
      return <String, dynamic>{
        'intent': 'ERROR',
        'spoken_response':
            "I'm sorry, I encountered a connection error. Please try again.",
        'parameters': <String, dynamic>{},
      };
    }
  }

  Map<String, dynamic> _parseSafely(String rawContent) {
    try {
      String cleaned = rawContent
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll('```', '')
          .trim();

      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');

      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }

      final dynamic parsed = jsonDecode(cleaned);

      if (parsed is Map) {
        final safeMap = Map<String, dynamic>.from(parsed);

        final intent = safeMap['intent'] as String? ?? 'GENERAL_CHAT';
        final spoken = safeMap['spoken_response'] as String? ?? 'Done.';
        final parameters = safeMap['parameters'] is Map
            ? Map<String, dynamic>.from(safeMap['parameters'] as Map)
            : <String, dynamic>{};

        return {
          'intent': intent,
          'spoken_response': spoken,
          'parameters': parameters,
        };
      }
    } catch (e) {
      log('LlmAgent: JSON Parse failed, falling back to GENERAL_CHAT: $e');
    }

    return <String, dynamic>{
      'intent': 'GENERAL_CHAT',
      'spoken_response':
          rawContent.replaceAll(RegExp(r'[\{\}\"\[\]]'), '').trim(),
      'parameters': <String, dynamic>{},
    };
  }
}