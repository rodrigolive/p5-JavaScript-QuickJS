#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 5;
use JavaScript::QuickJS;

my $js = JavaScript::QuickJS->new();

$js->set_globals(getLicense => sub {
    {
        license => {
            nodes => 100,
            expires => '2025-12-31'
        },
        status => 'active',
        message => 'OK'
    }
});

# The pattern from plugins/app/modules/api/index.ts
my $result = $js->eval(q{
    const license = getLicense();

    // Should be able to use delete instead of destructuring
    delete license['license'];

    license
});

ok(!exists $result->{license}, 'license property removed');
is($result->{status}, 'active', 'Other properties intact (status)');
is($result->{message}, 'OK', 'Other properties intact (message)');
is(scalar keys %$result, 2, 'Correct number of properties remain');

# Verify the old workaround still works too (for compatibility)
my $workaround = $js->eval(q{
    const license2 = getLicense();

    // Old workaround using destructuring
    const { license: _removed, ...result } = license2;

    result
});

ok(!exists $workaround->{license}, 'Destructuring workaround still works');
