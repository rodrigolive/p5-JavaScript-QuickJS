#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use JavaScript::QuickJS;

# Test 1: Arrow function source
{
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval('(x) => x * 2');

    isa_ok($func, 'JavaScript::QuickJS::Function', 'Got function object');

    my $source = $func->to_source();
    ok(defined $source, 'to_source returns defined value');
    ok(length($source) > 0, 'to_source returns non-empty string');

    # QuickJS preserves arrow function syntax
    like($source, qr/=>|function/, 'Source contains arrow or function syntax');
}

# Test 2: Named function source
{
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval('function myFunc(a, b) { return a + b; }; myFunc');

    my $source = $func->to_source();
    like($source, qr/myFunc/, 'Named function source includes name');
    like($source, qr/a.*b/, 'Source includes parameter names');
}

# Test 3: Function with complex body
{
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval(q{
        function calculate(n) {
            if (n <= 1) return 1;
            return n * calculate(n - 1);
        }
        calculate;
    });

    my $source = $func->to_source();
    like($source, qr/calculate/, 'Complex function source includes name');
    like($source, qr/if/, 'Source includes conditional logic');
}

# Test 4: Serialization and restoration
{
    my $js1 = JavaScript::QuickJS->new();
    my $original = $js1->eval('(x) => x * 2');

    my $source = $original->to_source();

    # Create new VM and restore function
    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->eval($source);

    isa_ok($restored, 'JavaScript::QuickJS::Function', 'Restored function is a Function');

    # Test that restored function works
    is($restored->(5), 10, 'Restored function executes correctly');
    is($restored->(10), 20, 'Restored function works with different input');
}

# Test 5: Built-in function source
{
    my $js = JavaScript::QuickJS->new();
    my $parse_int = $js->eval('parseInt');

    my $source = $parse_int->to_source();
    ok(defined $source, 'Built-in function has source');
    like($source, qr/function.*parseInt|native code/, 'Built-in source contains function or native indicator');
}

# Test 6: Anonymous function
{
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval('(function(x, y) { return x + y; })');

    my $source = $func->to_source();
    ok(defined $source, 'Anonymous function has source');
    like($source, qr/function/, 'Anonymous function source includes function keyword');
}

# Test 7: Function with closure
{
    my $js = JavaScript::QuickJS->new();
    my $func = $js->eval(q{
        (function() {
            let counter = 0;
            return function() { return ++counter; };
        })()
    });

    my $source = $func->to_source();
    ok(defined $source, 'Closure function has source');
    like($source, qr/function/, 'Closure source includes function keyword');
}

# Test 8: Multiple functions - ensure they can be serialized independently
{
    my $js = JavaScript::QuickJS->new();
    my $add = $js->eval('(a, b) => a + b');
    my $multiply = $js->eval('(a, b) => a * b');

    my $add_source = $add->to_source();
    my $multiply_source = $multiply->to_source();

    ok($add_source ne $multiply_source, 'Different functions have different sources');

    # Restore both in new VM
    my $js2 = JavaScript::QuickJS->new();
    my $add_restored = $js2->eval($add_source);
    my $multiply_restored = $js2->eval($multiply_source);

    is($add_restored->(3, 4), 7, 'Restored add function works');
    is($multiply_restored->(3, 4), 12, 'Restored multiply function works');
}

done_testing();
