#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 10;
use JavaScript::QuickJS;

my $js = JavaScript::QuickJS->new();

$js->set_globals(perl_obj => sub { { deletable => 'yes' } });

# Test configurable flag
my $descriptor = $js->eval(q{
    const obj = perl_obj();
    const desc = Object.getOwnPropertyDescriptor(obj, 'deletable');
    desc
});

is($descriptor->{configurable}, 1, 'Property is configurable');
is($descriptor->{writable}, 1, 'Property is writable');
is($descriptor->{enumerable}, 1, 'Property is enumerable');

# Test Object.defineProperty reconfiguration
my $reconfig = $js->eval(q{
    const obj2 = perl_obj();
    Object.defineProperty(obj2, 'deletable', {
        value: 'changed',
        configurable: true,
        writable: false
    });
    delete obj2.deletable;
    'deletable' in obj2
});

is($reconfig, '', 'Can delete reconfigured property');

# Test that we can make a property non-configurable
my $non_configurable = $js->eval(q{
    const obj3 = perl_obj();
    Object.defineProperty(obj3, 'deletable', {
        configurable: false,
        writable: true,
        enumerable: true
    });
    const desc2 = Object.getOwnPropertyDescriptor(obj3, 'deletable');
    [desc2.configurable, desc2.writable, desc2.enumerable]
});

is($non_configurable->[0], '', 'Can make property non-configurable');
is($non_configurable->[1], 1, 'Property remains writable');
is($non_configurable->[2], 1, 'Property remains enumerable');

# Test that non-configurable property cannot be deleted
# Note: QuickJS runs in strict mode by default, so this will throw
eval {
    $js->eval(q{
        const obj4 = perl_obj();
        Object.defineProperty(obj4, 'deletable', { configurable: false });
        const deleteSuccess = delete obj4.deletable;
        [deleteSuccess, 'deletable' in obj4]
    });
};

like($@, qr/TypeError|could not delete/i, 'Throws when attempting to delete non-configurable property');

# Test that the property is still there after failed delete attempt
my $still_there = $js->eval(q{
    const obj4b = perl_obj();
    Object.defineProperty(obj4b, 'deletable', { configurable: false });
    try {
        delete obj4b.deletable;
    } catch(e) {
        // Expected error
    }
    'deletable' in obj4b
});

is($still_there, 1, 'Non-configurable property remains after failed delete attempt');

# Test property descriptor after deletion
my $desc_after_delete = $js->eval(q{
    const obj5 = perl_obj();
    delete obj5.deletable;
    const desc3 = Object.getOwnPropertyDescriptor(obj5, 'deletable');
    desc3
});

is($desc_after_delete, undef, 'Property descriptor is undefined after deletion');
