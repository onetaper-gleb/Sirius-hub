import 'package:flutter/material.dart';

class ExpandableText extends StatefulWidget {
  final String text;
  final int lines;
  final TextStyle? style;
  final TextAlign? textAlign;

  const ExpandableText({
    required this.text,
    super.key,
    this.lines = 5,
    this.style,
    this.textAlign,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.lines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isExceeds = textPainter.didExceedMaxLines;

        if (!isExceeds) {
          return Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: Text(
                widget.text,
                style: widget.style,
                textAlign: widget.textAlign,
                maxLines: _expanded ? null : widget.lines,
                overflow: _expanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  _expanded ? "Свернуть" : "Читать далее",
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
