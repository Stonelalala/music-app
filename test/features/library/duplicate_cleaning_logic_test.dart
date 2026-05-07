import 'package:flutter_test/flutter_test.dart';
import 'package:music/features/library/duplicate_cleaning_logic.dart';

void main() {
  test('buildRecommendedSelection uses explicit backend recommendations', () {
    final groups = [
      DuplicateGroup(
        title: 'AI',
        artist: '薛之谦',
        recommendedKeepId: 'keep',
        files: const [
          DuplicateFile(
            id: 'keep',
            filename: 'AI.flac',
            extension: '.flac',
            size: 20,
            isRecommendedKeep: true,
          ),
          DuplicateFile(
            id: 'delete-a',
            filename: 'AI.mp3',
            extension: '.mp3',
            size: 10,
            recommendedDelete: true,
          ),
          DuplicateFile(
            id: 'delete-b',
            filename: 'AI_copy.mp3',
            extension: '.mp3',
            size: 9,
            recommendedDelete: true,
          ),
        ],
      ),
    ];

    expect(buildRecommendedSelection(groups), equals({'delete-a', 'delete-b'}));
  });

  test('buildRecommendedSelection falls back to keep-first ordering', () {
    final groups = [
      DuplicateGroup(
        title: 'Daylight',
        artist: 'Maroon 5',
        files: const [
          DuplicateFile(
            id: 'keep',
            filename: 'Daylight.flac',
            extension: '.flac',
            size: 20,
          ),
          DuplicateFile(
            id: 'delete',
            filename: 'Daylight.mp3',
            extension: '.mp3',
            size: 10,
          ),
        ],
      ),
    ];

    expect(buildRecommendedSelection(groups), equals({'delete'}));
  });

  test('DuplicateGroup.fromJson parses recommendation flags safely', () {
    final group = DuplicateGroup.fromJson({
      'title': 'Cloudy Day',
      'artist': 'Marcin Przybylowicz',
      'recommendedKeepId': 'keep',
      'files': [
        {
          'id': 'keep',
          'filename': 'Cloudy Day.flac',
          'extension': '.flac',
          'size': 123,
          'isRecommendedKeep': true,
        },
        {
          'id': 'delete',
          'filename': 'Cloudy Day.mp3',
          'extension': '.mp3',
          'size': 45,
          'recommendedDelete': true,
        },
      ],
    });

    expect(group.recommendedKeepId, 'keep');
    expect(group.files.first.isRecommendedKeep, isTrue);
    expect(group.files.last.recommendedDelete, isTrue);
  });
}
