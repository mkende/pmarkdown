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

is(remove_prefix_tab(0, 'test'), 'test', 'remove_prefix_tab1');
is(remove_prefix_tab(0, '  test'), '  test', 'remove_prefix_tab2');
is(remove_prefix_tab(0, '    test'), '    test', 'remove_prefix_tab3');
is(remove_prefix_tab(1, '    test'), 'test', 'remove_prefix_tab4');
is(remove_prefix_tab(1, '      test'), '  test', 'remove_prefix_tab5');
is(remove_prefix_tab(2, '        test'), 'test', 'remove_prefix_tab6');
is(remove_prefix_tab(2, '          test'), '  test', 'remove_prefix_tab7');
like(dies { remove_prefix_tab(1, '  test') }, qr/Can't remove 1 tab from/, 'remove_prefix_tab8');
like(dies { remove_prefix_tab(2, '    test') }, qr/Can't remove 2 tabs from/, 'remove_prefix_tab9');
is(remove_prefix_tab(2, "   \n"), "\n", 'remove_prefix_tab10');

done_testing;
