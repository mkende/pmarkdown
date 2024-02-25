use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

todo 'Link destination parsed as closing HTML tag' => sub {
  is(run('[foo](</bar>)'), "<p><a href=\"/bar\">foo</a></p>\n", 'todo1');
};

todo 'Keep the first appearence of a link reference definition' => sub {
  is(run("[foo][bar]\n\n[bar]: /url\n[bar]: /other"), "<p><a href=\"/url\">foo</a></p>\n", 'todo2');
};

todo 'New lines are forbidden in link dest' => sub {
  # This fails because the inner brackets are parsed as HTML and the code does
  # not check for new-line inside non-text nodes, inside the span delimited by
  # the outer brackets (like it does if the link destination is not in
  # brackets).
  is(run("[link](<dest <foo\nbar>>)"), "<p>[link](&lt;dest <foo\nbar>&gt;)</p>\n", 'newline in bracket in bracket in link');
};

todo 'Container block markers are not processed in subsequent lines of link reference definition' => sub {
  is(run("[foo]\n\n> [foo]:\n> /url\n"), "<p><a href=\"/url\">foo</a></p>\n<blockquote>\n<blockquote>\n", 'multi-line link reference definition in container block');
};

done_testing;
