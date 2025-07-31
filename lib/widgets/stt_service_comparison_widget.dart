import 'package:flutter/material.dart';
import 'package:babblelon/models/assessment_model.dart';

/// Widget to display three-way comparison of STT services
class STTServiceComparisonWidget extends StatelessWidget {
  final ThreeWayTranscriptionResponse? comparisonResult;
  final bool isLoading;
  final String? error;

  const STTServiceComparisonWidget({
    super.key,
    this.comparisonResult,
    this.isLoading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Processing with 3 STT services...'),
              ],
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 8),
              const Text(
                'STT Service Error',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (comparisonResult == null) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No three-way STT comparison data available',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildThreeWayServiceComparison(),
            const SizedBox(height: 16),
            _buildCostAnalysis(),
            const SizedBox(height: 16),
            _buildWinnerBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.compare_arrows,
          size: 28,
          color: Colors.blue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: const Text(
            'Three-Way STT Comparison',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${comparisonResult!.googleChirp2.audioDuration.toStringAsFixed(2)}s',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeWayServiceComparison() {
    return Column(
      children: [
        _buildServiceRow(comparisonResult!.googleChirp2, Colors.green, Icons.cloud, 'Google Chirp2'),
        const SizedBox(height: 12),
        _buildServiceRow(comparisonResult!.assemblyaiUniversal, Colors.orange, Icons.psychology, 'AssemblyAI Universal'),
        const SizedBox(height: 12),
        _buildServiceRow(comparisonResult!.speechmaticsUrsa, Colors.purple, Icons.voice_chat, 'Speechmatics Ursa'),
      ],
    );
  }

  Widget _buildServiceRow(STTServiceResult result, Color accentColor, IconData icon, String serviceName) {
    final isWinner = comparisonResult!.winnerService.toLowerCase().contains(serviceName.toLowerCase());
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: isWinner ? accentColor : Colors.grey.shade300,
          width: isWinner ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isWinner ? accentColor.withOpacity(0.05) : Colors.grey.shade50,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with service name and winner indicator
            Row(
              children: [
                Icon(
                  icon,
                  color: accentColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    serviceName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ),
                // Status indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.status == 'success' ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: result.status == 'success' ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                ),
                if (isWinner) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 24,
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Results and metrics in a compact row layout
            if (result.status == 'success') ...[
              // Transcription and translation
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildCompactResultSection(
                      'Thai',
                      result.transcription,
                      Icons.record_voice_over,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildCompactResultSection(
                      'English',
                      result.englishTranslation,
                      Icons.translate,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Metrics row
              Row(
                children: [
                  Expanded(
                    child: _buildMetricChip(
                      'Time',
                      '${result.processingTime.toStringAsFixed(2)}s',
                      Icons.timer,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricChip(
                      'Confidence',
                      '${(result.confidenceScore * 100).toStringAsFixed(1)}%',
                      Icons.assessment,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricChip(
                      'Accuracy',
                      '${(result.accuracyScore * 100).toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricChip(
                      'Speed',
                      result.realTimeFactor.toStringAsFixed(2),
                      Icons.speed,
                      Colors.purple,
                      tooltip: 'Real-Time Factor: Processing speed vs audio duration (lower = faster than real-time)',
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Error display
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.error ?? 'Service failed to process audio',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactResultSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            content.isEmpty ? 'No result' : content,
            style: TextStyle(
              fontSize: 12,
              color: content.isEmpty ? Colors.grey.shade500 : Colors.black87,
              fontStyle: content.isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon, Color color, {String? tooltip}) {
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        child: chip,
      );
    }
    
    return chip;
  }

  Widget _buildCostAnalysis() {
    if (comparisonResult == null) return const SizedBox.shrink();
    
    final summary = comparisonResult!.processingSummary;
    final audioDuration = comparisonResult!.googleChirp2.audioDuration / 60.0; // Convert to minutes
    
    // Cost calculations (per minute rates from backend)
    final googleCost = (summary['google_chirp2_cost'] as num?)?.toDouble() ?? 0.0;
    final assemblyaiCost = (summary['assemblyai_universal_cost'] as num?)?.toDouble() ?? 0.0;
    final speechmaticsCost = (summary['speechmatics_ursa_cost'] as num?)?.toDouble() ?? 0.0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.attach_money, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Cost Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${audioDuration.toStringAsFixed(3)} min',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildCostChip('Google', googleCost, Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCostChip('AssemblyAI', assemblyaiCost, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildCostChip('Speechmatics', speechmaticsCost, Colors.purple),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostChip(String service, double cost, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            service,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${cost.toStringAsFixed(6)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  Widget _buildWinnerBanner() {
    if (comparisonResult!.winnerService == 'none') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.balance, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'No clear winner determined',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // Determine winner color based on service
    Color winnerColor = Colors.blue;
    IconData winnerIcon = Icons.cloud;
    
    if (comparisonResult!.winnerService.toLowerCase().contains('google') || 
        comparisonResult!.winnerService.toLowerCase().contains('chirp')) {
      winnerColor = Colors.green;
      winnerIcon = Icons.cloud;
    } else if (comparisonResult!.winnerService.toLowerCase().contains('assemblyai') || 
               comparisonResult!.winnerService.toLowerCase().contains('universal')) {
      winnerColor = Colors.orange;
      winnerIcon = Icons.psychology;
    } else if (comparisonResult!.winnerService.toLowerCase().contains('speechmatics') || 
               comparisonResult!.winnerService.toLowerCase().contains('ursa')) {
      winnerColor = Colors.purple;
      winnerIcon = Icons.voice_chat;
    }

    // Get performance score if available
    final performanceScore = comparisonResult!.performanceAnalysis[comparisonResult!.winnerService];
    final scoreText = performanceScore != null ? ' (Score: ${(performanceScore as double).toStringAsFixed(3)})' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: winnerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: winnerColor, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Icon(winnerIcon, color: winnerColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${comparisonResult!.winnerService} Wins!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: winnerColor,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          if (scoreText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Best overall performance$scoreText',
              style: TextStyle(
                color: winnerColor.withOpacity(0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}