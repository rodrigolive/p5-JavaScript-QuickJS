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

done_testing();