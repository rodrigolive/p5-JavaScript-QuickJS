package JavaScript::QuickJS;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

JavaScript::QuickJS - Run JavaScript via L<QuickJS|https://bellard.org/quickjs> in Perl

=head1 SYNOPSIS

Quick and dirty …

    my $val = JavaScript::QuickJS->new()->eval( q<
        let foo = "bar";
        [ "The", "last", "value", "is", "returned." ];
    > );

… or load ES6 modules:

    my $js = JavaScript::QuickJS->new()->helpers();

    $js->eval_module( q/
        import * as coolStuff from 'cool/stuff';

        for (const [key, value] of Object.entries(coolStuff)) {
            console.log(key, value);
        }
    / );

=head1 DESCRIPTION

This library embeds Fabrice Bellard’s L<QuickJS|https://bellard.org/quickjs>
engine into a Perl XS module. You can thus run JavaScript
(L<ES2020|https://tc39.github.io/ecma262/> specification) directly in your
Perl programs.

This distribution includes all needed C code; unlike with most XS modules
that interface with C libraries, you don’t need QuickJS pre-installed on
your system.

=cut

# ----------------------------------------------------------------------

use XSLoader;

our $VERSION = '0.22';

XSLoader::load( __PACKAGE__, $VERSION );

# ----------------------------------------------------------------------

=head1 METHODS

=head2 $obj = I<CLASS>->new( %CONFIG_OPTS )

Instantiates I<CLASS>. %CONFIG_OPTS can include options from
C<configure()> below, plus:

=over

=item * C<preserve_types> - Boolean. When true, JavaScript primitive types
(boolean, null, undefined) are returned as blessed Perl objects instead of
plain scalars. This allows distinguishing between C<true>/C<false>, C<null>/C<undefined>,
and C<1>/C<0>. Default: false (for backward compatibility).

See L<JavaScript::QuickJS::Boolean>, L<JavaScript::QuickJS::Null>, and
L<JavaScript::QuickJS::Undefined> for details on the blessed object types.

=back

=cut

sub new {
    my ($class, %opts) = @_;

    my $preserve_types = delete $opts{preserve_types};

    my $self = $class->_new($preserve_types);

    return %opts ? $self->configure(%opts) : $self;
}

=head2 $obj = I<OBJ>->configure( %OPTS )

Tunes the QuickJS interpreter. Returns I<OBJ>.

%OPTS are any of:

=over

=item * C<max_stack_size>

=item * C<memory_limit>

=item * C<gc_threshold>

=back

For more information on these, see QuickJS itself.

=cut

sub configure {
    my ($self, %opts) = @_;

    my ($stack, $memlimit, $gc_threshold) = delete @opts{'max_stack_size', 'memory_limit', 'gc_threshold'};

    if (my @extra = sort keys %opts) {
        Carp::croak("Unknown: @extra");
    }

    return $self->_configure($stack, $memlimit, $gc_threshold);
}

#----------------------------------------------------------------------

=head2 $obj = I<OBJ>->set_globals( NAME1 => VALUE1, .. )

Sets 1 or more globals in I<OBJ>. See below for details on type conversions
from Perl to JavaScript.

Returns I<OBJ>.

=head2 $obj = I<OBJ>->helpers()

Defines QuickJS’s “helpers”, e.g., C<console.log>.

Returns I<OBJ>.

=head2 $obj = I<OBJ>->std()

Enables QuickJS’s C<std> module and creates a global of the same name
that’s usable from both script and module modes.

This resembles C<qjs>’s C<--std> flag except that it I<only> enables
C<std>, not C<os>.

Returns I<OBJ>.

=head2 $obj = I<OBJ>->os()

Like C<std()> but enables QuickJS’s C<os> module instead of C<std>.

=head2 $VALUE = I<OBJ>->eval( $JS_CODE )

Like running C<qjs -e '...'>. Returns $JS_CODE’s last value;
see below for details on type conversions from JavaScript to Perl.

Untrapped exceptions in JavaScript will be rethrown as Perl exceptions.

$JS_CODE is a I<character> string.

=head2 $promise = I<OBJ>->eval_module( $JS_CODE )

Runs $JS_CODE as a module, which enables ES6 module syntax.
Note that no values can be returned directly in this mode of execution.

Returns a promise that resolves once the module is loaded.

=head2 $obj = I<OBJ>->await()

Blocks until all of I<OBJ>’s pending work (if any) is complete.

For example, if you C<eval()> some code that creates a promise, call
this to wait for that promise to complete.

Returns I<OBJ>.

=head2 $obj = I<OBJ>->set_module_base( $PATH )

Sets a base path (a byte string) for ES6 module imports.

Returns I<OBJ>.

=head2 $obj = I<OBJ>->unset_module_base()

Restores QuickJS’s default directory for ES6 module imports
(as of this writing, it’s the process’s current directory).

Returns I<OBJ>.

=cut

# ----------------------------------------------------------------------

=head1 TYPE CONVERSION: JAVASCRIPT → PERL

This module converts returned values from JavaScript thus:

=over

=item * JS string primitives become I<character> strings in Perl.

=item * JS number primitives become corresponding Perl values.

=item * JS boolean primitives become corresponding Perl values (1 or 0), B<unless>
C<preserve_types =E<gt> 1> is enabled, in which case they become
L<JavaScript::QuickJS::Boolean> objects.

=item * JS null becomes Perl undef, B<unless> C<preserve_types =E<gt> 1> is enabled,
in which case it becomes a L<JavaScript::QuickJS::Null> object.

=item * JS undefined becomes Perl undef, B<unless> C<preserve_types =E<gt> 1> is enabled,
in which case it becomes a L<JavaScript::QuickJS::Undefined> object.

=item * JS objects …

=over

=item * Arrays become Perl array references.

=item * “Plain” objects become Perl hash references.

=item * Function, RegExp, and Date objects become Perl
L<JavaScript::QuickJS::Function>, L<JavaScript::QuickJS::RegExp>,
and L<JavaScript::QuickJS::Date> objects, respectively.

=item * Behaviour is B<UNDEFINED> for other object types.

=back

=back

=head2 Type Preservation

When C<preserve_types =E<gt> 1> is enabled, the blessed objects provide overloaded
operators so they behave like their primitive counterparts in most contexts:

    my $js = JavaScript::QuickJS->new(preserve_types => 1);
    my $bool = $js->eval('true');

    # Behaves like a boolean
    if ($bool) { ... }           # truthy

    # Can distinguish types
    ref($bool)                   # 'JavaScript::QuickJS::Boolean'

    # Stringifies/numifies correctly
    "$bool"                      # 'true'
    0 + $bool                    # 1

This is useful when you need to:

=over

=item * Distinguish between boolean C<true> and number C<1>

=item * Distinguish between boolean C<false> and number C<0> or empty string C<''>

=item * Distinguish between JavaScript C<null> and JavaScript C<undefined>

=item * Serialize back to JSON with correct types

=back

=head1 TYPE CONVERSION: PERL → JAVASCRIPT

Generally speaking, it’s the inverse of JS → Perl:

=over

=item * Perl strings, numbers, & booleans become corresponding JavaScript
primitives.

B<IMPORTANT:> Perl versions before 5.36 don’t reliably distinguish “numeric
strings” from “numbers”. If your perl predates 5.36, typecast accordingly
to prevent your Perl “number” from becoming a JavaScript string. (Even in
5.36 and later it’s still a good idea.)

=item * Perl undef becomes JS undefined (as of version 0.22).

=item * L<JavaScript::QuickJS::Null> objects become JS null.

=item * Unblessed array & hash references become JavaScript arrays and
“plain” objects.

=item * L<Types::Serialiser> booleans become JavaScript booleans.

=item * Perl code references become JavaScript functions.

=item * Perl L<JavaScript::QuickJS::Function>, L<JavaScript::QuickJS::RegExp>,
and L<JavaScript::QuickJS::Date> objects become their original
JavaScript objects.

=item * Anything else triggers an exception.

=back

=head1 NULL VS UNDEFINED HANDLING

=head2 Breaking Changes in Version 0.22

Starting with version 0.22, there are two important changes:

1. Perl C<undef> converts to JavaScript C<undefined> instead of C<null>
2. JavaScript C<undefined> B<always> returns plain Perl C<undef>, even with C<preserve_types =E<gt> 1>

These changes provide semantic correctness and improved compatibility with
Perl frameworks (especially Moose).

=head2 Key Behavior Changes

  | Conversion                           | Before (≤0.21)      | After (≥0.22)       | Why                          |
  |--------------------------------------|---------------------|---------------------|------------------------------|
  | Perl undef → JS                      | null ❌             | undefined ✅        | Semantic correctness         |
  | Perl Null object → JS                | N/A ❌              | null ✅             | Explicit null support        |
  | Perl Undefined object → JS           | N/A ❌              | undefined ✅        | Backward compatibility       |
  | JS null → Perl (default)             | undef ✅            | undef ✅            | No change                    |
  | JS undefined → Perl (default)        | undef ✅            | undef ✅            | No change                    |
  | JS null → Perl (preserve_types)      | Null object ✅      | Null object ✅      | No change                    |
  | JS undefined → Perl (preserve_types) | Undefined object ❌ | plain undef ✅      | Better compat, Moose fix     |

=head2 Why undefined Always Returns Plain undef?

JavaScript C<undefined> now B<always> returns plain Perl C<undef>, even with
C<preserve_types =E<gt> 1>. This provides:

=over

=item * B<Moose/Type::Tiny compatibility:> Plain C<undef> works with type constraints

=item * B<Performance:> No blessed object overhead for the most common "no value" case

=item * B<Semantic correctness:> JavaScript C<undefined> = Perl C<undef> (both mean "no value")

=back

The L<JavaScript::QuickJS::Undefined> class still exists for backward compatibility
and will convert to JavaScript C<undefined> when passed to JavaScript.

=head2 Why This Change?

In JavaScript, C<null> and C<undefined> have different semantics:

=over

=item * C<undefined> means "no value assigned" - the default for uninitialized variables,
missing function parameters, and missing object properties.

=item * C<null> means "intentional absence of value" - explicitly set by the programmer.

=back

This distinction matters for:

=over

=item * B<JSON serialization:> C<undefined> properties are omitted, C<null> properties
are included.

    // JavaScript
    JSON.stringify({a: null, b: undefined})
    // Result: '{"a":null}'  (b is omitted!)

=item * B<Function parameters:> Missing parameters are C<undefined>, not C<null>.

=item * B<JavaScript conventions:> Variables default to C<undefined>, not C<null>.

=back

=head2 Migration Guide

If you need explicit C<null> values (e.g., for database NULLs or API requirements),
use L<JavaScript::QuickJS::Null>:

    use JavaScript::QuickJS::Null;

    my $js = JavaScript::QuickJS->new();

    $js->set_globals(
        explicit_null => JavaScript::QuickJS::Null->new(),
        regular_undef => undef,
    );

    $js->eval(q{
        console.log(typeof explicit_null);  // "object" (null)
        console.log(typeof regular_undef);  // "undefined"

        console.log(explicit_null === null);      // true
        console.log(regular_undef === undefined); // true
    });

With C<preserve_types =E<gt> 1>, JavaScript C<null> becomes a blessed object
while C<undefined> B<always> returns plain C<undef>:

    my $js = JavaScript::QuickJS->new(preserve_types => 1);

    my $null = $js->eval('null');
    my $undef = $js->eval('undefined');

    ref($null)       # 'JavaScript::QuickJS::Null'
    defined($undef)  # false (plain undef, not blessed)

    # These round-trip back to JavaScript correctly
    $js->set_globals(
        null_val  => $null,
        undef_val => $undef,
    );

=head1 MEMORY HANDLING NOTES

If any instance of a class of this distribution is DESTROY()ed at Perl’s
global destruction, we assume that this is a memory leak, and a warning is
thrown. To prevent this, avoid circular references, and clean up all global
instances.

Callbacks make that tricky. When you give a JavaScript function to Perl,
that Perl object holds a reference to the QuickJS context. Only once that
object is C<DESTROY()>ed do we release that QuickJS context reference.

Consider the following:

    my $return;

    $js->set_globals(  __return => sub { $return = shift; () } );

    $js->eval('__return( a => a )');

This sets $return to be a L<JavaScript::QuickJS::Function> instance. That
object holds a reference to $js. $js also stores C<__return()>,
which is a Perl code reference that closes around $return. Thus, we have
a reference cycle: $return refers to $js, and $js refers to $return. Those
two values will thus leak, and you’ll see a warning about it at Perl’s
global destruction time.

To break the reference cycle, just do:

    undef $return;

… once you’re done with that variable.

You I<might> have thought you could instead do:

    $js->set_globals( __return => undef )

… but that doesn’t work because $js holds a reference to all Perl code
references it B<ever> receives. This is because QuickJS, unlike Perl,
doesn’t expose object destructors (C<DESTROY()> in Perl), so there’s no
good way to release that reference to the code reference.

=head1 CHARACTER ENCODING NOTES

QuickJS (like all JS engines) assumes its strings are text. Since Perl
can’t distinguish text from bytes, though, it’s possible to convert
Perl byte strings to JavaScript strings. It often yields a reasonable
result, but not always.

One place where this falls over, though, is ES6 modules. QuickJS, when
it loads an ES6 module, decodes that module’s string literals to characters.
Thus, if you pass in byte strings from Perl, QuickJS will treat your
Perl byte strings’ code points as character code points, and when you
combine those code points with those from your ES6 module you may
get mangled output.

Another place that may create trouble is if your argument to C<eval()>
or C<eval_module()> (above) contains JSON. Perl’s popular JSON encoders
output byte strings by default, but as noted above, C<eval()> and
C<eval_module()> need I<character> strings. So either configure your
JSON encoder to output characters, or decode JSON bytes to characters
before calling C<eval()>/C<eval_module()>.

For best results, I<always> interact with QuickJS via I<character>
strings, and double-check that you’re doing it that way consistently.

=head1 NUMERIC PRECISION

Note the following if you expect to deal with “large” numbers:

=over

=item * JavaScript’s numeric-precision limits apply. (cf.
L<Number.MAX_SAFE_INTEGER|https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER>.)

=item * Perl’s stringification of numbers may be I<less> precise than
JavaScript’s storage of those numbers, or even than Perl’s own storage.
For example, in Perl 5.34 C<print 1000000000000001.0> prints C<1e+15>.

To counteract this loss of precision, add 0 to Perl’s numeric scalars
(e.g., C<print 0 + 1000000000000001.0>); this will encourage Perl to store
numbers as integers when possible, which fixes this precision problem.

=item * Long-double and quad-math perls may lose precision when converting
numbers to/from JavaScript. To see if this affects your perl—which, if
you’re unsure, it probably doesn’t—run C<perl -V>, and see if that perl’s
compile-time options mention long doubles or quad math.

=back

=head1 OS SUPPORT

QuickJS supports Linux, macOS, and Windows natively, so these work without
issue.

FreeBSD, OpenBSD, & Cygwin work after a few patches that we apply when
building this library. (Hopefully these will eventually merge into QuickJS.)

=head1 LIBATOMIC

QuickJS uses C11 atomics. Most platforms implement that functionality in
hardware, but others (e.g., arm32) don’t. To fill that void, we need to link
to libatomic.

This library’s build logic detects whether libatomic is necessary and will
only link to it if needed. If, for some reason, you need manual control over
that linking, set C<JS_QUICKJS_LINK_LIBATOMIC> in the environment to 1 or a
falsy value.

If you don’t know what any of that means, you can probably ignore it.

=head1 SEE ALSO

This distribution includes these additional modules:

=over

=item * L<JavaScript::QuickJS::Boolean> - Blessed boolean type (when C<preserve_types =E<gt> 1>)

=item * L<JavaScript::QuickJS::Null> - Blessed null type (when C<preserve_types =E<gt> 1>)

=item * L<JavaScript::QuickJS::Undefined> - Blessed undefined type (when C<preserve_types =E<gt> 1>)

=item * L<JavaScript::QuickJS::Function> - JavaScript function wrapper

=item * L<JavaScript::QuickJS::RegExp> - JavaScript RegExp wrapper

=item * L<JavaScript::QuickJS::Date> - JavaScript Date wrapper

=item * L<JavaScript::QuickJS::Promise> - JavaScript Promise wrapper

=back

Other JavaScript modules on CPAN include:

=over

=item * L<JavaScript::Duktape::XS> and L<JavaScript::Duktape> make the
L<Duktape|https://duktape.org> library available to Perl. They’re similar to
this library, but Duktape itself (as of this writing) lacks support for
several JavaScript constructs that QuickJS supports. (It’s also slower.)

=item * L<JavaScript::V8> and L<JavaScript::V8::XS> expose Google’s
L<V8|https://v8.dev> library to Perl. Neither seems to support current
V8 versions.

=item * L<JE> is a pure-Perl (!) JavaScript engine.

=item * L<JavaScript> and L<JavaScript::Lite> expose Mozilla’s
L<SpiderMonkey|https://spidermonkey.dev/> engine to Perl.

=back

=head1 LICENSE & COPYRIGHT

This library is copyright 2023 Gasper Software Consulting.

This library is licensed under the same terms as Perl itself.
See L<perlartistic>.

QuickJS is copyright Fabrice Bellard and Charlie Gordon. It is released
under the L<MIT license|https://opensource.org/licenses/MIT>.

=cut

#----------------------------------------------------------------------

package JavaScript::QuickJS::JSObject;

package JavaScript::QuickJS::RegExp;

our @ISA;
BEGIN { @ISA = 'JavaScript::QuickJS::JSObject' };

package JavaScript::QuickJS::Function;

our @ISA;
BEGIN { @ISA = 'JavaScript::QuickJS::JSObject' };

# Load the Function.pm module which contains additional methods
# This must be done at runtime to avoid circular dependencies
eval { require JavaScript::QuickJS::Function; 1 } or do {
    warn "Note: JavaScript::QuickJS::Function module not found: $@" if $@ && $@ !~ /^Can't locate/;
};

1;
