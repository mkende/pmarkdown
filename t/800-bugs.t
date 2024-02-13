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

done_testing;
