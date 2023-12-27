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

is(run('    test'), "<pre><code>test</code></pre>", 'code1');
is(run("    test\n      next\n"), "<pre><code>test\n  next\n</code></pre>", 'code2');

done_testing;
