# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.

use strict;
use warnings;

use Test2::V0;

use IPC::Run3 'run3';
use File::Basename 'basename', 'dirname';
use File::Find 'find';
use File::Spec::Functions 'abs2rel';
use FindBin;

BEGIN {
  if (not $ENV{EXTENDED_TESTING}) {
    skip_all('Extended test. Set $ENV{EXTENDED_TESTING} to a true value to run.');
  }
}

my $aspell = `which aspell 2> /dev/null`;

my $root = $FindBin::Bin.'/..';

my $mode = (@ARGV && $ARGV[0] eq '--interactive') ? 'interactive' : 'list';

my @base_cmd = ('aspell', '--encoding=utf-8', "--home-dir=${root}",
                '--lang=en_GB-ise', '-p',  '.aspelldict');

if (not $aspell) {
   skip_all('The aspell program is required in the path to check the spelling.');
}

sub list_bad_words {
  my ($file, $type) = @_;
  my $bad_words;
  my @cmd = (@base_cmd, "--mode=${type}", 'list');
  run3(\@cmd, $file, \$bad_words) or die "Can’t run aspell: $!";
  return $bad_words;
}

sub interactive_check {
  my ($file, $type) = @_;
  my @cmd = (@base_cmd, "--mode=${type}", 'check', $file);
  return system @cmd;
}

# Note: while strings in Perl modules are checked, the POD content is ignored
# unfortunately.

sub wanted {
  # We should do something more generic to not recurse in Git sub-modules.
  $File::Find::prune = 1 if -d && m/^(blib|third_party|\..+)$/;
  return unless -f;

  my $type;
  if (m/\.(pm|pod)$/ || basename(dirname($_)) eq 'script') {
    $type = 'perl';
  } elsif (m/\.md$/) {
    $type = 'markdown';
  } else {
    return;
  }

  my $file_from_root = abs2rel($File::Find::name, $root);
  if ($mode eq 'list') {
    like(list_bad_words($_, $type), qr/^\s*$/, "Spell-checking ${file_from_root}");
  } elsif ($mode eq 'interactive') {
    is(interactive_check($_, $type), 0, "Interactive spell-checking for ${file_from_root}");
  } else {
    die "Unknown operating mode: '${mode}'";
  }
}

find(\&wanted, $root);
done_testing();

# End of the template. You can add custom content below this line.
