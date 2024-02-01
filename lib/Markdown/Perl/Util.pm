package Markdown::Perl::Util;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use List::MoreUtils 'first_index';

our @EXPORT = ();
our @EXPORT_OK = qw(split_while remove_prefix_spaces indent_size indented_one_tab horizontal_size);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

# Partition a list into a continuous chunk for which the given code evaluates to
# true, and the rest of the list. Returns a list of two array-ref.
sub split_while : prototype(&@) {
  my $test = shift;
  my $i = first_index { !$test->($_) } @_;
  return (\@_, []) unless $i >= 0;
  my @pass = splice(@_, 0, $i);
  return (\@pass, \@_);
}

# Removes the equivalent of n spaces at the beginning of the line. Tabs are
# matched to a tab-stop of size 4.
# Removes all the spaces if there is less than that.
# If needed, tabs are converted into 4 spaces.
sub remove_prefix_spaces {
  my ($n, $text) = @_;
  my $t = int($n / 4);
  my $s = $n % 4;
  # return substr $text, length($1) if $n % 4 == 0 && $text =~ m/^((?: {0,3}\t| {4}){$t})/;
  for my $i (1 .. $t) {
    if ($text =~ m/^( {0,3}\t| {4})/) {
      # We remove one full tab-stop from the string.
      substr $text, 0, length($1), '';
    } else {
      # We didn’t have a full tab-stop, so we remove as many spaces as we had.
      $text =~ m/^( {0,3})/;
      return substr $text, length($1);
    }
  }
  return $text if $s == 0;
  $text =~ m/^(?<p> {0,3}\t| {4})*?(?<l> {0,3}\t| {4})?(?<s> {0,3})(?<e>[^ \t].*|$)/s;
  my $ns = length $+{s};
  if ($ns >= $s) {
    return ($+{p} // '').($+{l} // '').(' ' x ($ns - $s)).$+{e};
  } elsif (length($+{l})) {
    return ($+{p} // '').(' ' x (4 + $ns - $s)).$+{e};
  } else {
    return $+{e};
  }
}

# Return the indentation of the given text
sub indent_size {
  my ($text) = @_;
  my $t = () = $text =~ m/\G( {0,3}\t| {4})/gc;  # Forcing list context.
  $text =~ m/\G( *)/;
  my $s = length($1);
  return $t * 4 + $s;
}

# Compute the horizontal size of a given string (similar to indent_size, but
# all characters count, not just tabs and space).
sub horizontal_size {
  my ($text) = @_;
  my $t = () = $text =~ m/\G([^\t]{0,3}\t|[^\t]{4})/gc;  # Forcing list context.
  my $s = length($text) - (pos($text) // 0);
  return $t * 4 + $s;
}

# Returns true if the text is indented by at least one tab-stop.
sub indented_one_tab {
  my ($text) = @_;
  return $text =~ m/^(?: {0,3}\t| {4})/;
}

1;
