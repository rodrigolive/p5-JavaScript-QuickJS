#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use JavaScript::QuickJS;
use JavaScript::QuickJS::Null;

# Test 1: Basic function serialization and deserialization
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => x * 2');

    my $bytecode = $func->to_bytecode();
    ok(defined $bytecode, 'to_bytecode() returns defined value');
    ok(length($bytecode) > 0, 'bytecode has non-zero length');
    ok(!utf8::is_utf8($bytecode), 'bytecode is a byte string, not utf8');

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    isa_ok($restored, 'JavaScript::QuickJS::Function', 'from_bytecode returns Function object');

    my $result = $restored->(5);
    is($result, 10, 'restored function works correctly');
}

# Test 2: Complex function with multiple parameters
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(a, b, c) => a + b * c');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    my $result = $restored->(2, 3, 4);
    is($result, 14, 'complex function with multiple params works');
}

# Test 3: Function with string operations
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(s) => s.toUpperCase() + "!!!"');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    my $result = $restored->('hello');
    is($result, 'HELLO!!!', 'string manipulation function works');
}

# Test 4: Function with object creation
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(name, age) => ({ name, age, greet: () => "Hi" })');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    my $result = $restored->('Alice', 30);
    is(ref($result), 'HASH', 'function returning object works');
    is($result->{name}, 'Alice', 'object has correct name');
    is($result->{age}, 30, 'object has correct age');
}

# Test 5: Function with array operations
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(arr) => arr.map(x => x * 2)');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    my $result = $restored->([1, 2, 3, 4]);
    is_deeply($result, [2, 4, 6, 8], 'array manipulation function works');
}

# Test 6: Bytecode survives context destruction
{
    my $bytecode;
    {
        my $js1 = JavaScript::QuickJS->new();
        my $func = $js1->eval('(x) => x * 3');
        $bytecode = $func->to_bytecode();
        # $js1 goes out of scope here
    }

    ok(defined $bytecode, 'bytecode survives original context destruction');

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);
    my $result = $restored->(7);
    is($result, 21, 'restored function works after original context destroyed');
}

# Test 7: Multiple serialization/deserialization cycles
{
    my $js1 = JavaScript::QuickJS->new();
    my $func1 = $js1->eval('(x) => x + 1');

    my $bytecode1 = $func1->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $func2 = $js2->from_bytecode($bytecode1);

    my $bytecode2 = $func2->to_bytecode();

    is($bytecode1, $bytecode2, 'bytecode is stable across serialization cycles');

    my $js3 = JavaScript::QuickJS->new();
    my $func3 = $js3->from_bytecode($bytecode2);

    is($func3->(10), 11, 'function works after multiple cycles');
}

# Test 8: Arrow function with no parameters
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('() => 42');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(), 42, 'parameterless function works');
}

# Test 9: Function with boolean return
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => x > 5');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    ok(!$restored->(3), 'boolean false works');
    ok($restored->(7), 'boolean true works');
}

# Test 10: Multi-line arrow function
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => { const doubled = x * 2; return doubled; }');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(6), 12, 'multi-line arrow function works');
}

# Test 11: compile() method
{
    my $js = JavaScript::QuickJS->new();
    my $compiled = $js->compile('(x) => x * 4');

    isa_ok($compiled, 'JavaScript::QuickJS::Function', 'compile() returns Function object');

    my $bytecode = $compiled->to_bytecode();
    ok(defined $bytecode, 'compiled function can be serialized');

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(3), 12, 'function from compile() works');
}

# Test 12: compile() with complex code (using arrow functions)
{
    my $js = JavaScript::QuickJS->new();
    my $compiled = $js->compile(q{
        (n) => {
            const factorial = (x) => x <= 1 ? 1 : x * factorial(x - 1);
            return factorial(n);
        }
    });

    my $bytecode = $compiled->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(5), 120, 'recursive function works');
}

# Test 13: Function with Math operations
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => Math.sqrt(x)');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(16), 4, 'Math.sqrt works');
    is($restored->(25), 5, 'Math operations preserved');
}

# Test 14: Function with JSON operations
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(obj) => JSON.stringify(obj)');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    my $result = $restored->({name => 'Test', value => 123});
    like($result, qr/"name":"Test"/, 'JSON.stringify works');
}

# Test 15: Function with null/undefined handling
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => x === null ? "null" : x === undefined ? "undefined" : "value"');

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(undef), 'undefined', 'undefined handling works');
    is($restored->(JavaScript::QuickJS::Null->new()), 'null', 'null handling works');
    is($restored->(42), 'value', 'regular value works');
}

# Test 16: Bytecode size is reasonable
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval('(x) => x * 2');

    my $bytecode = $func->to_bytecode();
    my $size = length($bytecode);

    ok($size > 20 && $size < 500, "bytecode size ($size bytes) is reasonable");
}

# Test 17: Different contexts don't interfere
{
    my $js1 = JavaScript::QuickJS->new();
    $js1->set_globals(multiplier => 2);
    my $func1 = $js1->eval('(x) => x * 2');

    my $js2 = JavaScript::QuickJS->new();
    $js2->set_globals(multiplier => 3);
    my $func2 = $js2->eval('(x) => x * 3');

    my $bytecode1 = $func1->to_bytecode();
    my $bytecode2 = $func2->to_bytecode();

    my $js3 = JavaScript::QuickJS->new();
    my $restored1 = $js3->from_bytecode($bytecode1);
    my $restored2 = $js3->from_bytecode($bytecode2);

    is($restored1->(5), 10, 'first function works independently');
    is($restored2->(5), 15, 'second function works independently');
}

# Test 18: Error handling - invalid bytecode
{
    my $js = JavaScript::QuickJS->new();

    throws_ok {
        $js->from_bytecode("invalid bytecode");
    } qr//, 'invalid bytecode throws error';
}

# Test 19: Error handling - empty bytecode
{
    my $js = JavaScript::QuickJS->new();

    throws_ok {
        $js->from_bytecode("");
    } qr//, 'empty bytecode throws error';
}

# Test 20: Function with try/catch
{
    my $js1 = JavaScript::QuickJS->new();
    my $func = $js1->eval(q{
        (x) => {
            try {
                return x.toString();
            } catch (e) {
                return "error";
            }
        }
    });

    my $bytecode = $func->to_bytecode();

    my $js2 = JavaScript::QuickJS->new();
    my $restored = $js2->from_bytecode($bytecode);

    is($restored->(123), '123', 'try/catch with valid input works');
}

done_testing();
