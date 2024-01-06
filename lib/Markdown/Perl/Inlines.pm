# Package to process the inline structure of Markdown.

package Markdown::Perl::Inlines;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use HTML::Entities 'decode_entities';
use Markdown::Perl::InlineTree ':all';

# Everywhere here, $that is a Markdown::Perl instance.
sub render {
  my ($that, @lines) = @_;

  my $text = join("\n", @lines);
  my $tree = find_code_and_tag_runs($that, $text);

  # At this point, @runs contains only 'text',  'code', or 'link' elements, that
  # can’t have any children (yet).

  $tree->map_shallow(sub { process_char_escaping($that, $_) });

  # At this point, @runs can also contain 'literal' elements, that don’t have
  # children either.

  process_links($that, $tree, 0, 0);  # We start at the beginning of the first node.

  # Now, there are more link elements and they can have children instead of
  # content.

  my $out = $tree->render_html();

  # We remove white-space at the beginning and end of the lines.
  # TODO: maybe this could be done more efficiently earlier in the processing?
  $out =~ s/(?:^[ \t]+)|(?:[ \t]+$)//gm;
  return $out;
}

sub find_code_and_tag_runs {
  my ($that, $text) = @_;

  my $tree = Markdown::Perl::InlineTree->new();

  # We match code-spans and autolinks first as they bind strongest. Raw HTML
  # should be here too, but we don’t support it yet.
  # https://spec.commonmark.org/0.30/#code-spans
  # TODO: https://spec.commonmark.org/0.30/#autolinks
  # TODO: https://spec.commonmark.org/0.30/#raw-html
  # while ($text =~ m/(?<code>\`+)|(?<html>\<)/g) {
  # We are manually handling the backcslash escaping here because they are not
  # interpreted inside code blocks. We will then process all the others
  # afterward.
  while ($text =~ m/(?<! \\) (?<backslashes> (\\\\)*) (?: (?<code>\`+) | \< )/gx) {
    my ($start_before, $start_after) = ($-[0] + length($+{backslashes}), $+[0]);
    if ($+{code}) {
      my $fence = $+{code};
      # We’re searching for a fence of the same length, without any backticks
      # before or after.
      if ($text =~ m/(?<!\`)${fence}(?!\`)/gc) {
        my ($end_before, $end_after) = ($-[0], $+[0]);
        $tree->push(new_text(substr($text, 0, $start_before))) if $start_before > 0;
        $tree->push(new_code(substr($text, $start_after, ($end_before - $start_after))));
        substr $text, 0, $end_after, '';  # This resets pos($text) as we want it to.
      }  # in the else clause, pos($text) == $start_after (because of the /c modifier).
    } else {
      # We matched a single < character.
      my $re = $that->autolinks_regex;
      my $email_re = $that->autolinks_email_regex;
      if ($text =~ m/\G(?<link>${re})\>/gc) {
        $tree->push(new_text(substr($text, 0, $start_before))) if $start_before > 0;
        $tree->push(new_link($+{link}, target => $+{link}));
        substr $text, 0, $+[0], '';  # This resets pos($text) as we want it to.
      } elsif ($text =~ m/\G(?<link>${email_re})\>/gc) {
        $tree->push(new_text(substr($text, 0, $start_before))) if $start_before > 0;
        $tree->push(new_link($+{link}, target => 'mailto:'.$+{link}));
        substr $text, 0, $+[0], '';  # This resets pos($text) as we want it to.
      }
    }
  }
  $tree->push(new_text($text)) if $text;

  return $tree;
}

sub process_char_escaping {
  my ($that, $node) = @_;

  # This is executed after 
  if ($node->{type} eq 'code' || $node->{type} eq 'link') {
    # For now, a link can only be an autolink. So we will later escape the
    # content of the link text. But we don’t want to decode HTML entities in it.
    return $node;
  } elsif ($node->{type} eq 'text') {
    # TODO: with the current code for map, this could just be @nodes.
    my $new_tree = Markdown::Perl::InlineTree->new();
    while ($node->{content} =~ m/\\(\p{PosixPunct})/g) {
      # TODO, BUG: We are introducing a bug here, due to the fact that when we parse
      # reference links, we should compare the exact string and not the decoded
      # ones. See: https://spec.commonmark.org/dingus/?text=%5Bb%60ar%60%3C%5D%0A%0A%5Bb%60ar%60%26lt%3B%5D%3Afoo%0A
      # So we should still parse the literals here, but only decode the HTML
      # entities later, after we have parsed the links.
      # Literal parsing is OK because we can always invert it (and it makes the
      # rest of the processing be much simpler because we don’t need to check
      # whether we have escaped text or not).
      $new_tree->push(new_text(decode_entities(substr $node->{content}, 0, $-[0]))) if $-[0] > 0;
      $new_tree->push(new_literal($1));
      substr $node->{content}, 0, $+[0], '';  # This resets pos($node->{content}) as we want it to.      
    }
    $new_tree->push(new_text(decode_entities($node->{content}))) if $node->{content};
    return $new_tree;
  }
}

# We find all the links in the tree, starting at the child $child_start and its
# offset $text_start. If the bounds are set, then we don’t investigate links
# that starts further than this bound.
#
# We are not implementing the recommended parsing strategy from the spec:
# https://spec.commonmark.org/0.30/#phase-2-inline-structure
# Instead, we are doing a more straight-forward algorithm, that is probably
# slower but easier to extend.
#
# Overall, this methods implement this whole section of the spec:
# https://spec.commonmark.org/0.30/#links
sub process_links {
  my ($that, $tree, $child_start, $text_start, $start_child_bound, $start_text_bound) = @_;

  my @open = $tree->find_in_text(qr/\[/, $child_start, $text_start, $start_child_bound, $start_text_bound);
  return unless @open;
  # TODO: add an argument here that recurse into sub-trees and returns false if
  # we cross a link element. However, at this stage, the only links that we
  # could find would be autolinks. Although it would make sense that the spec
  # disallow shuch elements (because it does not make sense in the resulting
  # HTLM), the current cmark implementation accepts that:
  # https://spec.commonmark.org/dingus/?text=%5Bbar%3Chttp%3A%2F%2Ftest.fr%3Ebaz%5D(%2Fbaz)%0A%0A
  # Maybe we want to fix this bug in our implementation.
  my @close = $tree->find_balanced_in_text(qr/\[/, qr/\]/, $open[0], $open[2]);
  if (@close) {
    # We found something that could be a link, now let’s see if it contains a
    # link (if so, we won’t process the current one).
    if (my @ret = process_links($that, $tree, $open[0], $open[2], $close[0], $close[1])) {
      # We found a link within our bounds, so we don’t create a new link around
      # it. If we are a top-level call we try again after the end of the
      # inner-most link found (which was necessarily the left-most valid link.
      # If we are not the top-level call, we just propagate that bound.
      return @ret if defined $start_child_bound;
      process_links($that, $tree, @ret);
      return;  # For top-level calls, we don’t care about the return value.
    } else {
      # We have a candidate link and no internal links, so we try to look at its
      # destination.
      # It’s unclear in the spec what happens in the case when a link
      # destination crosses the boundary of an enclosing candidate link. We
      # assume that the inner one is defined by the link text and not by the
      # destination.
      
      my $target = process_link_destination($that, $tree, $close[0], $close[2]);
      if ($target) {
        my $text_tree = $tree->extract($open[0], $open[2], $close[0], $close[1]);
        my (undef, $dest_node_index) = $tree->extract($open[0], $open[1], $open[0]+1, 1);
        # TODO: $target should be rendered to a "simple text" or something and
        # not added as a sub-tree.
        my $link = new_link($text_tree, target => $target);
        $tree->insert($dest_node_index, $link);
        # If we are not a top-level call, we return the coordinate where to
        # start looking again for a link.
        return ($dest_node_index + 1, 0) unless defined $start_child_bound;
        # If we are a top-level call, we directly start the search at these
        # coordinates.
        process_links($that, $tree, $dest_node_index + 1, 0);
        return;  # For top-level calls, we don’t care about the return value.
      } else {
        # We could not match a link target, so this is not a link at all.
        # We continue the search just after our initial opening bracket.
        # We do the same call whether or not we are a top-level call.
        return process_links($that, $tree, $open[0], $open[2], $start_child_bound, $start_text_bound);
      }
    }
  } else {
    # Our open bracket was unmatched. This necessarily means that we are in the
    # unbounded case (as, otherwise we are within a balanced pair of brackets).
    die "Unexpected bounded call to process_links with unbalanced brackets" if defined $start_child_bound;
    # We continue to search starting just after the open bracket that we found.
    process_links($that, $tree, $open[0], $open[2]);
    return;  # For top-level calls, we don’t care about the return value.
  }
}

sub process_link_destination {
  my ($that, $tree, $child_start, $text_start) = @_;
  # We assume that the beginning of the link destination must be just after the
  # link text and in the same child, as there can be no other constructs
  # in-between.
  # TODO: For now we only look at a single element.
  # TODO: this is a very very partial treatment of the link destination.
  # We need to support more formatting and the case where there are Literal
  # elements in the link. The spec does not say what happens if there are
  # other type of elements in the link destination like, stuff that looks like
  # code for example (in practice, cmark will not process their content).
  # So let’s not care too much...

  my $n = $tree->{children}[$child_start];
  die "Unexpected link destination search in a non-text element: ".$n->{type} unless $n->{type} eq 'text';
  # TODO: use find_in_text bounded (to work across child limit);
  return unless substr($n->{content}, $text_start, 1) eq '(';

  pos($n->{content}) = $text_start + 1;
  # TODO: use find_in_text (balanced?) to find the end of the potential target
  # and then try to build the text.
  if ($n->{content} =~ m/(\G[^ ()[:cntrl:]]*)\)/) {
    # If we found a target, we know that we will use it, so we can remove it
    # from the tree.
    my $target = $tree->extract($child_start, $text_start + 1, $child_start, $+[1]);
    # We remove the parenthesis. This relies on the fact that we were in one
    # large text node (that is now two text nodes).
    # TODO: remove this assumption.
    $tree->extract($child_start, $text_start, $child_start+1, 1);
    return $target;
  }
  return;

}

1;
