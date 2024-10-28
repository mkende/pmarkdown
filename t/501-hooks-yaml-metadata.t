use strict;
use warnings;
use utf8;

use Markdown::Perl 'convert', 'set_hooks';
use Test2::V0;

my $p = Markdown::Perl->new();
my $page = <<EOF;
---
name: Mark is down
draft: false
number: 42
---
# Mark is down!

I repeat: "Mark is down!"
EOF

my $invalid_page = <<EOF;
---
name: Mark is down
  draft: false
	number: 42
---
# Mark is down!

I repeat: "Mark is down!"
EOF

# Test 1: Check if we can get a string value
{
  sub hook_is_name_mark {
    my $x = shift;
    ok(exists($x->[0]->{name}) && $x->[0]->{name} eq 'Mark is down', "key 'name' was retrieved and validated as being 'Mark is down'");
  }
  $p->set_hooks(yaml_metadata => \&hook_is_name_mark);
  $p->convert($page);
}

# Test 2: Validate that hook is not called if yaml is invalid
{
  my $hook_called = 0;
  sub hook_called {
    $hook_called = 1;
  }
  $p->set_hooks(yaml_metadata => \&hook_called);
  ok(!$hook_called, "Hook was not called because metadata was invalid.");
  $p->convert($invalid_page);
}

done_testing;
