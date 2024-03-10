# A package to execute the tests of the MMD-Test-Suite repository.

package MmdTest;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use File::Basename;
use HtmlSanitizer;
use Test2::V0;
use Text::Diff;

our @EXPORT = qw(test_suite);

sub slurp_file  {
  my ($file_name) = @_;
  open my $fh, '<:encoding(utf-8)', $file_name;
  local $/ = undef;
  my $content = <$fh>;
  close $fh;
  return $content;
}

sub one_test {
  my ($pmarkdown, $md_file, $html_file) = @_;
  my $test_name = fileparse($md_file, '.text');
  my $md = slurp_file($md_file);
  my $out = sanitize_html($pmarkdown->convert($md));
  my $expected = sanitize_html(slurp_file($html_file));
  my @diag;
  my $diff = diff \$out, \$expected, { FILENAME_A => 'actual', FILENAME_B => 'expected', CONTEXT => 0 };
  push @diag, 'Diff:', $diff, "\n";
  push @diag, 'Input markdown:', $md, "\n";
  is ($out, $expected, $test_name, @diag);
}

sub test_suite {
  my ($test_dir, $pmarkdown, %opt) = @_;
  my $i = $opt{start_num} // 0;
  for my $md_file (glob "${test_dir}/*.text") {
    $i++;
    next if exists $opt{test_num} && $opt{test_num} != $i;
    my $html_file = $md_file =~ s/\.text$/.html/r;
    SKIP: {
      skip "Missing html file '${html_file}'" unless -f $html_file;
      one_test($pmarkdown, $md_file, $html_file);
    }
  }
  return $i;
}
