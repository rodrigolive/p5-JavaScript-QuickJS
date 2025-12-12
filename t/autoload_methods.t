#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use JavaScript::QuickJS;

# Test AUTOLOAD for Function classes
# This allows $func->property() to access function properties
# and $func->method() to call methods with 'this' binding

my $js = JavaScript::QuickJS->new();

# Test 4: Function with properties (functions can have properties in JS)
{
    my $func = $js->eval('Object.assign(() => 42, { meta: "info", getMeta() { return this.meta; } })');

    # Function call via overload
    my $result = $func->();
    is($result, 42, 'Function call via overload should work');

    # Property access via AUTOLOAD
    my $meta = $func->meta();
    is($meta, 'info', 'Function property access via AUTOLOAD should work');

    # Method call via AUTOLOAD
    my $meta2 = $func->getMeta();
    is($meta2, 'info', 'Function method call via AUTOLOAD should work');
}

# Test 5: get_property method on Function (used internally by AUTOLOAD)
{
    my $func = $js->eval('Object.assign(() => 99, { x: 123, y: 456 })');

    my $x = $func->get_property('x');
    is($x, 123, 'get_property should return property value from function');

    my $y = $func->get_property('y');
    is($y, 456, 'get_property should work for multiple properties');
}

# Test 6: AUTOLOAD doesn't intercept existing methods
{
    my $func = $js->eval('(x) => x * 2');

    # These are real methods, not AUTOLOAD
    my $name = $func->name();
    # Anonymous functions may have empty name
    ok(defined($name), 'name() method should work (not via AUTOLOAD)');

    my $length = $func->length();
    is($length, 1, 'length() method should work (not via AUTOLOAD)');

    # call() is a real method
    my $result = $func->call(undef, 5);
    is($result, 10, 'call() method should work (not via AUTOLOAD)');
}

# Test 7: AUTOLOAD with undefined properties on Function
{
    my $func = $js->eval('() => 42');

    my $undef = $func->nonexistent();
    ok(!defined($undef), 'AUTOLOAD for undefined property should return undef');
}

done_testing();
