import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/assessment_repository.dart';
import '../domain/assessment.dart';

final assessmentQuestionsProvider = StreamProvider<List<AssessmentQuestion>>(
  (ref) => ref.watch(assessmentRepositoryProvider).watchQuestions(),
);

/// The newest approved driver names, or null (the file's names stay).
final liveDriverLabelsProvider = StreamProvider<List<String>?>(
  (ref) => ref.watch(assessmentRepositoryProvider).watchDriverLabels(),
);

/// The person's latest driver scores (0..1 by driver id), or null.
final latestDriverScoresProvider = StreamProvider<Map<String, double>?>(
  (ref) => ref.watch(assessmentRepositoryProvider).watchLatestScores(),
);
