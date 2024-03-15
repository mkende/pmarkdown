use strict;
use warnings;
use utf8;

use FindBin;
use lib "${FindBin::Bin}/lib";

use Markdown::Perl;
use MmdTest;
use Test2::V0;

# TODO: remove these todos.
my %filter = (todo => [8, 16, 18, 20, 21, 23]);

while ($_ = shift) {
  $filter{test_num} = shift @ARGV if /^-n$/;
}

my $test_suite = "${FindBin::Bin}/../third_party/MMD-Test-Suite";
# As of writing, the spec seems more up to date in the commonmark-spec repo than
# in the cmark repo, although the cmark one has other tools too.
skip_all('MMD-Test-Suite must be checked out.') unless -d $test_suite;

my $pmarkdown = Markdown::Perl->new(mode => 'markdown');

my $n = test_suite($test_suite."/Tests", $pmarkdown, %filter);
test_suite($test_suite."/Test", $pmarkdown, start_num => $n, %filter);

done_testing;
