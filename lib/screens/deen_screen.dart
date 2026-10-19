import 'package:flutter/material.dart';

import 'quran_view.dart';
import 'tasbih_view.dart';

enum _Section { tasbih, quran }

/// Faith: the digital tasbih and the Quran.
class DeenScreen extends StatefulWidget {
  const DeenScreen({super.key});

  @override
  State<DeenScreen> createState() => _DeenScreenState();
}

class _DeenScreenState extends State<DeenScreen> {
  _Section _section = _Section.tasbih;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(expandedHeight: 124, title: const Text('Deen')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverToBoxAdapter(
            child: SegmentedButton<_Section>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: _Section.tasbih,
                  icon: Icon(Icons.radio_button_checked_rounded, size: 18),
                  label: Text('Tasbih'),
                ),
                ButtonSegment(
                  value: _Section.quran,
                  icon: Icon(Icons.menu_book_rounded, size: 18),
                  label: Text('Quran'),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
          ),
        ),
        if (_section == _Section.tasbih)
          const TasbihView()
        else
          const QuranView(),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}
