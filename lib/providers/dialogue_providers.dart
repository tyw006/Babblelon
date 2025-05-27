import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dialogue_providers.g.dart';

class DialogueData {
  final List<String> lines;
  final bool isExpanded;

  DialogueData({
    this.lines = const [
      'Player: Hi! What do you have today?',
      'NPC: Hello there, welcome to my stall!',
      'Player: I am looking for some delicious dumplings.',
      'NPC: You have come to the right place! We have the best in town.',
      'Player: Great! I will take a dozen.',
      'NPC: Coming right up!',
      'Player: Thanks!',
      'NPC: Enjoy!',
    ],
    this.isExpanded = false,
  });

  DialogueData copyWith({List<String>? lines, bool? isExpanded}) => DialogueData(
    lines: lines ?? this.lines,
    isExpanded: isExpanded ?? this.isExpanded,
  );
}

@Riverpod(keepAlive: true)
class DialogueState extends _$DialogueState {
  @override
  DialogueData build() => DialogueData();

  void addLine(String line) => state = state.copyWith(lines: [...state.lines, line]);
  void setExpanded(bool expanded) => state = state.copyWith(isExpanded: expanded);
} 