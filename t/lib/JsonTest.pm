package JsonTest;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use HTML::TreeBuilder;
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
    $out =~ s/\n//;
    my $val = HTML::TreeBuilder->new_from_content($out);
    my $expected = HTML::TreeBuilder->new_from_content($t->{html});

    my $title = sprintf "%s (%d)", $t->{section}, $t->{example};
    my @diag;
    push @diag, sprintf $opt{test_url}, $t->{example} if exists $opt{test_url};
    push @diag, 'Input markdown:', $t->{markdown}, "\n";
    ok($val->same_as($expected), $title, @diag);
  }
}
