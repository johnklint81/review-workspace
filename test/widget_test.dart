import 'package:flutter_test/flutter_test.dart';
import 'package:review_workspace/data/demo_data.dart';

void main() {
  test('an article with two matching votes is complete without conflict', () {
    const article = ReviewArticle('1', 'Example', 'A', 'B', 'Include', 'Include');
    expect(article.isComplete, isTrue);
    expect(article.isConflict, isFalse);
  });

  test('an article with different votes has a conflict', () {
    const article = ReviewArticle('2', 'Example', 'A', 'B', 'Include', 'Exclude');
    expect(article.isComplete, isTrue);
    expect(article.isConflict, isTrue);
  });
}
