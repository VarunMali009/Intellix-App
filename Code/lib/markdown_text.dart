import 'package:flutter/material.dart';

/// Tiny markdown renderer (no dependencies): headings, bullets,
/// **bold**, `inline code` and ``` code blocks ```.
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.data, {super.key});

  final String data;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!;
    final blocks = <Widget>[];
    final code = StringBuffer();
    var inCode = false;

    for (final line in data.split('\n')) {
      if (line.trimLeft().startsWith('```')) {
        if (inCode) {
          blocks.add(_codeBlock(context, code.toString().trimRight()));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.writeln(line);
      } else if (line.trim().isEmpty) {
        blocks.add(const SizedBox(height: 6));
      } else if (RegExp(r'^#{1,6}\s').hasMatch(line)) {
        final title = line.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
        blocks.add(Text(title, style: base.copyWith(fontWeight: FontWeight.bold, fontSize: 18)));
      } else if (RegExp(r'^\s*[-*]\s+').hasMatch(line)) {
        final item = line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '');
        blocks.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: base),
            Expanded(child: Text.rich(_inline(item, base))),
          ],
        ));
      } else {
        blocks.add(Text.rich(_inline(line, base)));
      }
    }
    // Code block still open while the reply is streaming.
    if (inCode) blocks.add(_codeBlock(context, code.toString().trimRight()));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _codeBlock(BuildContext context, String code) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
      ),
    );
  }

  TextSpan _inline(String s, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp(r'\*\*(.+?)\*\*|`([^`]+)`').allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
      } else {
        spans.add(TextSpan(
          text: m.group(2),
          style: const TextStyle(fontFamily: 'monospace', backgroundColor: Color(0x22808080)),
        ));
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
