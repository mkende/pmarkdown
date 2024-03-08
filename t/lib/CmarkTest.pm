# A package to execute the cmark test suite (and those of the specs derived from
# it).
# This is mostly based on a JSON file containing all the tests.

package CmarkTest;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use HtmlSanitizer;
use JSON 'from_json';
use Test2::V0;

our @EXPORT = qw(test_suite);

sub test_suite {
  my ($json_file, $pmarkdown, %opt) = @_;
  my $test_data;
  {
    local $/ = undef;
    open my $f, '<:encoding(utf-8)', $json_file;
    my $json_data = <$f>;
    close $f;
    $test_data = from_json($json_data);
  }
  $test_data = [$test_data->[$opt{test_num} - 1]] if exists $opt{test_num};
  for my $t (@{$test_data}) {
    my $out = $pmarkdown->convert($t->{markdown});
    my $val = sanitize_html($out);
    my $expected = sanitize_html($t->{html});

    my $title = sprintf "%s (%d)", $t->{section}, $t->{example};
    my @diag;
    push @diag, sprintf $opt{test_url}, $t->{example} if exists $opt{test_url};
    push @diag, 'Input markdown:', $t->{markdown}, "\n";
    is($val, $expected, $title, @diag);
  }
}
