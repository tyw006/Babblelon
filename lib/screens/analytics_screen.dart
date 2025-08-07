import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/vocabulary_analytics_widget.dart';
import '../providers/player_data_providers.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Analytics'),
        actions: [
          IconButton(
            icon: syncStatus.isSyncing 
                ? const CircularProgressIndicator()
                : const Icon(Icons.refresh),
            onPressed: syncStatus.isSyncing 
                ? null 
                : () => PlayerDataHelpers.performManualSync(ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Vocabulary', icon: Icon(Icons.book)),
            Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildVocabularyTab(),
          _buildProgressTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return const SingleChildScrollView(
      child: Column(
        children: [
          VocabularyAnalyticsWidget(),
          SizedBox(height: 16),
          // Add more overview widgets here
        ],
      ),
    );
  }

  Widget _buildVocabularyTab() {
    final customVocabularyAsync = ref.watch(customVocabularyProvider);

    return SingleChildScrollView(
      child: Column(
        children: [
          // NPC-specific vocabulary sections
          const NpcVocabularyWidget(npcId: 'amara'),
          const NpcVocabularyWidget(npcId: 'somchai'),
          
          const SizedBox(height: 16),
          
          // All custom words with filtering options
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'All Discovered Words',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  customVocabularyAsync.when(
                    data: (words) => _buildAllWordsList(words),
                    loading: () => const CircularProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSyncStatusCard(),
          const SizedBox(height: 16),
          _buildLearningStreakCard(),
          const SizedBox(height: 16),
          _buildRecentActivityCard(),
        ],
      ),
    );
  }

  Widget _buildAllWordsList(List<dynamic> words) {
    if (words.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Start conversations with NPCs to discover new words!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Filter options
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Filter by NPC',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All NPCs')),
                  DropdownMenuItem(value: 'amara', child: Text('Amara')),
                  DropdownMenuItem(value: 'somchai', child: Text('Somchai')),
                ],
                value: 'all',
                onChanged: (value) {
                  // Implement filtering logic
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Sort by',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                  DropdownMenuItem(value: 'used', child: Text('Most Used')),
                  DropdownMenuItem(value: 'mastered', child: Text('Mastered First')),
                ],
                value: 'recent',
                onChanged: (value) {
                  // Implement sorting logic
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Word list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: words.length,
          itemBuilder: (context, index) {
            final word = words[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ExpansionTile(
                title: Text(
                  word.wordThai,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: word.wordEnglish != null 
                    ? Text(word.wordEnglish!) 
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (word.isMastered)
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Text('${word.timesUsed}'),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (word.transliteration != null)
                          Text('Pronunciation: ${word.transliteration}'),
                        if (word.posTag != null)
                          Text('Part of Speech: ${word.posTag}'),
                        Text('Discovered: ${_formatDate(word.firstDiscoveredAt)}'),
                        Text('Last Used: ${_formatDate(word.lastUsedAt)}'),
                        if (word.pronunciationScore != null)
                          Text('Best Score: ${word.pronunciationScore!.toStringAsFixed(1)}%'),
                        
                        const SizedBox(height: 12),
                        
                        // Practice button
                        ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to practice mode for this word
                            _practiceWord(word);
                          },
                          icon: const Icon(Icons.mic),
                          label: const Text('Practice'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSyncStatusCard() {
    final syncStatus = ref.watch(syncStatusProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sync Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Icon(
                  syncStatus.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: syncStatus.isOnline ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(syncStatus.isOnline ? 'Online' : 'Offline'),
              ],
            ),
            
            if (syncStatus.lastSyncTime != null)
              Text(
                'Last sync: ${_formatDateTime(syncStatus.lastSyncTime!)}',
                style: const TextStyle(color: Colors.grey),
              ),
            
            if (syncStatus.lastError != null)
              Text(
                'Error: ${syncStatus.lastError}',
                style: const TextStyle(color: Colors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningStreakCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Learning Streak',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            const Row(
              children: [
                Icon(Icons.local_fire_department, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  '5 days', // This would come from actual data
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            const Text(
              'Keep it up! Practice daily to maintain your streak.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            
            // This would show recent practice sessions, battles, conversations
            const ListTile(
              leading: Icon(Icons.chat),
              title: Text('Conversation with Amara'),
              subtitle: Text('Learned 3 new words'),
              trailing: Text('2h ago'),
            ),
            const ListTile(
              leading: Icon(Icons.sports_martial_arts),
              title: Text('Boss Battle'),
              subtitle: Text('Grade: A'),
              trailing: Text('1d ago'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _practiceWord(dynamic word) {
    // Navigate to a practice mode for this specific word
    // This could open a dialogue with the word or a pronunciation practice
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Practice mode for "${word.wordThai}" coming soon!'),
      ),
    );
  }
}