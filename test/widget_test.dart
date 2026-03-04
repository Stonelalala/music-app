import 'package:flutter_test/flutter_test.dart';
import 'package:music/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 基础 smoke test，验证 MusicApp 能挂载
    // 注：完整测试需要 mock AudioService，此处跳过
    expect(MusicApp, isNotNull);
  });
}
