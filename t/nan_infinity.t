#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use JavaScript::QuickJS;

# Test that NaN, Infinity, and -Infinity are converted to undef

my $js = JavaScript::QuickJS->new();

# Test NaN
my $nan = $js->eval('NaN');
is($nan, undef, 'NaN converts to undef');

# Test Infinity
my $inf = $js->eval('Infinity');
is($inf, undef, 'Infinity converts to undef');

# Test -Infinity
my $neg_inf = $js->eval('-Infinity');
is($neg_inf, undef, '-Infinity converts to undef');

# Test that regular floats still work
my $float = $js->eval('3.14159');
cmp_ok($float, '>', 3.14, 'Regular float works');
cmp_ok($float, '<', 3.15, 'Regular float is correct value');

# Test NaN from operations
my $nan_op = $js->eval('0/0');
is($nan_op, undef, 'NaN from 0/0 converts to undef');

# Test Infinity from operations
my $inf_op = $js->eval('1/0');
is($inf_op, undef, 'Infinity from 1/0 converts to undef');

# Test -Infinity from operations
my $neg_inf_op = $js->eval('-1/0');
is($neg_inf_op, undef, '-Infinity from -1/0 converts to undef');

# Test in array context
my $arr = $js->eval('[1, NaN, 2, Infinity, 3, -Infinity]');
cmp_deeply($arr, [1, undef, 2, undef, 3, undef], 'NaN/Infinity in arrays convert to undef');

# Test in object context
my $obj = $js->eval('({a: 1, b: NaN, c: Infinity})');
cmp_deeply($obj, {a => 1, b => undef, c => undef}, 'NaN/Infinity in objects convert to undef');

# Test that integers still work
my $int = $js->eval('42');
is($int, 42, 'Integer still works');

# Test zero
my $zero = $js->eval('0');
is($zero, 0, 'Zero still works');

# Test negative zero (should be regular zero)
my $neg_zero = $js->eval('-0');
cmp_ok($neg_zero, '==', 0, 'Negative zero works');

done_testing();