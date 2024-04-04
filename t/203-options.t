use strict;
use warnings;
use utf8;

use Markdown::Perl 'convert';
use Test2::V0;

is(convert("~abc~"), "<p><s>abc</s></p>\n", 'default');
is(convert("~abc~", mode => 'cmark'), "<p>~abc~</p>\n", 'set_mode');
is(convert("~abc~"), "<p><s>abc</s></p>\n", 'default_again');

done_testing;
