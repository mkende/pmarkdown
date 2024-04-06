use strict;
use warnings;
use utf8;

use FindBin;
use lib "${FindBin::Bin}/lib";

use Markdown::Perl;
use MmdTest;
use Test2::V0;

# TODO: remove these todos.
my %opt = (todo => [16, 18, 21, 22]);

while ($_ = shift) {
  $opt{test_num} = shift @ARGV if /^-n$/;
}
$opt{ext} = 'xhtml';

my $pmarkdown = Markdown::Perl->new(mode => 'markdown');

my $n = test_suite("${FindBin::Bin}/../third_party/mdtest/Markdown.mdtest", $pmarkdown, %opt);

done_testing;
