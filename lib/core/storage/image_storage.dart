abstract interface class ImageStorage {
  /// Copies a selected image into storage and returns its filename.
  Future<String> save(String sourcePath);
  Future<void> delete(String path);
  Future<String> resolvePath(String storedPath);
}
