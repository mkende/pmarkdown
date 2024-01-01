use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run("> ```\n> abc\n> def\n> ```"), "<blockquote>\n<pre><code>abc\ndef\n</code></pre>\n</blockquote>\n", 'fenced_code_in_quotes');
is(run(">     abc\n>     def\n"), "<blockquote>\n<pre><code>abc\ndef\n</code></pre>\n</blockquote>\n", 'indented_code_in_quotes');

done_testing;
