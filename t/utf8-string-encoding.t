#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use Test::More tests => 8;
use JavaScript::QuickJS;
use JSON::XS;
use Encode;

my $js = JavaScript::QuickJS->new();

# Test 1: Simple UTF-8 string
{
    my $result = $js->eval(q{ "Gestión" });
    is($result, "Gestión", "Spanish string with accented ó");
    ok(utf8::is_utf8($result), "UTF-8 flag should be set");

    # Check actual bytes are correct UTF-8
    my $bytes = Encode::encode_utf8($result);
    is(unpack('H*', $bytes), "4765737469c3b36e", "Should be valid UTF-8 bytes");
}

# Test 2: Object with multiple UTF-8 strings
{
    my $result = $js->eval(q{
        ({
            title: "Gestión",
            year: "Año",
            name: "José"
        })
    });

    is($result->{title}, "Gestión", "Object property with ó");
    is($result->{year}, "Año", "Object property with ñ");
    is($result->{name}, "José", "Object property with é");
}

# Test 3: JSON round-trip should preserve UTF-8
{
    my $obj = $js->eval(q{ ({ text: "Gestión de años" }) });

    # Encode to JSON (simulating API response)
    my $json_encoder = JSON::XS->new->utf8;
    my $json_bytes = $json_encoder->encode($obj);

    # Decode back
    my $decoded = JSON::XS->new->utf8->decode($json_bytes);

    is($decoded->{text}, "Gestión de años",
        "JSON round-trip should preserve UTF-8 strings");
}

# Test 4: Emoji and multi-byte characters
{
    my $result = $js->eval(q{ "Hello 🌍 World" });
    my $bytes = Encode::encode_utf8($result);

    # Emoji earth globe is U+1F30D, encoded as F0 9F 8C 8D in UTF-8
    like(unpack('H*', $bytes), qr/f09f8c8d/,
        "4-byte UTF-8 sequences (emoji) should be handled correctly");
}
