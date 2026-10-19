import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/journal_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/entry_card.dart';
import 'routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journal = context.watch<JournalRepository>();
    final results = journal.search(_query.text);
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _query,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search your journal',
              prefixIcon: Icon(Icons.search_rounded, color: c.muted),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: Icon(Icons.close_rounded, color: c.muted),
                      onPressed: () => setState(_query.clear),
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      body: results.isEmpty
          ? Center(
              child: SingleChildScrollView(
                child: _query.text.trim().isEmpty
                    ? const EmptyState(
                        icon: Icons.search_rounded,
                        title: 'Find a memory',
                        message: 'Search the titles and stories of every day you have written.',
                      )
                    : const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        message:
                            'Try another word: a place, a person or a feeling.',
                      ),
              ),
            )
          : ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: results.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${results.length} ${results.length == 1 ? 'day' : 'days'} found',
                      style: context.text.bodySmall,
                    ),
                  );
                }
                final entry = results[i - 1];
                return EntryCard(
                  entry: entry,
                  onTap: () => openDay(context, entry.day),
                );
              },
            ),
    );
  }
}
