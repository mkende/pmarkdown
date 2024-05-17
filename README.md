# pmarkdown

Very configurable Markdown processor supporting the CommonMark spec and many
extensions.

## Main features

This software supports the entire
[`CommonMark` spec](https://spec.commonmark.org/0.31.2/) syntax, as well as all
[GitHub Flavored Markdown (gfm) extensions](https://github.github.com/gfm/)
some more custom extensions. It also has compatibility with the
[original Markdown syntax](https://daringfireball.net/projects/markdown/syntax).

See the [Syntax page](Syntax.md) for a full description of the default syntax
supported by `pmarkdown`. You can also
[try it out online](https://dingus.mkdoc.io/) or compare it to other
implementations by using [Babelmark](https://babelmark.github.io/).

This program is based on the
[Markdown::Perl](https://metacpan.org/pod/Markdown::Perl) library that can be
used in standalone Perl programs.

## Usage

Using `pmarkdown` is as simple as running the following command:

```shell
pmarkdown < input.md > output.html
```

You can read about all the command line options in the
[`pmarkdown` documentation](https://metacpan.org/pod/pmarkdown).

## Installation

### Pre-compiled binaries for Windows and Linux

You can download portable versions of `pmarkdown` for Windows and Linux on the
[releases page](https://github.com/mkende/pmarkdown/releases).

### Installation from the Perl package manager

To install `pmarkdown` you need Perl (which is already installed on most Linux
distributions) and you need the `cpanm` Perl package manager. In addition, the
`perl-doc` program is optional but will improve the display of the program
documentation. You can usually get them with one of these commands:

```shell
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus perl-doc

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus perl-doc
```

Then run the following to install `pmarkdown`:

```shell
sudo cpanm App::pmarkdown -n -L /usr/local --man-pages --install-args 'DESTINSTALLBIN=/usr/local/bin'
```

### Installation from the Git sources

To install `pmarkdown` you need Perl (which is already installed on most Linux
distributions) and you need the `cpanm` Perl package manager. In addition, the
`perl-doc` program is optional but will improve the display of the program
documentation. You can usually get them with one of these commands:

```shell
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus perl-doc

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus perl-doc
```

Then run the following command to install `pmarkdown` (note that you do not need
to initialize the git submodules):

```shell
git clone https://github.com/mkende/pmarkdown.git
cd pmarkdown
cpanm --notest --with-configure --installdeps .
perl Makefile.PL
make
sudo make install
```

Note that, with this installation method, you might need to reinstall the
program each time your system Perl is updated. So the methods above are
recommended.
