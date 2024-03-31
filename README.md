# pmarkdown

Very configurable Markdown processor supporting the CommonMark spec and many
extensions.

## Main features

This software supports the entire
[`CommonMark` spec](https://spec.commonmark.org/0.31.2/) syntax, as well as all
[GitHub Flavored Markdown (gfm) extensions](https://github.github.com/gfm/) and
some more custom extensions.

It is based on the [Markdown::Perl](https://metacpan.org/pod/Markdown::Perl)
library that can be used in standalone Perl program.

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
distributions) and you need the `cpanm` Perl package manager. You can usually
get both with one of these commands:

```shell
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus
```

Then run the following to install `pmarkdown`:

```shell
cpanm --notest App::pmarkdown
```

### Installation from the Git sources

To install `pmarkdown` you need Perl (which is already installed on most Linux
distributions) and you need the `cpanm` Perl package manager. You can usually
get both with one of these commands:

```shell
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus
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
