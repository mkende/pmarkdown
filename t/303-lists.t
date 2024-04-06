use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run("* a\n* b\n* c\n\n\nfoo"), "<ul>\n<li>a</li>\n<li>b</li>\n<li>c</li>\n</ul>\n<p>foo</p>\n", 'list is tight');

done_testing;
