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

done_testing;
