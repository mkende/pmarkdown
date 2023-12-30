use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run('> abc'), "<blockquote>\n<p>abc</p>\n</blockquote>\n", 'quote1');
is(run("> abc\n> def\n"), "<blockquote>\n<p>abc def</p>\n</blockquote>\n", 'quote2');
is(run("> abc\n\ndef\n"), "<blockquote>\n<p>abc</p>\n</blockquote>\n<p>def</p>\n", 'quote3');
is(run("> abc\n> > def\n"), "<blockquote>\n<p>abc</p>\n<blockquote>\n<p>def</p>\n</blockquote>\n</blockquote>\n", 'quote4');
is(run("> abc\ndef\n"), "<blockquote>\n<p>abc def</p>\n</blockquote>\n", 'quote5');
is(run("> abc\n>\ndef\n"), "<blockquote>\n<p>abc</p>\n</blockquote>\n<p>def</p>\n", 'quote6');

done_testing;
