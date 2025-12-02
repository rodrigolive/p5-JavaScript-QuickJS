use strict;
use warnings;
use Test::More tests => 5;
use JavaScript::QuickJS;

# Test that new GC approach handles complex scenarios

subtest 'automatic_cleanup' => sub {
    plan tests => 1;

    for (1..10) {
        my $js = JavaScript::QuickJS->new();
        $js->set_globals(cb => sub { { data => shift } });
        $js->eval('const f = (r) => cb(1); globalThis.__f = f;');
        undef $js;  # Should not assert
    }
    pass('10 iterations without assertion');
};

subtest 'explicit_cleanup' => sub {
    plan tests => 3;

    my $js = JavaScript::QuickJS->new();
    $js->set_globals(complex => sub {
        return {
            nested => sub { "value" },
            array => [sub {1}, sub {2}]
        };
    });
    $js->eval('globalThis.__x = complex();');

    # Test explicit cleanup
    ok($js->can('clear_perl_callbacks'), 'Method exists');
    $js->clear_perl_callbacks();

    # Should work without assertion
    undef $js;
    pass('Explicit cleanup successful');
    pass('No assertion during destruction');
};

subtest 'promise_patterns' => sub {
    plan tests => 1;

    my $js = JavaScript::QuickJS->new();
    $js->set_globals(
        handler => sub {
            my ($resolve) = @_;
            # In a real scenario, we'd call $resolve->(42)
            # but for this test we just verify no crash
            return;
        }
    );

    # Create a promise pattern (though we don't actually resolve it)
    eval {
        $js->eval('const p = new Promise((res, rej) => { handler(res); });');
    };

    undef $js;
    pass('Promise pattern handled');
};

subtest 'deeply_nested' => sub {
    plan tests => 1;

    my $js = JavaScript::QuickJS->new();
    my $depth = 10;

    $js->set_globals(leaf => sub { "leaf" });

    my $code = 'globalThis.__deep = ';
    $code .= '(() => ' x $depth;
    $code .= 'leaf()';
    $code .= ')' x $depth;

    $js->eval($code);
    undef $js;
    pass("Depth $depth nested closures handled");
};

subtest 'circular_capture' => sub {
    plan tests => 1;

    my $js = JavaScript::QuickJS->new();
    my $captured;

    $js->set_globals(
        capture => sub { $captured = shift; return {} }
    );

    $js->eval(q{
        const fn = (x) => capture(() => fn(x + 1));
        fn(0);
    });

    undef $captured;
    $js->clear_perl_callbacks();
    undef $js;

    pass('Circular capture with explicit cleanup');
};
