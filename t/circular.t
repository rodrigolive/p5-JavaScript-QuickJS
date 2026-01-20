#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use JavaScript::QuickJS;

# Test circular reference detection and handling

my $js = JavaScript::QuickJS->new();

# Test 1: Simple self-reference
{
    my $ret = $js->eval(q{
        var obj = {name: 'test', value: 42};
        obj.self = obj;
        obj;
    });

    ok(defined($ret), 'Simple self-reference returns defined value');
    isa_ok($ret, 'HASH', 'Result is a hash reference');
    is($ret->{name}, 'test', 'Object has correct name property');
    is($ret->{value}, 42, 'Object has correct value property');
    is($ret->{self}, $ret, 'Circular reference preserved (obj.self === obj)');
}

# Test 2: globalThis doesn't hang
{
    my $global;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm 5;  # 5 second timeout
        $global = $js->eval('globalThis');
        alarm 0;
    };

    ok(!$@, 'globalThis returns without hanging');
    ok(defined($global), 'globalThis returns a defined value');
}

# Test 3: Nested circular reference
{
    my $nested = $js->eval(q{
        var a = {name: 'a', b: {name: 'b'}};
        a.b.a = a;
        a;
    });

    ok(defined($nested), 'Nested circular reference returns defined value');
    isa_ok($nested, 'HASH', 'Result is a hash reference');
    is($nested->{name}, 'a', 'Top level object has correct name');
    isa_ok($nested->{b}, 'HASH', 'Nested object is a hash reference');
    is($nested->{b}{name}, 'b', 'Nested object has correct name');
    is($nested->{b}{a}, $nested, 'Nested circular reference preserved (a.b.a === a)');
}

# Test 4: Array with circular reference
{
    my $arr = $js->eval(q{
        var arr = [1, 2, 3];
        arr.push(arr);
        arr;
    });

    ok(defined($arr), 'Array with circular reference returns defined value');
    isa_ok($arr, 'ARRAY', 'Result is an array reference');
    is($arr->[0], 1, 'Array element 0 is correct');
    is($arr->[1], 2, 'Array element 1 is correct');
    is($arr->[2], 3, 'Array element 2 is correct');
    is($arr->[3], $arr, 'Array circular reference preserved (arr[3] === arr)');
}

# Test 5: Circular chain (a.b = b; b.a = a)
{
    my $chain = $js->eval(q{
        var a = {name: 'a'};
        var b = {name: 'b'};
        a.b = b;
        b.a = a;
        a;
    });

    ok(defined($chain), 'Circular chain returns defined value');
    isa_ok($chain, 'HASH', 'Result is a hash reference');
    is($chain->{name}, 'a', 'First object has correct name');
    isa_ok($chain->{b}, 'HASH', 'Second object is a hash reference');
    is($chain->{b}{name}, 'b', 'Second object has correct name');
    is($chain->{b}{a}, $chain, 'Circular chain preserved (a.b.a === a)');
}

# Test 6: Mixed object/array cycles
{
    my $mixed = $js->eval(q{
        var obj = {name: 'parent', children: []};
        obj.children.push(obj);
        obj;
    });

    ok(defined($mixed), 'Mixed object/array cycle returns defined value');
    isa_ok($mixed, 'HASH', 'Result is a hash reference');
    is($mixed->{name}, 'parent', 'Object has correct name');
    isa_ok($mixed->{children}, 'ARRAY', 'children is an array reference');
    is($mixed->{children}[0], $mixed, 'Mixed cycle preserved (obj.children[0] === obj)');
}

# Test 7: Deep nesting with cycles
{
    my $deep = $js->eval(q{
        var root = {level: 0};
        root.child = {level: 1, parent: root};
        root.child.child = {level: 2, parent: root.child, root: root};
        root;
    });

    ok(defined($deep), 'Deep nesting with cycles returns defined value');
    isa_ok($deep, 'HASH', 'Result is a hash reference');
    is($deep->{level}, 0, 'Root has correct level');
    is($deep->{child}{level}, 1, 'First child has correct level');
    is($deep->{child}{parent}, $deep, 'First child parent reference is correct');
    is($deep->{child}{child}{level}, 2, 'Second child has correct level');
    is($deep->{child}{child}{parent}, $deep->{child}, 'Second child parent reference is correct');
    is($deep->{child}{child}{root}, $deep, 'Second child root reference is correct');
}

# Test 8: Array containing itself directly
{
    my $self_arr = $js->eval(q{
        var arr = [];
        arr[0] = arr;
        arr;
    });

    ok(defined($self_arr), 'Array containing itself returns defined value');
    isa_ok($self_arr, 'ARRAY', 'Result is an array reference');
    is($self_arr->[0], $self_arr, 'Array self-reference preserved (arr[0] === arr)');
}

# Test 9: Multiple circular references in same object
{
    my $multi = $js->eval(q{
        var obj = {name: 'root'};
        obj.ref1 = obj;
        obj.ref2 = obj;
        obj.nested = {back: obj};
        obj;
    });

    ok(defined($multi), 'Multiple circular references return defined value');
    isa_ok($multi, 'HASH', 'Result is a hash reference');
    is($multi->{ref1}, $multi, 'First circular reference preserved');
    is($multi->{ref2}, $multi, 'Second circular reference preserved');
    is($multi->{nested}{back}, $multi, 'Nested circular reference preserved');
}

# Test 10: Verify non-circular objects still work
{
    my $normal = $js->eval(q{
        var obj = {
            name: 'normal',
            nested: {
                value: 123,
                array: [1, 2, 3]
            }
        };
        obj;
    });

    ok(defined($normal), 'Non-circular object returns defined value');
    isa_ok($normal, 'HASH', 'Result is a hash reference');
    is($normal->{name}, 'normal', 'Normal object has correct name');
    is($normal->{nested}{value}, 123, 'Nested value is correct');
    isa_ok($normal->{nested}{array}, 'ARRAY', 'Nested array is correct type');
    is_deeply($normal->{nested}{array}, [1, 2, 3], 'Nested array has correct values');
}

done_testing();
