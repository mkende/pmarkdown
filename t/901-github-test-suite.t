use strict;
use warnings;
use utf8;

use FindBin;
use lib "${FindBin::Bin}/lib";

use CmarkTest;
use Test2::V0;

# TODO: remove these todos.
my %opt = (todo => [198 .. 202, 204, 205, 279, 280, 398, 426, 434 .. 436,
                       473 .. 475, 477, 621 .. 631, 652],
              json_file => "${FindBin::Bin}/data/github.tests.json",
              test_url => 'https://github.github.com/gfm/#example-%d',
              spec_tool => "${FindBin::Bin}/../third_party/commonmark-spec/test/spec_tests.py",
              spec => "${FindBin::Bin}/../third_party/cmark-gfm/test/spec.txt",
              spec_name => 'GitHub',
              mode => 'github');

while ($_ = shift) {
  $opt{test_num} = shift @ARGV if /^-n$/;
  $opt{use_full_spec} = 0 if /^--fast/;
  $opt{use_full_spec} = 1 if /^--full/;
}

test_suite(%opt);

done_testing;
