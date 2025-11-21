#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use JavaScript::QuickJS;

# Test: Objects passed to Perl callbacks should be hashrefs, not stringified

my $js = JavaScript::QuickJS->new();

# Test 1: Basic object passed to callback
{
    my $received;
    $js->set_globals(
        captureArg => sub {
            $received = shift;
        }
    );

    $js->eval('captureArg({ foo: "bar", num: 42 })');

    is(ref($received), 'HASH', 'Object should be received as HASH ref');
    is($received->{foo}, 'bar', 'Object property "foo" should be "bar"');
    is($received->{num}, 42, 'Object property "num" should be 42');
}

# Test 2: Nested object passed to callback
{
    my $received;
    $js->set_globals(
        captureNested => sub {
            $received = shift;
        }
    );

    $js->eval('captureNested({ outer: { inner: "value" } })');

    is(ref($received), 'HASH', 'Nested object should be HASH ref');
    is(ref($received->{outer}), 'HASH', 'Inner object should be HASH ref');
    is($received->{outer}{inner}, 'value', 'Nested property should be accessible');
}

# Test 3: Array passed to callback
{
    my $received;
    $js->set_globals(
        captureArray => sub {
            $received = shift;
        }
    );

    $js->eval('captureArray([1, 2, 3])');

    is(ref($received), 'ARRAY', 'Array should be received as ARRAY ref');
    is_deeply($received, [1, 2, 3], 'Array contents should match');
}

# Test 4: Object with array property
{
    my $received;
    $js->set_globals(
        captureMixed => sub {
            $received = shift;
        }
    );

    $js->eval('captureMixed({ items: [1, 2], name: "test" })');

    is(ref($received), 'HASH', 'Mixed object should be HASH ref');
    is(ref($received->{items}), 'ARRAY', 'Array property should be ARRAY ref');
    is_deeply($received->{items}, [1, 2], 'Array property contents should match');
    is($received->{name}, 'test', 'String property should match');
}

# Test 5: Multiple arguments to callback
{
    my @received;
    $js->set_globals(
        captureMultiple => sub {
            @received = @_;
        }
    );

    $js->eval('captureMultiple({ a: 1 }, { b: 2 }, "string")');

    is(scalar(@received), 3, 'Should receive 3 arguments');
    is(ref($received[0]), 'HASH', 'First arg should be HASH ref');
    is(ref($received[1]), 'HASH', 'Second arg should be HASH ref');
    is($received[2], 'string', 'Third arg should be string');
    is($received[0]->{a}, 1, 'First object property should match');
    is($received[1]->{b}, 2, 'Second object property should match');
}

# Test 6: Object returned from Perl, then passed back to Perl
# This tests the round-trip conversion
{
    my $final;
    $js->set_globals(
        getObject => sub {
            return { from_perl => "hello" };
        },
        receiveObject => sub {
            $final = shift;
        }
    );

    $js->eval('var obj = getObject(); receiveObject(obj)');

    is(ref($final), 'HASH', 'Round-trip object should be HASH ref');
    is($final->{from_perl}, 'hello', 'Round-trip object property should match');
}

# Test 7: Object returned from Perl, modified in JS, then passed back
{
    my $final;
    $js->set_globals(
        getObject2 => sub {
            return { original => "value" };
        },
        receiveObject2 => sub {
            $final = shift;
        }
    );

    $js->eval('var obj = getObject2(); obj.added = "new"; receiveObject2(obj)');

    is(ref($final), 'HASH', 'Modified round-trip object should be HASH ref');
    is($final->{original}, 'value', 'Original property should exist');
    is($final->{added}, 'new', 'Added property should exist');
}

# Test 8: Verify object is NOT stringified as "[object Object]"
{
    my $received;
    $js->set_globals(
        checkNotStringified => sub {
            $received = shift;
        }
    );

    $js->eval('checkNotStringified({ test: "data" })');

    isnt($received, '[object Object]', 'Object should NOT be stringified to "[object Object]"');
    is(ref($received), 'HASH', 'Object should be HASH ref');
}

# Test 9: Console-like scenario with object argument
{
    my @logged;
    $js->set_globals(
        mockConsoleLog => sub {
            push @logged, @_;
        }
    );

    $js->eval('mockConsoleLog({ message: "test", code: 123 })');

    is(scalar(@logged), 1, 'Should receive 1 argument');
    is(ref($logged[0]), 'HASH', 'Logged object should be HASH ref');
    isnt($logged[0], '[object Object]', 'Logged object should NOT be "[object Object]" string');
}

# Test 10: Object with special values (null, undefined, boolean)
{
    my $received;
    $js->set_globals(
        captureSpecial => sub {
            $received = shift;
        }
    );

    $js->eval('captureSpecial({ nullVal: null, boolTrue: true, boolFalse: false })');

    is(ref($received), 'HASH', 'Object with special values should be HASH ref');
    ok(!defined($received->{nullVal}), 'null should be undef');
    # Note: boolean handling may vary
}

# Test 11: Empty object
{
    my $received;
    $js->set_globals(
        captureEmpty => sub {
            $received = shift;
        }
    );

    $js->eval('captureEmpty({})');

    is(ref($received), 'HASH', 'Empty object should be HASH ref');
    is(scalar(keys %$received), 0, 'Empty object should have no keys');
}

# Test 12: Object created via Object.create or class
{
    my $received;
    $js->set_globals(
        captureCreated => sub {
            $received = shift;
        }
    );

    $js->eval('
        function MyClass() {
            this.prop = "value";
        }
        captureCreated(new MyClass())
    ');

    is(ref($received), 'HASH', 'Class instance should be HASH ref');
    is($received->{prop}, 'value', 'Instance property should be accessible');
}

done_testing();
