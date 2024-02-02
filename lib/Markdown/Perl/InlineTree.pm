# A tree DataStructure to represent the content of an inline text of a block
# element.

package Markdown::Perl::InlineTree;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use English;
use Exporter 'import';
use Hash::Util ();
use Scalar::Util 'blessed';

our $VERSION = 0.01;

our @EXPORT_OK = qw(new_text new_code new_link new_literal is_node is_tree);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub new {
  my ($class) = @_;

  return bless {children => []}, $class;
}

package Markdown::Perl::InlineNode {  ## no critic (ProhibitMultiplePackages)

  sub new {
    my ($class, $type, $content, %options) = @_;

    my $this;
    if ($type eq 'text' || $type eq 'code' || $type eq 'literal') {
      die "Unexpected content for inline ${type} node: ".ref($content)
          if ref $content;
      die "Unexpected parameters for inline ${type} node: ".join(', ', %options)
          if %options;
      $this = {type => $type, content => $content};
    } elsif ($type eq 'link') {
      die "Unexpected parameters for inline ${type} node: ".join(', ', %options)
          if keys %options > 1 || !exists $options{target};
      if (Scalar::Util::blessed($content)
        && $content->isa('Markdown::Perl::InlineTree')) {
        $this = {type => $type, subtree => $content, target => $options{target}};
      } elsif (!ref($content)) {
        $this = {type => $type, content => $content, target => $options{target}};
      } else {
        die "Unexpected content for inline ${type} node: ".ref($content);
      }
    } else {
      die "Unexpected type for an InlineNode: ${type}";
    }
    bless $this, $class;

    Hash::Util::lock_keys %{$this};
    return $this;
  }

  sub clone {
    my ($this) = @_;

    return bless {%{$this}}, ref($this);
  }

  sub has_subtree {
    my ($this) = @_;

    return exists $this->{subtree};
  }
}

sub new_text { return Markdown::Perl::InlineNode->new(text => @_) }
sub new_code { return Markdown::Perl::InlineNode->new(code => @_) }
sub new_link { return Markdown::Perl::InlineNode->new(link => @_) }
sub new_literal { return Markdown::Perl::InlineNode->new(literal => @_) }

sub is_node {
  my ($obj) = @_;
  return blessed($obj) && $obj->isa('Markdown::Perl::InlineNode');
}

sub is_tree {
  my ($obj) = @_;
  return blessed($obj) && $obj->isa('Markdown::Perl::InlineTree');
}

# Add new nodes at the end of the list of children of this tree.
# The passed values can either be nodes or InlineTrees, whose children will be
# added to the current tree (directly, not as sub-trees).
sub push {  ## no critic (ProhibitBuiltinHomonyms)
  my ($this, @nodes_or_trees) = @_;

  for my $node_or_tree (@nodes_or_trees) {
    if (is_node($node_or_tree)) {
      push @{$this->{children}}, $node_or_tree;
    } elsif (is_tree($node_or_tree)) {
      push @{$this->{children}}, @{$node_or_tree->{children}};
    } else {
      die 'Invalid argument type for InlineTree::push: '.ref($node_or_tree);
    }
  }

  return;
}

# Replace the child at the given index by the given list of new nodes.
sub replace {
  my ($this, $child_index, @new_nodes) = @_;
  splice @{$this->{children}}, $child_index, 1,
      map { is_node($_) ? $_ : @{$_->{children}} } @new_nodes;
  return;
}

# Insert the new nodes at the given offset (the first inserted node will have
# that index after the operation).
sub insert {
  my ($this, $index, @new_nodes) = @_;
  splice @{$this->{children}}, 0, 0, map { is_node($_) ? $_ : @{$_->{children}} } @new_nodes;
  return;
}

# Return a new tree, containing a part of $this between the given child and
# text offsets. The start and end children must be text nodes.
# The extracted content is removed from the input tree.
# Returns a pair with the new tree and the index of the first block after the
# removed content. Usually it will be $child_start + 1, but it can be
# $child_start if $start_index was 0.
# In scalar context, returns only the extracted tree.
sub extract {
  my ($this, $child_start, $text_start, $child_end, $text_end) = @_;

  my $sn = $this->{children}[$child_start];
  my $en = $this->{children}[$child_end];
  die 'Start node in an extract operation is not of type text: '.$sn->{type}
      unless $sn->{type} eq 'text';
  die 'End node in an extract operation is not of type text: '.$en->{type}
      unless $en->{type} eq 'text';
  die 'Start offset is less than 0 in an extract operation' if $text_start < 0;
  die 'End offset is past the end of the text an extract operation'
      if $text_end > length($en->{content});

  # Clone will not recurse into sub-trees. But the start and end nodes can’t
  # have sub-trees, and the middle ones don’t matter because they are not shared
  # with the initial tree.
  my @nodes =
      map { $_->clone() } @{$this->{children}}[$child_start .. $child_end];
  ## no critic (ProhibitLvalueSubstr)
  substr($nodes[-1]{content}, $text_end) = '';
  substr($nodes[0]{content}, 0, $text_start) = '';  # We must do this after text_end in case they are the same node.
  shift @nodes if length($nodes[0]{content}) == 0;
  pop @nodes if @nodes and length($nodes[-1]{content}) == 0;
  my $new_tree = Markdown::Perl::InlineTree->new();
  $new_tree->push(@nodes);

  if ($child_start != $child_end) {
    if ($text_start == 0) {
      $child_start--;
    } else {
      substr($sn->{content}, $text_start) = '';
    }
    if ($text_end == length($en->{content})) {
      $child_end++;
    } else {
      substr($en->{content}, 0, $text_end) = '';
    }
    splice @{$this->{children}}, $child_start + 1, $child_end - $child_start - 1;
  } else {
    my @new_nodes;
    if ($text_start > 0) {
      CORE::push @new_nodes, new_text(substr $sn->{content}, 0, $text_start);
    } else {
      $child_start--;
    }
    if ($text_end < length($sn->{content})) {
      CORE::push @new_nodes, new_text(substr $sn->{content}, $text_end);
    }
    $this->replace($child_start, @new_nodes);
  }
  ## use critic (ProhibitLvalueSubstr)

  return ($new_tree, $child_start + 1) if wantarray;
  return $new_tree;
}

# Apply the given sub to each direct-child of the tree. The sub can return
# a node or a tree and the content is concatenated and replace the current tree.
#
# Only the top-level nodes of the tree are visited.
#
# In void context, update the tree in-place. In all cases, $sub must return new
# nodes or trees, it can’t modify the input object.
sub map_shallow {
  my ($this, $sub) = @_;

  my $new_tree = Markdown::Perl::InlineTree->new();

  for (@{$this->{children}}) {
    $new_tree->push($sub->());
  }

  return $new_tree if defined wantarray;
  %{$this} = %{$new_tree};
  return;
}

# Same as map_shallow, but the tree is visited recursively.
# The subtree of individual nodes are visited before the node itself is visited.
sub map {  ## no critic (ProhibitBuiltinHomonyms)
  my ($this, $sub) = @_;

  my $new_tree = Markdown::Perl::InlineTree->new();

  for (@{$this->{children}}) {
    if ($_->has_subtree()) {
      if (wantarray) {
        my $new_node = $_->clone();
        $new_node->{subtree}->map($sub);
        local *_ = \$new_node;
        $new_tree->push($sub->());
      } else {
        # Is there a risk that this modifies $_ before the call to $sub?
        $_->{subtree}->map($sub);
        $new_tree->push($sub->());
      }
    } else {
      $new_tree->push($sub->());
    }
  }

  return $new_tree if defined wantarray;
  %{$this} = %{$new_tree};
  return;
}

# Sub uses $a and $b as input. $a is the new item and $b is the output being
# computed.
# TODO: maybe have a "cat" methods that expects each node to return a string and
# concatenate them, so that we can concatenate them all together at once, which
#  might be more efficient.
sub iter {
  my ($this, $sub, $init) = @_;

  my $out = $init;

  for (@{$this->{children}}) {
    $out = $sub->($_, $out);
  }

  return $out;
}

# $tree->find_in_text($re, first_child, offset_in_first_child)
# finds the first offset match of re in the tree (not recursing in sub-tree),
# starting at the given child index and the given index in the child content.
# Only considers children of type text.
# We don’t look for anything startint at or after the bounds if they are given.
# Returns (child_number, start_offset, end_offset) or undef.
sub find_in_text {
  my ($this, $re, $child_start, $text_start, $child_bound, $text_bound) = @_;
  for my $i ($child_start .. ($child_bound // $#{$this->{children}})) {
    next unless $this->{children}[$i]{type} eq 'text';
    my ($match, @pos);
    if ($i == $child_start && $text_start != 0) {
      pos($this->{children}[$i]{content}) = $text_start;
      $match = $this->{children}[$i]{content} =~ m/${re}/g;
      @pos = ($LAST_MATCH_START[0], $LAST_MATCH_END[0]) if $match;  # @- and @+ are localized to this block
    } else {
      $match = $this->{children}[$i]{content} =~ m/${re}/;
      @pos = ($LAST_MATCH_START[0], $LAST_MATCH_END[0]) if $match;  # @- and @+ are localized to this block
    }
    if ($match) {
      return if $i == ($child_bound // -1) && $pos[0] >= $text_bound;
      return ($i, @pos);
    }
  }
  return;
}

# Same as find_in_text except that we look for both open_re and close_re and,
# each time open_re is found, we need to find close_re one more time before we
# return. We assume that $open_re has already been seen once before the given
# start child and text offset.
sub find_balanced_in_text {
  my ($this, $open_re, $close_re, $child_start, $text_start) = @_;

  my $open = 1;

  for my $i ($child_start .. $#{$this->{children}}) {
    next unless $this->{children}[$i]{type} eq 'text';
    if ($i == $child_start && $text_start != 0) {
      pos($this->{children}[$i]{content}) = $text_start;
    } else {
      pos($this->{children}[$i]{content}) = 0;
    }

    # When the code in this regex is executed, we are sure that the engine
    # won’t backtrack (as we are at the end of the regex).
    while (
      $this->{children}[$i]{content} =~ m/ ${open_re}(?{$open++}) | ${close_re}(?{$open--}) /gx)
    {
      return ($i, $LAST_MATCH_START[0], $LAST_MATCH_END[0]) if $open == 0;
    }
  }

  return;
}

sub render_html {
  my ($tree) = @_;
  return $tree->iter(\&render_node_html, '');
}

sub render_node_html {
  my ($n, $acc) = @_;

  if ($n->{type} eq 'text') {
    # TODO: Maybe we should not do that on the last newline of the string?
    html_escape($n->{content});
    $n->{content} =~ s{(?: {2,}|\\)\n}{<br />\n}g;
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'literal') {
    html_escape($n->{content});
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'code') {
    # New lines are treated like spaces in code.
    $n->{content} =~ s/\n/ /g;
    # If the content is not just whitespace and it has one space at the
    # beginning and one at the end, then we remove them.
    $n->{content} =~ s/ (.*[^ ].*) /$1/g;
    html_escape($n->{content});
    return $acc.'<code>'.$n->{content}.'</code>';
  } elsif ($n->{type} eq 'link') {
    # TODO: in the future links can contain sub-node (right?)
    # For now this is only autolinks.
    if (exists $n->{content}) {
      html_escape($n->{content});
      html_escape($n->{target});
      http_escape($n->{target});
      return $acc.'<a href="'.($n->{target}).'">'.($n->{content}).'</a>';
    } else {
      # TODO: the target should not be stored as a tree but directly as a string.
      my $target = $n->{target}->render_lite();
      my $content = $n->{subtree}->render_html();
      return $acc."<a href=\"${target}\">${content}</a>";
    }
  }
}

# Render the original Markdown code, more or less (with some html escaping still
# done).
sub render_lite {
  my ($tree) = @_;
  return $tree->iter(\&render_node_lite, '');
}

sub render_node_lite {
  my ($n, $acc) = @_;

  if ($n->{type} eq 'text') {
    html_escape($n->{content});
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'literal') {
    # TODO: this should be the original string, stored somewhere in the node.
    # (to follow the rules to match link-reference name).
    html_escape($n->{content});
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'code') {
    html_escape($n->{content});
    return $acc.'<code>'.$n->{content}.'</code>';
  } elsif ($n->{type} eq 'link') {
    die 'The render_lite method does not support link nodes';
  }
}

# There are four characters that are escaped in the html output (although the
# spec never really says so because they claim that they care only about parsing).
# TODO: move to the Util module.

my %char_to_html_entity = (
  '"' => '&quot;',
  '&' => '&amp;',
  '<' => '&lt;',
  '>' => '&gt;'
);

sub html_escape {
  $_[0] =~ s/([&"<>])/$char_to_html_entity{$1}/eg;
  return;
}

# TODO: move to the Util module.
sub http_escape {
  $_[0] =~ s/([\\\[\]])/sprintf('%%%02X', ord($1))/ge;
  return;
}

1;
