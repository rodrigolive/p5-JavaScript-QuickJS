#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use JavaScript::QuickJS;

my $js = JavaScript::QuickJS->new();

sub codepoints {
    my ($str) = @_;
    return [ map { ord($_) } split //u, $str ];
}

subtest 'Perl string round-trips through JS unchanged' => sub {
    my $input = "Perl→JS→Perl 𝄞 café ☕";

    my $roundtrip = $js->eval('(text) => ({ echo: text, cps: Array.from(text).map(ch => ch.codePointAt(0)) })');
    my $out = $roundtrip->($input);

    is($out->{echo}, $input, 'round-trip string matches');
    ok(utf8::is_utf8($out->{echo}), 'UTF-8 flag preserved from JS result');
    cmp_deeply($out->{cps}, codepoints($input), 'code points preserved');
};

subtest 'UTF-8 source code in Perl evals correctly in JS' => sub {
    my $js_code = q{(() => {
        const phrase = "Добро пожаловать 🌐";
        return `${phrase} + perl`;
    })()};

    my $result = $js->eval($js_code);

    is($result, "Добро пожаловать 🌐 + perl", 'UTF-8 source executed correctly');
    ok(utf8::is_utf8($result), 'UTF-8 flag set on eval result');
};

subtest 'compile() handles UTF-8 source and arguments' => sub {
    my $compiled = $js->compile('(name) => `¡Hola, ${name}! Mañana ☀️`');

    my $value = $compiled->("árbol");
    is($value, "¡Hola, árbol! Mañana ☀️", 'compiled function returns UTF-8 string');
    ok(utf8::is_utf8($value), 'UTF-8 flag preserved from compiled result');
};

subtest 'exceptions preserve UTF-8 content' => sub {
    eval { $js->eval(q{ throw new Error("Explosión 💥 número π"); }); };
    my $err = $@;

    like($err, qr/Explosión/, 'UTF-8 text preserved in error');
    like($err, qr/\x{1F4A5}/, 'emoji preserved in error');
    ok(utf8::is_utf8($err), 'UTF-8 flag preserved on error');
};

done_testing;
