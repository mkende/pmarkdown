# Package to process the inline structure of Markdown.

package Markdown::Perl::Inlines;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';

our @EXPORT = ();
our @EXPORT_OK = qw();
our %EXPORT_TAGS = (all => \@EXPORT_OK);



# Everywhere here, $that is a Markdown::Perl instance.
sub render {
  my ($that, @lines) = @_;

  my $text = join("\n", @lines);
  my @runs;

  # We match code-spans and autolinks first as they bind strongest. Raw HTML
  # should be here too, but we don’t support it yet.
  # https://spec.commonmark.org/0.30/#code-spans
  # TODO: https://spec.commonmark.org/0.30/#autolinks
  # TODO: https://spec.commonmark.org/0.30/#raw-html
  # while ($text =~ m/(?<code>\`+)|(?<html>\<)/g) {
  # TODO: we must check for backslash escaping at some point.
  while ($text =~ m/(?<code>\`+)/g) {
    my ($start_before, $start_after) = ($-[0], $+[0]);
    if ($+{code}) {
      my $fence = $+{code};
      # We’re searching for a fence of the same length, without any backticks
      # before or after.
      if ($text =~ m/(?<!\`)${fence}(?!\`)/gc) {
        my ($end_before, $end_after) = ($-[0], $+[0]);
        push @runs, { type => 'text', content => substr $text, 0, $start_before} if $start_before > 0;
        push @runs, { type => 'code', content => substr $text, $start_after, ($end_before - $start_after) };
        substr $text, 0, $end_after, '';  # This resets pos($text) as we want it to.
      }
    }
  }
  push @runs, { type => 'text', content => $text } if $text;

  return render_runs($that, @runs);
}

sub render_runs {
  my ($that, @runs) = @_;

  my $out = '';

  for my $r (@runs) {
    if ($r->{type} eq 'text') {
      # We match a newline preceeded by either 2 spaces or more or a non-escaped
      # back-slash and replace that with a hard-break.
      # TODO: Maybe we should not do that on the last newline of the string?
      $r->{content} =~ s{(?:\ {2,} | (?<! \\) (\\\\)* \\) \n}{($1 // '')."<br />\n"}gxe;
      $out .= $r->{content};
    } elsif ($r->{type} eq 'code') {
      # New lines are treated like spaces in code.
      $r->{content} =~ s/\n/ /g;
      # If the content is not just whitespace and it has one space at the
      # beginning and one at the end, then we remove them.
      $r->{content} =~ s/ (.*[^ ].*) /$1/g;
      $out .= '<code>'.$r->{content}.'</code>';
    }
  }

  # We remove white-space at the beginning and end of the lines.
  # TODO: maybe this could be done more efficiently earlier in the processing?
  $out =~ s/(?:^[ \t]+)|(?:[ \t]+$)//gm;
  return $out;
}
