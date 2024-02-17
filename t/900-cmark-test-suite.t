use strict;
use warnings;
use utf8;

use FindBin;
use Test2::V0;

BEGIN {
  if ($ENV{HARNESS_ACTIVE} && !$ENV{EXTENDED_TESTING}) {
    skip_all('Extended test. Run manually or set $ENV{EXTENDED_TESTING} to a true value to run.');
  }
}

skip_all('Python3 must be installed.') if system 'python3 -c "exit()" 2>/dev/null';

my $test_dir = "${FindBin::Bin}/../third_party/commonmark-spec/test";
# As of writing, the spec seems more up to date in the commonmark-spec repo than
# in the cmark repo, although the cmark one has other tools too.
my $spec_dir = "${FindBin::Bin}/../third_party/commonmark-spec";
skip_all('commonmark-spec must be checked out.') unless -d $test_dir;

my $root_dir = "${FindBin::Bin}/..";

my $test_suite_output = system "python3 ${test_dir}/spec_tests.py --spec ${spec_dir}/spec.txt --track ${root_dir}/commonmark.tests --program '$^X -I${root_dir}/lib ${root_dir}/script/pmarkdown -m cmark'";
is($test_suite_output, 0, 'Github test suite');

done_testing;
