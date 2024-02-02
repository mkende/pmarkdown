# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.

requires 'perl', '5.26.0';

on 'configure' => sub {
  requires 'ExtUtils::MakeMaker::CPANfile', '0.0.9';
};

on 'test' => sub {
  requires 'Test::More';
  requires 'Test2::V0';
  recommends 'Test::Pod', '1.22';
  recommends 'Test2::Tools::PerlCritic';
  suggests 'Perl::Tidy', '20220613';
};

# Develop phase dependencies are usually not installed, this is what we want as
# Devel::Cover has many dependencies.
on 'develop' => sub {
  requires 'Devel::Cover';
};

# End of the template. You can add custom content below this line.

requires 'List::MoreUtils';
requires 'HTML::Entities';

on 'test' => sub {
  requires 'Test2::V0';
}
