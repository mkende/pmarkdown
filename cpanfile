# DO NOT EDIT! This file is written by perl_setup_dist.
# If needed, you can add content at the end of the file.
requires 'perl', '5.26.0';

on 'configure' => sub {
  requires 'ExtUtils::MakeMaker::CPANfile', '0.0.9';
};
# End of the template. You can add custom content below this line.

requires List::MoreUtils;

on 'test' => sub {
  requires 'Test2::V0';
}
