package Shuvgey;
use 5.008005;
use strict;
use warnings;

our $VERSION = "0.01";

1;
__END__

=encoding utf-8

=head1 NAME

Shuvgey - AnyEvent HTTP/2 (draft 12) Server for PSGI

=head1 SYNOPSIS

    shuvgey --listen :8000 --tls_key=cert.key --tls_crt=cert.crt app.psgi

=head1 DESCRIPTION

Shuvgey is a lightweight non-blocking, single-threaded HTTP/2 (draft 12) Server
that runs PSGI applications on top of L<AnyEvent> event loop.

Shuvgey use L<Protocol::HTTP2> for HTTP/2 support. Supported plain text HTTP/2
connections, HTTP/1.1 Upgrade, and secure TLS connections (with ALPN/NPN
protocol negotiation).

=head1 STATUS

It's just prototype. But work started... 😉

=head1 NAMING

There is a wellknown python non-blocking, single-threaded HTTP server Tornado.

Shuvgey is the collective name of evil forces in Komi-Zyryan and Komi-Perm
folklore. Materialized in the form of a strong wind vortex. See also wikipedia
article
L<Шувгей|http://ru.wikipedia.org/wiki/%D0%A8%D1%83%D0%B2%D0%B3%D0%B5%D0%B9> (in
russian).

So Shuvgey is like Tornado, but more scary: written in Perl and support HTTP/2
protocol.

=head1 LICENSE

Copyright (C) Vladimir Lettiev.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Vladimir Lettiev E<lt>thecrux@gmail.comE<gt>

=cut

