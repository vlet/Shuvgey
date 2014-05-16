package Shuvgey::Server;
use strict;
use warnings;
use Net::SSLeay;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::TLS;
use Protocol::HTTP2;
use Protocol::HTTP2::Constants qw(const_name);
use Protocol::HTTP2::Server;
use Data::Dumper;
use URI::Escape qw(uri_unescape);

use constant {
    TRUE  => !undef,
    FALSE => !!undef,

    STOP => exists $ENV{SHUVGEY_DEBUG},

    # Log levels
    DEBUG     => 0,
    INFO      => 1,
    NOTICE    => 2,
    WARNING   => 3,
    ERROR     => 4,
    CRITICAL  => 5,
    ALERT     => 6,
    EMERGENCY => 7,
};

my $start_time = AnyEvent->now;

sub talk($$) {
    if ( shift() >= $ENV{SHUVGEY_DEBUG} ) {
        my $message = shift;
        chomp($message);
        $message =~ s/\n/\n           /g;

        printf "[%05.3f] %s\n", AnyEvent->now - $start_time, $message;
    }
}

sub new {
    my $class = shift;
    bless {@_}, $class;
}

sub run {
    my ( $self, $app ) = @_;

    STOP and talk DEBUG, Dumper($self);

    my ( $host, $port );
    if ( $self->{listen} ) {
        ( $self->{host}, $self->{port} ) = split /:/,
          shift @{ $self->{listen} };
    }

    $host = $self->{host} || undef;
    $port = $self->{port} || undef;

    $self->{exit} = AnyEvent->condvar;

    $self->run_tcp_server( $app, $host, $port );

    my $recv = $self->{exit}->recv;
    STOP and talk INFO, $recv;
}

sub run_tcp_server {
    my ( $self, $app, $host, $port ) = @_;

    tcp_server $host, $port, sub {

        my ( $fh, $peer_host, $peer_port ) = @_;

        my $tls = $self->create_tls or return;

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh       => $fh,
            autocork => 1,
            tls      => "accept",
            tls_ctx  => $tls,
            on_error => sub {
                $_[0]->destroy;
                STOP and talk ERROR, "connection error";
            },
            on_eof => sub {
                $handle->destroy;
            }
        );

        my $server;
        $server = Protocol::HTTP2::Server->new(
            on_change_state => sub {
                my ( $stream_id, $previous_state, $current_state ) = @_;
            },
            on_error => sub {
                my $error = shift;
                STOP and talk
                  ERROR,
                  sprintf "Error occured: %s\n",
                  const_name( "errors", $error );
            },
            on_request => sub {
                my ( $stream_id, $headers, $data ) = @_;

                my $env =
                  $self->psgi_env( $host, $port, $peer_host, $peer_port,
                    $headers, $data );

                my $response = eval { $app->($env) }
                  || $self->internal_error($@);

                # TODO: support for CODE
                if ( ref $response ne 'ARRAY' ) {
                    $response = $self->internal_error(
                        "PSGI CODE response not supported yet");
                }

                my $body;

                if ( ref $response->[2] eq 'ARRAY' ) {
                    $body = join '', @{ $response->[2] };
                }
                elsif ( ref $response->[2] eq 'GLOB' ) {
                    local $/ = \4096;
                    $body = '';
                    while ( defined( my $chunk = $response->[2]->getline ) ) {
                        $body .= $chunk;
                    }
                }
                else {
                    STOP and talk INFO, Dumper $response->[2];
                    $response =
                      $self->internal_error( "body ref type "
                          . ( ref $response->[2] )
                          . " not supported yet" );
                }

                my @h = ();
                for my $h ( @{ $response->[1] } ) {
                    STOP and talk INFO, $h;
                    push @h, "$h";
                }

                $server->response(
                    stream_id => $stream_id,
                    ':status' => $response->[0],
                    headers   => \@h,
                    data      => $body,
                );
            },
        );

        # First send settings to peer
        while ( my $frame = $server->next_frame ) {
            $handle->push_write($frame);
        }

        $handle->on_read(
            sub {
                my $handle = shift;

                $server->feed( $handle->{rbuf} );

                $handle->{rbuf} = undef;
                while ( my $frame = $server->next_frame ) {
                    $handle->push_write($frame);
                }
                $handle->push_shutdown if $server->shutdown;
            }
        );
      },

      # Bound to host:port
      sub {
        ( undef, $host, $port ) = @_;
        STOP and talk NOTICE, "Ready to serve request\n";

        # For Plack::Runner
        $self->{server_ready}->(
            {
                host            => $host,
                port            => $port,
                server_software => 'Shuvgey',
            }
        ) if $self->{server_ready};
        return TRUE;
      };

    return TRUE;
}

sub create_tls {
    my $self = shift;
    my $tls;
    eval {
        Net::SSLeay::initialize();
        my $ctx = Net::SSLeay::CTX_tlsv1_new() or die $!;
        Net::SSLeay::CTX_set_options( $ctx, &Net::SSLeay::OP_ALL );
        Net::SSLeay::set_cert_and_key( $ctx, $self->{tls_crt},
            $self->{tls_key} );

        # NPN  (Net-SSLeay > 1.45, openssl >= 1.0.1)
        Net::SSLeay::CTX_set_next_protos_advertised_cb( $ctx,
            [Protocol::HTTP2::ident_tls] );

        # ALPN (Net-SSLeay > 1.55, openssl >= 1.0.2)
        #Net::SSLeay::CTX_set_alpn_select_cb( $ctx,
        #    [ Protocol::HTTP2::ident_tls ] );
        $tls = AnyEvent::TLS->new_from_ssleay($ctx);
    };
    $self->finish("Some problem with SSL CTX: $@\n") if $@;
    return $tls;
}

sub finish {
    shift->{exit}->send(shift);
}

sub psgi_env {
    my ( $self, $host, $port, $peer_host, $peer_port, $headers, $data ) = @_;

    my $input;
    open $input, '<', \$data if defined $data;

    my $env = {
        'psgi.version'      => [ 1, 1 ],
        'psgi.input'        => $input,
        'psgi.errors'       => *STDERR,
        'psgi.multithread'  => FALSE,
        'psgi.multiprocess' => FALSE,
        'psgi.run_once'     => FALSE,
        'psgi.nonblocking'  => TRUE,
        'psgi.streaming'    => FALSE,
        'SCRIPT_NAME'       => '',
        'SERVER_NAME'       => $host,
        'SERVER_PORT'       => $port,

        # Plack::Middleware::Lint didn't like h2-12 ;-)
        'SERVER_PROTOCOL' => "HTTP/1.1",

        # This not in PSGI spec. Why not?
        'REMOTE_HOST' => $peer_host,
        'REMOTE_ADDR' => $peer_host,
        'REMOTE_PORT' => $peer_port,
    };

    for my $i ( 0 .. @$headers / 2 - 1 ) {
        my ( $h, $v ) = ( $headers->[ $i * 2 ], $headers->[ $i * 2 + 1 ] );
        if ( $h eq ':method' ) {
            $env->{REQUEST_METHOD} = $v;
        }
        elsif ( $h eq ':scheme' ) {
            $env->{'psgi.url_scheme'} = $v;
        }
        elsif ( $h eq ':path' ) {
            $env->{REQUEST_URI} = $v;
            my ( $path, $query ) = ( $v =~ /^([^?]*)\??(.*)?$/s );
            $env->{QUERY_STRING} = $query || '';
            $env->{PATH_INFO} = uri_unescape($path);
        }
        elsif ( $h eq ':authority' ) {

            #TODO: what to do with :authority?
        }
        elsif ( $h eq 'content-length' ) {
            $env->{CONTENT_LENGTH} = $v;
        }
        elsif ( $h eq 'content-type' ) {
            $env->{CONTENT_TYPE} = $v;
        }
        else {
            my $header = 'HTTP_' . uc($h);
            if ( exists $env->{$header} ) {
                $env->{$header} .= ', ' . $v;
            }
            else {
                $env->{$header} = $v;
            }
        }
    }
    @$headers = ();
    STOP and talk INFO, Dumper($env);
    return $env;
}

sub internal_error {
    my ( $self, $error ) = @_;

    my $message = "500 - Internal Server Error";
    STOP and talk ERROR, "$message: $error\n";

    return [
        500,
        [
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($message)
        ],
        [$message]
    ];
}

1;
