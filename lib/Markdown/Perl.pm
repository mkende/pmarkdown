package Markdown::Perl;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use Hash::Util 'lock_keys';
use List::Util 'pairs';
use Markdown::Perl::Inlines;
use Markdown::Perl::Util 'split_while', 'remove_prefix_spaces', 'indented_one_tab', 'indent_size';
use Scalar::Util 'blessed';

our $VERSION = '0.01';

our @EXPORT = ();
our @EXPORT_OK = qw(convert);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=pod

=encoding utf8

=cut

sub new {
  my ($class, %options) = @_;

  my $this = bless {
    options => \%options,
    local_options => {},
    blocks => [],
    blocks_stack => [],
    paragraph => [],
    last_line_is_blank => 0,
    last_line_was_blank => 0,
    skip_next_block_matching => 0,
    is_lazy_continuation => 0,
    lines => [] }, $class;
  lock_keys %{$this};

  return $this;
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


  # $this->{blocks} = [];
  # $this->{blocks_stack} = [];
  # $this->{paragraph} = [];
  $this->{lines} = \@lines;

  while (my $hd = shift @{$this->{lines}}) {
    # This field might be set to true at the beginning of the processing, while
    # we’re looking at the conditions of the currently open containers.
    $this->{is_lazy_continuation} = 0;
    $this->_parse_blocks($hd);
  }
  $this->_finalize_paragraph();
  while (@{$this->{blocks_stack}}) {
    $this->_restore_parent_block();
  }
  my $out = $this->_emit_html(0, @{delete $this->{blocks}});
  $this->{blocks} = [];
  return $out;
}

sub _finalize_paragraph {
  my ($this) = @_;
  return unless @{$this->{paragraph}};
  push @{$this->{blocks}}, { type => 'paragraph', content => $this->{paragraph}};
  $this->{paragraph} = [];
  return;
}

# Whether the list_item match the most recent list (should we add to the same
# list or create a new one).
sub _list_match {
  my ($this, $item) = @_;
  return 0 unless @{$this->{blocks}};
  my $list = $this->{blocks}[-1];
  return $list->{type} eq 'list' && $list->{style} eq $item->{style} && $list->{marker} eq $item->{marker};
}

sub _add_block {
  my ($this, $block) = @_;
  $this->_finalize_paragraph();
  if ($block->{type} eq 'list_item') {
    # https://spec.commonmark.org/0.30/#lists
    if ($this->_list_match($block)) {
      push @{$this->{blocks}[-1]{items}}, $block;
      $this->{blocks}[-1]{loose} ||= $block->{loose};
    } else {
      my $list = { type => 'list', style => $block->{style}, marker => $block->{marker},
                   start_num => $block->{num}, items => [$block], loose => $block->{loose} };
      push @{$this->{blocks}}, $list;
    }
  } else {
    push @{$this->{blocks}}, $block;
  }
  return;
}

sub _enter_child_block {
  my ($this, $hd, $new_block, $cond) = @_;
  $this->_finalize_paragraph();
  unshift @{$this->{lines}}, $hd if defined $hd;
  push @{$this->{blocks_stack}}, { cond => $cond, block => $new_block, parent_blocks => $this->{blocks} };
  $this->{blocks} = [];
  return;
}

sub _restore_parent_block {
  my ($this) = @_;
  # TODO: rename the variables here with something better.
  my $last_block = pop @{$this->{blocks_stack}};
  my $block = delete $last_block->{block};
  # TODO: maybe rename content to blocks here.
  $block->{content} = $this->{blocks};
  $this->{blocks} = delete $last_block->{parent_blocks};
  $this->_add_block($block);
  return;
}

# Returns true if $l would be parsed as the continuation of a paragraph in the
# context of $this (which is not modified).
sub _test_lazy_continuation {
  my ($this, $l) = @_;
  return unless @{$this->{paragraph}};
  my $tester = new(ref($this), $this->{options}, $this->{local_options});
  $tester->{paragraph} = [@{$this->{paragraph}}];
  # We use this field both in the tester and in the actual object when we
  # matched a lazy continuation.
  $tester->{is_lazy_continuation} = 1;
  # We’re ignoring the eol of the original line as it should not affect parsing.
  $tester->_parse_blocks([$l, '']);
  if (@{$tester->{paragraph}} > @{$this->{paragraph}}) {
    $this->{is_lazy_continuation} = 1;
    return 1;
  }
  return 0;
}

sub _count_matching_blocks {
  my ($this, $lr) = @_;  # $lr is a scalar *reference* to the current line text.
  for my $i (0..$#{$this->{blocks_stack}}) {
    local *::_ = $lr;
    return $i unless $this->{blocks_stack}[$i]{cond}();
  }
  return @{$this->{blocks_stack}};
}

sub _all_blocks_match {
  my ($this, $lr) =@_;
  return @{$this->{blocks_stack}} == $this->_count_matching_blocks($lr);
}

my $thematic_break_re = qr/^ {0,3}(?:(?:-[ \t]*){3,}|(_[ \t]*){3,}|(\*[ \t]*){3,})$/;
my $block_quotes_re = qr/^ {0,3}>/;
my $indented_code_re = qr/^(?: {0,3}\t| {4})/;
my $list_item_re = qr/^(?<indent> {0,3})(?<marker>[-+*]|(?:(?<digits>\d{1,9})(?<symbol>[.)])))(?<text>.*)$/;

# Parse at least one line of text to build a new block; and possibly several
# lines, depending on the block type.
# https://spec.commonmark.org/0.30/#blocks-and-inlines
sub _parse_blocks {
  my ($this, $hd) = @_;
  my $l = $hd->[0];
  
  if (!$this->{skip_next_block_matching}) {
    my $matched_block = $this->_count_matching_blocks(\$l);
    if (@{$this->{blocks_stack}} > $matched_block) {
      $this->_finalize_paragraph();
      while (@{$this->{blocks_stack}} > $matched_block) {
        $this->_restore_parent_block();
      }
    }
  } else {
    $this->{skip_next_block_matching} = 0;
  }

  # There are two different cases. The first one, handled here, is when we have
  # multiple blocks inside a list item separated by a blank line. The second
  # case (when the list items themselves are separated by a blank line) is
  # handled when parsing the list item itself (based on the last_line_was_blank
  # setting).
  if ($this->{last_line_is_blank}) {
    if (@{$this->{blocks_stack}} && $this->{blocks_stack}[-1]{block}{type} eq 'list_item') {
      $this->{blocks_stack}[-1]{block}{loose} = 1;
    }
  }
  $this->{last_line_was_blank} = $this->{last_line_is_blank};
  $this->{last_line_is_blank} = 0;

  # https://spec.commonmark.org/0.30/#atx-headings
  if ($l =~ /^ {0,3}(#{1,6})(?:[ \t]+(.+?))??(?:[ \t]+#+)?[ \t]*$/) {
    # Note: heading breaks can interrupt a paragraph or a list
    # TODO: the content of the header needs to be interpreted for inline content.
    $this->_add_block({ type => 'heading', level => length($1), content => $2 // '', debug => 'atx' });
    return;
  }

  # https://spec.commonmark.org/0.30/#setext-headings
  if ($l =~ /^ {0,3}(-+|=+)[ \t]*$/
     && @{$this->{paragraph}} && indent_size($this->{paragraph}[0]) < 4
     && !$this->{is_lazy_continuation}) {
    # TODO: this should not interrupt a list if the heading is just one -
    my $c = substr $1, 0, 1;
    my $p = $this->{paragraph};
    my $m = $this->multi_lines_setext_headings;
    if ($m eq 'single_line' && @{$p} > 1) {
      my $last_line = pop @{$p};
      $this->_finalize_paragraph();
      $p = [$last_line];
    } elsif ($m eq 'break' && $l =~ m/${thematic_break_re}/) {
      $this->_finalize_paragraph();
      $this->_add_block({ type => 'break', debug => 'setext_as_break' });
      return;
    } elsif ($m eq 'ignore') {
      push @{$this->{paragraph}}, $l;
      return;
    }
    $this->{paragraph} = [];
    $this->_add_block({ type => 'heading', level => ($c eq '=' ? 1 : 2), content => $p, debug => 'setext' });
    return;
  }


  # https://spec.commonmark.org/0.30/#thematic-breaks
  # Thematic breaks are described first in the spec, but the setext headings has
  # precedence in case of conflict, so we test for the break after the heading.
  if ($l =~ /${thematic_break_re}/) {
    $this->_add_block({ type => 'break', debug => 'native_break' });
    return;
  }

  # https://spec.commonmark.org/0.30/#indented-code-blocks
  # Indented code blocks cannot interrupt a paragraph.
  if (!@{$this->{paragraph}} && $l =~ m/${indented_code_re}/) {
    my $last = -1;
    my @code_lines = remove_prefix_spaces(4, $l.$hd->[1]);
    for my $i (0..$#{$this->{lines}}) {
      my $l = $this->{lines}[$i]->[0];
      if ($this->_all_blocks_match(\$l)) {
        push @code_lines, remove_prefix_spaces(4, $l.$this->{lines}[$i]->[1]);
        if ($l =~ m/${indented_code_re}/) {
          $last = $i;
        } elsif ($this->{lines}[$i]->[0] ne '') {
          last;
        }
      } else {
        last;
      }
    }
    # @code_lines starts with $hd, so there is one more element than what is removed from our lines.
    splice @code_lines, ($last + 2);
    splice @{$this->{lines}}, 0, ($last + 1);
    my $code = join('', @code_lines);
    $this->_add_block({ type => "code", content => $code, debug => 'indented'});
    return;
  }

  # https://spec.commonmark.org/0.30/#fenced-code-blocks
  if ($l =~ /^(?<indent> {0,3})(?<fence>`{3,}|~{3,})[ \t]*(?<info>.*?)[ \t]*$/
            && (((my $f = substr $+{fence}, 0, 1) ne '`') || (index($+{info}, '`') == -1))) {
    my $fl = length($+{fence});
    my $info = $+{info};
    my $indent = length($+{indent});
    # The spec does not describe what we should do with fenced code blocks inside
    # other containers if we don’t match them.
    my @code_lines;  # The first line is not part of the block.
    my $end_fence_seen = -1;
    for my $i (0..$#{$this->{lines}}) {
      my $l = $this->{lines}[$i]->[0];
      if ($this->_all_blocks_match(\$l)) {
        if ($l =~ m/^ {0,3}${f}{$fl,}[ \t]*$/) {
          $end_fence_seen = $i;
          last;
        } else {
          # We’re adding one line to the fenced code block
          push @code_lines, remove_prefix_spaces($indent, $l.$this->{lines}[$i]->[1]);
        }
      } else {
        # We’re out of our enclosing block and we haven’t seen the end of the
        # fence.
        last;
      }
    }
    
    # The spec is unclear about what happens if we haven’t seen the end-fence at
    # the end of the enclosing block. For now, we decide that we don’t have a
    # fenced code block at all.
    if ($end_fence_seen >= 0 || (!@{$this->{blocks_stack}} && !$this->fenced_code_blocks_must_be_closed)) {
      my $code = join('', @code_lines);
      $this->_add_block({ type => "code", content => $code, info => $info, debug => 'fenced' });
      if ($end_fence_seen >= 0) {
        splice @{$this->{lines}}, 0, ($end_fence_seen + 1);
      } else {
        # If we ever accept unclosed fenced code blocks inside other blocks we
        # will need to track the end of the block (instead of assuming that we
        # reached the end of the document as we do here).
        @{$this->{lines}} = ();
      }
      return;
    } else {
      # pass-through intended
    }
  }

  # https://spec.commonmark.org/0.30/#block-quotes
  if ($l =~ /${block_quotes_re}/) {
    # TODO: handle laziness (block quotes where the > prefix is missing)
    my $cond = sub {
      if ($_ =~ s/(${block_quotes_re})/' ' x length($1)/e) {
        # We remove the '>' character that we replaced by a space, and the
        # optional space after it. We’re using this approach to correctly handle
        # the case of a line like '>\t\tfoo' where we need to retain the 6
        # spaces of indentation, to produce a code block starting with two 
        # spaces.
        $_ = remove_prefix_spaces(length($1) + 1, $_);
        return 1;
      };
      return $this->_test_lazy_continuation($_);
    };
    $this->_enter_child_block($hd, { type => 'quotes' }, $cond);
    return;
  }

  # https://spec.commonmark.org/0.30/#list-items
  if ($l =~ m/${list_item_re}/) {
    # There is a note in the spec on thematic breaks that are not list items,
    # it’s not exactly clear what is intended, and there are no examples.
    my ($indent_outside, $marker, $text, $digits, $symbol) = @+{qw(indent marker text digits symbol)};
    my $type = $marker =~ m/[-+*]/ ? 'ul' : 'ol';
    my $text_indent = indent_size($text);
    # When interrupting a paragraph, the rules are stricter.
    if (@{$this->{paragraph}} && ($text eq '' || ($type eq 'ol' && $digits != 1))) {
      # pass-through intended
    } elsif ($text ne '' && $text_indent == 0) {
      # pass-through intended
    } else {
      # in the current implementation, $text_indent is enough to know if $text
      # is matching $indented_code_re, but let’s not depend on that.
      my $indent_inside = ($text eq  '' || $text =~ m/${indented_code_re}/) ? 1 : $text_indent;
      my $indent_marker = length($indent_outside) + length($marker);
      my $indent = $indent_inside + $indent_marker;
      my $cond = sub {
        if (indent_size($_) >= $indent) {
          $_ = remove_prefix_spaces($indent, $_);
          return 1;
        }
        return ($l !~ m/${list_item_re}/ && $this->_test_lazy_continuation($_)) || $_ eq '';
      };
      my $new_hd;
      if ($text ne '') {
        # We are doing a weird compensation for the fact that we are not
        # processing the condition and to correctly handle the case where the
        # list marker was following by tabs.
        $new_hd = [remove_prefix_spaces($indent, (' ' x $indent_marker).$text), $hd->[1]];
        $this->{skip_next_block_matching} = 1 ;
      }
      # Note that we are handling the creation of the lists themselves in the
      # _add_block method. See https://spec.commonmark.org/0.30/#lists for
      # reference.
      # TODO: handle tight and loose lists.
      my $item = { type => 'list_item', style => $type, marker => $symbol // $marker, num => $digits};
      $item->{loose} = $this->_list_match($item) && $this->{last_line_was_blank};
      $this->_enter_child_block($new_hd, $item, $cond);
      return;
    }
  }

  # TODO:
  # - https://spec.commonmark.org/0.30/#html-blocks
  # - https://spec.commonmark.org/0.30/#link-reference-definitions

  # https://spec.commonmark.org/0.30/#paragraphs
  if ($l ne '') {
    push @{$this->{paragraph}}, $l;
    return;
  }


  # https://spec.commonmark.org/0.30/#blank-lines
  if ($l eq  '') {
    $this->_finalize_paragraph();
    $this->{last_line_is_blank} = 1;  # Needed to detect loose lists.
    return;
  }

  {
    ...
  }
}

sub _preprocess_lists {
  my ($this, @blocks) = @_;
  for my $b (@blocks) {
  }
}

sub _render_inlines {
  my ($this, @lines) = @_;
  return Markdown::Perl::Inlines::render($this, @lines);
}

sub _emit_html {
  my ($this, $tight_block, @blocks) = @_;
  my $out =  '';
  for my $b (@blocks) {
    if ($b->{type} eq 'break') {
      $out .= "<hr />\n";
    } elsif ($b->{type} eq 'heading') {
      my $l = $b->{level};
      my $c = $b->{content};
      $c = $this->_render_inlines(ref $c eq 'ARRAY' ? @{$c} : $c);
      $out .= "<h${l}>$c</h${l}>\n";
    } elsif ($b->{type} eq 'code') {
      my $c = $b->{content};
      my $i = '';
      if ($this->code_blocks_info eq 'language' && $b->{info}) {
        my $l = $b->{info} =~ s/\s.*//r;  # The spec does not really cover this behavior so we’re using Perl notion of whitespace here.
        $i = " class=\"language-${l}\"";
      }
      $out .= "<pre><code${i}>$c</code></pre>\n";
    } elsif ($b->{type} eq 'paragraph') {
      if ($tight_block) {
        $out .= $this->_render_inlines(@{$b->{content}});
      } else {
        $out .= "<p>".$this->_render_inlines(@{$b->{content}})."</p>\n";
      }
    } elsif ($b->{type} eq 'quotes') {
      my $c = $this->_emit_html(0, @{$b->{content}});
      $out .= "<blockquote>\n${c}</blockquote>\n";
    } elsif ($b->{type} eq 'list') {
      my $type = $b->{style};  # 'ol' or 'ul'
      my $start = '';
      my $num = $b->{start_num};
      my $loose = $b->{loose};
      $start = " start=\"${num}\"" if $type eq 'ol' && $num != 1;
      $out .= "<${type}${start}>\n<li>".join("</li>\n<li>", map { $this->_emit_html(!$loose, @{$_->{content}}) } @{$b->{items}})."</li>\n</${type}>\n";
    }
  }
  return $out;
}

sub _get_option {
  my ($this, $option) = @_;
  return $this->{local_options}{$option} // $this->{options}{$option};
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

=item B<code_blocks_info>

Fenced code blocks can have info strings on their opening lines (any text after
the C<```> or C<~~~> fence). This option controls what is done with that text.

The possible values are:

=over 4

=item B<ignored>

The info text is ignored.

=item B<language> I<(default)>

=back

=cut

sub code_blocks_info {
  my ($this) = @_;
  return $this->_get_option('code_blocks_info') // 'language';
}

=pod=item B<multi_lines_setext_headings>

The default behavior of setext headings in the CommonMark spec is that they can
have multiple lines of text preceeding them (forming the heading itself).

This option allows to change this behavior. And is illustrated with this example
of Markdown:

    Foo
    bar
    ---
    baz

The possible values are:

=over 4

=item B<single_line>

Only the last line of text is kept as part of the heading. The preceeding lines
are a paragraph of themselves. The result on the example would be:
paragraph C<Foo>, heading C<bar>, paragraph C<baz>

=item B<break>

If the heading underline can be interpreted as a thematic break, then it is
interpreted as such (normally the heading interpretation takes precedence). The
result on the example would be: paragraph C<Foo bar>, thematic break,
paragraph C<baz>.

If the heading underline cannot be interpreted as a thematic break, then the
heading will use the default B<multi_line> behavior.

=item B<multi_line> I<(default)>

This is the default CommonMark behavior where all the preceeding lines are part
of the heading. The result on the example would be:
heading C<Foo bar>, paragraph C<baz>

=item B<ignore>

The heading is ignored, and form just one large paragraph. The result on the
example would be: paragraph C<Foo bar --- baz>.

Note that this actually has an impact on the interpretation of the thematic
breaks too.

=back

=cut

sub multi_lines_setext_headings {
  my ($this) = @_;
  return $this->_get_option('multi_lines_setext_headings') // 'multi_line';
}

=pod

=back

=cut

1;
