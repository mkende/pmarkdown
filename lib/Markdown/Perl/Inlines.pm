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

  # my @runs = process_links($that, @runs);

  # Now, there are more link elements and they can have children instead of
  # content.

  my $out = $tree->iter(\&render_node, '');

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
    my $new_tree = Markdown::Perl::InlineTree->new();
    while ($node->{content} =~ m/\\(\p{PosixPunct})/g) {
      $new_tree->push(new_text(decode_entities(substr $node->{content}, 0, $-[0]))) if $-[0] > 0;
      $new_tree->push(new_literal($1));
      substr $node->{content}, 0, $+[0], '';  # This resets pos($node->{content}) as we want it to.      
    }
    $new_tree->push(new_text(decode_entities($node->{content}))) if $node->{content};
    return $new_tree;
  }
}

sub process_links {
  my ($that, @runs) = @_;

  for (my $i = 0; $i < @runs; $i++) {
    if ($runs[$i]{type} eq 'text') {
      if ($runs[$i]{content} =~ m/\[/) {
        my $open_pos = $-[0];

      }
    } elsif ($runs[$i]{type} eq 'code') {
      # passthrough
    } elsif ($runs[$i]{type} eq 'link') {
      # passthrough, these are autolink with no content.
    } elsif ($runs[$i]{type} eq 'literal') {
      # passthrough
    }
  }
}

# There are four characters that are escaped in the html output (although the
# spec never really says so because they claim that they care only about parsing).
sub html_escape {
  $_[0] =~ s/([&"<>])/&map_entity/eg;
  # TODO, compare speed with `encode_entities($_[0], '<>&"')` from HTML::Entities
  return;
}
# TODO: fork HTML::Escape at some point, so that it supports only these 4
# characters.
sub map_entity {
  return '&quot;' if $1 eq '"';
  return '&amp;' if $1 eq '&';
  return '&lt;' if $1 eq '<';
  return '&gt;' if $1 eq '>';
}

sub http_escape {
  $_[0] =~ s/([\\\[\]])/sprintf('%%%02X', ord($1))/ge;
}

sub render_node {
  my ($n, $acc) = @_;

  if ($n->{type} eq 'text') {
    # TODO: Maybe we should not do that on the last newline of the string?
    html_escape($n->{content});
    $n->{content} =~ s{(?: {2,}|\\)\n}{<br />\n}g;
    return $acc . $n->{content};
  } elsif ($n->{type} eq 'literal') {
    html_escape($n->{content});
    return $acc . $n->{content};
  } elsif ($n->{type} eq 'code') {
    # New lines are treated like spaces in code.
    $n->{content} =~ s/\n/ /g;
    # If the content is not just whitespace and it has one space at the
    # beginning and one at the end, then we remove them.
    $n->{content} =~ s/ (.*[^ ].*) /$1/g;
    html_escape($n->{content});
    return $acc . '<code>'.$n->{content}.'</code>';
  } elsif ($n->{type} eq 'link') {
    # TODO: in the future links can contain sub-node (right?)
    # For now this is only autolinks.
    html_escape($n->{content});
    html_escape($n->{target});
    http_escape($n->{target});
    return $acc . '<a href="'.($n->{target}).'">'.($n->{content}).'</a>';
  }
}

1;
