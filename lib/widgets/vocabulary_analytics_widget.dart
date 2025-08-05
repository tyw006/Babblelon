import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_data_providers.dart';
import '../models/local_storage_models.dart';

class VocabularyAnalyticsWidget extends ConsumerWidget {
  const VocabularyAnalyticsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabularyStatsAsync = ref.watch(vocabularyStatsProvider);
    final customVocabularyAsync = ref.watch(customVocabularyProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Analytics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Stats Overview
            vocabularyStatsAsync.when(
              data: (stats) => _buildStatsOverview(stats),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading stats: $error'),
            ),
            
            const SizedBox(height: 24),
            
            // Custom Vocabulary List
            const Text(
              'Discovered Words',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            
            customVocabularyAsync.when(
              data: (words) => _buildCustomVocabularyList(words),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading vocabulary: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsOverview(Map<String, dynamic> stats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Words',
                '${stats['totalCustomWords']}',
                Icons.library_books,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Mastered',
                '${stats['masteredWords']}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Mastery Rate',
                '${stats['masteryPercentage'].toStringAsFixed(1)}%',
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'This Week',
                '${stats['recentlyDiscovered']}',
                Icons.new_releases,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Most Used Words
        if (stats['mostUsedWords'] != null && stats['mostUsedWords'].isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Most Practiced Words',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...stats['mostUsedWords'].map<Widget>((word) => 
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(word['word'] ?? ''),
                      Text(
                        '${word['timesUsed']} times',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomVocabularyList(List<CustomVocabularyEntry> words) {
    if (words.isEmpty) {
      return const Center(
        child: Text(
          'No custom words discovered yet.\nTry having conversations with NPCs!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Sort by recent usage and mastery status
    final sortedWords = List<CustomVocabularyEntry>.from(words)
      ..sort((a, b) {
        // Prioritize recently used words
        return b.lastUsedAt.compareTo(a.lastUsedAt);
      });

    return Column(
      children: sortedWords.take(10).map((word) => _buildWordTile(word)).toList(),
    );
  }

  Widget _buildWordTile(CustomVocabularyEntry word) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          word.wordThai,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (word.wordEnglish != null)
              Text(word.wordEnglish!),
            if (word.transliteration != null)
              Text(
                word.transliteration!,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (word.npcContext.isNotEmpty)
                  Chip(
                    label: Text(
                      word.npcContext.first,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  ),
                const SizedBox(width: 8),
                Text(
                  'Used ${word.timesUsed} times',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              word.isMastered ? Icons.check_circle : Icons.circle_outlined,
              color: word.isMastered ? Colors.green : Colors.grey,
            ),
            if (word.pronunciationScores.isNotEmpty)
              Text(
                '${word.pronunciationScores.last.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: word.pronunciationScores.last >= 60 ? Colors.green : Colors.orange,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NpcVocabularyWidget extends ConsumerWidget {
  final String npcId;
  
  const NpcVocabularyWidget({
    super.key,
    required this.npcId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final npcWordsAsync = ref.watch(npcCustomVocabularyProvider(npcId));

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Words Learned from ${npcId.toUpperCase()}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            npcWordsAsync.when(
              data: (words) => _buildNpcWordsList(words),
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error loading words: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNpcWordsList(List<CustomVocabularyEntry> words) {
    if (words.isEmpty) {
      return const Text(
        'No words learned from this NPC yet.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: words.map((word) => 
        ListTile(
          dense: true,
          title: Text(word.wordThai),
          subtitle: word.wordEnglish != null ? Text(word.wordEnglish!) : null,
          trailing: word.isMastered 
            ? const Icon(Icons.star, color: Colors.amber)
            : null,
        ),
      ).toList(),
    );
  }
}