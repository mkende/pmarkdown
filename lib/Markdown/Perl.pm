package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Scalar::Util 'blessed';

our $VERSION = '0.01';

sub new {
  my ($class, %options) = @_;
  return bless { %options }, $class;
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
  my @lines = split(/\n|\r|\r\n/, $md);
  map { $_ = '' if /^[ \t]+$/ } @lines;  # We simplify all blank lines.

  # https://spec.commonmark.org/0.30/#tabs
  # TODO: nothing to do at this stage.

  # https://spec.commonmark.org/0.30/#insecure-characters
  map { s/\000/\xfffd/g } @lines;

  # https://spec.commonmark.org/0.30/#backslash-escapes
  # TODO: at a later stage, as escaped characters don’t have their Markdown
  # meaning, we need a way to represent that.
  # map { s{\\(.)}{slash_escape($1)}ge } @lines

  # https://spec.commonmark.org/0.30/#entity-and-numeric-character-references
  # TODO: probably nothing is needed here.

  sub parse_blocks {
    return $_[0] if @_ == 1;  # Base case, we have no more lines to process.
    my ($blocks, $hd, @tl) = @_;
    if ($hd =~ /^ {0,3}(?:(?:-[ \t]*){3,}|(_[ \t]*){3,}|(\*[ \t]*){3,})$/) {
      # https://spec.commonmark.org/0.30/#thematic-breaks
      return parse_blocks([@{$blocks}, { type => 'break' }], @tl)
    } else {
      ...
    }
  }
  my $blocks = parse_blocks([], @lines);

  sub emit_html {
    my (@blocks) = @_;
    my $out =  '';
    for my $b (@blocks) {
      if ($b->{type} eq 'break') {
        $out .= "<hr />\n";
      }
    }
    return $out;
  }
  return emit_html(@{$blocks});
}
