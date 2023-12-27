use strict;
use warnings;
use utf8;

use FindBin;
use Test2::V0;

skip_all('Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.') unless $ENV{TEST_AUTHOR};

skip_all('Python3 must be installed.') if system 'python3 -c "exit()" 2>/dev/null';

my $spec_dir = "${FindBin::Bin}/../third_party/commonmark-spec";
skip_all('Commonmark-spec must be checked out.') unless -d $spec_dir;
chdir $spec_dir;

my $test_suite_output = system "python3 test/spec_tests.py --track ../../commonmark.tests --program '$^X -I../../blib/lib ../../blib/script/pmarkdown'";
is($test_suite_output, 0, 'Commonmark-spec test suite');

done_testing;
