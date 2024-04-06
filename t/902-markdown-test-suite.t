use strict;
use warnings;
use utf8;

use FindBin;
use lib "${FindBin::Bin}/lib";

use Markdown::Perl;
use MmdTest;
use Test2::V0;

# TODO: remove these todos.
my %opt = (
  todo => [16, 18, 22],
  # These are bugs in the Markdown "spec", not in our implementation. All of
  # these have been tested to be buggy in the real Markdown.pl implementation.
  bugs => [
    # The original implementation will emit <strong><em> tag for ***foo***,
    # however this does not extrapolate well to other cases. In particular:
    # ***foo** bar* is rendered as the buggy <strong><em>foo</strong> bar</em>
    21,
  ],
);

while ($_ = shift) {
  $opt{test_num} = shift @ARGV if /^-n$/;
}
$opt{ext} = 'xhtml';

my $pmarkdown = Markdown::Perl->new(mode => 'markdown');

my $n = test_suite("${FindBin::Bin}/../third_party/mdtest/Markdown.mdtest", $pmarkdown, %opt);

done_testing;
