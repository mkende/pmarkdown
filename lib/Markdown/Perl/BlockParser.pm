package Markdown::Perl::BlockParser;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use feature 'refaliasing';
no warnings 'experimental::refaliasing';

use Carp;
use English;
use Hash::Util 'lock_keys_plus';
use List::MoreUtils 'first_index';
use List::Util 'pairs';
use Markdown::Perl::HTML 'html_escape', 'decode_entities', 'remove_disallowed_tags';
use Markdown::Perl::Util ':all';

our $VERSION = '0.01';

=pod

=encoding utf8

=cut

sub new {
  # $md must be a reference
  my ($class, $pmarkdown, $md) = @_;

  my $this = bless {
    pmarkdown => $pmarkdown,
    blocks => [],
    blocks_stack => [],
    paragraph => [],
    last_line_is_blank => 0,
    last_line_was_blank => 0,
    skip_next_block_matching => 0,
    is_lazy_continuation => 0,
    md => undef,
    last_pos => 0,
    line_ending => '',
    linkrefs => {}
  }, $class;
  lock_keys_plus(%{$this}, qw(forced_line));

  \$this->{md} = $md;  # aliasing to avoid copying the input, does this work? is it useful?

  return $this;
}

# This autoload method allows to call option accessors from the parent object
# transparently.
my $pkg = __PACKAGE__;

sub AUTOLOAD {  ## no critic (ProhibitAutoloading, RequireArgUnpacking)
  our $AUTOLOAD;  # Automatically populated when the method is called.
  $AUTOLOAD =~ s/${pkg}:://;
  return if $AUTOLOAD eq 'DESTROY';
  confess "Undefined method ${AUTOLOAD}" unless $AUTOLOAD =~ m/^get_/;
  my $this = shift @_;
  return $this->{pmarkdown}->$AUTOLOAD(@_);
}

sub next_line {
  my ($this) = @_;
  # When we are forcing a line, we don’t recompute the line_ending, but it
  # should already be correct because the forced one is a substring of the last
  # line.
  return delete $this->{forced_line} if exists $this->{forced_line};
  return if pos($this->{md}) == length($this->{md});
  $this->{last_pos} = pos($this->{md});
  $this->{md} =~ m/\G([^\n\r]*)(\r\n|\n|\r)?/g or confess 'Should not happen';
  my ($t, $e) = ($1, $2);
  if ($1 =~ /^[ \t]+$/) {
    $this->{line_ending} = $t.($e // '') if $this->get_preserve_white_lines;
    return '';
  } else {
    $this->{line_ending} = $e // ($this->get_force_final_new_line ? "\n" : '');
    return $t;
  }
}

sub line_ending {
  my ($this) = @_;
  return $this->{line_ending};
}

sub set_pos {
  my ($this, $pos) = @_;
  pos($this->{md}) = $pos;
  return;
}

sub get_pos {
  my ($this) = @_;
  return pos($this->{md});
}

sub redo_line {
  my ($this) = @_;
  confess 'Cannot push back more than one line' unless exists $this->{last_pos};
  $this->set_pos(delete $this->{last_pos});
  return;
}

# Takes a string and converts it to HTML. Can be called as a free function or as
# class method. In the latter case, provided options override those set in the
# class constructor.
# Both the input and output are unicode strings.
sub process {
  my ($this) = @_;
  pos($this->{md}) = 0;

  # https://spec.commonmark.org/0.30/#characters-and-lines
  $this->{md} =~ s/\000/\xfffd/g;

  # https://spec.commonmark.org/0.30/#tabs
  # TODO: nothing to do at this stage.

  # https://spec.commonmark.org/0.30/#backslash-escapes
  # https://spec.commonmark.org/0.30/#entity-and-numeric-character-references
  # Done at a later stage, as escaped characters don’t have their Markdown
  # meaning, we need a way to represent that.

  while (defined (my $l = $this->next_line())) {
    # This field might be set to true at the beginning of the processing, while
    # we’re looking at the conditions of the currently open containers.
    $this->{is_lazy_continuation} = 0;
    $this->_parse_blocks($l);
  }
  $this->_finalize_paragraph();
  while (@{$this->{blocks_stack}}) {
    $this->_restore_parent_block();
  }
  return delete $this->{linkrefs}, delete $this->{blocks};
}

sub _finalize_paragraph {
  my ($this) = @_;
  return unless @{$this->{paragraph}};
  push @{$this->{blocks}}, {type => 'paragraph', content => $this->{paragraph}};
  $this->{paragraph} = [];
  return;
}

# Whether the list_item match the most recent list (should we add to the same
# list or create a new one).
sub _list_match {
  my ($this, $item) = @_;
  return 0 unless @{$this->{blocks}};
  my $list = $this->{blocks}[-1];
  return
         $list->{type} eq 'list'
      && $list->{style} eq $item->{style}
      && $list->{marker} eq $item->{marker};
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
      my $list = {
        type => 'list',
        style => $block->{style},
        marker => $block->{marker},
        start_num => $block->{num},
        items => [$block],
        loose => $block->{loose}
      };
      push @{$this->{blocks}}, $list;
    }
  } else {
    push @{$this->{blocks}}, $block;
  }
  return;
}

sub _enter_child_block {
  my ($this, $new_block, $cond, $forced_next_line) = @_;
  $this->_finalize_paragraph();
  if (defined $forced_next_line) {
    $this->{forced_line} = $forced_next_line;
  }
  push @{$this->{blocks_stack}},
      {cond => $cond, block => $new_block, parent_blocks => $this->{blocks}};
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
  my $tester = new(ref($this), $this->{pmarkdown}, \'');
  pos($tester->{md}) = 0;
  # What is a paragraph depends on whether we already have a paragraph or not.
  $tester->{paragraph} = [@{$this->{paragraph}} ? ('foo') : ()];
  # We use this field both in the tester and in the actual object when we
  # matched a lazy continuation.
  $tester->{is_lazy_continuation} = 1;
  # We’re ignoring the eol of the original line as it should not affect parsing.
  $tester->_parse_blocks($l);
  # BUG: there is a bug here which is that a construct like a fenced code block
  # or a link ref definition, whose validity depends on more than one line,
  # might be misclassified. The probability of that is low.
  if (@{$tester->{paragraph}}) {
    $this->{is_lazy_continuation} = 1;
    return 1;
  }
  return 0;
}

sub _count_matching_blocks {
  my ($this, $lr) = @_;  # $lr is a scalar *reference* to the current line text.
  for my $i (0 .. $#{$this->{blocks_stack}}) {
    local *::_ = $lr;
    return $i unless $this->{blocks_stack}[$i]{cond}();
  }
  return @{$this->{blocks_stack}};
}

sub _all_blocks_match {
  my ($this, $lr) = @_;
  return @{$this->{blocks_stack}} == $this->_count_matching_blocks($lr);
}

my $thematic_break_re = qr/^\ {0,3} (?: (?:-[ \t]*){3,} | (_[ \t]*){3,} | (\*[ \t]*){3,} ) $/x;
my $block_quotes_re = qr/^ {0,3}>/;
my $indented_code_re = qr/^(?: {0,3}\t| {4})/;
my $list_item_marker_re = qr/ [-+*] | (?<digits>\d{1,9}) (?<symbol>[.)])/x;
my $list_item_re =
    qr/^ (?<indent>\ {0,3}) (?<marker>${list_item_marker_re}) (?<text>(?:[ \t].*)?) $/x;
my $supported_html_tags = join('|',
  qw(address article aside base basefont blockquote body caption center col colgroup dd details dialog dir div dl dt fieldset figcaption figure footer form frame frameset h1 h2 h3 h4 h5 h6 head header hr html iframe legend li link main menu menuitem nav noframes ol optgroup option p param search section summary table tbody td tfoot th thead title tr track ul)
);
# TODO: Share these regex with the Inlines.pm file that has a copy of them.
my $html_tag_name_re = qr/[a-zA-Z][-a-zA-Z0-9]*/;
my $html_attribute_name_re = qr/[a-zA-Z_:][-a-zA-Z0-9_.:]*/;
# We include new lines in these regex as the spec mentions them, but we can’t
# match them for now as the regex will see lines one at a time.
my $html_space_re = qr/\n[ \t]*|[ \t][ \t]*\n?[ \t]*/;  # Spaces, tabs, and up to one line ending.
my $opt_html_space_re = qr/[ \t]*\n?[ \t]*/;  # Optional spaces.
my $html_attribute_value_re = qr/ [^ \t\n"'=<>`]+ | '[^']*' | "[^"]*" /x;
my $html_attribute_re =
    qr/ ${html_space_re} ${html_attribute_name_re} (?: ${opt_html_space_re} = ${opt_html_space_re} ${html_attribute_value_re} )? /x;
my $html_open_tag_re =
    qr/ < ${html_tag_name_re} ${html_attribute_re}* ${opt_html_space_re} \/? > /x;
my $html_close_tag_re = qr/ <\/ ${html_tag_name_re} ${opt_html_space_re} > /x;

# Parse at least one line of text to build a new block; and possibly several
# lines, depending on the block type.
# https://spec.commonmark.org/0.30/#blocks-and-inlines
our $l;  # global variable, localized during the call to _parse_blocks.

sub _parse_blocks {  ## no critic (RequireArgUnpacking)
  my $this = shift @_;
  # TODO do the localization in process to avoid the copy (but this will need
  # change in the continuation tester).
  local $l = shift @_;  ## no critic (ProhibitLocalVars)

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
    if (@{$this->{blocks_stack}}
      && $this->{blocks_stack}[-1]{block}{type} eq 'list_item') {
      $this->{blocks_stack}[-1]{block}{loose} = 1;
    }
  }
  $this->{last_line_was_blank} = $this->{last_line_is_blank};
  $this->{last_line_is_blank} = 0;

  _do_atx_heading($this)
      || _do_setext_heading($this)
      # Thematic breaks are described first in the spec, but the setext headings has
      # precedence in case of conflict, so we test for the break after the heading.
      || _do_thematic_break($this)
      || _do_indented_code_block($this)
      || _do_fenced_code_block($this)
      || _do_html_block($this)
      || _do_block_quotes($this)
      || _do_list_item($this)
      || _do_link_reference_definition($this)
      || _do_paragraph($this)
      || croak "Current line could not be parsed as anything: $l";
  return;
}

# https://spec.commonmark.org/0.30/#atx-headings
sub _do_atx_heading {
  my ($this) = @_;
  if ($l =~ /^ \ {0,3} (\#{1,6}) (?:[ \t]+(.+?))?? (?:[ \t]+\#+)? [ \t]* $/x) {
    # Note: heading breaks can interrupt a paragraph or a list
    # TODO: the content of the header needs to be interpreted for inline content.
    $this->_add_block({
      type => 'heading',
      level => length($1),
      content => $2 // '',
      debug => 'atx'
    });
    return 1;
  }
  return;
}

# https://spec.commonmark.org/0.30/#setext-headings
sub _do_setext_heading {
  my ($this) = @_;
  return unless $l =~ /^ {0,3}(-+|=+)[ \t]*$/;
  if ( !@{$this->{paragraph}}
    || indent_size($this->{paragraph}[0]) >= 4
    || $this->{is_lazy_continuation}) {
    return;
  }
  # TODO: this should not interrupt a list if the heading is just one -
  my $c = substr $1, 0, 1;
  my $p = $this->{paragraph};
  my $m = $this->get_multi_lines_setext_headings;
  if ($m eq 'single_line' && @{$p} > 1) {
    my $last_line = pop @{$p};
    $this->_finalize_paragraph();
    $p = [$last_line];
  } elsif ($m eq 'break' && $l =~ m/${thematic_break_re}/) {
    $this->_finalize_paragraph();
    $this->_add_block({type => 'break', debug => 'setext_as_break'});
    return 1;
  } elsif ($m eq 'ignore') {
    # TODO: maybe we should just do nothing and return 0 here.
    push @{$this->{paragraph}}, $l;
    return 1;
  }
  $this->{paragraph} = [];
  $this->_add_block({
    type => 'heading',
    level => ($c eq '=' ? 1 : 2),
    content => $p,
    debug => 'setext'
  });
  return 1;
}

# https://spec.commonmark.org/0.30/#thematic-breaks
sub _do_thematic_break {
  my ($this) = @_;
  if ($l !~ /${thematic_break_re}/) {
    return;
  }
  $this->_add_block({type => 'break', debug => 'native_break'});
  return 1;
}

# https://spec.commonmark.org/0.30/#indented-code-blocks
sub _do_indented_code_block {
  my ($this) = @_;
  # Indented code blocks cannot interrupt a paragraph.
  if (@{$this->{paragraph}} || $l !~ m/${indented_code_re}/) {
    return;
  }
  my @code_lines = remove_prefix_spaces(4, $l.$this->line_ending(), $this->get_preserve_tabs);
  my $count = 1;  # The number of lines we have read
  my $valid_count = 1;  # The number of lines we know are in the code block.
  my $valid_pos = $this->get_pos();
  while (defined (my $nl = $this->next_line())) {
    if ($this->_all_blocks_match(\$nl)) {
      $count++;
      if ($nl =~ m/${indented_code_re}/) {
        $valid_pos = $this->get_pos();
        $valid_count = $count;
        push @code_lines,
            remove_prefix_spaces(4, $nl.$this->line_ending(), $this->get_preserve_tabs);
      } elsif ($nl eq '') {
        push @code_lines,
            remove_prefix_spaces(4, $nl.$this->line_ending(), $this->get_preserve_tabs);
      } else {
        last;
      }
    } else {
      last;
    }
  }
  splice @code_lines, $valid_count;
  $this->set_pos($valid_pos);
  my $code = join('', @code_lines);
  $this->_add_block({type => 'code', content => $code, debug => 'indented'});
  return 1;
}

# https://spec.commonmark.org/0.30/#fenced-code-blocks
sub _do_fenced_code_block {
  my ($this) = @_;
  return unless $l =~ /^ (?<indent>\ {0,3}) (?<fence>`{3,}|~{3,}) [ \t]* (?<info>.*?) [ \t]* $/x;  ## no critic (ProhibitComplexRegexes)
  my $f = substr $+{fence}, 0, 1;
  if ($f eq '`' && index($+{info}, '`') != -1) {
    return;
  }
  return unless $this->get_use_fenced_code_blocks;
  my $fl = length($+{fence});
  my $info = $+{info};
  my $indent = length($+{indent});
  # This is one of the few case where we need to process character escaping
  # outside of the full inlines rendering process.
  # TODO: Consider if it would be cleaner to do it inside the render_html method.
  $info =~ s/\\(\p{PosixPunct})/$1/g;
  # The spec does not describe what we should do with fenced code blocks inside
  # other containers if we don’t match them.
  my @code_lines;  # The first line is not part of the block.
  my $end_fence_seen = 0;
  my $start_pos = $this->get_pos();
  while (defined (my $nl = $this->next_line())) {
    if ($this->_all_blocks_match(\$nl)) {
      if ($nl =~ m/^ {0,3}${f}{$fl,}[ \t]*$/) {
        $end_fence_seen = 1;
        last;
      } else {
        # We’re adding one line to the fenced code block
        push @code_lines, remove_prefix_spaces($indent, $nl.$this->line_ending());
      }
    } else {
      # We’re out of our enclosing block and we haven’t seen the end of the
      # fence. If we accept enclosed fence, then that last line must be tried
      # again (and, otherwise, we will start again from start_pos).
      $this->redo_line() if !$this->get_fenced_code_blocks_must_be_closed;
      last;
    }
  }

  if (!$end_fence_seen && $this->get_fenced_code_blocks_must_be_closed) {
    $this->set_pos($start_pos);
    return;
  }
  my $code = join('', @code_lines);
  $this->_add_block({
    type => 'code',
    content => $code,
    info => $info,
    debug => 'fenced'
  });
  return 1;
}

# https://spec.commonmark.org/0.31.2/#html-blocks
sub _do_html_block {
  my ($this) = @_;
  # HTML blocks can interrupt a paragraph.
  # TODO: PERF: test that $l =~ m/^ {0,3}</ to short circuit all these regex.
  my $html_end_condition;
  if ($l =~ m/ ^\ {0,3} < (?:pre|script|style|textarea) (?:\ |\t|>|$) /x) {
    $html_end_condition = qr/ <\/ (?:pre|script|style|textarea) > /x;
  } elsif ($l =~ m/^ {0,3}<!--/) {
    $html_end_condition = qr/-->/;
  } elsif ($l =~ m/^ {0,3}<\?/) {
    $html_end_condition = qr/\?>/;
  } elsif ($l =~ m/^ {0,3}<![a-zA-Z]/) {
    $html_end_condition = qr/=>/;
  } elsif ($l =~ m/^ {0,3}<!\[CDATA\[/) {
    $html_end_condition = qr/]]>/;
  } elsif ($l =~ m/^\ {0,3} < \/? (?:${supported_html_tags}) (?:\ |\t|\/?>|$) /x) {
    $html_end_condition = qr/^$/;  ## no critic (ProhibitFixedStringMatches)
  } elsif (!@{$this->{paragraph}}
    && $l =~ m/^\ {0,3} (?: ${html_open_tag_re} | ${html_close_tag_re} ) [ \t]* $ /x) {
    # TODO: the spec seem to say that the tag can take more than one line, but
    # this is not tested, so we don’t implement this for now.
    $html_end_condition = qr/^$/;  ## no critic (ProhibitFixedStringMatches)
  }
  # TODO: Implement rule 7 about any possible tag.
  if (!$html_end_condition) {
    return;
  }
  # TODO: see if some code could be shared with the code blocks
  my @html_lines = $l.$this->line_ending();
  # TODO: add an option to not parse a tag if it’s closing condition is never
  # seen.
  if ($l !~ m/${html_end_condition}/) {
    # The end condition can occur on the opening line.
    while (defined (my $nl = $this->next_line())) {
      if ($this->_all_blocks_match(\$nl)) {
        if ($nl !~ m/${html_end_condition}/) {
          if ($this->get_preserve_tabs) {
            push @html_lines, $nl.$this->line_ending();
          } else {
            push @html_lines, remove_prefix_spaces(0, $nl.$this->line_ending(), 0);
          }
        } elsif ($nl eq '') {
          # This can only happen for rules 6 and 7 where the end condition
          # line is not part of the HTML block.
          $this->redo_line();
          last;
        } else {
          push @html_lines, $nl.$this->line_ending();
          last;
        }
      } else {
        $this->redo_line();
        last;
      }
    }
  }
  my $html = join('', @html_lines);
  remove_disallowed_tags($html, $this->get_disallowed_html_tags);
  $this->_add_block({type => 'html', content => $html});
  return 1;
}

# https://spec.commonmark.org/0.30/#block-quotes
sub _do_block_quotes {
  my ($this) = @_;
  if ($l =~ /${block_quotes_re}/) {
    # TODO: handle laziness (block quotes where the > prefix is missing)
    my $cond = sub {
      if (s/(${block_quotes_re})/' ' x length($1)/e) {
        # We remove the '>' character that we replaced by a space, and the
        # optional space after it. We’re using this approach to correctly handle
        # the case of a line like '>\t\tfoo' where we need to retain the 6
        # spaces of indentation, to produce a code block starting with two
        # spaces.
        $_ = remove_prefix_spaces(length($1) + 1, $_);
        return 1;
      }
      return $this->_test_lazy_continuation($_);
    };
    {
      local *::_ = \$l;
      $cond->();
    }
    $this->{skip_next_block_matching} = 1;
    $this->_enter_child_block({type => 'quotes'}, $cond, $l);
    return 1;
  }
  return;
}

# https://spec.commonmark.org/0.30/#list-items
sub _do_list_item {
  my ($this) = @_;
  if ($l =~ m/${list_item_re}/) {
    # There is a note in the spec on thematic breaks that are not list items,
    # it’s not exactly clear what is intended, and there are no examples.
    my ($indent_outside, $marker, $text, $digits, $symbol) =
        @+{qw(indent marker text digits symbol)};
    my $type = $marker =~ m/[-+*]/ ? 'ul' : 'ol';
    my $text_indent = indent_size($text);
    # When interrupting a paragraph, the rules are stricter.
    if (@{$this->{paragraph}}
      && ($text eq '' || ($type eq 'ol' && $digits != 1))) {
      return;
    } elsif ($text ne '' && $text_indent == 0) {
      return;
    } else {
      # in the current implementation, $text_indent is enough to know if $text
      # is matching $indented_code_re, but let’s not depend on that.
      my $first_line_blank = $text =~ m/^[ \t]*$/;
      my $discard_text_indent = $first_line_blank || indented(4 + 1, $text);  # 4 + 1 is an indented code block, plus the required space after marker.
      my $indent_inside = $discard_text_indent ? 1 : $text_indent;
      my $indent_marker = length($indent_outside) + length($marker);
      my $indent = $indent_inside + $indent_marker;
      my $cond = sub {
        if ($first_line_blank && m/^[ \t]*$/) {
          # A list item can start with at most one blank line
          return 0;
        } else {
          $first_line_blank = 0;
        }
        if (indent_size($_) >= $indent) {
          $_ = remove_prefix_spaces($indent, $_);
          return 1;
        }
        # TODO: we probably don’t need to test the list_item_re case here, just
        # the lazy continuation and the emptiness is enough.
        return (!m/${list_item_re}/ && $this->_test_lazy_continuation($_))
            || $_ eq '';
      };
      my $forced_next_line = undef;
      if (!$first_line_blank) {
        # We are doing a weird compensation for the fact that we are not
        # processing the condition and to correctly handle the case where the
        # list marker was followed by tabs.
        $forced_next_line = remove_prefix_spaces($indent, (' ' x $indent_marker).$text);
        $this->{skip_next_block_matching} = 1;
      }
      # Note that we are handling the creation of the lists themselves in the
      # _add_block method. See https://spec.commonmark.org/0.30/#lists for
      # reference.
      # TODO: handle tight and loose lists.
      my $item = {
        type => 'list_item',
        style => $type,
        marker => $symbol // $marker,
        num => int($digits // 1),
      };
      $item->{loose} =
          $this->_list_match($item) && $this->{last_line_was_blank};
      $this->_enter_child_block($item, $cond, $forced_next_line);
      return 1;
    }
  }
  return;
}

# https://spec.commonmark.org/0.31.2/#link-reference-definitions
sub _do_link_reference_definition {
  my ($this) = @_;
  # Link reference definitions cannot interrupt paragraphs
  #
  # This construct needs to be parsed across multiple lines, so we are directly
  # using the {md} string rather than our parsed $l line
  # TODO: another maybe much simpler approach would be to parse the block as a
  # normal paragraph but immediately try to parse the content as a link
  # reference definition (and otherwise to keep it as a normal paragraph).
  # That would allow to use the higher lever InlineTree parsing constructs.
  if (!@{$this->{paragraph}} && $l =~ m/^ {0,3}\[/) {
    my $init_pos = $this->get_pos();
    $this->redo_line();
    my $start_pos = $this->get_pos();

    # We consume the prefix of enclosing blocks until we find the marker that we
    # know is there. This won’t work if we accept task list markers in the
    # future.
    # This also won’t work to consume markers of subsequent lines of the link
    # reference definition.
    # TODO: fix these two bugs above (hard!).
    $this->{md} =~ m/\G.*?\[/g;

    # TODO:
    # - Support for escaped or balanced parenthesis in naked destination
    # - break this up in smaller pieces and test them independently.
    # - The need to disable ProhibitUnusedCapture seems to be buggy...
    ## no critic (ProhibitComplexRegexes, ProhibitUnusedCapture)
    if (
      $this->{md} =~ m/\G
        (?>(?<LABEL>                                            # The link label (in square brackets), matched as an atomic group
          (?:
            [^\\\[\]]{0,100} (?:(?:\\\\)* \\ .)?                # The label cannot contain unescaped ]
            # With 5.38 this could be (?(*{ ...}) (*FAIL))  which will be more efficient.
            (*COMMIT) (?(?{ pos() > $start_pos + 1004 }) (*FAIL) )  # As our block can be repeated, we prune the search when we are far enough.
          )+ 
        )) \]:
        [ \t]*\n?[ \t]*                                         # optional spaces and tabs with up to one line ending
        (?>(?<TARGET>                                           # the destination can be either:
          < (?: [^\n>]* (?<! \\) (?:\\\\)* )+ >                 # - enclosed in <> and containing no unescaped >
          | [^< [:cntrl:]] [^ [:cntrl:]]*                       # - not enclosed but cannot contains spaces, new lines, etc. and only balanced or escaped parenthesis
        ))
        (?:
          (?> [ \t]+\n?[ \t]* | [ \t]*\n?[ \t]+ | [ \t]*\n[ \t]* )  # The spec says that spaces must be present here, but it seems that a new line is fine too.
          (?<TITLE>                                             # The title can be between ", ' or (). The matching characters can’t appear unescaped in the title
            "  (:?[^\n"]* (?: (?<! \n) \n (?! \n) | (?<! \\) (?:\\\\)* \\ " )? )* "
          |  '  (:?[^\n']* (?: (?<! \n) \n (?! \n) | (?<! \\) (?:\\\\)* \\ ' )? )* '
          |  \( (:?[^\n"()]* (?: (?<! \n) \n (?! \n) | (?<! \\) (?:\\\\)* \\ [()] )? )* \)
          )
        )?
        [ \t]*(:?\r\n|\n|\r|$)                                  # The spec says that no characters can occur after the title, but it seems that whitespace is tolerated.
        /gx
      ## use critic
    ) {
      my ($ref, $target, $title) = @LAST_PAREN_MATCH{qw(LABEL TARGET TITLE)};
      $ref = normalize_label($ref);
      if ($ref ne '') {
        # TODO: option to keep the last appearance instead of the first one.
        return 1 if exists $this->{linkrefs}{$ref};  # We keep the forts appearance of a label.
        if (defined $title) {
          $title =~ s/^.(.*).$/$1/s;
          _unescape_char($title);
        }
        $target =~ s/^<(.*)>$/$1/;
        _unescape_char($target);
        $this->{linkrefs}{$ref} = {
          target => $target,
          (defined $title ? ('title' => $title) : ())
        };
        return 1;
      }
      #pass-through intended;
    }
    $this->set_pos($init_pos);
  }
  return;
}

# https://spec.commonmark.org/0.30/#paragraphs
sub _do_paragraph {
  my ($this) = @_;
  # We need to test for blank lines here (not just emptiness) because after we
  # have removed the markers of container blocks our line can become empty. The
  # fact that we need to do this, seems to imply that we don’t really need to
  # check for emptiness when initially building $l.
  # TODO: check if the blank-line detection in next_line() is needed or not.
  if ($l !~ m/^[ \t]*$/) {
    push @{$this->{paragraph}}, $l;
    return 1;
  }

  # https://spec.commonmark.org/0.30/#blank-lines
  # if ($l eq '')
  $this->_finalize_paragraph();
  # Needed to detect loose lists. But ignore blank lines when they are inside
  # block quotes
  $this->{last_line_is_blank} =
      !@{$this->{blocks_stack}} || $this->{blocks_stack}[-1]{block}{type} ne 'quotes';
  return 1;
}

sub _unescape_char {
  # TODO: configure the set of escapable character. Note that this regex is
  # shared with Inlines.pm process_char_escaping.
  $_[0] =~ s/\\(\p{PosixPunct})/$1/g;
  return;
}

1;
