import 'package:flutter/material.dart';

import '../models/mood.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Five compact emoji buttons. Tapping the selected mood clears it.
class MoodPicker extends StatelessWidget {
  const MoodPicker({super.key, required this.value, required this.onChanged});

  final Mood? value;
  final ValueChanged<Mood?> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (final mood in Mood.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: mood == Mood.values.last ? 0 : 8),
              child: Semantics(
                button: true,
                selected: mood == value,
                label: mood.label,
                excludeSemantics: true,
                child: Tooltip(
                  message: mood.label,
                  child: Pressable(
                    onTap: () => onChanged(mood == value ? null : mood),
                    scale: 0.92,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 52,
                      decoration: BoxDecoration(
                        color: mood == value
                            ? mood.color.withValues(alpha: 0.16)
                            : c.cardAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: mood == value
                              ? mood.color
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: value == null || mood == value ? 1 : 0.4,
                        child: Text(
                          mood.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
