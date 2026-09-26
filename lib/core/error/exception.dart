sealed class AppException implements Exception {
  const AppException();
}

final class LocalDataSourceException extends AppException {
  const LocalDataSourceException();
}

final class LocalDataNotFoundException extends AppException {
  const LocalDataNotFoundException();
}

final class ImageStorageException extends AppException {
  const ImageStorageException();
}
