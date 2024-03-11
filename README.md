# pmarkdown

Configurable Markdown processor.

## Main features

This software supports the entire `CommonMark` spec syntax, with some addition.

## Installation

### Pre-compiled binaries for Windows and Linux

You can download on the
[releases page](https://github.com/mkende/pmarkdown/releases) portable version
of `pmarkdown` for Windows and Linux.

### Installation from the Perl package manager

To install `pmarkdown` you need Perl (which is already installed on most Linux
distribution) and you need the `cpanm` Perl package manager. You can usually get
both with one of these commands:

```
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus
```

Then run the following:

```
cpanm --notest App::pmarkdown
```

### Installation from the Git source

To install `pmarkdown` you need Perl (which is already installed on most Linux
distribution) and you need the `cpanm` Perl package manager. You can usually get
both with one of these commands:

```
# On Debian, Ubuntu, Mint, etc.
sudo apt-get install perl cpanminus

# On Red Hat, Fedora, CentOS, etc.
sudo yum install perl perl-App-cpanminus
```

Then run the following:

```
git clone https://github.com/mkende/pmarkdown.git
cd pmarkdown
cpanm --notest --with-configure --installdeps .
perl Makefile.PL
make
sudo make install
```
