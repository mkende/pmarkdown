package Markdown::Perl::Util;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use List::MoreUtils 'first_index';

our @EXPORT = ();
our @EXPORT_OK = qw(split_while remove_prefix_tab);
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

# Remove the equivalent of n*4 spaces at the beginning of the line. Tabs are
# matched to a tab-stop of size 4.
# Dies if the line does not start with that much tabs (and it’s not a blank
# line).
sub remove_prefix_tab {
  my ($n, $text) = @_;
  return substr $text, length($1) if $text =~ m/^((?: {0,3}\t| {4}){$n})/;
  return $1 if $text =~ m/^[ \t]*([\r\n]*)$/;  # TODO: check exactly for the allowed end of line.
  die ("Can't remove ${n} tab".($n > 1 ? 's' : '')." from the beginning of line: '${text}'\n");
}
