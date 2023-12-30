use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run('***'), "<hr />\n", 'break1');
is(run(' -  - -'), "<hr />\n", 'break2');
is(run('   ___        __     '), "<hr />\n", 'break3');

is(run('# test'), "<h1>test</h1>\n", 'atx_heading1');
is(run('#'), "<h1></h1>\n", 'atx_heading2');
is(run('## '), "<h2></h2>\n", 'atx_heading3');
is(run('#### ###'), "<h4></h4>\n", 'atx_heading4');
is(run('## other   '), "<h2>other</h2>\n", 'atx_heading5');

is(run("abc\n===\n"), "<h1>abc</h1>\n", 'setext_heading1');
is(run("abc\ndef\n===\n"), "<h1>abc\ndef</h1>\n", 'setext_heading2');
is(run("abc\n---\n"), "<h2>abc</h2>\n", 'setext_heading3');
is(run("   abc\n===\n"), "<h1>   abc</h1>\n", 'setext_heading4');  # TODO: this is wrong, atsome point the spaces must be remove in the output
is(run("abc\n   =\n"), "<h1>abc</h1>\n", 'setext_heading5');

is(run('    test'), "<pre><code>test</code></pre>", 'indented_code1');
is(run("    test\n      next\n"), "<pre><code>test\n  next\n</code></pre>", 'indented_code2');
is(run("\t  test\n\t  next\n"), "<pre><code>  test\n  next\n</code></pre>", 'indented_code3');

is(run("```\ntest\n```"), "<pre><code>test\n</code></pre>", 'fenced_code1');
is(run("  ```\ntest\n   other\n```"), "<pre><code>test\n other\n</code></pre>", 'fenced_code2');
is(run("```\ntest\nother\n"), "<pre><code>test\nother\n</code></pre>", 'fenced_code3');
is(run("~~~~\ntest\n~~~~"), "<pre><code>test\n</code></pre>", 'fenced_code4');
is(run("~~~~\ntest\n~~~"), "<pre><code>test\n~~~</code></pre>", 'fenced_code5');
is(run("```abc\ntest\n```"), "<pre><code class=\"language-abc\">test\n</code></pre>", 'fenced_code6');
is(run("```abc def\ntest\n```"), "<pre><code class=\"language-abc\">test\n</code></pre>", 'fenced_code7');

is(run("abc"), "<p>abc</p>\n", 'paragraph1');
is(run("abc\ndef"), "<p>abc\ndef</p>\n", 'paragraph2');
is(run("abc\n\ndef"), "<p>abc</p>\n<p>def</p>\n", 'paragraph3');

done_testing;
