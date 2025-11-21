#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use JavaScript::QuickJS;
use JSON::XS;

plan tests => 9;

my $js = JavaScript::QuickJS->new();
my $json = JSON::XS->new->canonical;

# Test NaN conversion
{
    my $result = $js->eval('NaN');
    ok(!defined $result, 'NaN converts to undef');

    # The critical test: verify it serializes as null, not nan
    my $json_str = $json->encode({ value => $result });
    is($json_str, '{"value":null}', 'NaN serializes as null in JSON');
}

# Test Infinity conversion
{
    my $result = $js->eval('Infinity');
    ok(!defined $result, 'Infinity converts to undef');

    my $json_str = $json->encode({ value => $result });
    is($json_str, '{"value":null}', 'Infinity serializes as null in JSON');
}

# Test -Infinity conversion
{
    my $result = $js->eval('-Infinity');
    ok(!defined $result, '-Infinity converts to undef');

    my $json_str = $json->encode({ value => $result });
    is($json_str, '{"value":null}', '-Infinity serializes as null in JSON');
}

# Test mixed object with NaN, Infinity, and normal values
{
    my $result = $js->eval('({ a: 1, b: NaN, c: "test", d: Infinity, e: -Infinity, f: 3.14 })');

    my $json_str = $json->encode($result);
    is($json_str, '{"a":1,"b":null,"c":"test","d":null,"e":null,"f":3.14}',
       'Mixed object with NaN/Infinity serializes correctly');
}

# Test array with NaN and Infinity
{
    my $result = $js->eval('[1, NaN, 2, Infinity, 3, -Infinity]');

    my $json_str = $json->encode($result);
    is($json_str, '[1,null,2,null,3,null]',
       'Array with NaN/Infinity serializes correctly');
}

# Test that normal floats still work
{
    my $result = $js->eval('3.14159');
    is($result, 3.14159, 'Normal float values work correctly');
}

done_testing();
