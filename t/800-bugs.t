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
}
done_testing;
