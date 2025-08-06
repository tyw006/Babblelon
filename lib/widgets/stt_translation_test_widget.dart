import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

// Data class for benchmark result
class BenchmarkResult {
  final String inputEnglish;
  final String expectedThai;
  final String expectedRomanized;
  final List<ServiceResult> serviceResults;
  final DateTime timestamp;
  final String? audioPath;
  
  BenchmarkResult({
    required this.inputEnglish,
    required this.expectedThai,
    required this.expectedRomanized,
    required this.serviceResults,
    required this.timestamp,
    this.audioPath,
  });
  
  // Get average accuracy across all services
  double get averageAccuracy {
    if (serviceResults.isEmpty) return 0.0;
    final sum = serviceResults.map((r) => r.accuracyScore).reduce((a, b) => a + b);
    return sum / serviceResults.length;
  }
  
  // Get average latency across all services
  double get averageLatency {
    if (serviceResults.isEmpty) return 0.0;
    final sum = serviceResults.map((r) => r.processingTimeMs.toDouble()).reduce((a, b) => a + b);
    return sum / serviceResults.length;
  }
}

// Data class for service result
class ServiceResult {
  final String serviceName;
  final String sttProvider;
  final String translationProvider;
  final String transcription;
  final String romanization;
  final String translation;
  final int processingTimeMs;
  final double confidenceScore;
  final bool isOffline;
  final String? error;
  final Map<String, dynamic> rawData;
  final double accuracyScore;
  final double translationQualityScore;

  ServiceResult({
    required this.serviceName,
    required this.sttProvider,
    required this.translationProvider,
    required this.transcription,
    required this.romanization,
    required this.translation,
    required this.processingTimeMs,
    required this.confidenceScore,
    required this.isOffline,
    this.error,
    required this.rawData,
    this.accuracyScore = 0.0,
    this.translationQualityScore = 0.0,
  });
}

class STTTranslationTestWidget extends ConsumerStatefulWidget {
  const STTTranslationTestWidget({super.key});

  @override
  ConsumerState<STTTranslationTestWidget> createState() => _STTTranslationTestWidgetState();
}

class _STTTranslationTestWidgetState extends ConsumerState<STTTranslationTestWidget> {
  // Services
  final AudioRecorder _audioRecorder = AudioRecorder();
  just_audio.AudioPlayer? _audioPlayer;
  
  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _audioPath;
  List<ServiceResult> _results = [];
  
  // Custom translation state
  final TextEditingController _customTextController = TextEditingController();
  bool _isTranslating = false;
  
  // Google Translate state
  String _expectedThai = '';
  String _expectedRomanized = '';
  String _customAudioBase64 = '';
  List<Map<String, dynamic>> _googleTranslationWordMappings = [];
  just_audio.AudioPlayer? _customAudioPlayer;
  
  // DeepL state
  bool _isTranslatingDeepL = false;
  String _deeplExpectedThai = '';
  String _deeplExpectedRomanized = '';
  String _deeplAudioBase64 = '';
  List<Map<String, dynamic>> _deeplTranslationWordMappings = [];
  just_audio.AudioPlayer? _deeplAudioPlayer;
  
  // Session history for benchmarking
  List<BenchmarkResult> _sessionHistory = [];
  bool _showCharts = false;
  
  @override
  void initState() {
    super.initState();
  }
  
  @override
  void dispose() {
    _audioPlayer?.dispose();
    _customAudioPlayer?.dispose();
    _deeplAudioPlayer?.dispose();
    _audioRecorder.dispose();
    _customTextController.dispose();
    super.dispose();
  }
  
  
  Future<void> _startRecording() async {
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/test_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _results.clear(); // Clear previous results
      });
      
      // Auto-stop after 30 seconds
      Timer(const Duration(seconds: 30), () {
        if (_isRecording) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('Failed to start recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }
  
  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      
      if (path != null) {
        // Use the new backend method that tests multiple services
        await _processAllServicesWithBackend(path);
      }
    } catch (e) {
      debugPrint('Failed to stop recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop recording: $e')),
        );
      }
    }
  }
  
  
  Future<void> _processAllServicesWithBackend(String audioPath) async {
    setState(() {
      _isProcessing = true;
      _results.clear();
    });
    
    try {
      // Call the backend endpoint that tests all service combinations
      final testResult = await ApiService.testSTTTranslationCombinations(
        audioPath: audioPath,
        sourceLanguage: 'th',
        targetLanguage: 'en',
        testName: 'Mobile App Test',
        includeCloudServices: true,
      );
      
      if (testResult != null && testResult['results'] != null) {
        final List<ServiceResult> backendResults = [];
        
        // Parse backend results and calculate accuracy scores
        for (final result in testResult['results']) {
          final transcription = result['transcription'] ?? '';
          final translation = result['translation'] ?? '';
          
          // Calculate accuracy scores
          final accuracyScore = _calculateCharacterAccuracy(_expectedThai, transcription);
          final translationQualityScore = await _calculateTranslationQuality(
            _customTextController.text.trim(), 
            translation
          );
          
          backendResults.add(ServiceResult(
            serviceName: result['service_name'],
            sttProvider: result['stt_provider'],
            translationProvider: result['translation_provider'],
            transcription: transcription,
            romanization: result['romanization'],
            translation: translation,
            processingTimeMs: result['processing_time_ms'],
            confidenceScore: result['confidence_score'].toDouble(),
            isOffline: result['is_offline'],
            error: result['error'],
            rawData: result,
            accuracyScore: accuracyScore,
            translationQualityScore: translationQualityScore,
          ));
        }
        
        // Set results directly from backend
        setState(() {
          _results = backendResults;
          _isProcessing = false;
          
          // Add to session history if we have expected text for benchmarking
          if (_expectedThai.isNotEmpty && _customTextController.text.trim().isNotEmpty) {
            _sessionHistory.add(BenchmarkResult(
              inputEnglish: _customTextController.text.trim(),
              expectedThai: _expectedThai,
              expectedRomanized: _expectedRomanized,
              serviceResults: backendResults,
              timestamp: DateTime.now(),
              audioPath: _audioPath,
            ));
          }
        });
      } else {
        // Backend endpoint failed
        setState(() {
          _isProcessing = false;
        });
        debugPrint('Backend multi-service test returned null');
      }
    } catch (e) {
      debugPrint('Error with backend multi-service test: $e');
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _playRecording() async {
    if (_audioPath == null) return;
    
    try {
      _audioPlayer ??= just_audio.AudioPlayer();
      await _audioPlayer!.setFilePath(_audioPath!);
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('Failed to play recording: $e');
    }
  }

  Future<void> _playUserAudio(String? audioPath) async {
    if (audioPath == null) return;
    
    try {
      _audioPlayer ??= just_audio.AudioPlayer();
      await _audioPlayer!.setFilePath(audioPath);
      await _audioPlayer!.play();
    } catch (e) {
      debugPrint('Failed to play user audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to play audio recording')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('STT/Translation Service Test'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCustomTranslationSection(),
            const SizedBox(height: 20),
            _buildRecordingSection(),
            const SizedBox(height: 20),
            if (_isProcessing) _buildProcessingIndicator(),
            if (_results.isNotEmpty) _buildResultsSection(),
            if (_sessionHistory.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSessionHistorySection(),
            ],
          ],
        ),
      ),
    );
  }
  
  
  
  
  
  Widget _buildRecordingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Recording',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Services to be tested:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  const Text('• Google Cloud STT + Google Translate', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const Text('• Google Cloud STT + DeepL', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const Text('• ElevenLabs STT + Google Translate', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const Text('• ElevenLabs STT + DeepL', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const Text('• OpenAI Whisper + Google Translate', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  const Text('• OpenAI Whisper + DeepL', style: TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            
            // Recording controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Record button
                ElevatedButton.icon(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                // Play button
                if (_audioPath != null)
                  IconButton(
                    onPressed: _playRecording,
                    icon: const Icon(Icons.play_arrow),
                    iconSize: 32,
                  ),
              ],
            ),
            if (_isRecording)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Recording... (Max 30 seconds)',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProcessingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing audio through all services...', style: TextStyle(color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildResultsSection() {
    // Sort results by processing time
    final sortedResults = List<ServiceResult>.from(_results)
      ..sort((a, b) => a.processingTimeMs.compareTo(b.processingTimeMs));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Results',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            if (_audioPath != null)
              ElevatedButton.icon(
                onPressed: () => _playUserAudio(_audioPath),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Play Recording'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...sortedResults.map((result) => _buildResultCard(result)),
      ],
    );
  }
  
  Widget _buildResultCard(ServiceResult result) {
    final hasError = result.error != null;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: hasError 
            ? Border.all(color: Colors.red.shade300, width: 1)
            : Border.all(color: Colors.grey.shade200, width: 1),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    result.serviceName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: result.isOffline ? Colors.grey.shade200 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400, width: 1),
                  ),
                  child: Text(
                    result.isOffline ? 'OFFLINE' : 'ONLINE',
                    style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Error or results
            if (hasError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: ${result.error}',
                        style: TextStyle(color: Colors.red.shade800, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Transcription results
              _buildResultRow('Thai:', result.transcription),
              _buildResultRow('Romanization:', result.romanization),
              _buildResultRow('English:', result.translation),
              
              const SizedBox(height: 12),
              
              // Metrics with processing time, accuracy, and quality scores
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Processing: ${result.processingTimeMs}ms',
                              style: TextStyle(
                                fontSize: 14, 
                                color: Colors.blue.shade900, 
                                fontWeight: FontWeight.w600
                              ),
                            ),
                          ],
                        ),
                        if (result.confidenceScore > 0)
                          Text(
                            'Confidence: ${(result.confidenceScore * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13, 
                              color: Colors.blue.shade700, 
                              fontWeight: FontWeight.w500
                            ),
                          ),
                      ],
                    ),
                    if (_expectedThai.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 16, color: Colors.green.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Accuracy: ${(result.accuracyScore * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 14, 
                                  color: Colors.green.shade900, 
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ],
                          ),
                          if (result.translationQualityScore > 0)
                            Text(
                              'Quality: ${(result.translationQualityScore * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 13, 
                                color: Colors.purple.shade700, 
                                fontWeight: FontWeight.w500
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(String label, String value) {
    // Always show the field, even if empty
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              value.isEmpty ? '(not available)' : value,
              style: TextStyle(
                fontSize: 14, 
                color: value.isEmpty ? Colors.grey : Colors.black87,
                fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCustomTranslationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom Phrase Translation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customTextController,
                    decoration: const InputDecoration(
                      hintText: 'Type in English...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isTranslating ? null : _translateCustomText,
                  icon: _isTranslating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.translate),
                  label: Text(_isTranslating ? 'Translating...' : 'Translate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            // Show translation results side-by-side
            if (_expectedThai.isNotEmpty || _deeplExpectedThai.isNotEmpty) ...[
              const SizedBox(height: 16),
              
              // Side-by-side comparison layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Google Translate Results
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.translate, color: Colors.blue.shade600, size: 18),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Google Translate',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                                ),
                              ),
                              if (_customAudioBase64.isNotEmpty)
                                IconButton(
                                  onPressed: _playCustomAudio,
                                  icon: const Icon(Icons.volume_up, size: 18),
                                  tooltip: 'Play Google TTS',
                                ),
                            ],  
                          ),
                          const SizedBox(height: 8),
                          if (_expectedThai.isNotEmpty) ...[
                            Text(
                              _expectedThai,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            if (_expectedRomanized.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _expectedRomanized,
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                              ),
                            ],
                            
                            // Google Translate word-for-word breakdown
                            if (_googleTranslationWordMappings.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Word breakdown:',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: _googleTranslationWordMappings.map((wordCard) {
                                  return Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.blue.shade300, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (wordCard['target']?.isNotEmpty == true)
                                          Text(
                                            wordCard['target']!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        if (wordCard['romanized']?.isNotEmpty == true) ...[
                                          Text(
                                            wordCard['romanized']!,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                        if (wordCard['english']?.isNotEmpty == true) ...[
                                          Text(
                                            wordCard['english']!,
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ] else ...[
                            const Text(
                              'Translation failed',
                              style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // DeepL Results
                  Expanded(
                    flex: 1,
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.language, color: Colors.green.shade600, size: 18),
                              const SizedBox(width: 8), 
                              const Expanded(
                                child: Text(
                                  'DeepL',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
                                ),
                              ),
                              if (_deeplAudioBase64.isNotEmpty)
                                IconButton(
                                  onPressed: _playDeeplAudio,
                                  icon: const Icon(Icons.volume_up, size: 18),
                                  tooltip: 'Play DeepL TTS',
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_deeplExpectedThai.isNotEmpty) ...[
                            Text(
                              _deeplExpectedThai,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            if (_deeplExpectedRomanized.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _deeplExpectedRomanized,
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
                              ),
                            ],
                            
                            // DeepL word-for-word breakdown
                            if (_deeplTranslationWordMappings.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Word breakdown:',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: _deeplTranslationWordMappings.map((wordCard) {
                                  return Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.green.shade300, width: 1),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        if (wordCard['target']?.isNotEmpty == true)
                                          Text(
                                            wordCard['target']!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        if (wordCard['romanized']?.isNotEmpty == true) ...[
                                          Text(
                                            wordCard['romanized']!,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                        if (wordCard['english']?.isNotEmpty == true) ...[
                                          Text(
                                            wordCard['english']!,
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ] else ...[
                            const Text(
                              'Translation failed',
                              style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Future<void> _translateCustomText() async {
    final englishText = _customTextController.text.trim();
    if (englishText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some English text to translate')),
      );
      return;
    }
    
    setState(() {
      _isTranslating = true;
      _isTranslatingDeepL = true;
    });
    
    try {
      // Call both Google Translate and DeepL in parallel
      final results = await Future.wait([
        ApiService.translateText(
          englishText: englishText,
          targetLanguage: 'th',
        ),
        ApiService.translateTextWithDeepL(
          englishText: englishText,
          targetLanguage: 'th',
        ),
      ]);
      
      final googleResult = results[0];
      final deeplResult = results[1];
      
      if (mounted) {
        setState(() {
          // Process Google Translate result
          if (googleResult != null) {
            _expectedThai = googleResult['target_text'] ?? '';
            _expectedRomanized = googleResult['romanized_text'] ?? '';
            _customAudioBase64 = googleResult['audio_base64'] ?? '';
            
            // Parse Google Translate word mappings
            if (googleResult['word_mappings'] != null && googleResult['word_mappings'].isNotEmpty) {
              _googleTranslationWordMappings = [];
              for (var mapping in googleResult['word_mappings']) {
                final wordCard = {
                  'english': mapping['translation']?.toString() ?? '',      // English meaning
                  'target': mapping['target']?.toString() ?? '',            // Thai word
                  'romanized': mapping['transliteration']?.toString() ?? '', // Romanization
                };
                _googleTranslationWordMappings.add(wordCard);
              }
            } else {
              _googleTranslationWordMappings = [];
            }
          }
          
          // Process DeepL result
          if (deeplResult != null) {
            _deeplExpectedThai = deeplResult['target_text'] ?? '';
            _deeplExpectedRomanized = deeplResult['romanized_text'] ?? '';
            _deeplAudioBase64 = deeplResult['audio_base64'] ?? '';
            
            // Parse DeepL word mappings
            if (deeplResult['word_mappings'] != null && deeplResult['word_mappings'].isNotEmpty) {
              _deeplTranslationWordMappings = [];
              for (var mapping in deeplResult['word_mappings']) {
                final wordCard = {
                  'english': mapping['translation']?.toString() ?? '',      // English meaning
                  'target': mapping['target']?.toString() ?? '',            // Thai word
                  'romanized': mapping['transliteration']?.toString() ?? '', // Romanization
                };
                _deeplTranslationWordMappings.add(wordCard);
              }
            } else {
              _deeplTranslationWordMappings = [];
            }
          }
          
          _isTranslating = false;
          _isTranslatingDeepL = false;
        });
        
        // Show error if both failed
        if (googleResult == null && deeplResult == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Both translations failed. Please try again.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isTranslating = false;
        _isTranslatingDeepL = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: $e')),
        );
      }
    }
  }
  
  Future<void> _playCustomAudio() async {
    if (_customAudioBase64.isEmpty) return;
    
    try {
      _customAudioPlayer ??= just_audio.AudioPlayer();
      
      // Convert base64 to bytes
      final audioBytes = base64.decode(_customAudioBase64);
      
      // Create a temporary file for the audio
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/custom_audio.wav');
      await audioFile.writeAsBytes(audioBytes);
      
      // Play the audio using setFilePath
      await _customAudioPlayer!.setFilePath(audioFile.path);
      await _customAudioPlayer!.play();
    } catch (e) {
      debugPrint('Failed to play custom audio: $e');
    }
  }
  
  Future<void> _playDeeplAudio() async {
    if (_deeplAudioBase64.isEmpty) return;
    
    try {
      _deeplAudioPlayer ??= just_audio.AudioPlayer();
      
      // Convert base64 to bytes
      final audioBytes = base64.decode(_deeplAudioBase64);
      
      // Create a temporary file for the audio
      final tempDir = await getTemporaryDirectory();
      final audioFile = File('${tempDir.path}/deepl_audio.wav');
      await audioFile.writeAsBytes(audioBytes);
      
      // Play the audio using setFilePath
      await _deeplAudioPlayer!.setFilePath(audioFile.path);
      await _deeplAudioPlayer!.play();
    } catch (e) {
      debugPrint('Failed to play DeepL audio: $e');
    }
  }
  
  // Text normalization helper - removes spaces and special characters
  String _normalizeText(String text) {
    return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\u0E00-\u0E7F]'), '') // Keep only letters, numbers, and Thai characters
      .replaceAll(' ', ''); // Remove spaces
  }
  
  // Simple character-level accuracy calculation with proper text normalization
  double _calculateCharacterAccuracy(String expected, String received) {
    if (expected.isEmpty && received.isEmpty) return 1.0;
    if (expected.isEmpty || received.isEmpty) return 0.0;
    
    final expNormalized = _normalizeText(expected);
    final recNormalized = _normalizeText(received);
    
    int matches = 0;
    final minLength = expNormalized.length < recNormalized.length 
        ? expNormalized.length 
        : recNormalized.length;
        
    for (int i = 0; i < minLength; i++) {
      if (expNormalized[i] == recNormalized[i]) matches++;
    }
    
    final maxLength = expNormalized.length > recNormalized.length 
        ? expNormalized.length 
        : recNormalized.length;
        
    return maxLength > 0 ? matches / maxLength : 0.0;
  }
  
  // Calculate translation quality with proper text normalization
  Future<double> _calculateTranslationQuality(String originalEnglish, String backTranslatedEnglish) async {
    if (originalEnglish.isEmpty || backTranslatedEnglish.isEmpty) return 0.0;
    
    final originalNormalized = _normalizeText(originalEnglish);
    final backTranslatedNormalized = _normalizeText(backTranslatedEnglish);
    
    int matchingChars = 0;
    final minLength = originalNormalized.length < backTranslatedNormalized.length 
        ? originalNormalized.length 
        : backTranslatedNormalized.length;
        
    for (int i = 0; i < minLength; i++) {
      if (originalNormalized[i] == backTranslatedNormalized[i]) matchingChars++;
    }
    
    final maxLength = originalNormalized.length > backTranslatedNormalized.length 
        ? originalNormalized.length 
        : backTranslatedNormalized.length;
        
    return maxLength > 0 ? matchingChars / maxLength : 0.0;
  }
  
  Widget _buildSessionHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Session History & Charts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          '${_sessionHistory.length} tests',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showCharts = !_showCharts;
                            });
                          },
                          icon: Icon(_showCharts ? Icons.expand_less : Icons.expand_more),
                          label: Text(_showCharts ? 'Hide' : 'Show'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Session summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSessionStat('Avg Accuracy', '${(_getAverageSessionAccuracy() * 100).toStringAsFixed(1)}%', Icons.check_circle_outline, Colors.green),
                  _buildSessionStat('Avg Latency', '${_getAverageSessionLatency().toStringAsFixed(0)}ms', Icons.timer, Colors.blue),
                  _buildSessionStat('Best Service', _getBestService(), Icons.star, Colors.orange),
                ],
              ),
            ),
            
            if (_showCharts && _sessionHistory.length >= 2) ...[
              const SizedBox(height: 16),
              _buildChartsSection(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildSessionStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
  
  Widget _buildChartsSection() {
    final serviceComparisons = _getServiceComparisons();
    if (serviceComparisons.isEmpty) {
      return const Center(
        child: Text('No data available for service comparison'),
      );
    }

    return Column(
      children: [
        // Thai Transcription Accuracy Chart
        _buildServiceComparisonChart(
          title: 'Thai Transcription Accuracy',
          data: serviceComparisons,
          valueExtractor: (data) => data['thaiAccuracy'] ?? 0.0,
          color: Colors.green,
          unit: '%',
          isPercentage: true,
        ),
        
        const SizedBox(height: 16),
        
        // English Translation Quality Chart
        _buildServiceComparisonChart(
          title: 'English Translation Quality',
          data: serviceComparisons,
          valueExtractor: (data) => data['englishAccuracy'] ?? 0.0,
          color: Colors.blue,
          unit: '%',
          isPercentage: true,
        ),
        
        const SizedBox(height: 16),
        
        // Processing Latency Chart
        _buildServiceComparisonChart(
          title: 'Processing Latency',
          data: serviceComparisons,
          valueExtractor: (data) => data['latency'] ?? 0.0,
          color: Colors.orange,
          unit: 'ms',
          isPercentage: false,
        ),
      ],
    );
  }

  Widget _buildServiceComparisonChart({
    required String title,
    required Map<String, Map<String, double>> data,
    required double Function(Map<String, double>) valueExtractor,
    required Color color,
    required String unit,
    required bool isPercentage,
  }) {
    final services = data.keys.toList();
    final maxValue = data.values.map(valueExtractor).reduce((a, b) => a > b ? a : b);
    final chartMaxValue = isPercentage ? 1.0 : maxValue * 1.2;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: chartMaxValue,
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (isPercentage) {
                          return Text('${(value * 100).toInt()}$unit', 
                            style: const TextStyle(fontSize: 10, color: Colors.black87));
                        } else {
                          return Text('${value.toInt()}$unit', 
                            style: const TextStyle(fontSize: 10, color: Colors.black87));
                        }
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < services.length) {
                          final serviceName = services[value.toInt()];
                          final shortName = serviceName.split(' + ')[0]; // Show just STT provider
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              shortName,
                              style: const TextStyle(fontSize: 9, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                barGroups: services.asMap().entries.map((entry) {
                  final index = entry.key;
                  final serviceName = entry.value;
                  final value = valueExtractor(data[serviceName]!);
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        color: color,
                        width: 20,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Map<String, Map<String, double>> _getServiceComparisons() {
    if (_sessionHistory.isEmpty) return {};
    
    final Map<String, List<double>> serviceThaiAccuracy = {};
    final Map<String, List<double>> serviceEnglishAccuracy = {};
    final Map<String, List<double>> serviceLatency = {};
    
    // Aggregate data from all session history
    for (final test in _sessionHistory) {
      for (final result in test.serviceResults) {
        final serviceName = result.serviceName;
        
        serviceThaiAccuracy.putIfAbsent(serviceName, () => []);
        serviceEnglishAccuracy.putIfAbsent(serviceName, () => []);
        serviceLatency.putIfAbsent(serviceName, () => []);
        
        serviceThaiAccuracy[serviceName]!.add(result.accuracyScore);
        serviceEnglishAccuracy[serviceName]!.add(result.translationQualityScore);
        serviceLatency[serviceName]!.add(result.processingTimeMs.toDouble());
      }
    }
    
    // Calculate averages for each service
    final Map<String, Map<String, double>> comparisons = {};
    
    for (final serviceName in serviceThaiAccuracy.keys) {
      final thaiAccuracies = serviceThaiAccuracy[serviceName]!;
      final englishAccuracies = serviceEnglishAccuracy[serviceName]!;
      final latencies = serviceLatency[serviceName]!;
      
      comparisons[serviceName] = {
        'thaiAccuracy': thaiAccuracies.reduce((a, b) => a + b) / thaiAccuracies.length,
        'englishAccuracy': englishAccuracies.reduce((a, b) => a + b) / englishAccuracies.length,
        'latency': latencies.reduce((a, b) => a + b) / latencies.length,
      };
    }
    
    return comparisons;
  }

  double _getAverageSessionAccuracy() {
    if (_sessionHistory.isEmpty) return 0.0;
    final sum = _sessionHistory.map((r) => r.averageAccuracy).reduce((a, b) => a + b);
    return sum / _sessionHistory.length;
  }
  
  double _getAverageSessionLatency() {
    if (_sessionHistory.isEmpty) return 0.0;
    final sum = _sessionHistory.map((r) => r.averageLatency).reduce((a, b) => a + b);
    return sum / _sessionHistory.length;
  }
  
  String _getBestService() {
    if (_sessionHistory.isEmpty) return 'N/A';
    
    final Map<String, List<double>> serviceAccuracies = {};
    for (final test in _sessionHistory) {
      for (final result in test.serviceResults) {
        serviceAccuracies.putIfAbsent(result.serviceName, () => []);
        serviceAccuracies[result.serviceName]!.add(result.accuracyScore);
      }
    }
    
    String bestService = 'N/A';
    double bestAverage = 0.0;
    
    serviceAccuracies.forEach((service, accuracies) {
      final average = accuracies.reduce((a, b) => a + b) / accuracies.length;
      if (average > bestAverage) {
        bestAverage = average;
        bestService = service.split(' + ')[0]; // Just show the STT provider
      }
    });
    
    return bestService;
  }
  
}