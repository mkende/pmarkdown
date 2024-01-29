use strict;
use warnings;
use utf8;

use Markdown::Perl::InlineTree ':all';
use Test2::V0;

sub text_tree {
  my $t = Markdown::Perl::InlineTree->new();
  for (@_) {
    $t->push(new_text($_)) if $_;
    $t->push(new_code('ignored)')) unless $_;
  }
  return $t;
}

my $t = text_tree('a(bc', '123d(e)f', '', 'gh)i');

is([$t->find_in_text(qr/\(/, 0, 0)], [0, 1, 2], 'find_in_text_from_start');
is([$t->find_in_text(qr/\(/, 1, 0)], [1, 4, 5], 'find_in_text_from_second_child');
is([$t->find_in_text(qr/\(/, 0, 1)], [0, 1, 2], 'find_in_text_from_early_in_first_child');
is([$t->find_in_text(qr/\(/, 0, 2)], [1, 4, 5], 'find_in_text_from_far_in_first_child');
is([$t->find_in_text(qr/\(/, 0, 2, 2, 0)], [1, 4, 5], 'find_in_text_with_bound');
is($t->find_in_text(qr/\(/, 0, 2, 1, 1), U(), 'find_in_text_with_too_small_bound');

is([$t->find_balanced_in_text(qr/\(/, qr/\)/, 0, 2)], [3, 2, 3], 'find_balanced_in_text');

my $nt = $t->extract(1, 3, 3, 2);
is($nt->iter(sub { $_[1].$_[0]->{content} }, ''), 'd(e)fignored)gh', 'extract_extracted');
is($t->iter(sub { $_[1].$_[0]->{content} }, ''), 'a(bc123)i', 'extract_rest');

$nt = $t->extract(0, 0, 2, 2);
is($nt->iter(sub { $_[1].$_[0]->{content} }, ''), 'a(bc123)i', 'extract_all');
is($t->iter(sub { $_[1].$_[0]->{content} }, ''), '', 'extract_rest_nothing');

done_testing;
