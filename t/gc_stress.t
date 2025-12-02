use strict;
use warnings;
use Test::More tests => 1;
use JavaScript::QuickJS;

# Stress test: Create and destroy 1000 VMs with complex graphs

for my $i (1..1000) {
    my $js = JavaScript::QuickJS->new();
    $js->set_globals(cb => sub { { iter => $i } });
    $js->eval(q{
        const handlers = Array.from({length: 10},
            (_, i) => () => cb(i));
        globalThis['__h' + Math.random()] = handlers;
    });

    # Periodically use explicit cleanup
    if ($i % 100 == 0) {
        $js->clear_perl_callbacks();
    }

    undef $js;
}

pass('1000 iterations without crash or assertion');
