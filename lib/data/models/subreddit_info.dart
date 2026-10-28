class SubredditInfo {
  final String name;
  final int count;
  final bool isNsfw;
  final String? iconUrl;
  final bool isVerified;

  const SubredditInfo({
    required this.name,
    required this.count,
    this.isNsfw = false,
    this.iconUrl,
    this.isVerified = false,
  });

  String get $1 => name;
  int get $2 => count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubredditInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          count == other.count &&
          isNsfw == other.isNsfw &&
          iconUrl == other.iconUrl &&
          isVerified == other.isVerified;

  @override
  int get hashCode =>
      name.hashCode ^
      count.hashCode ^
      isNsfw.hashCode ^
      iconUrl.hashCode ^
      isVerified.hashCode;

  @override
  String toString() =>
      'SubredditInfo(name: $name, count: $count, isNsfw: $isNsfw, verified: $isVerified)';
}
