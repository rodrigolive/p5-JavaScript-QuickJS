package JavaScript::QuickJS::Undefined;
use strict;
use warnings;

our $VERSION = '0.22';

use overload (
    '""'   => sub { '' },
    '0+'   => sub { 0 },
    'bool' => sub { 0 },
    '!'    => sub { 1 },
    '=='   => sub {
        my ($self, $other) = @_;
        return !defined($other) || ref($other) eq __PACKAGE__;
    },
    'eq'   => sub {
        my ($self, $other) = @_;
        return !defined($other) || ref($other) eq __PACKAGE__;
    },
    fallback => 1,
);

sub new {
    my $class = shift;
    bless \(my $o = undef), $class;
}

sub TO_JSON {
    return undef;
}

1;

__END__

=head1 NAME

JavaScript::QuickJS::Undefined - Undefined type for JavaScript::QuickJS

=head1 SYNOPSIS

    use JavaScript::QuickJS;

    my $js = JavaScript::QuickJS->new(preserve_types => 1);
    my $result = $js->eval('undefined');

    if (ref($result) eq 'JavaScript::QuickJS::Undefined') {
        print "Got JavaScript undefined (not null!)\n";
    }

=head1 DESCRIPTION

This class represents JavaScript undefined values when type preservation is
enabled. It allows distinguishing between undefined and null, which both become
C<undef> in Perl when C<preserve_types> is disabled.

=head2 OVERLOADS

=over 4

=item Stringification ("")

Returns empty string

=item Numeric (0+)

Returns 0

=item Boolean (bool)

Returns false

=item Negation (!)

Returns true

=item Equality (==, eq)

Compares as equal to undef or another Undefined object

=back

=head2 METHODS

=over 4

=item new()

Constructor. Takes no arguments.

=item TO_JSON()

Returns undef (often omitted from JSON)

=back

=head1 SEE ALSO

L<JavaScript::QuickJS>, L<JavaScript::QuickJS::Null>

=cut
