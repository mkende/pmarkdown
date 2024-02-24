use strict;
use warnings;
use utf8;

use Markdown::Perl;
use Test2::V0;

sub run {
  &Markdown::Perl::convert;
}

is(run("[foo][bar]\n\n[bar]: /url"), "<p><a href=\"/url\">foo</a></p>\n", 'one_reference_link');
is(run("[foo][bar]\n\n[bar]: /url 'the title'"), "<p><a href=\"/url\" title=\"the title\">foo</a></p>\n", 'one_reference_link_with_title');

is(run("[foo][]\n\n[foo]: /url"), "<p><a href=\"/url\">foo</a></p>\n", 'collapsed_reference_link');
is(run("[foo]\n\n[foo]: /url"), "<p><a href=\"/url\">foo</a></p>\n", 'shortcut_reference_link');

done_testing;
