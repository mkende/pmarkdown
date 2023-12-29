use strict;
use warnings;
use utf8;

use Markdown::Perl::Util ':all';
use Test2::V0;

{
  my @a = (2, 4, 6, 7, 8, 9, 10);
  is([split_while { $_ % 2 == 0 } @a], [[2, 4, 6], [7, 8, 9, 10]], 'split_while1');
  is (\@a, [2, 4, 6, 7, 8, 9, 10], 'split_while2');
}

{
  my @a = (2, 4, 6);
  is([split_while { $_ % 2 == 0 } @a], [[2, 4, 6], []], 'split_while3');
}

is(remove_prefix_spaces(0, 'test'), 'test', 'remove_prefix_spaces1');
is(remove_prefix_spaces(0, '  test'), '  test', 'remove_prefix_spaces2');
is(remove_prefix_spaces(0, '    test'), '    test', 'remove_prefix_spaces3');
is(remove_prefix_spaces(2, '    test'), '  test', 'remove_prefix_spaces4');
is(remove_prefix_spaces(2, ' test'), 'test', 'remove_prefix_spaces5');
is(remove_prefix_spaces(2, 'test'), 'test', 'remove_prefix_spaces6');
is(remove_prefix_spaces(2, '    test'), '  test', 'remove_prefix_spaces7');
is(remove_prefix_spaces(2, "\ttest"), '  test', 'remove_prefix_spaces8');
is(remove_prefix_spaces(2, " \ttest"), "   test", 'remove_prefix_spaces9');
is(remove_prefix_spaces(2, "  \ttest"), "\ttest", 'remove_prefix_spaces10');
is(remove_prefix_spaces(4, '    test'), 'test', 'remove_prefix_spaces11');
is(remove_prefix_spaces(4, '      test'), '  test', 'remove_prefix_spaces12');
is(remove_prefix_spaces(8, '        test'), 'test', 'remove_prefix_spaces13');
is(remove_prefix_spaces(8, '          test'), '  test', 'remove_prefix_spaces14');
is(remove_prefix_spaces(2, "  \n"), "\n", 'remove_prefix_spaces15');

is(indent_size("abc"), 0, 'indent_size1');
is(indent_size(" abc"), 1, 'indent_size2');
is(indent_size("    abc"), 4, 'indent_size3');
is(indent_size("\tabc"), 4, 'indent_size4');
is(indent_size("  \tabc"), 4, 'indent_size5');
is(indent_size("  \t  abc"), 6, 'indent_size6');
is(indent_size("  \t     abc"), 9, 'indent_size7');

is(indented_one_tab("abc"), F(), 'indented_one_tab0');
is(indented_one_tab("   abc"), F(), 'indented_one_tab1');
is(indented_one_tab("    abc"), T(), 'indented_one_tab2');
is(indented_one_tab("xxx    abc"), F(), 'indented_one_tab3');
is(indented_one_tab("\tabc"), T(), 'indented_one_tab4');
is(indented_one_tab("  \tabc"), T(), 'indented_one_tab5');

done_testing;
