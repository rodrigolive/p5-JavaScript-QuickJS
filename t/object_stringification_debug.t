#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use JavaScript::QuickJS;

# Debug test to find the "[object Object]" stringification issue

my $js = JavaScript::QuickJS->new();

# Scenario 1: Object from Perl with nested objects, accessed in JS
{
    my $result;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        getPerlObject => sub {
            return {
                data => { nested => "value" },
                items => [1, 2, 3]
            };
        },
        processInJS => sub {
            my $obj = shift;
            $result = $obj;
        }
    );

    # Object goes Perl -> JS -> modified in JS -> back to Perl
    $js->eval(q{
        var obj = getPerlObject();
        obj.newProp = "added";
        obj.data.anotherNested = "also added";
        processInJS(obj);
    });

    # Verify it's not stringified
    isnt($result, '[object Object]', 'Round-trip object should not be stringified');
    is(ref($result), 'HASH', 'Should be HASH ref');
    is($result->{newProp}, 'added', 'Added property should exist');
    is($result->{data}{anotherNested}, 'also added', 'Nested added property should exist');
}

# Scenario 2: Try to trigger the issue with variadic console-like function
{
    my @captured;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        myConsole => {
            log => sub {
                for my $arg (@_) {
                    push @captured, $arg;
                }
            }
        }
    );

    $js->eval(q{
        myConsole.log("string", { obj: "data" }, [1, 2], 42);
    });

    is(scalar(@captured), 4, 'Should capture 4 arguments');
    is($captured[0], 'string', 'First arg should be string');
    isnt($captured[1], '[object Object]', 'Second arg should not be stringified');
    is(ref($captured[1]), 'HASH', 'Second arg should be HASH');
    is(ref($captured[2]), 'ARRAY', 'Third arg should be ARRAY');
    is($captured[3], 42, 'Fourth arg should be number');
}

# Scenario 3: Use JavaScript's own console API to see behavior
# This tests if the helpers or std modules affect things
{
    my @captured;
    my $js = JavaScript::QuickJS->new();

    # Create our own console replacement
    $js->set_globals(
        console => {
            log => sub { push @captured, @_; },
            warn => sub { push @captured, @_; },
            error => sub { push @captured, @_; },
        }
    );

    $js->eval(q{
        var testObj = { key: "value", nested: { deep: true } };
        console.log(testObj);
        console.error(testObj);
    });

    is(scalar(@captured), 2, 'Should capture 2 calls');
    for my $i (0, 1) {
        isnt($captured[$i], '[object Object]', "Capture $i should not be stringified");
        is(ref($captured[$i]), 'HASH', "Capture $i should be HASH ref");
        is($captured[$i]->{key}, 'value', "Capture $i key property should be accessible");
    }
}

# Scenario 4: Test with std module's console
{
    my @captured;
    my $js = JavaScript::QuickJS->new()->std();

    # Override std console with our own
    $js->set_globals(
        myCapture => sub {
            push @captured, @_;
        }
    );

    $js->eval(q{
        var obj = { test: "data" };
        myCapture(obj);
    });

    is(scalar(@captured), 1, 'Should capture 1 argument');
    isnt($captured[0], '[object Object]', 'With std module: should not be stringified');
    is(ref($captured[0]), 'HASH', 'With std module: should be HASH ref');
}

# Scenario 5: Test if the issue occurs with helpers module
{
    my @captured;
    my $js = JavaScript::QuickJS->new()->helpers();

    $js->set_globals(
        myCapture => sub {
            push @captured, @_;
        }
    );

    $js->eval(q{
        var obj = { test: "data" };
        myCapture(obj);
    });

    is(scalar(@captured), 1, 'Should capture 1 argument');
    isnt($captured[0], '[object Object]', 'With helpers: should not be stringified');
    is(ref($captured[0]), 'HASH', 'With helpers: should be HASH ref');
}

# Scenario 6: Object returned from async function / Promise
{
    my $result;
    my $js = JavaScript::QuickJS->new()->std()->os();

    $js->set_globals(
        capturePromise => sub {
            $result = shift;
        }
    );

    $js->eval(q{
        var promise = new Promise(function(resolve) {
            resolve({ promised: "data" });
        });
        promise.then(capturePromise);
    });

    # Need to await the promise
    $js->await();

    isnt($result, '[object Object]', 'Promise result should not be stringified');
    is(ref($result), 'HASH', 'Promise result should be HASH ref');
    is($result->{promised}, 'data', 'Promise property should be accessible');
}

# Scenario 7: Test with actual arguments object using Array.from
{
    my $result;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        captureArgs => sub {
            $result = shift;
        }
    );

    $js->eval(q{
        function test() {
            // Convert arguments to real array first
            captureArgs(Array.from(arguments));
        }
        test({a: 1}, {b: 2}, {c: 3});
    });

    is(ref($result), 'ARRAY', 'Should be ARRAY');
    is(scalar(@$result), 3, 'Should have 3 elements');
    for my $i (0..2) {
        isnt($result->[$i], '[object Object]', "Element $i should not be stringified");
        is(ref($result->[$i]), 'HASH', "Element $i should be HASH ref");
    }
}

# Scenario 8: Test with plugin-like initialization pattern
{
    my @errors;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        console => {
            error => sub {
                push @errors, @_;
            }
        },
        initPlugin => sub {
            return {
                name => "test-plugin",
                version => "1.0.0",
                config => { setting => "value" }
            };
        }
    );

    # Simulate plugin initialization
    $js->eval(q{
        var plugin = initPlugin();
        if (plugin.config) {
            console.error(plugin.config);
        }
    });

    is(scalar(@errors), 1, 'Should capture 1 error');
    isnt($errors[0], '[object Object]', 'Plugin config should not be stringified');
    is(ref($errors[0]), 'HASH', 'Plugin config should be HASH ref');
    is($errors[0]->{setting}, 'value', 'Config property should be accessible');
}

# Scenario 9: Test with eval inside the callback
{
    my $result;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        capture => sub {
            $result = shift;
        },
        getObject => sub {
            return { nested => { value => 42 } };
        }
    );

    $js->eval(q{
        var obj = getObject();
        var inner = obj.nested;
        capture(inner);
    });

    isnt($result, '[object Object]', 'Inner object should not be stringified');
    is(ref($result), 'HASH', 'Inner object should be HASH ref');
    is($result->{value}, 42, 'Inner property should be accessible');
}

# Scenario 10: Test string concatenation (this should stringify)
{
    my $result;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        capture => sub {
            $result = shift;
        }
    );

    $js->eval(q{
        var obj = { key: "value" };
        // This SHOULD be "[object Object]" because we explicitly stringify
        capture("Object: " + obj);
    });

    like($result, qr/\[object Object\]/, 'Concatenated string should contain [object Object]');
}

# Scenario 11: Test JSON.stringify doesn't affect objects
{
    my $result;
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        capture => sub {
            $result = shift;
        }
    );

    $js->eval(q{
        var obj = { key: "value" };
        capture(obj);  // Not stringified
    });

    isnt($result, '{"key":"value"}', 'Should not be JSON string');
    isnt($result, '[object Object]', 'Should not be toString');
    is(ref($result), 'HASH', 'Should be HASH ref');
}

done_testing();
