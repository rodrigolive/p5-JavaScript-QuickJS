#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use JavaScript::QuickJS;

# Test that Perl hash properties are enumerable in JavaScript

my $js = JavaScript::QuickJS->new();

my $hash = {
    name => 'test',
    value => 42,
    nested => { foo => 'bar' }
};

$js->set_globals( testObj => $hash );

# Test Object.keys()
my $keys = $js->eval('Object.keys(testObj)');
is(ref($keys), 'ARRAY', 'Object.keys() returns array');
is(scalar(@$keys), 3, 'Object.keys() returns 3 keys');

# Test JSON.stringify()
my $json = $js->eval('JSON.stringify(testObj)');
isnt($json, '{}', 'JSON.stringify() is not empty');
like($json, qr/"name":"test"/, 'JSON.stringify() contains name');
like($json, qr/"value":42/, 'JSON.stringify() contains value');
like($json, qr/"nested":\{/, 'JSON.stringify() contains nested object');

# Test for...in loop
my $for_in_count = $js->eval('
    var count = 0;
    for (var key in testObj) {
        count++;
    }
    count;
');
is($for_in_count, 3, 'for...in loop iterates 3 times');

# Test spread operator
my $spread_keys = $js->eval('Object.keys({...testObj})');
is(scalar(@$spread_keys), 3, 'Spread operator preserves all properties');

# Test nested object enumeration
my $nested_keys = $js->eval('Object.keys(testObj.nested)');
is(scalar(@$nested_keys), 1, 'Nested object has enumerable properties');
is($nested_keys->[0], 'foo', 'Nested object key is foo');

# Test Object.entries()
my $entries = $js->eval('Object.entries(testObj).length');
is($entries, 3, 'Object.entries() returns 3 entries');

# Test Object.values()
my $values = $js->eval('Object.values(testObj)');
is(ref($values), 'ARRAY', 'Object.values() returns array');
is(scalar(@$values), 3, 'Object.values() returns 3 values');

# ===== ARRAY ENUMERATION TESTS =====

my $array = [10, 20, 30, 40];
$js->set_globals( testArray => $array );

# Test Object.keys() on array (returns indices as strings)
my $array_keys = $js->eval('Object.keys(testArray)');
is(ref($array_keys), 'ARRAY', 'Object.keys() on array returns array');
cmp_deeply($array_keys, ['0', '1', '2', '3'], 'Array indices are enumerable');

# Test array spread operator
my $spread_array = $js->eval('[...testArray]');
is(ref($spread_array), 'ARRAY', 'Array spread returns array');
cmp_deeply($spread_array, [10, 20, 30, 40], 'Array spread works correctly');

# Test JSON.stringify() on array
my $array_json = $js->eval('JSON.stringify(testArray)');
is($array_json, '[10,20,30,40]', 'Array JSON serialization works');

# Test for...in loop on array
my $array_for_in = $js->eval('
    var indices = [];
    for (var idx in testArray) {
        indices.push(idx);
    }
    indices;
');
cmp_deeply($array_for_in, ['0', '1', '2', '3'], 'for...in iterates array indices');

# Test Object.values() on array
my $array_values = $js->eval('Object.values(testArray)');
cmp_deeply($array_values, [10, 20, 30, 40], 'Object.values() works on arrays');

# Test Object.entries() on array
my $array_entries = $js->eval('Object.entries(testArray)');
cmp_deeply($array_entries, [['0', 10], ['1', 20], ['2', 30], ['3', 40]], 'Object.entries() works on arrays');

# Test nested arrays
my $nested_array = [[1, 2], [3, 4]];
$js->set_globals( nestedArray => $nested_array );

my $nested_json = $js->eval('JSON.stringify(nestedArray)');
is($nested_json, '[[1,2],[3,4]]', 'Nested arrays serialize correctly');

# Test mixed array/object structures
my $mixed = {
    users => [
        { name => 'Alice', age => 30 },
        { name => 'Bob', age => 25 }
    ],
    count => 2
};
$js->set_globals( mixedData => $mixed );

my $mixed_json = $js->eval('JSON.stringify(mixedData)');
like($mixed_json, qr/"users":\[/, 'Mixed structure has users array');
like($mixed_json, qr/"name":"Alice"/, 'Mixed structure has nested object properties');
like($mixed_json, qr/"count":2/, 'Mixed structure has top-level properties');

# Test empty array
my $empty_array = [];
$js->set_globals( emptyArray => $empty_array );

my $empty_keys = $js->eval('Object.keys(emptyArray)');
cmp_deeply($empty_keys, [], 'Empty array has no indices');

my $empty_json = $js->eval('JSON.stringify(emptyArray)');
is($empty_json, '[]', 'Empty array serializes as []');

# Test array returned from callback
$js->set_globals( getArray => sub { return [100, 200, 300]; } );

my $callback_array = $js->eval('
    var arr = getArray();
    Object.keys(arr);
');
cmp_deeply($callback_array, ['0', '1', '2'], 'Callback-returned array has enumerable indices');

my $callback_spread = $js->eval('[...getArray()]');
cmp_deeply($callback_spread, [100, 200, 300], 'Callback-returned array spread works');

done_testing();