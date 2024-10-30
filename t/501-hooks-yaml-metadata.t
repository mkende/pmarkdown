use strict;
use warnings;
use utf8;

use Markdown::Perl 'convert', 'set_hooks';
use Test::More;
use Test2::Tools::Warnings;
use Test2::Tools::Exception;

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
    ok(exists($x->{name}) && $x->{name} eq 'Mark is down', "key 'name' was retrieved and validated as being 'Mark is down'");
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

# Test 3: Validate that invalid yaml causes a carp()
{
  sub hook {
  }
  $p->set_hooks(yaml_metadata => \&hook);
  like(warning { $p->convert($invalid_page) }, qr/invalid/, "Got expected warning");
}

# Test 4: What happens if inside the hook we die()
{
  sub hook_die {
    die "last words";
  }
  $p->set_hooks(yaml_metadata => \&hook_die);
  like( dies { $p->convert($page) }, qr/last words/, "The hook correctly died.");
}

done_testing;
