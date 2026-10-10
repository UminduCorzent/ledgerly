/// Version and build identity shown in Settings → About.
///
/// [version] must match `pubspec.yaml`. The build number and commit are injected
/// by CI with `--dart-define`, so a tester can tell exactly which build they
/// are looking at.
class AppInfo {
  const AppInfo._();

  static const String version = '1.1.0';
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: 'dev');
  static const String buildSha =
      String.fromEnvironment('BUILD_SHA', defaultValue: 'local');
}
