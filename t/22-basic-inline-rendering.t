use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run("abc"), "<p>abc</p>\n", 'line1');
is(run("abc\n"), "<p>abc</p>\n", 'line2');
is(run(" abc "), "<p>abc</p>\n", 'line3');

is(run("abc\ndef\n"), "<p>abc\ndef</p>\n", 'soft_break');
is(run("abc  \ndef\n"), "<p>abc<br />\ndef</p>\n", 'hard_break1');
is(run("abc\ndef  \n"), "<p>abc\ndef</p>\n", 'hard_break2');
is(run("abc\\\ndef"), "<p>abc<br />\ndef</p>\n", 'hard_break3');
is(run("abc\\\\\ndef"), "<p>abc\\\ndef</p>\n", 'hard_break4');
is(run("abc\\\\\\\ndef"), "<p>abc\\<br />\ndef</p>\n", 'hard_break5');

is(run("abc `def` ghi"), "<p>abc <code>def</code> ghi</p>\n", 'code1');
is(run("abc`def`ghi"), "<p>abc<code>def</code>ghi</p>\n", 'code2');
is(run("abc``def`ghi``"), "<p>abc<code>def`ghi</code></p>\n", 'code3');
is(run("`` ` ``"), "<p><code>`</code></p>\n", 'code4');
is(run("``  ``"), "<p><code>  </code></p>\n", 'code5');

is(run("`abc`def`"), "<p><code>abc</code>def`</p>\n", 'escaped_code1');
is(run("\\`abc`def`"), "<p>`abc<code>def</code></p>\n", 'escaped_code2');
is(run("`abc\\`def`"), "<p><code>abc\\</code>def`</p>\n", 'escaped_code3');
is(run("\\\\`abc`def`"), "<p>\\<code>abc</code>def`</p>\n", 'escaped_code4');

is(run("&="), "<p>&amp;=</p>\n", 'html_escape1');
is(run("&amp;"), "<p>&amp;</p>\n", 'html_escape2');
is(run("`&amp;`"), "<p><code>&amp;amp;</code></p>\n", 'html_escape3');

is(run("&copy;"), "<p>©</p>\n", 'html_decode1');
is(run("`&copy;`"), "<p><code>&amp;copy;</code></p>\n", 'html_decode2');

done_testing;
