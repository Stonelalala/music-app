class DuplicateFile {
  const DuplicateFile({
    required this.id,
    required this.filename,
    required this.extension,
    required this.size,
    this.artist = '未知艺术家',
    this.album = '未知专辑',
    this.duration = 0,
    this.bitrate = 0,
    this.sampleRate = 0,
    this.qualityScore = 0,
    this.isRecommendedKeep = false,
    this.recommendedDelete = false,
  });

  final String id;
  final String filename;
  final String extension;
  final int size;
  final String artist;
  final String album;
  final double duration;
  final int bitrate;
  final int sampleRate;
  final int qualityScore;
  final bool isRecommendedKeep;
  final bool recommendedDelete;

  factory DuplicateFile.fromJson(Map<String, dynamic> json) => DuplicateFile(
    id: (json['id'] as String?) ?? '',
    filename: (json['filename'] as String?) ?? '未知文件',
    extension: (json['extension'] as String?) ?? '',
    size: ((json['size'] as num?) ?? 0).round(),
    artist: (json['artist'] as String?) ?? '未知艺术家',
    album: (json['album'] as String?) ?? '未知专辑',
    duration: ((json['duration'] as num?) ?? 0).toDouble(),
    bitrate: ((json['bitrate'] as num?) ?? 0).round(),
    sampleRate: ((json['sampleRate'] as num?) ?? 0).round(),
    qualityScore: ((json['qualityScore'] as num?) ?? 0).round(),
    isRecommendedKeep: json['isRecommendedKeep'] == true,
    recommendedDelete: json['recommendedDelete'] == true,
  );

  bool get isLossless {
    const extensions = {'.flac', '.wav', '.ape', '.alac', '.aiff'};
    return extensions.contains(extension.toLowerCase());
  }
}

class DuplicateGroup {
  const DuplicateGroup({
    required this.title,
    required this.artist,
    required this.files,
    this.recommendedKeepId,
  });

  final String title;
  final String artist;
  final String? recommendedKeepId;
  final List<DuplicateFile> files;

  factory DuplicateGroup.fromJson(Map<String, dynamic> json) => DuplicateGroup(
    title: (json['title'] as String?) ?? '未知标题',
    artist: (json['artist'] as String?) ?? '未知艺术家',
    recommendedKeepId: json['recommendedKeepId'] as String?,
    files: ((json['files'] as List<dynamic>?) ?? const [])
        .map(
          (item) =>
              DuplicateFile.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
  );
}

Set<String> buildRecommendedSelection(List<DuplicateGroup> groups) {
  final selected = <String>{};

  for (final group in groups) {
    final explicitDeletes = group.files
        .where((file) => file.recommendedDelete)
        .map((file) => file.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (explicitDeletes.isNotEmpty) {
      selected.addAll(explicitDeletes);
      continue;
    }

    var keepId = group.recommendedKeepId;
    keepId ??= _findRecommendedKeep(group.files)?.id;
    keepId ??= group.files.isNotEmpty ? group.files.first.id : null;

    for (final file in group.files) {
      if (file.id.isEmpty || file.id == keepId) {
        continue;
      }
      selected.add(file.id);
    }
  }

  return selected;
}

DuplicateFile? _findRecommendedKeep(List<DuplicateFile> files) {
  for (final file in files) {
    if (file.isRecommendedKeep) {
      return file;
    }
  }
  return null;
}
