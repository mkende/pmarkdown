package Markdown::Perl::Options;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use List::Util 'any';

our $VERSION = '0.01';

=pod

=encoding utf8

=head1 Configuration options for pmarkdown and Markdown::Perl

=over 4

=cut

sub _get_option {
  my ($this, $option) = @_;
  return $this->{local_options}{$option} // $this->{options}{$option};
}

my %options;
my %validation;

sub _make_option {
  my ($opt, $default, $validation, %mode) = @_;
  die "Options '${opt}' created twice" if exists $options{default}{$opt};
  while (my ($k, $v) = each %mode) {
    $options{$k}{$opt} = $v;
  }
  $validation{$opt} = $validation;

  {
    no strict 'refs';
    *{$opt} = sub { return $_[0]->{local_options}{$opt} // $_[0]->{options}{$opt} // $default };
  }

  return;
}

sub _boolean {
  return sub { $_[0] == 0 || $_[0] == 1 };
};

sub _enum {
  my @valid = @_;
  return sub { any { $_ eq $_[0] } @valid };
}

sub _regex {
  return sub { defined eval { qr/$_[0]/ } };
}

=pod

=item B<fenced_code_blocks_must_be_closed> I<(boolean, default: false)>

By default, a fenced code block with no closing fence will run until the end of
the document. With this setting, the opening fence will be treated as normal
text, rather than the start of a code block, if there is no matching closing
fence.

=cut

_make_option(fenced_code_blocks_must_be_closed => 0, _boolean);

=pod

=item B<code_blocks_info> I<(enum, default: language)>

Fenced code blocks can have info strings on their opening lines (any text after
the C<```> or C<~~~> fence). This option controls what is done with that text.

The possible values are:

=over 4

=item B<ignored>

The info text is ignored.

=item B<language> I<(default)>

=back

=cut

_make_option(code_blocks_info => 'language', _enum(qw(ignored language)));

=pod

=item B<multi_lines_setext_headings> I<(enum, default: multi_line)>

The default behavior of setext headings in the CommonMark spec is that they can
have multiple lines of text preceding them (forming the heading itself).

This option allows to change this behavior. And is illustrated with this example
of Markdown:

    Foo
    bar
    ---
    baz

The possible values are:

=over 4

=item B<single_line>

Only the last line of text is kept as part of the heading. The preceding lines
are a paragraph of themselves. The result on the example would be:
paragraph C<Foo>, heading C<bar>, paragraph C<baz>

=item B<break>

If the heading underline can be interpreted as a thematic break, then it is
interpreted as such (normally the heading interpretation takes precedence). The
result on the example would be: paragraph C<Foo bar>, thematic break,
paragraph C<baz>.

If the heading underline cannot be interpreted as a thematic break, then the
heading will use the default B<multi_line> behavior.

=item B<multi_line> I<(default)>

This is the default CommonMark behavior where all the preceding lines are part
of the heading. The result on the example would be:
heading C<Foo bar>, paragraph C<baz>

=item B<ignore>

The heading is ignored, and form just one large paragraph. The result on the
example would be: paragraph C<Foo bar --- baz>.

Note that this actually has an impact on the interpretation of the thematic
breaks too.

=back

=cut

_make_option(multi_lines_setext_headings => 'multi_line', _enum(qw(single_line break multi_line ignore)));

=pod

=item B<autolinks_regex> I<(regex string)>

The regex that an autolink must match. This is for CommonMark autolinks, that
are recognized only if they appear between brackets C<\<I<link>\>>.

The default value is meant to match the
L<spec|https://spec.commonmark.org/0.30/#autolinks>. Basically it requires a
scheme (e.g. C<https:>) followed by mostly anything else except that spaces and
the bracket symbols (C<\<> and C<\>>) must be escaped.

=cut

_make_option(autolinks_regex => '(?i)[a-z][-+.a-z0-9]{1,31}:[^ <>[:cntrl:]]*', _regex);

=pod

=item B<autolinks_email_regex> I<(regex string)>

The regex that an autolink must match to be recognised as an email address. This
allows to omit the C<mailto:> scheme that would be needed to be recognised as
an autolink otherwise.

The default value is exactly the regex specified by the
L<spec|https://spec.commonmark.org/0.30/#autolinks>.

=cut

_make_option(autolinks_email_regex => q{[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*}, _regex);

=pod

=back

=cut

1;
