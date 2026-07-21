enum WebDavEntryType { directory, file }

class WebDavEntry {
  final String name;
  final String path;
  final WebDavEntryType type;
  final int? size;
  final DateTime? modified;

  const WebDavEntry({
    required this.name,
    required this.path,
    required this.type,
    this.size,
    this.modified,
  });

  bool get isDirectory => type == WebDavEntryType.directory;
}
