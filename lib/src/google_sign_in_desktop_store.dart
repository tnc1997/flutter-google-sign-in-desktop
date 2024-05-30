/// Defines methods to get a value from a store and set a value in a store.
abstract class GoogleSignInDesktopStore<T> {
  /// Gets the value from the store.
  Future<T?> get();

  /// Sets the [value] in the store.
  Future<void> set(T? value);
}
