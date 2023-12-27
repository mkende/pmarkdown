package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use List::MoreUtils 'first_index';
use List::Util 'pairs';
use Scalar::Util 'blessed';

our $VERSION = '0.01';

sub new {
  my ($class, %options) = @_;
  return bless { %options }, $class;
}

# Partition a list into a continuous chunk for which the given code evaluates to
# true, and the rest of the list. Returns a list of two array-ref.
sub _split_while :prototype(&@) {
  my $test = shift;
  my $i = first_index { ! $test->($_) } @_;
  my @pass = splice @_, 0, $i;
  # TODO: test if it’s safe to return (\@pass, \@_) or if some aliasing would occur.
  return ([@pass],  [@_]);
}

# Remove the equivalent of n spaces at the beginning of the line. Tabs are
# matched to a tab-stop of size 4. `n` is expected to be a multiple of 4.
sub _remove_prefix_space {
  my ($n, $text) = @_;
  my $t = int($n / 4);
  return substr $text, length($1) if $text =~ m/^((?: {0,3}\t| {4}){$t})/;
  return '' if $text =~ m/^[ \t]*[\r\n]*$/;  # TODO: check exactly for the allowed end of line.
  die "Can't remove ${n} spaces at the beginning of line: '${text}'\n";
}

# Takes a string and converts it to HTML. Can be called as a free function or as
# class method. In the latter case, provided options override those set in the
# class constructor.
# Both the input and output are unicode strings.
sub convert {
  my $this = shift @_;
  # We could use `$this isa Markdown::Perl` that does not require to test
  # blessedness first. However this requires 5.31.6 which is not in Debian
  # stable as of writing this.
  unless (blessed($this) && $this->isa("Markdown::Perl")) {
    unshift @_, $this;
    $this = {};
  }
  my ($md, %options) = @_;
  %options = (%{$this}, %options);
  
  # https://spec.commonmark.org/0.30/#characters-and-lines
  my @lines = split(/(\n|\r|\r\n)/, $md);
  push @lines, '' if @lines % 2 != 0;  # Add a missing line ending.
  @lines = pairs @lines;
  # We simplify all blank lines (but keep the data around as it does matter in
  # some cases, so we move the black part to the line separator field).
  map { $_ = ['', $_->[0].$_->[1]] if $_->[0] =~ /^[ \t]+$/ } @lines;

  # https://spec.commonmark.org/0.30/#tabs
  # TODO: nothing to do at this stage.

  # https://spec.commonmark.org/0.30/#insecure-characters
  map { $_->[0] =~ s/\000/\xfffd/g } @lines;

  # https://spec.commonmark.org/0.30/#backslash-escapes
  # TODO: at a later stage, as escaped characters don’t have their Markdown
  # meaning, we need a way to represent that.
  # map { s{\\(.)}{slash_escape($1)}ge } @lines

  # https://spec.commonmark.org/0.30/#entity-and-numeric-character-references
  # TODO: probably nothing is needed here.


  # TODO: implement this with a has_tabs_stop(n) method shared with _remove_prefix_space.
  sub is_indented_code_block {
    return $_[0] =~ /^(?:(?: {0,3}\t)| {4})/;
  }

  sub parse_blocks {
    return $_[0] if @_ == 1;  # Base case, we have no more lines to process.
    my ($blocks, $hd, @tl) = @_;
    my $l = $hd->[0];
    if ($l =~ /^ {0,3}(?:(?:-[ \t]*){3,}|(_[ \t]*){3,}|(\*[ \t]*){3,})$/) {
      # https://spec.commonmark.org/0.30/#thematic-breaks
      # Note: thematic breaks can interrupt a paragraph or a list
      return parse_blocks([@{$blocks}, { type => 'break' }], @tl);
    } elsif ($l =~ /^ {0,3}(#{1,6})(?:[ \t]+(.+?))??(?:[ \t]+#+)?[ \t]*$/) {
      # https://spec.commonmark.org/0.30/#atx-headings
      # Note: heading breaks can interrupt a paragraph or a list
      # TODO: the content of the header needs to be interpreted for inline content.
      return parse_blocks([@{$blocks}, { type => "heading", level => length($1), content => $2 // '' }], @tl);
    } elsif (is_indented_code_block($l)) {
      # https://spec.commonmark.org/0.30/#indented-code-blocks
      my ($code_lines, $rest) = _split_while { is_indented_code_block($_[0]) || $_[0] eq '' } @tl;
      my $code = join('', map { _remove_prefix_space(4, $_->[0].$_->[1]) } ($hd, @{$code_lines}));
      return parse_blocks([@{$blocks}, { type => "code", content => $code }], @{$rest});
    } else {
      ...
    }
    # TODO: https://spec.commonmark.org/0.30/#setext-headings
    # This requires looking at future lines when processing a paragraph.
  }
  my $blocks = parse_blocks([], @lines);

  sub emit_html {
    my (@blocks) = @_;
    my $out =  '';
    for my $b (@blocks) {
      if ($b->{type} eq 'break') {
        $out .= "<hr />\n";
      } elsif ($b->{type} eq 'heading') {
        my $l = $b->{level};
        my $c = $b->{content};
        $out .= "<h${l}>$c</h${l}>\n";
      } elsif ($b->{type} eq 'code') {
        my $c = $b->{content};
        $out .= "<pre><code>$c</code></pre>";
      }
    }
    return $out;
  }
  return emit_html(@{$blocks});
}
