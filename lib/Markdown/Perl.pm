package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Carp;
use English;
use Exporter 'import';
use Hash::Util 'lock_keys';
use Markdown::Perl::BlockParser;
use Markdown::Perl::Inlines;
use Markdown::Perl::HTML 'html_escape', 'decode_entities';
use Scalar::Util 'blessed';

use parent 'Markdown::Perl::Options';

our $VERSION = '1.00';

our @EXPORT_OK = qw(convert);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=pod

=encoding utf8

=cut

sub new {
  my ($class, @options) = @_;

  my $this = $class->SUPER::new(
    mode => undef,
    options => {},
    local_options => {});
  $this->SUPER::set_options(options => @options);
  lock_keys(%{$this});

  return $this;
}

sub set_options {
  my ($this, @options) = @_;
  $this->SUPER::set_options(options => @options);
  return;
}

# Returns @_, unless the first argument is not blessed as a Markdown::Perl
# object, in which case it returns a default object.
my $default_this = Markdown::Perl->new();

sub _get_this_and_args {  ## no critic (RequireArgUnpacking)
  my $this = shift @_;
  # We could use `$this isa Markdown::Perl` that does not require to test
  # blessedness first. However this requires 5.31.6 which is not in Debian
  # stable as of writing this.
  if (!blessed($this) || !$this->isa(__PACKAGE__)) {
    unshift @_, $this;
    $this = $default_this;
  }
  unshift @_, $this;
  return;
  # return ($this, @_);
}

# Takes a string and converts it to HTML. Can be called as a free function or as
# class method. In the latter case, provided options override those set in the
# class constructor.
# Both the input and output are unicode strings.
sub convert {  ## no critic (RequireArgUnpacking)
  &_get_this_and_args;  ## no critic (ProhibitAmpersandSigils)
  my $this = shift @_;
  my $md = \(shift @_);  # Taking a reference to avoid copying the input. is it useful?
  $this->SUPER::set_options(local_options => @_);

  my $parser = Markdown::Perl::BlockParser->new($this, $md);

  # TODO: introduce an HtmlRenderer object that carries the $linkrefs states
  # around (instead of having to pass it in all the calls).
  my ($linkrefs, $blocks) = $parser->process();
  my $out = $this->_emit_html(0, $linkrefs, @{$blocks});
  $this->{local_options} = {};
  return $out;
}

sub _render_inlines {
  my ($this, $linkrefs, @lines) = @_;
  return Markdown::Perl::Inlines::render($this, $linkrefs, @lines);
}

sub _emit_html {
  my ($this, $tight_block, $linkrefs, @blocks) = @_;
  my $out = '';
  for my $b (@blocks) {
    if ($b->{type} eq 'break') {
      $out .= "<hr />\n";
    } elsif ($b->{type} eq 'heading') {
      my $l = $b->{level};
      my $c = $b->{content};
      $c = $this->_render_inlines($linkrefs, ref $c eq 'ARRAY' ? @{$c} : $c);
      $c =~ s/^[ \t]+|[ \t]+$//g;  # Only the setext headings spec asks for this, but this can’t hurt atx heading where this can’t change anything.
      $out .= "<h${l}>$c</h${l}>\n";
    } elsif ($b->{type} eq 'code') {
      my $c = $b->{content};
      html_escape($c, $this->get_html_escaped_code_characters);
      my $i = '';
      if ($this->get_code_blocks_info eq 'language' && $b->{info}) {
        my $l = $b->{info} =~ s/\s.*//r;  # The spec does not really cover this behavior so we’re using Perl notion of whitespace here.
        decode_entities($l);
        html_escape($l, $this->get_html_escaped_characters);
        $i = " class=\"language-${l}\"";
      }
      $out .= "<pre><code${i}>$c</code></pre>\n";
    } elsif ($b->{type} eq 'html') {
      $out .= $b->{content};
    } elsif ($b->{type} eq 'paragraph') {
      if ($tight_block) {
        $out .= $this->_render_inlines($linkrefs, @{$b->{content}});
      } else {
        $out .= '<p>'.$this->_render_inlines($linkrefs, @{$b->{content}})."</p>\n";
      }
    } elsif ($b->{type} eq 'quotes') {
      my $c = $this->_emit_html(0, $linkrefs, @{$b->{content}});
      $out .= "<blockquote>\n${c}</blockquote>\n";
    } elsif ($b->{type} eq 'list') {
      my $type = $b->{style};  # 'ol' or 'ul'
      my $start = '';
      my $num = $b->{start_num};
      my $loose = $b->{loose};
      $start = " start=\"${num}\"" if $type eq 'ol' && $num != 1;
      $out .= "<${type}${start}>\n<li>"
          .join("</li>\n<li>",
        map { $this->_emit_html(!$loose, $linkrefs, @{$_->{content}}) } @{$b->{items}})
          ."</li>\n</${type}>\n";
    }
  }
  # Note: a final new line should always be appended to $out. This is not
  # guaranteed when the last element is HTML and the input file did not contain
  # a final new line, unless the option force_final_new_line is set.
  return $out;
}

1;
