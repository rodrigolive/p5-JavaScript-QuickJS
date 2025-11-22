#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Check if module loads
use_ok('JavaScript::QuickJS');

# Test with preserve_types disabled (default behavior)
subtest 'Default behavior (preserve_types disabled)' => sub {
    my $js = JavaScript::QuickJS->new();

    # Test true
    my $true = $js->eval('true');
    ok(defined $true, 'true is defined');
    is(ref($true), '', 'true is not blessed');
    is($true, 1, 'true equals 1');

    # Test false
    my $false = $js->eval('false');
    ok(defined $false, 'false is defined');
    is(ref($false), '', 'false is not blessed');
    # Note: false might be 0 or '', implementation dependent
    ok(!$false, 'false is falsy');

    # Test null
    my $null = $js->eval('null');
    ok(!defined $null, 'null is undefined in Perl');

    # Test undefined
    my $undef = $js->eval('undefined');
    ok(!defined $undef, 'undefined is undefined in Perl');

    # Test we can't distinguish null from undefined
    # This is expected behavior in compatibility mode
    ok(!defined $null && !defined $undef,
       'null and undefined both undefined (as expected)');
};

# Test with preserve_types enabled
subtest 'Type preservation enabled' => sub {
    plan skip_all => 'Boolean class not available'
        unless eval { require JavaScript::QuickJS::Boolean; 1 };
    plan skip_all => 'Null class not available'
        unless eval { require JavaScript::QuickJS::Null; 1 };
    plan skip_all => 'Undefined class not available'
        unless eval { require JavaScript::QuickJS::Undefined; 1 };

    my $js = JavaScript::QuickJS->new(preserve_types => 1);

    # Test true
    my $true = $js->eval('true');
    isa_ok($true, 'JavaScript::QuickJS::Boolean', 'true');
    ok($true->{value}, 'true has truthy value');
    is("$true", 'true', 'true stringifies to "true"');
    is(0 + $true, 1, 'true numifies to 1');
    ok($true, 'true is truthy in boolean context');

    # Test false
    my $false = $js->eval('false');
    isa_ok($false, 'JavaScript::QuickJS::Boolean', 'false');
    ok(!$false->{value}, 'false has falsy value');
    is("$false", 'false', 'false stringifies to "false"');
    is(0 + $false, 0, 'false numifies to 0');
    ok(!$false, 'false is falsy in boolean context');

    # Test null
    my $null = $js->eval('null');
    isa_ok($null, 'JavaScript::QuickJS::Null', 'null');
    ok(!$null, 'null is falsy');
    is("$null", '', 'null stringifies to empty string');
    is(0 + $null, 0, 'null numifies to 0');

    # Test undefined
    my $undef = $js->eval('undefined');
    isa_ok($undef, 'JavaScript::QuickJS::Undefined', 'undefined');
    ok(!$undef, 'undefined is falsy');
    is("$undef", '', 'undefined stringifies to empty string');
    is(0 + $undef, 0, 'undefined numifies to 0');

    # Test we CAN distinguish null from undefined
    isnt(ref($null), ref($undef),
         'null and undefined have different types');
    is(ref($null), 'JavaScript::QuickJS::Null',
       'null is Null class');
    is(ref($undef), 'JavaScript::QuickJS::Undefined',
       'undefined is Undefined class');
};

# Test type preservation in objects
subtest 'Types in objects' => sub {
    plan skip_all => 'Requires type preservation support'
        unless eval {
            my $js = JavaScript::QuickJS->new(preserve_types => 1);
            my $test = $js->eval('true');
            ref($test) eq 'JavaScript::QuickJS::Boolean';
        };

    my $js = JavaScript::QuickJS->new(preserve_types => 1);

    my $obj = $js->eval(q{
        ({
            bool_true: true,
            bool_false: false,
            null_val: null,
            undef_val: undefined,
            number: 42,
            string: "hello"
        })
    });

    isa_ok($obj->{bool_true}, 'JavaScript::QuickJS::Boolean',
           'object property true');
    isa_ok($obj->{bool_false}, 'JavaScript::QuickJS::Boolean',
           'object property false');
    isa_ok($obj->{null_val}, 'JavaScript::QuickJS::Null',
           'object property null');
    isa_ok($obj->{undef_val}, 'JavaScript::QuickJS::Undefined',
           'object property undefined');

    is($obj->{number}, 42, 'number unchanged');
    is($obj->{string}, "hello", 'string unchanged');
};

# Test type preservation in arrays
subtest 'Types in arrays' => sub {
    plan skip_all => 'Requires type preservation support'
        unless eval {
            my $js = JavaScript::QuickJS->new(preserve_types => 1);
            my $test = $js->eval('true');
            ref($test) eq 'JavaScript::QuickJS::Boolean';
        };

    my $js = JavaScript::QuickJS->new(preserve_types => 1);

    my $arr = $js->eval('[true, false, null, undefined, 42, "hi"]');

    isa_ok($arr->[0], 'JavaScript::QuickJS::Boolean', 'array[0] true');
    isa_ok($arr->[1], 'JavaScript::QuickJS::Boolean', 'array[1] false');
    isa_ok($arr->[2], 'JavaScript::QuickJS::Null', 'array[2] null');
    isa_ok($arr->[3], 'JavaScript::QuickJS::Undefined', 'array[3] undefined');
    is($arr->[4], 42, 'array[4] number');
    is($arr->[5], "hi", 'array[5] string');
};

# Test Boolean class directly
subtest 'Boolean class' => sub {
    plan skip_all => 'Boolean class not available'
        unless eval { require JavaScript::QuickJS::Boolean; 1 };

    # Test constructors
    my $true = JavaScript::QuickJS::Boolean->true();
    my $false = JavaScript::QuickJS::Boolean->false();

    ok($true->{value}, 'true() creates true');
    ok(!$false->{value}, 'false() creates false');

    # Test new()
    my $t = JavaScript::QuickJS::Boolean->new(1);
    my $f = JavaScript::QuickJS::Boolean->new(0);

    ok($t->{value}, 'new(1) creates true');
    ok(!$f->{value}, 'new(0) creates false');

    # Test overloads
    is("$true", "true", 'true stringifies');
    is("$false", "false", 'false stringifies');
    is(0 + $true, 1, 'true numifies to 1');
    is(0 + $false, 0, 'false numifies to 0');

    # Test TO_JSON
    can_ok($true, 'TO_JSON');
    my $tj = $true->TO_JSON();
    my $fj = $false->TO_JSON();
    is(ref($tj), 'SCALAR', 'TO_JSON returns scalar ref');
    is($$tj, 1, 'true TO_JSON is \1');
    is($$fj, 0, 'false TO_JSON is \0');
};

# Test Null class directly
subtest 'Null class' => sub {
    plan skip_all => 'Null class not available'
        unless eval { require JavaScript::QuickJS::Null; 1 };

    my $null = JavaScript::QuickJS::Null->new();

    ok(!$null, 'null is falsy');
    is("$null", '', 'null stringifies to empty');
    is(0 + $null, 0, 'null numifies to 0');

    can_ok($null, 'TO_JSON');
    my $json = $null->TO_JSON();
    ok(!defined $json, 'TO_JSON returns undef');
};

# Test Undefined class directly
subtest 'Undefined class' => sub {
    plan skip_all => 'Undefined class not available'
        unless eval { require JavaScript::QuickJS::Undefined; 1 };

    my $undef = JavaScript::QuickJS::Undefined->new();

    ok(!$undef, 'undefined is falsy');
    is("$undef", '', 'undefined stringifies to empty');
    is(0 + $undef, 0, 'undefined numifies to 0');

    can_ok($undef, 'TO_JSON');
    my $json = $undef->TO_JSON();
    ok(!defined $json, 'TO_JSON returns undef');
};

done_testing;
