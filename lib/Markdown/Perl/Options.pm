package Markdown::Perl::Options;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Carp;
use Exporter 'import';
use List::Util 'any', 'pairs';

our $VERSION = '0.01';

our @EXPORT_OK = qw(validate_options);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=pod

=encoding utf8

=head1 NAME

Configuration options for pmarkdown and Markdown::Perl

=head1 SYNOPSIS

This document describes the existing configuration options for the
L<Markdown::Perl> library and the L<pmarkdown> program. Please refer to their
documentation to know how to set and use these options.

=head1 MODES

Bundle of options can be set together using I<modes>.

TODO

=head1 OPTIONS

=cut

sub new {
  my ($class, %options) = @_;

  my $this = bless \%options, $class;
  $this->{memoized} = {};  # TODO: use this.
  return $this;
}

my %options_modes;
my %validation;

sub set_options {
  my ($this, $dest, @options) = @_;
  # We don’t put the options into a hash, to preserve the order in which they
  # are passed.
  for my $p (pairs @options) {
    my ($k, $v) = @{$p};
    if ($k eq 'mode') {
      $this->set_mode($v);
    } else {
      carp "Unknown option ignored: ${k}" unless exists $validation{$k};
      my $validated_value = $validation{$k}($v);
      croak "Invalid value for option '${k}': ${!}" unless defined $validated_value;
      $this->{$dest}{$k} = $validated_value;
    }
  }
  return;
}

# returns nothing but dies if the options are not valid. Useful to call before
# set_options to get error messages without stack-traces in context where this
# is not needed (while set_options will use carp/croak).
sub validate_options {
  my (%options) = @_;
  while (my ($k, $v) = each %options) {
    if ($k eq 'mode') {
      die "Unknown mode '${v}'\n" unless exists $options_modes{$v};
    } else {
      die "Unknown option: ${k}\n" unless exists $validation{$k};
      my $validated = $validation{$k}($v);
      die "Invalid value for option '${k}': ${!}\n" unless defined $validated;
    }
  }
  return;
}

sub set_mode {
  my ($this, $mode) = @_;
  carp "Setting mode '${mode}' overriding already set mode '$this->{mode}'"
      if defined $this->{mode};
  if ($mode eq 'default' || $mode eq 'pmarkdown') {
    undef $this->{mode};
    return;
  }
  croak "Unknown mode '${mode}'" unless exists $options_modes{$mode};
  $this->{mode} = $mode;
  return;
}

# This method is called below to "create" each option. In particular, it
# populate an accessor method in this package to reach the option value.
sub _make_option {
  my ($opt, $default, $validation, %mode) = @_;
  while (my ($k, $v) = each %mode) {
    $options_modes{$k}{$opt} = $v;
  }
  $validation{$opt} = $validation;

  {
    no strict 'refs';
    *{"get_".$opt} = sub {
      my ($this) = @_;
      return $this->{local_options}{$opt} if exists $this->{local_options}{$opt};
      return $this->{options}{$opt} if exists $this->{options}{$opt};
      if (defined $this->{mode}) {
        return $options_modes{$this->{mode}}{$opt}
            if exists $options_modes{$this->{mode}}{$opt};
      }
      return $default;
    };
  }

  return;
}

sub _boolean {
  return sub {
    return 0 if $_[0] eq 'false' || $_[0] eq '0';
    return 1 if $_[0] eq 'true' || $_[0] eq '1';
    $! = 'must be a boolean value (0 or 1)';
    return;
  };
}

sub _enum {
  my @valid = @_;
  return sub {
    return $_[0] if any { $_ eq $_[0] } @valid;
    $! = "must be one of '".join("', '", @valid)."'";
    return;
  };
}

sub _regex {
  return sub {
    my $re = eval { qr/$_[0]/ };
    return $re if defined $re;
    $! = 'cannot be parsed as a Perl regex ($@)';
    return;
  };
}

=pod

=head2 B<fenced_code_blocks_must_be_closed> I<(boolean, default: true)>

By default, a fenced code block with no closing fence will run until the end of
the document. With this setting, the opening fence will be treated as normal
text, rather than the start of a code block, if there is no matching closing
fence.

=cut

_make_option(fenced_code_blocks_must_be_closed => 1, _boolean, (cmark => 0, github => 0));

=pod

=head2 B<code_blocks_info> I<(enum, default: language)>

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

=head2 B<multi_lines_setext_headings> I<(enum, default: multi_line)>

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

_make_option(
  multi_lines_setext_headings => 'multi_line',
  _enum(qw(single_line break multi_line ignore)));

=pod

=head2 B<autolinks_regex> I<(regex string)>

The regex that an autolink must match. This is for CommonMark autolinks, that
are recognized only if they appear between brackets C<\<I<link>\>>.

The default value is meant to match the
L<spec|https://spec.commonmark.org/0.30/#autolinks>. Basically it requires a
scheme (e.g. C<https:>) followed by mostly anything else except that spaces and
the bracket symbols (C<\<> and C<\>>) must be escaped.

=cut

_make_option(autolinks_regex => '(?i)[a-z][-+.a-z0-9]{1,31}:[^ <>[:cntrl:]]*', _regex);

=pod

=head2 B<autolinks_email_regex> I<(regex string)>

The regex that an autolink must match to be recognised as an email address. This
allows to omit the C<mailto:> scheme that would be needed to be recognised as
an autolink otherwise.

The default value is exactly the regex specified by the
L<spec|https://spec.commonmark.org/0.30/#autolinks>.

=cut

_make_option(
  autolinks_email_regex =>
      q{[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*},
  _regex);

=pod

=head2 B<inline_delimiters> I<(map)>

TODO: document
TODO: provide a way to add entries to this option without redefining it entirely
(when used on the command line).

=cut

sub _delimiters_map {
  return sub {
    my %m = ref $_[0] eq 'HASH' ? %{$_[0]} : map { split(/=/, $_, 2) } split(/,/, $_[0]);
    # TODO: validate the keys and values of m.
    return \%m if %m;
    return { "\x{00}" => 'p' } # this can’t trigger but the code fails with an empty map otherwise.
  };
}

_make_option(
  inline_delimiters =>
    {
      '*' => 'em',
      '**' => 'strong',
      '_' => 'em',
      '__' => 'strong',
      '~' => 's',
      '~~' => 'del',
    },
    _delimiters_map,
    cmark => {
      '*' => 'em',
      '**' => 'strong',
      '_' => 'em',
      '__' => 'strong',
    },
    github => {
      '*' => 'em',
      '**' => 'strong',
      '_' => 'em',
      '__' => 'strong',
      '~' => 'del',
      '~~' => 'del',
    }
);

=pod

=head2 B<html_escaped_characters> I<(character_class)>

This option specifies the list of characters that will be escaped in the HTML
output. This should be a string containing the characters to escapes. Only the
following characters are supported and can be passed in the string: C<">, C<'>,
C<&>, C<E<lt>>, and C<E<gt>>.

=cut

sub _escaped_characters {
  return sub {
    return $_[0] if $_[0] =~ m/^["'&<>]*$/;
    $! = "must only contains the following characters: \", ', &, <, and >";
    return;
  };
}

_make_option(html_escaped_characters => '"&<>', _escaped_characters, markdown => '&<');

=pod

=head2 B<allow_spaces_in_links> I<(enum, default: none)>

This option controls whether spaces are allowed between the link text and the
link destination (between the closing bracket of the text and the opening
parenthesis or bracket of the destination).

=over 4

=item B<none> I<(default)>

No space is allowed between the link text and the link target.

=item B<reference>

This allows at most one space between the two sets of brackets in a
reference link.

=back

=cut

_make_option(
  allow_spaces_in_links => 'none',
  _enum(qw(none reference)),
  (markdown => 'reference'));

1;
