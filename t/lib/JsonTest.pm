package JsonTest;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';
use JSON 'from_json';
use Test2::V0;

our @EXPORT = qw(test_suite);

# The sanitizing here is quite strict (it only removes new lines happening just
# before or after an HTML tag), so this forces our converter to match closely
# what the cmark spec has (I guess it’s not a bad thing).
# In addition, this light-weight normalization did encover a couple of bugs that
# were hidden by the normalization done by the cmark tool.
sub  _sanitize_html {
  my ($html) = @_;
  while ($html =~ m/<code>|(?<=>)\n(?=.)|\n(?=<)/g) {
    if ($& eq "\n") {
      my $p = pos($html);
      substr $html, $-[0], $+[0] - $-[0], '';
      pos($html) = $p - length($&);
    } else {
      $html =~ m/<\/code>|$/g;
    }
  }
  return $html;
}

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
    my $val = _sanitize_html($out);
    my $expected = _sanitize_html($t->{html});

    my $title = sprintf "%s (%d)", $t->{section}, $t->{example};
    my @diag;
    push @diag, sprintf $opt{test_url}, $t->{example} if exists $opt{test_url};
    push @diag, 'Input markdown:', $t->{markdown}, "\n";
    is($val, $expected, $title, @diag);
  }
}
