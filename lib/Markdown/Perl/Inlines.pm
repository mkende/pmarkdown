# Package to process the inline structure of Markdown.

package Markdown::Perl::Inlines;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use HTML::Entities 'decode_entities';

our @EXPORT = ();
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (all => \@EXPORT_OK);


# Everywhere here, $that is a Markdown::Perl instance.
sub render {
  my ($that, @lines) = @_;

  my $text = join("\n", @lines);
  my @runs = find_code_and_tag_runs($that, $text);

  # At this point, @runs contains only 'text' or  'code' elements, that can’t
  # have any children.

  @runs = map { process_char_escaping($that, $_) } @runs;

  # At this point, @runs can also contain 'literal' elements, that don’t have
  # children either.

  return render_runs($that, @runs);
}

sub find_code_and_tag_runs {
  my ($that, $text) = @_;
  my @runs;

  # We match code-spans and autolinks first as they bind strongest. Raw HTML
  # should be here too, but we don’t support it yet.
  # https://spec.commonmark.org/0.30/#code-spans
  # TODO: https://spec.commonmark.org/0.30/#autolinks
  # TODO: https://spec.commonmark.org/0.30/#raw-html
  # while ($text =~ m/(?<code>\`+)|(?<html>\<)/g) {
  # We are manually handling the backcslash escaping here because they are not
  # interpreted inside code blocks. We will then process all the others
  # afterward.
  while ($text =~ m/(?<! \\) (?<backslashes> (\\\\)*) (?<code>\`+)/gx) {
    my ($start_before, $start_after) = ($-[0] + length($+{backslashes}), $+[0]);
    if ($+{code}) {
      my $fence = $+{code};
      # We’re searching for a fence of the same length, without any backticks
      # before or after.
      if ($text =~ m/(?<!\`)${fence}(?!\`)/gc) {
        my ($end_before, $end_after) = ($-[0], $+[0]);
        push @runs, { type => 'text', content => substr $text, 0, $start_before} if $start_before > 0;
        push @runs, { type => 'code', content => substr $text, $start_after, ($end_before - $start_after) };
        substr $text, 0, $end_after, '';  # This resets pos($text) as we want it to.
      }  # in the else clause, pos($text) == $start_after (because of the /c modifier).
    }
  }
  push @runs, { type => 'text', content => $text } if $text;

  return @runs;
}

sub process_char_escaping {
  my ($that, $run) = @_;

  # This is executed after 
  if ($run->{type} eq 'code') {
    return $run;
  } elsif ($run->{type} eq 'text') {
    my @new_runs;
    #while ($run->{content} =~ s/\\[!"#$%&'()*+,\-./:;<=>?+[\\\]^_`{|}~]//)
    while ($run->{content} =~ m/\\(\p{PosixPunct})/g) {
      push @new_runs, { type => 'text', content => decode_entities(substr $run->{content}, 0, $-[0])} if $-[0] > 0;
      push @new_runs, { type => 'literal', content => $1 };
      substr $run->{content}, 0, $+[0], '';  # This resets pos($run->{content}) as we want it to.      
    }
    push @new_runs, { type => 'text', content => decode_entities($run->{content}) } if $run->{content};
    return @new_runs;
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

sub render_runs {
  my ($that, @runs) = @_;

  my $out = '';

  for my $r (@runs) {
    if ($r->{type} eq 'text') {
      # TODO: Maybe we should not do that on the last newline of the string?
      html_escape($r->{content});
      $r->{content} =~ s{(?: {2,}|\\)\n}{<br />\n}g;
      $out .= $r->{content};
    } elsif ($r->{type} eq 'literal') {
      html_escape($r->{content});
      $out .= $r->{content};
    } elsif ($r->{type} eq 'code') {
      # New lines are treated like spaces in code.
      $r->{content} =~ s/\n/ /g;
      # If the content is not just whitespace and it has one space at the
      # beginning and one at the end, then we remove them.
      $r->{content} =~ s/ (.*[^ ].*) /$1/g;
      html_escape($r->{content});
      $out .= '<code>'.$r->{content}.'</code>';
    }
  }

  # We remove white-space at the beginning and end of the lines.
  # TODO: maybe this could be done more efficiently earlier in the processing?
  $out =~ s/(?:^[ \t]+)|(?:[ \t]+$)//gm;
  return $out;
}
