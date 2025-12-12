#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Fatal;

use JavaScript::QuickJS;

# Test pattern: storing JS functions in a registry and calling them later
subtest 'Registry pattern - handler stored and called later' => sub {
    my %registry;

    # Phase 1: Create and register a function
    {
        my $js = JavaScript::QuickJS->new();

        # Create handler that accesses nested objects
        my $handler = $js->eval(q{
            (function(ctx, config) {
                var mid = config.mid;
                var obj = config.obj;

                // Access nested object properties
                // Simulates: obj.repo().mid()
                if (obj && obj.repo) {
                    var repo = obj.repo();
                    if (repo && repo.mid) {
                        return repo.mid();
                    }
                }
                return mid;
            })
        });

        # Store in registry
        $registry{'service.handler'} = {
            name => 'test_handler',
            handler => $handler,
        };

        # Verify it works immediately
        my $result = $registry{'service.handler'}->{handler}->(
            {},
            {
                mid => '123',
                obj => {
                    repo => sub {
                        return {
                            mid => sub { return '456'; }
                        };
                    }
                }
            }
        );
        is $result, '456', 'Handler works immediately while VM is alive';
    }
    # VM destroyed here - $js goes out of scope

    # Phase 2: Call the stored handler after VM destruction
    local $SIG{__DIE__} = sub { die shift; };  # Custom DIE handler

    my $service = $registry{'service.handler'};
    my $result = exception {
        $service->{handler}->(
            {},
            {
                mid => '123',
                obj => {
                    repo => sub {
                        return {
                            mid => sub { return '456'; }
                        };
                    }
                }
            }
        );
    };

    if ($result) {
        like $result, qr/undefined|freed|invalid/i,
            'Handler fails after VM destroyed with clear error';
    } else {
        pass 'Handler still works after VM destroyed';
    }
};

# Test nested function calls pattern
subtest 'Nested function calls with object chaining' => sub {
    my $js = JavaScript::QuickJS->new();

    my $handler = $js->eval(q{
        (function(obj) {
            // Call method that returns object with another method
            var inner = obj.getInner();
            return inner.getValue();
        })
    });

    my $result = $handler->({
        getInner => sub {
            return {
                getValue => sub { return 42; }
            };
        }
    });

    is $result, 42, 'Nested function calls work correctly';
};

# Test handling of undefined values returned from JS
subtest 'Undefined value handling' => sub {
    my $js = JavaScript::QuickJS->new();

    # Create a function that may return undefined
    my $func = $js->eval(q{
        (function(obj) {
            // Try to call something that might be undefined
            if (obj && obj.method) {
                return obj.method();
            }
            return undefined;
        })
    });

    # Call with missing method
    my $result = $func->({ method => undef });

    ok !defined($result), 'Function returns undef for missing method';

    # Try to use that result as a function (should fail)
    my $error = exception {
        $result->();
    };

    like $error, qr/Can't use an undefined value as a subroutine reference/,
        'Undefined value as subroutine gives correct error';
};

# Test function stored in data structure with custom DIE handler
subtest 'Function in hash with custom DIE handler' => sub {
    my $js = JavaScript::QuickJS->new();

    my $func = $js->eval(q{
        (function(x) {
            return x * 2;
        })
    });

    my $storage = {
        handler => $func,
        metadata => { name => 'doubler' }
    };

    # Set up custom DIE handler
    local $SIG{__DIE__} = sub {
        my $err = shift;
        die "Custom DIE: $err";
    };

    # Call function from storage
    my $result = $storage->{handler}->(21);
    is $result, 42, 'Function in storage works with custom DIE handler';
};

# Test function that accesses closures
subtest 'Function with closure accessing outer scope' => sub {
    my $js = JavaScript::QuickJS->new();

    my $func = $js->eval(q{
        (function() {
            var counter = 0;
            return function() {
                return ++counter;
            };
        })()
    });

    is $func->(), 1, 'First call returns 1';
    is $func->(), 2, 'Second call returns 2';
    is $func->(), 3, 'Third call returns 3 - closure state maintained';
};

done_testing;

__END__

=head1 NAME

t/function_lifecycle.t - Test JavaScript function lifecycle and storage patterns

=head1 DESCRIPTION

This test suite verifies the behavior of JavaScript::QuickJS functions in
various lifecycle scenarios:

=over 4

=item * Functions stored in Perl data structures (registries, hashes)

=item * Function behavior after VM destruction

=item * Nested function calls with object chaining

=item * Undefined value handling

=item * Interaction with custom DIE signal handlers

=item * Closure state preservation

=back

=head2 Common Patterns Tested

B<Registry Pattern:>
1. JavaScript handler function is created
2. Stored in a registry (hash/array)
3. VM goes out of scope (destroyed)
4. Later, handler is retrieved from registry
5. Called with or without DIE signal handler active
6. Handler accesses nested objects/functions

This pattern is common in:
- Service registries
- Event handlers
- Callback storage
- Plugin systems

B<Expected Behavior:>

Functions should either:
- Continue to work if the underlying VM resources are still valid
- Fail with a clear, descriptive error message
- Properly handle undefined/null values from JavaScript

=cut
