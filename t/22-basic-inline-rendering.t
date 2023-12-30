use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run("abc\ndef\n"), "<p>abc\ndef</p>\n", 'soft_break');
is(run("abc  \ndef\n"), "<p>abc<br />\ndef</p>\n", 'hard_break1');
is(run("abc\ndef  \n"), "<p>abc\ndef</p>\n", 'hard_break2');

done_testing;
