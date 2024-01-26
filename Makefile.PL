# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.

use 5.026;
use strict;
use warnings;
use ExtUtils::MakeMaker::CPANfile;


WriteMakefile(
    NAME             => 'Markdown::Perl',
    DISTNAME         => 'Markdown-Perl',
    AUTHOR           => q{Mathias Kende <mathias@cpan.org>},
    VERSION_FROM     => 'lib/Markdown/Perl.pm',
    ABSTRACT         => q{Very configurable Markdown processor written in pure Perl},
    LICENSE          => 'mit',
    EXE_FILES        => ['script/pmarkdown',],
    MIN_PERL_VERSION => '5.026',
    MAN3PODS         => {},
    # Directories in which we look for Makefile.PL. In general could be omitted but is needed in case there
    # is a file named Makefile.PL in a sub-directory. Should be customized if such a file needs to be
    # processed by ExtUtils.
    DIR              => [],
    NO_MYMETA => 1,
    META_MERGE => {
      'meta-spec' => { version => 2 },
      # Goes with NO_MYMETA (which would provide the dynamic config).
      dynamic_config => 0,
      no_index => {
        directory => [ 'local', 'vendor' ],
      },
      resources => {
        repository => {
          type => 'git',
          url => 'git@github.com:mkende/pmarkdown.git',
          web => 'https://github.com/mkende/pmarkdown',
        },
        bugtracker => {
          web => 'https://github.com/mkende/pmarkdown/issues',
        },
      },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => '.gz', },
    clean => { FILES => 'Markdown-Perl-*' },
);

sub MY::postamble {
  my ($self) = @_;

  my @postamble;
  push @postamble, ::postamble() if *::postamble{CODE};

  push @postamble, <<"MAKE_FRAGMENT";
distupload: tardist
\tcpan-upload --directory Markdown-Perl \$(DISTVNAME).tar\$(SUFFIX)
MAKE_FRAGMENT

  return join "\n", @postamble;
}

# You can add below this template a `postamble` sub that returns more content to
# add to the generated Makefile.

# End of the template. You can add custom content below this line.
