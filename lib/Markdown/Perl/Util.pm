package Markdown::Perl::Util;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use List::MoreUtils 'first_index';

our @EXPORT = ();
our @EXPORT_OK = qw(split_while remove_prefix_space);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

# Partition a list into a continuous chunk for which the given code evaluates to
# true, and the rest of the list. Returns a list of two array-ref.
sub split_while :prototype(&@) {
  my $test = shift;
  my $i = first_index { ! $test->($_) } @_;
  return (\@_, []) unless $i >= 0;
  my @pass = splice(@_, 0, $i);
  return (\@pass,  \@_);
}

# Remove the equivalent of n spaces at the beginning of the line. Tabs are
# matched to a tab-stop of size 4. `n` is expected to be a multiple of 4.
sub remove_prefix_space {
  my ($n, $text) = @_;
  my $t = int($n / 4);
  return substr $text, length($1) if $text =~ m/^((?: {0,3}\t| {4}){$t})/;
  return $1 if $text =~ m/^[ \t]*([\r\n]*)$/;  # TODO: check exactly for the allowed end of line.
  die "Can't remove ${n} spaces at the beginning of line: '${text}'\n";
}
