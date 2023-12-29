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

is(run('# test'), "<h1>test</h1>\n", 'h1');
is(run('#'), "<h1></h1>\n", 'h2');
is(run('## '), "<h2></h2>\n", 'h3');
is(run('#### ###'), "<h4></h4>\n", 'h4');
is(run('## other   '), "<h2>other</h2>\n", 'h5');

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

done_testing;
