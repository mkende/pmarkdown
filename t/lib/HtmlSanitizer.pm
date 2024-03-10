# A package to sanitize HTML in order to ease comparison between multiple tool.

package HtmlSanitizer;

use strict;
use warnings;
use utf8;
use feature ':5.24';

use Exporter 'import';

our @EXPORT = qw(sanitize_html);

# The sanitizing here is quite strict (it only removes new lines happening just
# before or after an HTML tag), so this forces our converter to match closely
# what the cmark spec has (I guess it’s not a bad thing).
# In addition, this light-weight normalization did uncover a couple of bugs that
# were hidden by the normalization done by the cmark tool.
sub  sanitize_html {
  my ($html) = @_;
  while ($html =~ m/<code>|(?<new_line>(?<=>)\n+(?=.)|\n+(?=<))/g) {
    if ($+{new_line}) {
      my $p = pos($html);
      substr $html, $-[0], $+[0] - $-[0], '';
      pos($html) = $p - length($+{new_line});
    } else {
      $html =~ m/<\/code>|$/g;
    }
  }
  $html =~ s/(<\/[a-z]+>)/$1\n/g;
  return $html;
}
