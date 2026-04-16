import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatInputField extends StatelessWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
    required this.isLoading,
    required this.showSuggestions,
    this.onSuggestionTap,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final bool showSuggestions;
  final ValueChanged<String>? onSuggestionTap;

  static const List<String> _suggestions = [
    'Summarize this topic for me',
    'Give me important exam questions',
    'Explain in simple language',
  ];

  Future<void> _pasteFromClipboard(BuildContext context) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final pastedText = clipboardData?.text?.trim();

    if (pastedText == null || pastedText.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }

    final updatedText =
        '${controller.text}${controller.text.isEmpty ? '' : '\n'}$pastedText';
    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: updatedText.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFDCE3ED)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showSuggestions) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions.map((suggestion) {
                    return ActionChip(
                      label: Text(suggestion),
                      backgroundColor: const Color(0xFFF2F6FB),
                      side: const BorderSide(color: Color(0xFFD7E2F0)),
                      onPressed: onSuggestionTap == null
                          ? null
                          : () => onSuggestionTap!(suggestion),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FB),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFD7E2F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Paste',
                      onPressed:
                          isLoading ? null : () => _pasteFromClipboard(context),
                      icon: const Icon(Icons.content_paste_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Ask UniGuide anything from your syllabus',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 6),
                      child: FilledButton(
                        onPressed: isLoading ? null : onSend,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B4D8C),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(52, 52),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Answers are selectable and can be copied from each message.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
