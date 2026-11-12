class AuthorInfo {
  final String name;
  final String lowerName;
  final int count;
  final bool isNsfw;
  final String? iconUrl;
  final bool isVerified;

  AuthorInfo({
    required this.name,
    required this.count,
    this.isNsfw = false,
    this.iconUrl,
    this.isVerified = false,
  }) : lowerName = name.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthorInfo &&
          name == other.name &&
          count == other.count &&
          isNsfw == other.isNsfw &&
          iconUrl == other.iconUrl &&
          isVerified == other.isVerified;

  @override
  int get hashCode => Object.hash(name, count, isNsfw, iconUrl, isVerified);

  @override
  String toString() =>
      'AuthorInfo(name: $name, count: $count, isNsfw: $isNsfw, verified: $isVerified)';
}
