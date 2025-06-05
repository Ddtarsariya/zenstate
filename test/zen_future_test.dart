import 'package:flutter_test/flutter_test.dart';
import 'package:zenstate/src/async/zen_future.dart';

void main() {
  group('ZenFuture', () {
    test('should initialize with initial status', () {
      final future = ZenFuture<int>();

      expect(future.status, ZenStatus.initial);
      expect(future.isInitial, true);
      expect(future.isLoading, false);
      expect(future.isSuccess, false);
      expect(future.isError, false);
      expect(future.data, null);
      expect(future.error, null);
      expect(future.stackTrace, null);
    });

    test('should transition to loading and success states', () async {
      final future = ZenFuture<int>();

      // Capture state changes
      final states = <ZenStatus>[];
      future.addListener(() {
        states.add(future.status);
      });

      // Start loading
      future.load(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        return 42;
      });

      expect(future.isLoading, true);

      // Wait for completion
      await Future.delayed(const Duration(milliseconds: 20));

      expect(future.isSuccess, true);
      expect(future.data, 42);
      expect(states, [ZenStatus.loading, ZenStatus.success]);
    });

    test('should transition to error state on exception', () async {
      final future = ZenFuture<int>();

      // Capture state changes
      final states = <ZenStatus>[];
      future.addListener(() {
        states.add(future.status);
      });

      // Start loading with an error
      future.load(() async {
        await Future.delayed(const Duration(milliseconds: 10));
        throw Exception('Test error');
      }).catchError((_) {
        // Catch the error to prevent the test from failing
      });

      expect(future.isLoading, true);

      // Wait for completion
      await Future.delayed(const Duration(milliseconds: 20));

      expect(future.isError, true);
      expect(future.error.toString(), contains('Test error'));
      expect(states, [ZenStatus.loading, ZenStatus.error]);
    });

    test('should create with data', () {
      final future = ZenFuture.withData<int>(42);

      expect(future.isSuccess, true);
      expect(future.data, 42);
    });

    test('should create with error', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final future = ZenFuture.withError<int>(error, stackTrace);

      expect(future.isError, true);
      expect(future.error, error);
      expect(future.stackTrace, stackTrace);
    });

    test('should map data to a different type', () async {
      final future = ZenFuture.withData<int>(42);
      final mapped = future.map<String>((data) => 'Value: $data');

      expect(mapped.isSuccess, true);
      expect(mapped.data, 'Value: 42');
    });

    test('should execute when callbacks based on state', () {
      final initialFuture = ZenFuture<int>();
      final loadingFuture = ZenFuture<int>(status: ZenStatus.loading);
      final successFuture = ZenFuture.withData<int>(42);
      final errorFuture = ZenFuture.withError<int>(
        Exception('Test error'),
        StackTrace.current,
      );

      expect(
        initialFuture.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          error: (error, _) => 'error: $error',
        ),
        'initial',
      );

      expect(
        loadingFuture.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          error: (error, _) => 'error: $error',
        ),
        'loading',
      );

      expect(
        successFuture.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          error: (error, _) => 'error: $error',
        ),
        'success: 42',
      );

      expect(
        errorFuture.when(
          initial: () => 'initial',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          error: (error, _) => 'error: $error',
        ),
        contains('error: Exception'),
      );
    });

    test('should reset to initial state', () {
      final future = ZenFuture.withData<int>(42);

      expect(future.isSuccess, true);
      expect(future.data, 42);

      future.reset();

      expect(future.isInitial, true);
      expect(future.data, null);
    });
  });
}
