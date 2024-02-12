# A tree data structure to represent the content of an inline text of a block
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

our @EXPORT_OK = qw(new_text new_code new_link new_html new_style new_literal is_node is_tree);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=pod

=encoding utf8

=head1 NAME Markdown::Perl::InlineTree

=head1 SYNOPSIS

A tree structure meant to represent the inline elements of a Markdown paragraph.

=head1 DESCRIPTION

=head2 new

  my $tree = Markdown::Perl::InlineTree->new();

The constructor currently does not support any options.

=cut

sub new {
  my ($class) = @_;

  return bless {children => []}, $class;
}

package Markdown::Perl::InlineNode {  ## no critic (ProhibitMultiplePackages)

  sub hashpush (\%%) {
    my ($hash, %args) = @_;
    while (my ($k, $v) = each %args) {
      $hash->{$k} = $v;
    }
  }

  sub new {
    my ($class, $type, $content, %options) = @_;

    my $this = {type => $type};
    $this->{debug} = delete $options{debug} if exists $options{debug};
    # There is one more node type, not created here, that looks like a text
    # node but that is a 'delimiter' node. These nodes are created manually
    # inside the Inlines module.
    if ($type eq 'text' || $type eq 'code' || $type eq 'literal' || $type eq 'html') {
      die "Unexpected content for inline ${type} node: ".ref($content)
          if ref $content;
      die "Unexpected parameters for inline ${type} node: ".join(', ', %options)
          if %options;
      hashpush %{$this}, content => $content;
    } elsif ($type eq 'link') {
      die 'Unexpected parameters for inline link node: '.join(', ', %options)
          if keys %options > 1 || !exists $options{target};
      if (Scalar::Util::blessed($content)
        && $content->isa('Markdown::Perl::InlineTree')) {
        hashpush %{$this}, subtree => $content, target => $options{target};
      } elsif (!ref($content)) {
        hashpush %{$this}, content => $content, target => $options{target};
      } else {
        die "Unexpected content for inline ${type} node: ".ref($content);
      }
    } elsif ($type eq 'style') {
      die 'Unexpected parameters for inline style node: '.join(', ', %options)
          if keys %options > 1 || !exists $options{tag};
      die 'The content of a style node must be an InlineTree'
          if !Markdown::Perl::InlineTree::is_tree($content);
      hashpush %{$this}, subtree => $content, tag => $options{tag};
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

=pod

=head2 new_text, new_code, new_link, new_literal

  my $text_node = new_text('text content');
  my $code_node = new_code('code content');
  my $link_node = new_link('text content', target => 'the target'[, title => 'the title']);
  my $link_node = new_link($subtree_content, target => 'the target'[, title => 'the title']);
  my $html_node = new_html('<raw html content>');
  my $style_node = new_literal($subtree_content, 'html_tag');
  my $literal_node = new_literal('literal content');

These methods return a text node that can be inserted in an C<InlineTree>.

=cut

sub new_text { return Markdown::Perl::InlineNode->new(text => @_) }
sub new_code { return Markdown::Perl::InlineNode->new(code => @_) }
sub new_link { return Markdown::Perl::InlineNode->new(link => @_) }
sub new_html { return Markdown::Perl::InlineNode->new(html => @_) }
sub new_style { return Markdown::Perl::InlineNode->new(style => @_) }
sub new_literal { return Markdown::Perl::InlineNode->new(literal => @_) }

=pod

=head2 is_node, is_tree

These two methods returns whether a given object is a node that can be inserted
in an C<InlineTree> and whether it’s an C<InlineTree> object.

=cut

sub is_node {
  my ($obj) = @_;
  return blessed($obj) && $obj->isa('Markdown::Perl::InlineNode');
}

sub is_tree {
  my ($obj) = @_;
  return blessed($obj) && $obj->isa('Markdown::Perl::InlineTree');
}

=pod

=head2 push

  $tree->push(@nodes_or_trees);

Push a list of nodes at the end of the top-level nodes of the current tree.

If passed C<InlineTree> objects, then the nodes of these trees are pushed (not
the tree itself).

=cut

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

=pod

=head2 replace

  $tree->replace($index, @nodes);

Remove the existing node at the given index and replace it by the given list of
nodes (or, if passed C<InlineTree> objects, their own nodes).

=cut

sub replace {
  my ($this, $child_index, @new_nodes) = @_;
  splice @{$this->{children}}, $child_index, 1,
      map { is_node($_) ? $_ : @{$_->{children}} } @new_nodes;
  return;
}

=pod

=head2 insert

  $tree->insert($index, @new_nodes);

Inserts the given nodes  (or, if passed C<InlineTree> objects, their own nodes)
at the given index. After the operation, the first inserted node will have that
index.

=cut

sub insert {
  my ($this, $index, @new_nodes) = @_;
  splice @{$this->{children}}, $index, 0, map { is_node($_) ? $_ : @{$_->{children}} } @new_nodes;
  return;
}

=pod

=head2 extract

  $tree->extract($start_child, $start_offset, $end_child, $end_offset);

Extract the content of the given tree, starting at the child with the given
index (which must be a B<text> node) and at the given offset in the child’s
text, and ending at the given node and offset (which must also be a B<text>
node).

That content is removed from the input tree and returned as a new C<InlineTree>
object. Returns a pair with the new tree and the index of the first child after
the removed content in the input tree. Usually it will be C<$start_child + 1>,
but it can be C<$start_child> if C<$start_offset> was 0.

In scalar context, returns only the extracted tree.

=cut

sub extract {
  my ($this, $child_start, $text_start, $child_end, $text_end) = @_;

  my $sn = $this->{children}[$child_start];
  my $en = $this->{children}[$child_end];
  die 'Start node in an extract operation is not of type text: '.$sn->{type}
      unless $sn->{type} eq 'text';
  die 'End node in an extract operation is not of type text: '.$en->{type}
      unless $en->{type} eq 'text';
  die 'Start offset is less than 0 in an extract operation' if $text_start < 0;
  die 'End offset is past the end of the text in an extract operation'
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
    }
    if ($text_end < length($sn->{content})) {
      CORE::push @new_nodes, new_text(substr $sn->{content}, $text_end);
    }
    $this->replace($child_start, @new_nodes);
    $child_start-- if $text_start == 0;
  }
  ## use critic (ProhibitLvalueSubstr)

  return ($new_tree, $child_start + 1) if wantarray;
  return $new_tree;
}

=pod

=head2 map_shallow

  $tree->map_shallow($sub);

Apply the given sub to each direct child of the tree. The sub can return a node
or a tree and that returned content is concatenated to form a new tree.

Only the top-level nodes of the tree are visited.

In void context, update the tree in-place. Otherwise, the new tree is returned.

In all cases, C<$sub> must return new nodes or trees, it can’t modify the input
object. The argument to C<$sub> are passed in the usual way in C<@_>, not in
C<$_>.

=cut

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

=pod

=head2 map

  $tree->map($sub);

Same as C<map_shallow>, but the tree is visited recursively. The subtree of
individual nodes are visited and their content replaced before the node itself
are visited.

=cut

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

=pod

=head2 fold

  $tree->fold($sub, $init);

Iterates over the top-level nodes of the tree, calling C<$sub> for each of them.
It receives two arguments, the current node and the result of the previous call.
The first call receives C<$init> as its second argument.

Returns the result of the last call of C<$sub>.

=cut

# TODO: maybe have a "cat" methods that expects each node to return a string and
# concatenate them, so that we can concatenate them all together at once, which
#  might be more efficient.
sub fold {
  my ($this, $sub, $init) = @_;

  my $out = $init;

  for (@{$this->{children}}) {
    $out = $sub->($_, $out);
  }

  return $out;
}

=pod

=head2 find_in_text

  $tree->find_in_text($regex, $start_child, $start_offset, [$end_child, $end_offset]);

Find the first match of the given regex in the tree, starting at the given
offset in the node. This only considers top-level nodes of the tree and skip
over non B<text> node (including the first one).

If C<$end_child> and C<$end_offset> are given, then does not look for anything
starting at or after that bound.

Does not match the regex across multiple nodes.

Returns C<$child_number, $match_start_offset, $match_end_offset> or C<undef>.

=cut

sub find_in_text {
  my ($this, $re, $child_start, $text_start, $child_bound, $text_bound) = @_;
  # qr/^\b$/ is a regex that can’t match anything.
  return $this->find_balanced_in_text(qr/^\b$/, $re, $child_start, $text_start, $child_bound, $text_bound);
}

=pod

=head2 find_balanced_in_text

  $tree->find_balanced_in_text(
    $open_re, $close_re, $start_child, $start_offset, $child_bound, $text_bound);

Same as C<find_in_text> except that this method searches for both C<$open_re> and
C<$close_re> and, each time C<$open_re> is found, it needs to find C<$close_re>
one more time before we it returns. The method assumes that C<$open_re> has
already been seen once before the given C<$start_child> and C<$start_offset>.

=cut

sub find_balanced_in_text {
  my ($this, $open_re, $close_re, $child_start, $text_start, $child_bound, $text_bound) = @_;

  my $open = 1;

  for my $i ($child_start .. ($child_bound // $#{$this->{children}})) {
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
      return if $i == ($child_bound // -1) && $LAST_MATCH_START[0] >= $text_bound;
      return ($i, $LAST_MATCH_START[0], $LAST_MATCH_END[0]) if $open == 0;
    }
  }

  return;
}

=pod

=head2 find_in_text_with_balanced_content

  $tree->find_in_text_with_balanced_content(
    $open_re, $close_re, $end_re, $start_child, $start_offset,
    $child_bound, $text_bound);

Similar to C<find_balanced_in_text> except that this method ends when C<$end_re>
is seen, after the C<$open_re> and C<$close_re> regex have been seen a balanced 
number of time. If the closing one is seen more than the opening one, the search
fails. The method does B<not> assumes that C<$open_re> has already been seen
before the given C<$start_child> and C<$start_offset> (as opposed to
C<find_balanced_in_text>).

=cut

sub find_in_text_with_balanced_content {
  my ($this, $open_re, $close_re, $end_re, $child_start, $text_start, $child_bound, $text_bound) = @_;

  my $open = 0;

  for my $i ($child_start .. ($child_bound // $#{$this->{children}})) {
    next unless $this->{children}[$i]{type} eq 'text';
    if ($i == $child_start && $text_start != 0) {
      pos($this->{children}[$i]{content}) = $text_start;
    } else {
      pos($this->{children}[$i]{content}) = 0;
    }

    # When the code in this regex is executed, we are sure that the engine
    # won’t backtrack (as we are at the end of the regex).

    my $done = 0;
    while ($this->{children}[$i]{content} =~ m/ ${end_re}(?{$done = 1}) | ${open_re}(?{$open++}) | ${close_re}(?{$open--}) /gx) {
      return if $i == ($child_bound // -1) && $LAST_MATCH_START[0] >= $text_bound;
      return if $open < 0;
      return ($i, $LAST_MATCH_START[0], $LAST_MATCH_END[0]) if $open == 0 && $done;
      $done = 0;
    }
  }

  return;
}

=pod

=head2 render_html

  $tree->render_html();

Returns the HTML representation of that C<InlineTree>.

=cut

sub render_html {
  my ($tree) = @_;
  return $tree->fold(\&render_node_html, '');
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
  } elsif ($n->{type} eq 'html') {
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
      my $title = exists $n->{title} ? " title=\"$n->{title}\"" : '';
      my $content = $n->{subtree}->render_html();
      return $acc."<a href=\"$n->{target}\"${title}>${content}</a>";
    }
  } elsif ($n->{type} eq 'style') {
    my $content = $n->{subtree}->render_html();
    my $tag = $n->{tag};
    return $acc."<${tag}>${content}</${tag}>";
  } else {
    die 'Unexpected node type in render_node_html: '.$n->{type};
  }
}

=pod

=head2 to_text

  $tree->to_text();

Returns the text content of this C<InlineTree>. Not all node types are supported
and their handling is not specified here. This method is meant to be called
during the creation of an C<InlineTree>, before all the processing as been done.

=cut

sub to_text {
  my ($tree) = @_;
  return $tree->fold(\&node_to_text, '');
}

sub node_to_text {
  my ($n, $acc) = @_;

  if ($n->{type} eq 'text') {
    html_escape($n->{content});
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'literal' || $n->{type} eq 'html') {
    # TODO: this should be the original string, stored somewhere in the node.
    # (to follow the rules to match link-reference name).
    # Note: here we do escapethe content, even for raw-html, because this will
    # not be used in HTML context.
    html_escape($n->{content});
    return $acc.$n->{content};
  } elsif ($n->{type} eq 'code') {
    html_escape($n->{content});
    return $acc.'<code>'.$n->{content}.'</code>';
  } else {
    die 'Unsupported node type for to_text: '.$n->{type};
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
  # We put the " twice, to not confuse our spell-checker.
  $_[0] =~ s/([&""<>])/$char_to_html_entity{$1}/eg;
  return;
}

# TODO: move to the Util module.
sub http_escape {
  $_[0] =~ s/([\\\[\]])/sprintf('%%%02X', ord($1))/ge;
  return;
}

1;
