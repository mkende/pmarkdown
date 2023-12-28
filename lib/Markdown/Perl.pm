package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use List::Util 'pairs';
use Markdown::Perl::Util 'remove_prefix_tab';
use Scalar::Util 'blessed';

our $VERSION = '0.01';

sub new {
  my ($class, %options) = @_;
  return bless { %options }, $class;
}

# Returns @_, unless the first argument is not blessed as a Markdown::Perl
# object, in which case it returns a default object for now, an empty hash-ref.
sub _get_this_and_args {
  my $this = shift @_;
  # We could use `$this isa Markdown::Perl` that does not require to test
  # blessedness first. However this requires 5.31.6 which is not in Debian
  # stable as of writing this.
  unless (blessed($this) && $this->isa(__PACKAGE__)) {
    unshift @_, $this;
    $this = {};
  }
  return ($this, @_);
}

# Takes a string and converts it to HTML. Can be called as a free function or as
# class method. In the latter case, provided options override those set in the
# class constructor.
# Both the input and output are unicode strings.
sub convert {
  my ($this, $md, %options) = &_get_this_and_args;
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


  # TODO: implement this with a has_tabs_stop(n) method shared with remove_prefix_tab.
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
      my $last = -1;
      for my $i (0..$#tl) {
        if (is_indented_code_block($tl[$i]->[0])) {
          $last = $i;
        } elsif ($tl[$i]->[0] ne '') {
          last;
        }
      }
      my @code_lines = splice @tl, 0, ($last + 1);
      my $code = join('', map { remove_prefix_tab(1, $_->[0].$_->[1]) } ($hd, @code_lines));
      return parse_blocks([@{$blocks}, { type => "code", content => $code }], @tl);
    } elsif ($l eq  '') {
      # TODO: is it correct?
      return parse_blocks($blocks, @tl);
    } elsif (0) {
      # https://spec.commonmark.org/0.30/#fenced-code-blocks
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

1;
