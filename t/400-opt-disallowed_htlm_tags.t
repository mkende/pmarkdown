use strict;
use warnings;
use utf8;

use Markdown::Perl 'convert';
use Test2::V0;

is(convert("<div>\n<title>\n</div>"), "<div>\n<title>\n</div>", 'html_block_no_disallowed_tag');
is(convert("foo <title> bar"), "<p>foo <title> bar</p>\n", 'inline_html_no_disallowed_tag');

is(convert("<div>\n<title>\n</div>", disallowed_htlm_tags => [qw(foo title)]), "<div>\n&lt;title>\n</div>", 'html_block_disallowed_tag');
is(convert("foo <title> bar", disallowed_htlm_tags => [qw(foo title)]), "<p>foo &lt;title> bar</p>\n", 'inline_html_disallowed_tag');

is(convert("<div>\n<title>\n</div>", disallowed_htlm_tags => "foo,title"), "<div>\n&lt;title>\n</div>", 'html_block_disallowed_tag_from_string');
is(convert("foo <title> bar", disallowed_htlm_tags => "foo,title"), "<p>foo &lt;title> bar</p>\n", 'inline_html_disallowed_tag_from_string');

done_testing;
