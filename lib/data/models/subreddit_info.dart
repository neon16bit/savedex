class SubredditInfo {
  final String name;
  final String lowerName;
  final int count;
  final bool isNsfw;
  final String? iconUrl;
  final bool isVerified;

  SubredditInfo({
    required this.name,
    required this.count,
    this.isNsfw = false,
    this.iconUrl,
    this.isVerified = false,
  }) : lowerName = name.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubredditInfo &&
          name == other.name &&
          count == other.count &&
          isNsfw == other.isNsfw &&
          iconUrl == other.iconUrl &&
          isVerified == other.isVerified;

  @override
  int get hashCode => Object.hash(name, count, isNsfw, iconUrl, isVerified);

  @override
  String toString() =>
      'SubredditInfo(name: $name, count: $count, isNsfw: $isNsfw, verified: $isVerified)';
}
