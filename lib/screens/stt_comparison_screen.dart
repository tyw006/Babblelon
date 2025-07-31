import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:babblelon/models/assessment_model.dart';
import 'package:babblelon/services/api_service.dart';
import 'package:babblelon/widgets/stt_service_comparison_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class STTComparisonScreen extends StatefulWidget {
  const STTComparisonScreen({super.key});

  @override
  State<STTComparisonScreen> createState() => _STTComparisonScreenState();
}

class _STTComparisonScreenState extends State<STTComparisonScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  ThreeWayTranscriptionResponse? _comparisonResult;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _error;
  String _expectedText = '';
  final TextEditingController _expectedTextController = TextEditingController();
  
  // Translation helper functionality
  bool _showTranslationHelper = false;
  bool _isTranslating = false;
  String _translatedText = '';
  String _romanizedText = '';
  final TextEditingController _translationController = TextEditingController();

  @override
  void dispose() {
    _audioRecorder.dispose();
    _expectedTextController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      // Request microphone permission with proper handling
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() {
          _error = 'Microphone permission is required for STT comparison';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')),
          );
        }
        return;
      }

      final Directory tempDir = await getTemporaryDirectory();
      final String path = '${tempDir.path}/stt_comparison_recording.wav';

      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );

      // Stop any existing recording
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }

      await _audioRecorder.start(config, path: path);
      
      setState(() {
        _isRecording = true;
        _error = null;
        _comparisonResult = null; // Clear previous results
      });

      // Provide haptic feedback
      HapticFeedback.mediumImpact();
      
      debugPrint('STT Comparison: Recording started at $path');
    } catch (e) {
      debugPrint('STT Comparison: Failed to start recording - $e');
      setState(() {
        _error = 'Failed to start recording: $e';
        _isRecording = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    try {
      if (!await _audioRecorder.isRecording()) {
        debugPrint('STT Comparison: No active recording to stop');
        setState(() {
          _error = 'No active recording to stop';
        });
        return;
      }

      final path = await _audioRecorder.stop();
      if (path == null) {
        debugPrint('STT Comparison: Failed to get recording path');
        setState(() {
          _error = 'Failed to stop recording - no path received';
        });
        return;
      }

      debugPrint('STT Comparison: Recording stopped successfully at $path');
      
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _error = null;
      });

      // Provide haptic feedback
      HapticFeedback.lightImpact();

      // Verify the file exists and has content
      final audioFile = File(path);
      if (!audioFile.existsSync()) {
        throw Exception('Audio file does not exist at $path');
      }

      final fileSize = audioFile.lengthSync();
      debugPrint('STT Comparison: Audio file size: $fileSize bytes');
      
      if (fileSize < 1000) { // Less than 1KB suggests no meaningful audio
        throw Exception('Audio file too small ($fileSize bytes) - recording may have failed');
      }

      // Call the three-way transcription API
      debugPrint('STT Comparison: Calling three-way transcription API...');
      final result = await ApiService.threeWayTranscribe(
        audioPath: path,
        languageCode: 'th',
        expectedText: _expectedText,
      );

      if (result != null) {
        debugPrint('STT Comparison: Three-way API call successful');
        setState(() {
          _comparisonResult = result;
          _isProcessing = false;
        });
        debugPrint('STT Comparison: Three-way results displayed successfully');
      } else {
        throw Exception('Three-way API returned null response');
      }
    } catch (e) {
      debugPrint('STT Comparison: Error in _stopRecordingAndProcess - $e');
      setState(() {
        _error = 'Error processing audio: $e';
        _isProcessing = false;
        _isRecording = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearResults() {
    setState(() {
      _comparisonResult = null;
      _error = null;
    });
  }

  void _toggleTranslationHelper() {
    setState(() {
      _showTranslationHelper = !_showTranslationHelper;
    });
    
    // Provide haptic feedback
    HapticFeedback.selectionClick();
  }

  Future<void> _translateText() async {
    final englishText = _translationController.text.trim();
    if (englishText.isEmpty) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      final result = await ApiService.translateText(
        englishText: englishText,
        targetLanguage: 'th',
      );

      if (mounted && result != null) {
        setState(() {
          _translatedText = result['target_text'] ?? '';
          _romanizedText = result['romanized_text'] ?? '';
          _expectedText = _translatedText; // Set as expected text for comparison
          _expectedTextController.text = _translatedText;
          _isTranslating = false;
        });
      } else {
        setState(() {
          _error = 'Translation failed';
          _isTranslating = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Translation error: $e';
        _isTranslating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Three-Way STT Comparison'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (_comparisonResult != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearResults,
              tooltip: 'Clear results',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Instructions and controls
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Three-Way STT Comparison Test',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Record Thai speech to compare Google Chirp2, AssemblyAI Universal, and Speechmatics Ursa performance across three services.',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    
                    // Translation helper
                    _buildTranslationHelper(),
                    const SizedBox(height: 16),
                    
                    // Expected text input
                    TextField(
                      controller: _expectedTextController,
                      decoration: const InputDecoration(
                        labelText: 'Expected Thai text (optional)',
                        hintText: 'Enter the expected Thai transcription for accuracy comparison',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _expectedText = value;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Enhanced recording controls with visual feedback
                    _buildRecordingInterface(),
                  ],
                ),
              ),
            ),
            
            // STT Service Comparison Results
            STTServiceComparisonWidget(
              comparisonResult: _comparisonResult,
              isLoading: _isProcessing,
              error: _error,
            ),
            
            // Additional tips
            if (_comparisonResult == null && !_isProcessing && _error == null)
              Card(
                margin: const EdgeInsets.all(16),
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tips for best results:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Speak clearly and at a moderate pace\n'
                        '• Record in a quiet environment\n'
                        '• Try different Thai phrases or sentences\n'
                        '• Provide expected text for accuracy comparison\n'
                        '• Compare processing times, confidence scores, and costs\n'
                        '• View winner analysis across speed, accuracy, and cost',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingInterface() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isRecording ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isRecording ? Colors.red.shade300 : Colors.green.shade300,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // Recording status with waveform-like animation
          if (_isRecording) _buildRecordingAnimation(),
          
          // Main recording button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Start/Recording button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : (_isRecording ? null : _startRecording),
                  icon: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 28,
                  ),
                  label: Text(
                    _isRecording ? 'Recording...' : 'Start Recording',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Stop & Process button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : (_isRecording ? _stopRecordingAndProcess : null),
                  icon: _isProcessing 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.stop, size: 28),
                  label: Text(
                    _isProcessing ? 'Processing...' : 'Stop & Process',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isProcessing ? Colors.orange : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // Recording status message
          if (_isRecording || _isProcessing) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red.shade100 : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isRecording ? Icons.fiber_manual_record : Icons.hourglass_empty,
                    color: _isRecording ? Colors.red : Colors.blue,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isRecording 
                      ? 'Listening... Speak clearly in Thai' 
                      : 'Processing with 3 STT services...',
                    style: TextStyle(
                      color: _isRecording ? Colors.red.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecordingAnimation() {
    return Container(
      height: 60,
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(7, (index) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 200 + (index * 50)),
            curve: Curves.easeInOut,
            width: 4,
            height: _isRecording ? (20 + (index % 3) * 20).toDouble() : 8,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTranslationHelper() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _showTranslationHelper ? Colors.blue.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header with toggle
          Material(
            color: _showTranslationHelper ? Colors.blue.shade50 : Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            child: InkWell(
              onTap: _toggleTranslationHelper,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate,
                      size: 20,
                      color: _showTranslationHelper ? Colors.blue.shade700 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Translation Helper - Convert English to Thai',
                        style: TextStyle(
                          color: _showTranslationHelper ? Colors.blue.shade800 : Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Icon(
                      _showTranslationHelper ? Icons.expand_less : Icons.expand_more,
                      color: _showTranslationHelper ? Colors.blue.shade700 : Colors.grey.shade600,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expandable content
          if (_showTranslationHelper)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.3),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Translation input and button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _translationController,
                          decoration: InputDecoration(
                            hintText: 'Type English text to translate to Thai...',
                            hintStyle: const TextStyle(fontSize: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isTranslating ? null : _translateText,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _isTranslating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Translate'),
                      ),
                    ],
                  ),
                  
                  // Translation results
                  if (_translatedText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                              const SizedBox(width: 8),
                              const Text(
                                'Thai Translation:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _translatedText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_romanizedText.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Romanization: $_romanizedText',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'This text has been automatically set as the expected transcription for accuracy comparison.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (_isTranslating) ...[
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Translating...'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}