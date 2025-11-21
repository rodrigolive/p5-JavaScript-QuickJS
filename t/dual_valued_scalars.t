#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use JavaScript::QuickJS;

# Test that dual-valued Perl scalars (having both numeric and string representations)
# are correctly handled when passed to JavaScript. This is important because when
# a number is stringified in Perl, both IOK/NOK and POK flags are set.
#
# The fix prioritizes numeric flags over string flags to preserve numeric semantics
# when values roundtrip through JavaScript -> Perl -> JavaScript.

my $js = JavaScript::QuickJS->new();

# Test 1: Number from JS should stay numeric when passed back
{
    my $num = $js->eval('0');

    # Force stringification (sets both numeric and string flags)
    my $stringified = "$num";

    # Now pass it back to JS - it should be treated as a number, not a string
    $js->set_globals(val => $num);
    my $result = $js->eval('val + 1');

    is($result, 1, 'JS number -> Perl -> JS preserves numeric type (0 + 1 = 1)');
}

# Test 2: Explicit test for string concatenation vs numeric addition
{
    my $num = $js->eval('5');
    my $str = "$num";  # Force dual-valued scalar

    $js->set_globals(testval => $num);

    my $add_result = $js->eval('testval + 10');
    my $concat_result = $js->eval('testval + "10"');

    is($add_result, 15, 'Dual-valued scalar: numeric addition (5 + 10 = 15)');
    is($concat_result, '510', 'Dual-valued scalar: string concatenation (5 + "10" = "510")');
}

# Test 3: Loop increment (the original failing test case)
{
    my $counter = $js->eval('0');
    my $dummy = "$counter";  # Make it dual-valued

    $js->set_globals(ok => $counter);

    my $result = $js->eval(q{
        var sum = 0;
        for (var i = 0; i < 5; i++) {
            ok = ok + 1;
            sum += ok;
        }
        sum;
    });

    is($result, 15, 'Loop with dual-valued counter: 1+2+3+4+5 = 15');
}

# Test 4: Multiple roundtrips
{
    my $val = 10;

    for my $i (1..3) {
        $val = "$val";  # Stringify
        $js->set_globals(roundtrip => $val);
        $val = $js->eval('roundtrip * 2');
    }

    is($val, 80, 'Multiple roundtrips preserve numeric type (10 * 2 * 2 * 2 = 80)');
}

# Test 5: Floating point numbers
{
    my $num = $js->eval('3.14159');
    my $str = "$num";  # Make dual-valued

    $js->set_globals(pi => $num);
    my $result = $js->eval('pi * 2');

    # Allow for floating point imprecision
    ok(abs($result - 6.28318) < 0.00001, 'Dual-valued float: pi * 2 ≈ 6.28318');
}

# Test 6: Zero (special case that often fails)
{
    my $zero = $js->eval('0');
    my $str = "$zero";

    $js->set_globals(zero => $zero);

    my $is_zero = $js->eval('zero === 0');
    my $is_string_zero = $js->eval('zero === "0"');

    ok($is_zero, 'Dual-valued zero is === 0 (number)');
    ok(!$is_string_zero, 'Dual-valued zero is NOT === "0" (string)');
}

# Test 7: typeof check
{
    my $num = $js->eval('42');
    my $str = "$num";

    $js->set_globals(value => $num);
    my $type = $js->eval('typeof value');

    is($type, 'number', 'typeof dual-valued scalar is "number", not "string"');
}

done_testing;
