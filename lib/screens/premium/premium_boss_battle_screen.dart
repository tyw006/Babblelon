import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';

/// Premium boss battle training screen for practicing pronunciation outside of game context
class PremiumBossBattleScreen extends ConsumerStatefulWidget {
  const PremiumBossBattleScreen({super.key});

  @override
  ConsumerState<PremiumBossBattleScreen> createState() => _PremiumBossBattleScreenState();
}

class _PremiumBossBattleScreenState extends ConsumerState<PremiumBossBattleScreen> {
  String? selectedBossId;
  BattleDifficulty selectedDifficulty = BattleDifficulty.normal;
  bool isInBattle = false;
  bool isRecording = false;
  int currentScore = 0;
  int playerHealth = 100;
  int bossHealth = 100;
  
  // Mock boss data - in real implementation, this would come from existing boss data
  final List<BossData> availableBosses = [
    BossData(
      id: 'shadow_serpent',
      name: 'Shadow Serpent',
      description: 'Ancient guardian of forgotten words',
      element: 'Shadow',
      difficulty: BattleDifficulty.normal,
      portraitPath: 'assets/images/bosses/shadow_serpent.png',
      isUnlocked: true,
    ),
    BossData(
      id: 'crystal_phoenix',
      name: 'Crystal Phoenix',
      description: 'Majestic bird of pronunciation perfection',
      element: 'Crystal',
      difficulty: BattleDifficulty.hard,
      portraitPath: 'assets/images/bosses/crystal_phoenix.png',
      isUnlocked: true,
    ),
    BossData(
      id: 'void_dragon',
      name: 'Void Dragon',
      description: 'Master of all Thai tones',
      element: 'Void',
      difficulty: BattleDifficulty.nightmare,
      portraitPath: 'assets/images/bosses/void_dragon.png',
      isUnlocked: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      appBar: AppBar(
        title: Text(
          'Boss Battle Training',
          style: AppTheme.textTheme.headlineMedium,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: selectedBossId == null 
          ? _buildBossSelection()
          : isInBattle 
            ? _buildBattleInterface()
            : _buildPreBattleSetup(),
      ),
    );
  }

  /// Boss selection screen
  Widget _buildBossSelection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFD700),
                  Color(0xFFFFA500),
                ],
              ),
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.sports_mma,
                  color: Colors.black,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Opponent',
                        style: AppTheme.textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Battle powerful bosses to perfect your pronunciation',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Available Bosses',
            style: AppTheme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: availableBosses.length,
              itemBuilder: (context, index) {
                final boss = availableBosses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BossCard(
                    boss: boss,
                    onTap: boss.isUnlocked 
                      ? () => _selectBoss(boss.id)
                      : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Pre-battle setup screen
  Widget _buildPreBattleSetup() {
    final selectedBoss = availableBosses.firstWhere((boss) => boss.id == selectedBossId);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Boss Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _getBossElementColor(selectedBoss.element).withValues(alpha: 0.2),
                  child: Icon(
                    _getBossIcon(selectedBoss.id),
                    color: _getBossElementColor(selectedBoss.element),
                    size: 50,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  selectedBoss.name,
                  style: AppTheme.textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFFFFD700),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedBoss.description,
                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                    color: ModernDesignSystem.slateGray,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Difficulty Selection
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
              border: Border.all(
                color: ModernDesignSystem.electricCyan.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Difficulty',
                  style: AppTheme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ...BattleDifficulty.values.map((difficulty) => 
                  RadioListTile<BattleDifficulty>(
                    title: Text(
                      difficulty.displayName,
                      style: AppTheme.textTheme.bodyMedium,
                    ),
                    subtitle: Text(
                      difficulty.description,
                      style: AppTheme.textTheme.bodySmall?.copyWith(
                        color: ModernDesignSystem.slateGray,
                      ),
                    ),
                    value: difficulty,
                    groupValue: selectedDifficulty,
                    onChanged: (value) {
                      setState(() => selectedDifficulty = value!);
                    },
                    activeColor: const Color(0xFFFFD700),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Battle Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => setState(() => selectedBossId = null),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
                    foregroundColor: ModernDesignSystem.ghostWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _startBattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Start Battle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Active battle interface
  Widget _buildBattleInterface() {
    final selectedBoss = availableBosses.firstWhere((boss) => boss.id == selectedBossId);
    
    return Column(
      children: [
        // Health Bars
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.9),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Player Health
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Text('You', style: AppTheme.textTheme.bodyMedium),
                  const Spacer(),
                  Text('$playerHealth/100', style: AppTheme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: playerHealth / 100,
                backgroundColor: Colors.red.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              const SizedBox(height: 16),
              // Boss Health
              Row(
                children: [
                  Icon(_getBossIcon(selectedBoss.id), color: _getBossElementColor(selectedBoss.element), size: 20),
                  const SizedBox(width: 8),
                  Text(selectedBoss.name, style: AppTheme.textTheme.bodyMedium),
                  const Spacer(),
                  Text('$bossHealth/100', style: AppTheme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: bossHealth / 100,
                backgroundColor: _getBossElementColor(selectedBoss.element).withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(_getBossElementColor(selectedBoss.element)),
              ),
            ],
          ),
        ),
        
        // Battle Arena
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Score Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Score: $currentScore',
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          color: const Color(0xFFFFD700),
                        ),
                      ),
                      Text(
                        selectedDifficulty.displayName,
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: ModernDesignSystem.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Current Word Challenge
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
                    border: Border.all(
                      color: ModernDesignSystem.electricCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Pronounce this word:',
                        style: AppTheme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'สวัสดี',
                        style: AppTheme.textTheme.headlineLarge?.copyWith(
                          color: const Color(0xFFFFD700),
                          fontSize: 48,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'sawatdi',
                        style: AppTheme.textTheme.titleMedium?.copyWith(
                          color: ModernDesignSystem.slateGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hello',
                        style: AppTheme.textTheme.bodyMedium?.copyWith(
                          color: ModernDesignSystem.slateGray,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
        
        // Battle Controls
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              // Record Button
              GestureDetector(
                onTapDown: (_) => _startRecording(),
                onTapUp: (_) => _stopRecording(),
                onTapCancel: () => _stopRecording(),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700),
                        const Color(0xFFFFA500),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                        blurRadius: isRecording ? 20 : 10,
                        spreadRadius: isRecording ? 5 : 0,
                      ),
                    ],
                  ),
                  child: Icon(
                    isRecording ? Icons.mic : Icons.mic_none,
                    color: Colors.black,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isRecording ? 'Recording...' : 'Hold to Attack',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: _forfeitBattle,
                    icon: const Icon(Icons.flag, color: Colors.red),
                    label: const Text('Forfeit', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Show battle statistics
                    },
                    icon: const Icon(Icons.analytics, color: ModernDesignSystem.electricCyan),
                    label: const Text('Stats', style: TextStyle(color: ModernDesignSystem.electricCyan)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectBoss(String bossId) {
    setState(() {
      selectedBossId = bossId;
    });
  }

  void _startBattle() {
    setState(() {
      isInBattle = true;
      playerHealth = 100;
      bossHealth = 100;
      currentScore = 0;
    });
  }

  void _forfeitBattle() {
    setState(() {
      isInBattle = false;
      selectedBossId = null;
    });
  }

  void _startRecording() {
    setState(() {
      isRecording = true;
    });
    // TODO: Start audio recording and connect to pronunciation assessment API
  }

  void _stopRecording() {
    setState(() {
      isRecording = false;
    });
    // TODO: Stop recording and send to pronunciation assessment API
    // Mock battle result for now
    _processBattleResult(85); // Mock score
  }

  void _processBattleResult(int pronunciationScore) {
    setState(() {
      currentScore += pronunciationScore;
      
      // Calculate damage based on score
      if (pronunciationScore >= 80) {
        bossHealth = (bossHealth - 25).clamp(0, 100);
      } else if (pronunciationScore >= 60) {
        bossHealth = (bossHealth - 15).clamp(0, 100);
      } else {
        playerHealth = (playerHealth - 20).clamp(0, 100);
      }
      
      // Check for battle end
      if (bossHealth <= 0 || playerHealth <= 0) {
        _endBattle();
      }
    });
  }

  void _endBattle() {
    // TODO: Show victory/defeat dialog and return to boss selection
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        isInBattle = false;
        selectedBossId = null;
      });
    });
  }

  Color _getBossElementColor(String element) {
    switch (element) {
      case 'Shadow':
        return const Color(0xFF9C27B0);
      case 'Crystal':
        return const Color(0xFF00BCD4);
      case 'Void':
        return const Color(0xFF673AB7);
      default:
        return const Color(0xFFFFD700);
    }
  }

  IconData _getBossIcon(String bossId) {
    switch (bossId) {
      case 'shadow_serpent':
        return Icons.pets;
      case 'crystal_phoenix':
        return Icons.flight;
      case 'void_dragon':
        return Icons.eco;
      default:
        return Icons.sports_mma;
    }
  }
}

/// Boss selection card widget
class _BossCard extends StatelessWidget {
  final BossData boss;
  final VoidCallback? onTap;

  const _BossCard({
    required this.boss,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: boss.isUnlocked 
            ? ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6)
            : ModernDesignSystem.slateGray.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
          border: Border.all(
            color: boss.isUnlocked 
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : ModernDesignSystem.slateGray.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 35,
              backgroundColor: boss.isUnlocked 
                ? _getBossElementColor(boss.element).withValues(alpha: 0.2)
                : ModernDesignSystem.slateGray.withValues(alpha: 0.2),
              child: Icon(
                _getBossIcon(boss.id),
                color: boss.isUnlocked ? _getBossElementColor(boss.element) : ModernDesignSystem.slateGray,
                size: 35,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    boss.name,
                    style: AppTheme.textTheme.titleLarge?.copyWith(
                      color: boss.isUnlocked ? const Color(0xFFFFD700) : ModernDesignSystem.slateGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    boss.description,
                    style: AppTheme.textTheme.bodyMedium?.copyWith(
                      color: ModernDesignSystem.slateGray,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: boss.isUnlocked 
                            ? _getBossElementColor(boss.element).withValues(alpha: 0.2)
                            : ModernDesignSystem.slateGray.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          boss.element,
                          style: AppTheme.textTheme.bodySmall?.copyWith(
                            color: boss.isUnlocked ? _getBossElementColor(boss.element) : ModernDesignSystem.slateGray,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: boss.difficulty.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          boss.difficulty.displayName,
                          style: AppTheme.textTheme.bodySmall?.copyWith(
                            color: boss.isUnlocked ? boss.difficulty.color : ModernDesignSystem.slateGray,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!boss.isUnlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Locked',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: ModernDesignSystem.slateGray,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBossElementColor(String element) {
    switch (element) {
      case 'Shadow':
        return const Color(0xFF9C27B0);
      case 'Crystal':
        return const Color(0xFF00BCD4);
      case 'Void':
        return const Color(0xFF673AB7);
      default:
        return const Color(0xFFFFD700);
    }
  }

  IconData _getBossIcon(String bossId) {
    switch (bossId) {
      case 'shadow_serpent':
        return Icons.pets;
      case 'crystal_phoenix':
        return Icons.flight;
      case 'void_dragon':
        return Icons.eco;
      default:
        return Icons.sports_mma;
    }
  }
}

/// Boss data model for premium battles
class BossData {
  final String id;
  final String name;
  final String description;
  final String element;
  final BattleDifficulty difficulty;
  final String portraitPath;
  final bool isUnlocked;

  BossData({
    required this.id,
    required this.name,
    required this.description,
    required this.element,
    required this.difficulty,
    required this.portraitPath,
    required this.isUnlocked,
  });
}

/// Battle difficulty levels
enum BattleDifficulty {
  normal,
  hard,
  nightmare;

  String get displayName {
    switch (this) {
      case BattleDifficulty.normal:
        return 'Normal';
      case BattleDifficulty.hard:
        return 'Hard';
      case BattleDifficulty.nightmare:
        return 'Nightmare';
    }
  }

  String get description {
    switch (this) {
      case BattleDifficulty.normal:
        return 'Perfect for practice sessions';
      case BattleDifficulty.hard:
        return 'Challenging pronunciation tests';
      case BattleDifficulty.nightmare:
        return 'Expert-level precision required';
    }
  }

  Color get color {
    switch (this) {
      case BattleDifficulty.normal:
        return const Color(0xFF4CAF50);
      case BattleDifficulty.hard:
        return const Color(0xFFFF9800);
      case BattleDifficulty.nightmare:
        return const Color(0xFFF44336);
    }
  }
}