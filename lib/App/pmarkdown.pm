package App::pmarkdown;

use Markdown::Perl;

our $VERSION = $Markdown::Perl::VERSION; ## no critic (ProhibitComplexVersion,RequireConstantVersion)

=pod

=head1 NAME

App::pmarkdown

=head1 SYNOPSIS

This package is only here to reserve the C<App::pmarkdown> name to simplify the
installation of the L<pmarkdown> markdown processor.

The documentation for the markdown processor is in the L<pmarkdown> page. It’s
implementation is based on the L<Markdown::Perl> library that can be used
programmatically too.

=cut
