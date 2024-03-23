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

our @EXPORT_OK = qw(convert set_options);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

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
  my ($this, @options) = &_get_this_and_args;  ## no critic (ProhibitAmpersandSigils)
  $this->SUPER::set_options(options => @options);
  return;
}

sub set_mode {
  my ($this, $mode) = &_get_this_and_args;  ## no critic (ProhibitAmpersandSigils)
  $this->SUPER::set_mode($mode);
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
  return ($this, @_) if wantarray;
  unshift @_, $this;
  return;
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

__END__

=pod

=encoding utf8

=head1 NAME

Markdown::Perl – Very configurable Markdown processor written in pure Perl

=head1 SYNOPSIS

This is the library underlying the L<pmarkdown> tool.

=head1 DESCRIPTION

  use Markdown::Perl;
  my $converter = Markdown::Perl->new([mode => $mode], %options);
  my $html = $converter->convert($markdown);

Or you can use the library functionally:

  use Markdown::Perl 'convert';
  Markdown::Perl::set_options([mode => $mode], %options);
  my $html = convert($markdown);

=head1 METHODS

=head2 new

  my $pmarkdown = Markdown::Perl->new([mode => $mode], %options);

See the L<pmarkdown/MODES> page for the documentation of existing modes.

See the L<Markdown::Perl::Options> documentation for all the existing options.

=head2 set_options

  $pmarkdown->set_options(%options);
  Markdown::Perl::set_options(%option);

Sets the options of the current object or, for the functional version, the
options used by functional calls to C<convert>. The options set through the
functional version do B<not> apply to any objects created through a call to
C<new>.

See the L<Markdown::Perl::Options> documentation for all the existing options.

=head2 set_mode

See the L<pmarkdown/MODES> page for the documentation of existing modes.

=head2 convert

=head1 AUTHOR

Mathias Kende

=head1 COPYRIGHT AND LICENSE

Copyright 2024 Mathias Kende

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=head1 SEE ALSO

=over

=item L<pmarkdown>

=item L<Text::Markdown> another pure Perl implementation, implementing the
original Markdown syntax from L<http://daringfireball.net/projects/markdown>.

=back

=cut
