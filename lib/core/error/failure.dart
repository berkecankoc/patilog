sealed class Failure {
  final String message;
  const Failure(this.message);
}

final class LocalDatabaseFailure extends Failure {
  const LocalDatabaseFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}
