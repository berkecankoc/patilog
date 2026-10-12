abstract interface class ImageStorage {
  /// Copies a selected image into storage and returns its filename.
  Future<String> save(String sourcePath);

  /// Deletes a stored photo by filename or legacy absolute path.
  Future<void> delete(String path);

  /// Resolves a filename or legacy absolute path in the current storage directory.
  Future<String> resolvePath(String storedPath);
}
