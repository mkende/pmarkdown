# A tree DataStructure to represent the content of an inline text of a block
# element.

package Markdown::Perl::InlineTree;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use Hash::Util ();
use Scalar::Util 'blessed';

our @EXPORT = ();
our @EXPORT_OK = qw(new_text new_code new_link new_literal is_node is_tree);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

sub new {
  my ($class) = @_;

  return bless { children => [] }, $class;
}

package Markdown::Perl::InlineNode {

  sub new {
    my ($class, $type, $content, %options) = @_;

    my $this;
    if ($type eq 'text' || $type eq 'code' || $type eq 'literal') {
      die "Unexpected content for inline ${type} node: ".ref($content) if ref $content;
      die "Unexpected parameters for inline ${type} node: ".join(', ', %options) if %options;
      $this = { type => $type, content => $content};
    } elsif ($type eq 'link') {
      die "Unexpected parameters for inline ${type} node: ".join(', ', %options) if keys %options > 1 || !exists $options{target};
      if (Scalar::Util::blessed($content) && $this->isa('Markdown::Perl::InlineTree')) {
        $this = { type => $type, subtree => $content, target => $options{target} };
      } elsif (!ref($content)) {
        $this = { type => $type, content => $content, target => $options{target} };
      } else {
        die "Unexpected content for inline ${type} node: ".ref($content);
      }
    } else {
      die "Unexpected type for an InlineNode: ".$type;
    }
    bless $this, $class;

    Hash::Util::lock_keys %{$this};
    return $this;
  }

  sub clone {
    my ($this) = @_;

    return bless { %{$this} }, ref($this);
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

# Add a new node at the end of the list of children of this tree.
# The node’s content can either be a string or an InlineTree, depending on the
# type of the node.
sub push {
  my ($this, $node_or_tree) = @_;

  if (is_node($node_or_tree)) {
    push @{$this->{children}}, $node_or_tree;
  } elsif (is_tree($node_or_tree)) {
    push @{$this->{children}}, @{$node_or_tree->{children}};
  } else {
    die "Invalid argument type for InlineTree::push: ".ref($node_or_tree);
  }
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

  my $new_tree = new(__PACKAGE__);

  for (@{$this->{children}}) {
    $new_tree->push($sub->());
  }

  return $new_tree if defined wantarray;
  %{$this} = %{$new_tree};
}

# Same as map_shallow, but the tree is visited recursively.
# The subtree of individual nodes are visited before the node itself is visited.
sub map {
  my ($this, $sub) = @_;

  my $new_tree = new(__PACKAGE__);

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
  };

  return $out;
}

1;
