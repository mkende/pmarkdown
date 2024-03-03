use strict;
use warnings;
use utf8;

use FindBin;
use lib "${FindBin::Bin}/lib";

use Markdown::Perl;
use JsonTest;
use Test2::V0;

my %filter;
my $use_full_spec = 0;

while ($_ = shift) {
  %filter = (test_num => shift @ARGV) if /^-n$/;
  $use_full_spec = 0 if /^--fast/;
  $use_full_spec = 1 if /^--full/;
}

sub json_test {
  my $test_data = "${FindBin::Bin}/data/github.tests.json";

  my %opt = (test_url => 'https://github.github.com/gfm/#example-%d',
            %filter);

  test_suite($test_data, Markdown::Perl->new(mode => 'github'), %opt);
}

sub full_test {
  skip_all('Python3 must be installed.') if system 'python3 -c "exit()" 2>/dev/null';

  my $test_dir = "${FindBin::Bin}/../third_party/commonmark-spec/test"; 
  skip_all('commonmark-spec must be checked out.') unless -d $test_dir;

  my $spec_dir = "${FindBin::Bin}/../third_party/cmark-gfm/test";
  skip_all('cmark-gfm must be checked out.') unless -d $spec_dir;

  my $root_dir = "${FindBin::Bin}/..";

  my $mode;
  if (exists $filter{test_num}) {
    $mode = "-n ".$filter{test_num};
  } else {
    $mode = "--track ${root_dir}/commonmark.tests";
  }

  my $test_suite_output = system "python3 ${test_dir}/spec_tests.py --spec ${spec_dir}/spec.txt ${mode} --program '$^X -I${root_dir}/lib ${root_dir}/script/pmarkdown -m cmark'";
  is($test_suite_output, 0, 'Github test suite');
}

todo 'Github syntax is not yet fully implemented' => sub {
  if ($use_full_spec) {
    full_test();
  } else {
    json_test();
  }
};

done_testing;
