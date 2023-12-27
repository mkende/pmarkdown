use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

is(Markdown::Perl::convert('***'), "<hr />\n");
is(Markdown::Perl::convert(' -  - -'), "<hr />\n");
is(Markdown::Perl::convert('   ___        __     '), "<hr />\n");

done_testing;
