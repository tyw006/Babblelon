import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';

/// Premium NPC chat screen for practicing conversations outside of game context
class PremiumNPCChatScreen extends ConsumerStatefulWidget {
  const PremiumNPCChatScreen({super.key});

  @override
  ConsumerState<PremiumNPCChatScreen> createState() => _PremiumNPCChatScreenState();
}

class _PremiumNPCChatScreenState extends ConsumerState<PremiumNPCChatScreen> {
  String? selectedNpcId;
  bool isRecording = false;
  
  // Mock NPC data - in real implementation, this would come from existing NPC data
  final List<NPCData> availableNPCs = [
    NPCData(
      id: 'amara',
      name: 'Amara',
      description: 'Food Vendor',
      specialization: 'Ordering food, Thai numbers',
      portraitPath: 'assets/images/npcs/amara_portrait.png',
      isAvailable: true,
    ),
    NPCData(
      id: 'somchai',
      name: 'Somchai',
      description: 'Local Guide',
      specialization: 'Directions, greetings',
      portraitPath: 'assets/images/npcs/somchai_portrait.png',
      isAvailable: true,
    ),
    NPCData(
      id: 'niran',
      name: 'Niran',
      description: 'Shop Owner',
      specialization: 'Shopping, bargaining',
      portraitPath: 'assets/images/npcs/niran_portrait.png',
      isAvailable: false, // Coming soon
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      appBar: AppBar(
        title: Text(
          'NPC Conversations',
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
        child: selectedNpcId == null 
          ? _buildNPCSelection()
          : _buildChatInterface(),
      ),
    );
  }

  /// NPC selection grid
  Widget _buildNPCSelection() {
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
                  Icons.chat_bubble_outline,
                  color: Colors.black,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Conversation Partner',
                        style: AppTheme.textTheme.titleLarge?.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Practice Thai conversations with AI-powered NPCs',
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
            'Available NPCs',
            style: AppTheme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: availableNPCs.length,
              itemBuilder: (context, index) {
                final npc = availableNPCs[index];
                return _NPCCard(
                  npc: npc,
                  onTap: npc.isAvailable 
                    ? () => _selectNPC(npc.id)
                    : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Chat interface with selected NPC
  Widget _buildChatInterface() {
    final selectedNPC = availableNPCs.firstWhere((npc) => npc.id == selectedNpcId);
    
    return Column(
      children: [
        // NPC Info Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.2),
                child: Icon(
                  Icons.person,
                  color: const Color(0xFFFFD700),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selectedNPC.name,
                      style: AppTheme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                    Text(
                      selectedNPC.description,
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: ModernDesignSystem.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: ModernDesignSystem.slateGray,
                onPressed: () => setState(() => selectedNpcId = null),
              ),
            ],
          ),
        ),
        
        // Chat Messages Area
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // NPC Greeting
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.chat_bubble,
                            color: const Color(0xFFFFD700),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedNPC.name,
                            style: AppTheme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _getGreetingForNPC(selectedNPC.id),
                        style: AppTheme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Recent Topics
                Container(
                  padding: const EdgeInsets.all(16),
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
                        'Suggested Topics:',
                        style: AppTheme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        selectedNPC.specialization,
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
        
        // Voice Recording Section
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
                isRecording ? 'Recording...' : 'Hold to Record',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFFFD700),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Show conversation history
                    },
                    icon: const Icon(Icons.history, color: ModernDesignSystem.electricCyan),
                    label: const Text('History', style: TextStyle(color: ModernDesignSystem.electricCyan)),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => selectedNpcId = null);
                    },
                    icon: const Icon(Icons.people, color: ModernDesignSystem.electricCyan),
                    label: const Text('Change NPC', style: TextStyle(color: ModernDesignSystem.electricCyan)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectNPC(String npcId) {
    setState(() {
      selectedNpcId = npcId;
    });
  }

  void _startRecording() {
    setState(() {
      isRecording = true;
    });
    // TODO: Start audio recording and connect to API
  }

  void _stopRecording() {
    setState(() {
      isRecording = false;
    });
    // TODO: Stop recording and send to NPC dialogue API
  }

  String _getGreetingForNPC(String npcId) {
    switch (npcId) {
      case 'amara':
        return 'สวัสดีค่ะ! วันนี้อยากกินอะไรดีคะ?\n(Hello! What would you like to eat today?)';
      case 'somchai':
        return 'สวัสดีครับ! ต้องการความช่วยเหลืออะไรครับ?\n(Hello! How can I help you?)';
      case 'niran':
        return 'ยินดีต้อนรับครับ! มีอะไรให้ช่วยไหมครับ?\n(Welcome! Is there anything I can help you with?)';
      default:
        return 'สวัสดีครับ/ค่ะ!\n(Hello!)';
    }
  }
}

/// NPC selection card widget
class _NPCCard extends StatelessWidget {
  final NPCData npc;
  final VoidCallback? onTap;

  const _NPCCard({
    required this.npc,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: npc.isAvailable 
            ? ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6)
            : ModernDesignSystem.slateGray.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
          border: Border.all(
            color: npc.isAvailable 
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : ModernDesignSystem.slateGray.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: npc.isAvailable 
                ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                : ModernDesignSystem.slateGray.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                color: npc.isAvailable ? const Color(0xFFFFD700) : ModernDesignSystem.slateGray,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              npc.name,
              style: AppTheme.textTheme.titleMedium?.copyWith(
                color: npc.isAvailable ? const Color(0xFFFFD700) : ModernDesignSystem.slateGray,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              npc.description,
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: ModernDesignSystem.slateGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (!npc.isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Coming Soon',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: ModernDesignSystem.slateGray,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// NPC data model for premium chat
class NPCData {
  final String id;
  final String name;
  final String description;
  final String specialization;
  final String portraitPath;
  final bool isAvailable;

  NPCData({
    required this.id,
    required this.name,
    required this.description,
    required this.specialization,
    required this.portraitPath,
    required this.isAvailable,
  });
}