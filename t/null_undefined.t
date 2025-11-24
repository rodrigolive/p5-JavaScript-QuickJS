#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use_ok('JavaScript::QuickJS');

# Test 1: Perl undef becomes JavaScript undefined
subtest 'Perl undef -> JS undefined' => sub {
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        get_undef => sub { return undef; }
    );

    my $type = $js->eval('typeof get_undef()');
    is($type, 'undefined', 'Perl undef becomes JS undefined');

    my $is_undefined = $js->eval('get_undef() === undefined');
    ok($is_undefined, 'Value is strictly equal to undefined');

    my $is_not_null = $js->eval('get_undef() !== null');
    ok($is_not_null, 'Value is NOT null');
};

# Test 2: JavaScript undefined becomes Perl undef (default mode)
subtest 'JS undefined -> Perl undef (default)' => sub {
    my $js = JavaScript::QuickJS->new();

    my $result = $js->eval('undefined');
    ok(!defined($result), 'JS undefined becomes Perl undef');
    is(ref($result), '', 'Result is not blessed');
};

# Test 3: JavaScript null becomes Perl undef (default mode)
subtest 'JS null -> Perl undef (default)' => sub {
    my $js = JavaScript::QuickJS->new();

    my $result = $js->eval('null');
    ok(!defined($result), 'JS null becomes Perl undef');
    is(ref($result), '', 'Result is not blessed');
};

# Test 4: With preserve_types, can distinguish null from undefined
SKIP: {
    skip 'preserve_types support required', 6 unless eval {
        my $js = JavaScript::QuickJS->new(preserve_types => 1);
        my $test = $js->eval('null');
        ref($test) eq 'JavaScript::QuickJS::Null';
    };

    subtest 'JS null -> Perl Null object (preserve_types)' => sub {
        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        my $null = $js->eval('null');
        isa_ok($null, 'JavaScript::QuickJS::Null');
        ok(!$null, 'Null object is falsy');
    };

    subtest 'JS undefined -> Perl Undefined object (preserve_types)' => sub {
        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        my $undef = $js->eval('undefined');
        isa_ok($undef, 'JavaScript::QuickJS::Undefined');
        ok(!$undef, 'Undefined object is falsy');
    };

    subtest 'Can distinguish null from undefined' => sub {
        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        my $null = $js->eval('null');
        my $undef = $js->eval('undefined');

        isnt(ref($null), ref($undef),
             'Null and Undefined have different types');
        is(ref($null), 'JavaScript::QuickJS::Null',
           'null is Null class');
        is(ref($undef), 'JavaScript::QuickJS::Undefined',
           'undefined is Undefined class');
    };

    subtest 'Null object round-trips to JS null' => sub {
        eval { require JavaScript::QuickJS::Null; 1; } or
            skip 'JavaScript::QuickJS::Null not available', 3;

        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        my $perl_null = JavaScript::QuickJS::Null->new();
        $js->set_globals(my_null => $perl_null);

        my $is_null = $js->eval('my_null === null');
        ok($is_null, 'Perl Null object becomes JS null');

        my $type = $js->eval('typeof my_null');
        is($type, 'object', 'typeof null is "object" (JS behavior)');

        my $not_undefined = $js->eval('my_null !== undefined');
        ok($not_undefined, 'Value is NOT undefined');
    };

    subtest 'Undefined object round-trips to JS undefined' => sub {
        eval { require JavaScript::QuickJS::Undefined; 1; } or
            skip 'JavaScript::QuickJS::Undefined not available', 3;

        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        my $perl_undef = JavaScript::QuickJS::Undefined->new();
        $js->set_globals(my_undef => $perl_undef);

        my $is_undefined = $js->eval('my_undef === undefined');
        ok($is_undefined, 'Perl Undefined object becomes JS undefined');

        my $type = $js->eval('typeof my_undef');
        is($type, 'undefined', 'typeof undefined is "undefined"');

        my $not_null = $js->eval('my_undef !== null');
        ok($not_null, 'Value is NOT null');
    };

    subtest 'Plain undef still becomes undefined (not Null)' => sub {
        my $js = JavaScript::QuickJS->new(preserve_types => 1);

        $js->set_globals(plain_undef => undef);

        my $is_undefined = $js->eval('plain_undef === undefined');
        ok($is_undefined, 'Plain Perl undef becomes JS undefined');

        my $not_null = $js->eval('plain_undef !== null');
        ok($not_null, 'Plain undef is NOT null');
    };
}

# Test 5: JSON serialization behavior
subtest 'JSON serialization' => sub {
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        get_undefined => sub { return undef; }
    );

    # undefined properties are omitted from JSON
    my $json1 = $js->eval(q{
        JSON.stringify({ a: 1, b: get_undefined(), c: 3 })
    });
    is($json1, '{"a":1,"c":3}',
       'undefined properties omitted from JSON');

    # null properties are included
    SKIP: {
        skip 'Null object support required', 1 unless eval {
            require JavaScript::QuickJS::Null; 1;
        };

        my $js2 = JavaScript::QuickJS->new();
        $js2->set_globals(
            my_null => JavaScript::QuickJS::Null->new()
        );

        my $json2 = $js2->eval(q{
            JSON.stringify({ a: 1, b: my_null, c: 3 })
        });
        is($json2, '{"a":1,"b":null,"c":3}',
           'null properties included in JSON');
    }
};

# Test 6: Function parameters
subtest 'Function parameters' => sub {
    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        test_params => sub {
            my ($a, $b, $c) = @_;
            return {
                a_defined => defined($a),
                b_defined => defined($b),
                c_defined => defined($c),
            };
        }
    );

    my $result = $js->eval(q{
        test_params(1, undefined, 3)
    });

    ok($result->{a_defined}, 'First parameter is defined');
    ok(!$result->{b_defined}, 'Second parameter (undefined) is not defined');
    ok($result->{c_defined}, 'Third parameter is defined');
};

# Test 7: Object properties with null and undefined
subtest 'Object properties with null and undefined' => sub {
    my $js = JavaScript::QuickJS->new(preserve_types => 1);

    my $obj = $js->eval(q{
        ({
            explicit_null: null,
            explicit_undefined: undefined,
            number: 42
        })
    });

    SKIP: {
        skip 'preserve_types support required', 2 unless
            ref($obj->{explicit_null}) eq 'JavaScript::QuickJS::Null';

        isa_ok($obj->{explicit_null}, 'JavaScript::QuickJS::Null',
               'null property');
        isa_ok($obj->{explicit_undefined}, 'JavaScript::QuickJS::Undefined',
               'undefined property');
    }
};

done_testing;
