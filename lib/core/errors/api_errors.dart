import 'package:equatable/equatable.dart';

abstract class ApiError extends Equatable{
  final String message;
  const ApiError(this.message);

  @override
  List<Object?> get props => [message];
}

class InternalSeverError extends ApiError{
  const InternalSeverError(super.message);
}

class NetworkError extends ApiError{
  const NetworkError(super.message);
}

class CacheError extends ApiError{
  const CacheError(super.message);
}
