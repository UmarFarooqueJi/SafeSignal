// -----------------------------------------------------------------------------
// SafeSignal Mobile Security Suite
// Module: Functional Error Handling (Result<T, E> Type)
// Author: Umar Farooque (https://github.com/UmarFarooqueJi)
// Copyright (c) 2026 Umar Farooque (https://github.com/UmarFarooqueJi). All rights reserved.
//
// Implements a type-safe Result monad replacing raw try/catch at API boundaries.
// Used throughout the data layer so errors are explicit and unhandled failures
// become compile-time issues.
// -----------------------------------------------------------------------------

/// A discriminated union representing either a successful [Ok] value
/// or a [Failure] error. Forces callers to handle both branches.
sealed class Result<T> {
  const Result();

  /// Returns `true` when this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Returns `true` when this is a [Failure].
  bool get isFailure => this is Failure<T>;

  /// Extracts the value or throws [StateError] if this is a [Failure].
  T get value {
    if (this is Ok<T>) return (this as Ok<T>).data;
    throw StateError('Result is a Failure: ${(this as Failure<T>).message}');
  }

  /// Returns null if this is a [Failure].
  T? get valueOrNull => this is Ok<T> ? (this as Ok<T>).data : null;

  /// Returns the failure message, or null if [Ok].
  String? get errorMessage =>
      this is Failure<T> ? (this as Failure<T>).message : null;

  /// Transforms the inner value when [Ok], passes [Failure] through unchanged.
  Result<R> map<R>(R Function(T value) transform) {
    if (this is Ok<T>) {
      return Ok(transform((this as Ok<T>).data));
    }
    return Failure<R>(
      (this as Failure<T>).message,
      cause: (this as Failure<T>).cause,
    );
  }

  /// Calls [onOk] when success, [onFailure] when error.
  R fold<R>({
    required R Function(T value) onOk,
    required R Function(String message, Object? cause) onFailure,
  }) {
    if (this is Ok<T>) return onOk((this as Ok<T>).data);
    final f = this as Failure<T>;
    return onFailure(f.message, f.cause);
  }
}

/// Successful result wrapping a value of type [T].
final class Ok<T> extends Result<T> {
  final T data;
  const Ok(this.data);

  @override
  String toString() => 'Ok($data)';
}

/// Failed result carrying an error message and optional cause.
final class Failure<T> extends Result<T> {
  final String message;
  final Object? cause;
  const Failure(this.message, {this.cause});

  @override
  String toString() =>
      'Failure($message${cause != null ? ', cause: $cause' : ''})';
}

/// Convenience extension to wrap values and errors.
extension ResultExtension<T> on T {
  Ok<T> asOk() => Ok(this);
}

extension FutureResultExtension<T> on Future<T> {
  Future<Result<T>> asResult() async {
    try {
      return Ok(await this);
    } catch (e, st) {
      return Failure('$e', cause: st);
    }
  }
}
