package Shuvgey::Server;
use strict;
use warnings;
use Net::SSLeay;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::TLS;
use Protocol::HTTP2::Constants qw(const_name);
use Protocol::HTTP2::Server;
use Data::Dumper;

use constant {
    TRUE  => !undef,
    FALSE => !!undef,
    DEBUG => $ENV{SHUVGEY_DEBUG},
};

my $start_time = AnyEvent->now;

sub debug {
    return unless DEBUG;

    if ( shift() <= DEBUG ) {
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

    debug( 5, Dumper($self) );

    my ( $host, $port );
    if ( $self->{listen} ) {
        ( $self->{host}, $self->{port} ) = split /:/,
          shift @{ $self->{listen} };
    }

    $host = $self->{host} || undef;
    $port = $self->{port} || undef;

    $self->{exit} = AnyEvent->condvar;

    $self->run_tcp_server( $host, $port );

    my $recv = $self->{exit}->recv;
    debug( 5, $recv );
}

sub run_tcp_server {
    my ( $self, $host, $port ) = @_;

    tcp_server $host, $port, sub {

        my ( $fh, $host, $port ) = @_;

        my $tls = $self->create_tls or return;

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh       => $fh,
            autocork => 1,
            tls      => "accept",
            tls_ctx  => $tls,
            on_error => sub {
                $_[0]->destroy;
                debug( 1, "connection error" );
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
                debug(
                    1,
                    sprintf "Error occured: %s\n",
                    const_name( "errors", $error )
                );
            },
            on_request => sub {
                my ( $stream_id, $headers, $data ) = @_;
                my %h = (@$headers);

                # Push promise (must be before response)
                if ( $h{':path'} eq '/minil.toml' ) {
                    $server->push(
                        ':authority' => $host . ':' . $port,
                        ':method'    => 'GET',
                        ':path'      => '/cpanfile',
                        ':scheme'    => 'https',
                        stream_id    => $stream_id,
                    );
                }

                my $message = "hello, world!";
                $server->response(
                    ':status' => 200,
                    stream_id => $stream_id,
                    headers   => [
                        'server'         => 'Shuvgey/0.01',
                        'content-length' => length($message),
                        'cache-control'  => 'max-age=3600',
                        'date'           => 'Fri, 18 Apr 2014 07:27:11 GMT',
                        'last-modified'  => 'Thu, 27 Feb 2014 10:30:37 GMT',
                    ],
                    data => $message,
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

1;
