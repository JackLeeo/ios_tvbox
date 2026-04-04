import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ios_tvbox/main.dart';

void main() {
  testWidgets('App启动测试', (WidgetTester tester) async {
    // 构建应用，验证正常启动
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
