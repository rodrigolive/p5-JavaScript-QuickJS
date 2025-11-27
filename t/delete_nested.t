#!/usr/bin/env perl

use strict;
use warnings;
use Test::More tests => 8;
use JavaScript::QuickJS;

my $js = JavaScript::QuickJS->new();

# Nested Perl objects
$js->set_globals(nested => sub {
    {
        user => { name => 'Alice', age => 30 },
        settings => { theme => 'dark', lang => 'en' }
    }
});

my $nested_delete = $js->eval(q{
    const obj = nested();
    delete obj.user.age;
    delete obj.settings.theme;
    [
        'age' in obj.user,
        'theme' in obj.settings,
        Object.keys(obj.user).sort(),
        Object.keys(obj.settings).sort()
    ]
});

is($nested_delete->[0], '', 'Nested property deleted (user.age)');
is($nested_delete->[1], '', 'Nested property deleted (settings.theme)');
is_deeply($nested_delete->[2], ['name'], 'Nested keys correct (user)');
is_deeply($nested_delete->[3], ['lang'], 'Nested keys correct (settings)');

# Test deleting top-level property with nested structure
my $delete_nested_obj = $js->eval(q{
    const obj2 = nested();
    delete obj2.user;
    ['user' in obj2, 'settings' in obj2]
});

is($delete_nested_obj->[0], '', 'Top-level nested object deleted');
is($delete_nested_obj->[1], 1, 'Other top-level property remains');

# Test deeply nested deletion
$js->set_globals(deep => sub {
    {
        level1 => {
            level2 => {
                level3 => {
                    value => 'deep'
                }
            }
        }
    }
});

my $deep_delete = $js->eval(q{
    const obj3 = deep();
    delete obj3.level1.level2.level3.value;
    [
        'value' in obj3.level1.level2.level3,
        Object.keys(obj3.level1.level2.level3)
    ]
});

is($deep_delete->[0], '', 'Deeply nested property deleted');
is_deeply($deep_delete->[1], [], 'Deeply nested object is empty after delete');
