#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use JavaScript::QuickJS;

# Advanced test cases to investigate "[object Object]" stringification issue
# These cover edge cases that might not be tested in basic tests

my $js = JavaScript::QuickJS->new();

# Test 1: Object passed through intermediate JS function
{
    my $result;
    $js->set_globals(
        captureResult => sub { $result = shift; }
    );

    $js->eval(q{
        function intermediate(obj) {
            return obj;
        }
        var original = { test: "data" };
        var passed = intermediate(original);
        captureResult(passed);
    });

    isnt($result, '[object Object]', 'Object through intermediate function should not be stringified');
    is(ref($result), 'HASH', 'Object through intermediate function should be HASH ref');
    is($result->{test}, 'data', 'Object properties should be preserved');
}

# Test 2: Object as property of returned object (child access)
{
    my $result;
    $js->set_globals(
        getContainer => sub {
            return {
                child => { name => "child object" }
            };
        },
        captureChild => sub { $result = shift; }
    );

    $js->eval(q{
        var container = getContainer();
        captureChild(container.child);
    });

    isnt($result, '[object Object]', 'Child object should not be stringified');
    is(ref($result), 'HASH', 'Child should be HASH ref');
    is($result->{name}, 'child object', 'Child property should be accessible');
}

# Test 3: Object with methods/functions as properties
{
    my $result;
    $js->set_globals(
        captureWithMethod => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = {
            data: "value",
            method: function() { return this.data; }
        };
        captureWithMethod(obj);
    });

    # Should still get the data properties even if methods become Function objects
    is(ref($result), 'HASH', 'Object with methods should be HASH ref');
    is($result->{data}, 'value', 'Data property should be accessible');
}

# Test 4: Arguments object (array-like)
# Note: arguments object has non-enumerable properties which causes issues
SKIP: {
    skip "arguments object has non-enumerable length property", 1;

    my $result;
    $js->set_globals(
        captureArguments => sub { $result = shift; }
    );

    $js->eval(q{
        function passArguments() {
            captureArguments(arguments);
        }
        passArguments(1, 2, 3);
    });

    # arguments object should be converted to array-like
    ok(ref($result), 'Arguments object should be converted to ref');
    # Arguments is array-like so should become either HASH or ARRAY
}

# Test 5: Object created with Object.create(null) - no prototype
{
    my $result;
    $js->set_globals(
        captureNullProto => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = Object.create(null);
        obj.foo = "bar";
        captureNullProto(obj);
    });

    isnt($result, '[object Object]', 'Object with null prototype should not be stringified');
    is(ref($result), 'HASH', 'Object with null prototype should be HASH ref');
    is($result->{foo}, 'bar', 'Property should be accessible');
}

# Test 6: Console-like scenario with multiple objects
{
    my @logged;
    $js->set_globals(
        console => {
            log => sub { push @logged, @_; },
            error => sub { push @logged, @_; },
            warn => sub { push @logged, @_; },
        }
    );

    $js->eval(q{
        console.log({ msg: "test1" });
        console.error({ msg: "test2", code: 500 });
        console.warn({ msg: "test3" }, { msg: "test4" });
    });

    is(scalar(@logged), 4, 'Should receive 4 arguments total');

    for my $i (0..$#logged) {
        isnt($logged[$i], '[object Object]', "Logged item $i should not be stringified");
        is(ref($logged[$i]), 'HASH', "Logged item $i should be HASH ref");
    }
}

# Test 7: Object created and passed during initial eval (same eval call)
{
    my $result;
    $js->set_globals(
        captureImmediate => sub { $result = shift; }
    );

    $js->eval(q{
        captureImmediate({ immediate: true, nested: { deep: "value" } });
    });

    isnt($result, '[object Object]', 'Immediate object should not be stringified');
    is(ref($result), 'HASH', 'Immediate object should be HASH ref');
    is(ref($result->{nested}), 'HASH', 'Nested object should be HASH ref');
}

# Test 8: Object stored in variable, then passed later in separate eval
{
    my $result;
    $js->set_globals(
        captureLater => sub { $result = shift; }
    );

    $js->eval(q{
        var stored = { stored: "object" };
    });

    $js->eval(q{
        captureLater(stored);
    });

    isnt($result, '[object Object]', 'Stored object should not be stringified');
    is(ref($result), 'HASH', 'Stored object should be HASH ref');
    is($result->{stored}, 'object', 'Stored property should be accessible');
}

# Test 9: Object with numeric keys
{
    my $result;
    $js->set_globals(
        captureNumeric => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = {};
        obj[0] = "zero";
        obj[1] = "one";
        obj.name = "test";
        captureNumeric(obj);
    });

    isnt($result, '[object Object]', 'Object with numeric keys should not be stringified');
    is(ref($result), 'HASH', 'Object with numeric keys should be HASH ref');
}

# Test 10: Object with symbols (non-enumerable properties should be skipped)
{
    my $result;
    $js->set_globals(
        captureWithSymbol => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = { visible: "yes" };
        var sym = Symbol("hidden");
        obj[sym] = "should not see this";
        captureWithSymbol(obj);
    });

    isnt($result, '[object Object]', 'Object with symbol should not be stringified');
    is(ref($result), 'HASH', 'Object with symbol should be HASH ref');
    is($result->{visible}, 'yes', 'Visible property should be accessible');
}

# Test 11: Object with getter/setter
{
    my $result;
    $js->set_globals(
        captureWithGetter => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = {
            _value: 42,
            get value() { return this._value; },
            set value(v) { this._value = v; }
        };
        captureWithGetter(obj);
    });

    isnt($result, '[object Object]', 'Object with getter should not be stringified');
    is(ref($result), 'HASH', 'Object with getter should be HASH ref');
    is($result->{_value}, 42, 'Underlying value should be accessible');
    # Note: getter 'value' would be called and its return value stored
}

# Test 12: Proxy object
{
    my $result;
    $js->set_globals(
        captureProxy => sub { $result = shift; }
    );

    $js->eval(q{
        var target = { foo: "bar" };
        var handler = {};
        var proxy = new Proxy(target, handler);
        captureProxy(proxy);
    });

    isnt($result, '[object Object]', 'Proxy object should not be stringified');
    is(ref($result), 'HASH', 'Proxy object should be HASH ref');
    is($result->{foo}, 'bar', 'Proxy property should be accessible');
}

# Test 13: Object spread/assign
{
    my $result;
    $js->set_globals(
        captureSpread => sub { $result = shift; }
    );

    $js->eval(q{
        var a = { x: 1 };
        var b = { y: 2 };
        var c = { ...a, ...b, z: 3 };
        captureSpread(c);
    });

    isnt($result, '[object Object]', 'Spread object should not be stringified');
    is(ref($result), 'HASH', 'Spread object should be HASH ref');
    is($result->{x}, 1, 'Spread property x should be accessible');
    is($result->{y}, 2, 'Spread property y should be accessible');
    is($result->{z}, 3, 'Spread property z should be accessible');
}

# Test 14: Object returned from Promise (async context)
SKIP: {
    skip "async tests may need special handling", 3;

    my $result;
    $js->set_globals(
        captureAsync => sub { $result = shift; }
    );

    $js->eval(q{
        async function asyncFunc() {
            return { async: "data" };
        }
        asyncFunc().then(captureAsync);
    });

    # May need $js->await() or similar

    isnt($result, '[object Object]', 'Async result should not be stringified');
    is(ref($result), 'HASH', 'Async result should be HASH ref');
}

# Test 15: Object with non-enumerable properties added via defineProperty
{
    my $result;
    $js->set_globals(
        captureDefineProperty => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = { enumerable: "yes" };
        Object.defineProperty(obj, 'nonEnum', {
            value: "no",
            enumerable: false
        });
        captureDefineProperty(obj);
    });

    isnt($result, '[object Object]', 'Object with defineProperty should not be stringified');
    is(ref($result), 'HASH', 'Object with defineProperty should be HASH ref');
    is($result->{enumerable}, 'yes', 'Enumerable property should be accessible');
    # nonEnum should not be present due to JS_GPN_STRING_MASK
}

# Test 16: Object passed multiple times in same eval
{
    my @results;
    $js->set_globals(
        captureMultipleTimes => sub { push @results, shift; }
    );

    $js->eval(q{
        var obj = { key: "value" };
        captureMultipleTimes(obj);
        captureMultipleTimes(obj);
        captureMultipleTimes(obj);
    });

    is(scalar(@results), 3, 'Should capture object 3 times');
    for my $i (0..2) {
        isnt($results[$i], '[object Object]', "Capture $i should not be stringified");
        is(ref($results[$i]), 'HASH', "Capture $i should be HASH ref");
        is($results[$i]->{key}, 'value', "Capture $i property should be accessible");
    }
}

# Test 17: Large object with many properties
{
    my $result;
    $js->set_globals(
        captureLarge => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = {};
        for (var i = 0; i < 100; i++) {
            obj['key' + i] = i;
        }
        captureLarge(obj);
    });

    isnt($result, '[object Object]', 'Large object should not be stringified');
    is(ref($result), 'HASH', 'Large object should be HASH ref');
    is(scalar(keys %$result), 100, 'Large object should have 100 keys');
    is($result->{key0}, 0, 'First property should be accessible');
    is($result->{key99}, 99, 'Last property should be accessible');
}

# Test 18: Object passed as this value to callback
{
    my $this_value;
    $js->set_globals(
        captureThis => sub {
            # In Perl, 'this' context would need special handling
            # Just capture the argument for now
            $this_value = shift;
        }
    );

    $js->eval(q{
        var obj = { name: "context" };
        captureThis.call(obj, obj);
    });

    isnt($this_value, '[object Object]', 'Object as argument should not be stringified');
    is(ref($this_value), 'HASH', 'Object should be HASH ref');
}

# Test 19: Array of objects
{
    my $result;
    $js->set_globals(
        captureArrayOfObjects => sub { $result = shift; }
    );

    $js->eval(q{
        captureArrayOfObjects([{ a: 1 }, { b: 2 }, { c: 3 }]);
    });

    is(ref($result), 'ARRAY', 'Should receive array');
    is(scalar(@$result), 3, 'Array should have 3 elements');
    for my $i (0..2) {
        isnt($result->[$i], '[object Object]', "Array element $i should not be stringified");
        is(ref($result->[$i]), 'HASH', "Array element $i should be HASH ref");
    }
}

# Test 20: Deeply nested objects
{
    my $result;
    $js->set_globals(
        captureDeep => sub { $result = shift; }
    );

    $js->eval(q{
        var obj = {
            level1: {
                level2: {
                    level3: {
                        level4: {
                            level5: "deep"
                        }
                    }
                }
            }
        };
        captureDeep(obj);
    });

    isnt($result, '[object Object]', 'Deep object should not be stringified');
    is(ref($result), 'HASH', 'Deep object should be HASH ref');
    is($result->{level1}{level2}{level3}{level4}{level5}, 'deep', 'Deep property should be accessible');
}

done_testing();
