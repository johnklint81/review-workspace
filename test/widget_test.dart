import 'package:flutter_test/flutter_test.dart';
import 'package:review_workspace/app/app.dart';

void main() {
  testWidgets('Review Workspace loads successfully', (tester) async {
    await tester.pumpWidget(const ReviewWorkspaceApp());

    expect(find.text('Review Workspace'), findsWidgets);
  });
}