package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use List::Util 'pairs';
use Markdown::Perl::Util 'split_while', 'remove_prefix_spaces', 'indented_one_tab';
use Scalar::Util 'blessed';

our $VERSION = '0.01';

=pod

=encoding utf8

=cut

sub new {
  my ($class, %options) = @_;
  return bless { %options }, $class;
}

# Returns @_, unless the first argument is not blessed as a Markdown::Perl
# object, in which case it returns a default object.
my $default_this = Markdown::Perl->new();
sub _get_this_and_args {
  my $this = shift @_;
  # We could use `$this isa Markdown::Perl` that does not require to test
  # blessedness first. However this requires 5.31.6 which is not in Debian
  # stable as of writing this.
  unless (blessed($this) && $this->isa(__PACKAGE__)) {
    unshift @_, $this;
    $this = $default_this;
  }
  return ($this, @_);
}

# Takes a string and converts it to HTML. Can be called as a free function or as
# class method. In the latter case, provided options override those set in the
# class constructor.
# Both the input and output are unicode strings.
sub convert {
  my ($this, $md, %options) = &_get_this_and_args;
  $this->{local_options} = \%options;
  
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


  my $blocks = $this->_parse_blocks([], @lines);
  return $this->_emit_html(@{$blocks});
}

# Tail-rec method to parse all the blocks of the document (both leaf and
# container blocks):
# https://spec.commonmark.org/0.30/#blocks-and-inlines
sub _parse_blocks {
  my ($this, $blocks, @tl) = @_;
  return $blocks unless @tl;  # Base case, we have no more lines to process.
  my $hd = shift @tl;
  my $l = $hd->[0];

  # https://spec.commonmark.org/0.30/#thematic-breaks
  if ($l =~ /^ {0,3}(?:(?:-[ \t]*){3,}|(_[ \t]*){3,}|(\*[ \t]*){3,})$/) {
    # Note: thematic breaks can interrupt a paragraph or a list
    return $this->_parse_blocks([@{$blocks}, { type => 'break' }], @tl);
  }

  # https://spec.commonmark.org/0.30/#atx-headings
  if ($l =~ /^ {0,3}(#{1,6})(?:[ \t]+(.+?))??(?:[ \t]+#+)?[ \t]*$/) {
    # Note: heading breaks can interrupt a paragraph or a list
    # TODO: the content of the header needs to be interpreted for inline content.
    return $this->_parse_blocks([@{$blocks}, { type => "heading", level => length($1), content => $2 // '' }], @tl);
  }

  # https://spec.commonmark.org/0.30/#indented-code-blocks
  if (indented_one_tab($l)) {
    my $last = -1;
    for my $i (0..$#tl) {
      if (indented_one_tab($tl[$i]->[0])) {
        $last = $i;
      } elsif ($tl[$i]->[0] ne '') {
        last;
      }
    }
    my @code_lines = splice @tl, 0, ($last + 1);
    my $code = join('', map { remove_prefix_spaces(4, $_->[0].$_->[1]) } ($hd, @code_lines));
    return $this->_parse_blocks([@{$blocks}, { type => "code", content => $code, debug => 'indented'}], @tl);
  }

  # https://spec.commonmark.org/0.30/#fenced-code-blocks
  if ($l =~ /^(?<indent> {0,3})(?<fence>`{3,}|~{3,})[ \t]*(?<info>.*?)[ \t]*$/
            && (((my $f = substr $+{fence}, 0, 1) ne '`') || (index($+{info}, '`') == -1))) {
    my $l = length($+{fence});
    my $info = $+{info};
    my $indent = length($+{indent});
    my ($code_lines, $rest) = split_while { $_->[0] !~ m/^ {0,3}${f}{$l,}[ \t]*$/ } @tl;
    my $code = join('', map { remove_prefix_spaces($indent, $_->[0].$_->[1]) } @{$code_lines});
    # Note that @$rest might be empty if we never find the closing fence. The
    # spec says that we should then consider the whole doc to be a code block
    # although we could consider that this was then not a code-block.
    if (!$this->fenced_code_blocks_must_be_closed || @{$rest}) {
      shift @{$rest};  # OK even if @$rest is empty.
      return $this->_parse_blocks([@{$blocks}, { type => "code", content => $code, info => $info, debug => 'fenced' }], @{$rest});
    } else {
      # pass-through intended
    }
  }

  if ($l eq  '') {
    # TODO: is it correct?
    return $this->_parse_blocks($blocks, @tl);
  } 
  
  {
    ...
  }
  # TODO: https://spec.commonmark.org/0.30/#setext-headings
  # This requires looking at future lines when processing a paragraph.
}

sub _emit_html {
  my ($this, @blocks) = @_;
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
      my $i = '';
      if ($this->code_blocks_info eq 'language' && $b->{info}) {
        my $l = $b->{info} =~ s/\s.*//r;  # The spec does not really cover this behavior so we’re using Perl notion of whitespace here.
        $i = " class=\"language-${l}\"";
      }
      $out .= "<pre><code${i}>$c</code></pre>";
    }
  }
  return $out;
}

sub _get_option {
  my ($this, $option) = @_;
  return $this->{local_options}{$option} // $this->{$option};
}

=pod

=head1 CONFIGURATION OPTIONS

=over 4

=item B<fenced_code_blocks_must_be_closed> I<default: false>

By default, a fenced code block with no closing fence will run until the end of
the document. With this setting, the openning fence will be treated as normal
text, rather than the start of a code block, if there is no matching closing
fence.

=cut

sub fenced_code_blocks_must_be_closed {
  my ($this) = @_;
  return $this->_get_option('fenced_code_blocks_must_be_closed') // 0;
}

=pod

=item B<code_blocks_info> I<default: language>

=over 4

=item B<none>

=item B<language>

=back

=cut

sub code_blocks_info {
  my ($this) = @_;
  return $this->_get_option('code_blocks_info') // 'language';
}

=pod

=back

=cut

1;
