# NAME

Shuvgey - AnyEvent HTTP/2 (draft 12) Server for PSGI

# SYNOPSIS

    shuvgey --listen :8000 --tls_key=cert.key --tls_crt=cert.crt app.psgi

# DESCRIPTION

Shuvgey is a lightweight non-blocking, single-threaded HTTP/2 (draft 12) Server
that runs PSGI applications on top of [AnyEvent](https://metacpan.org/pod/AnyEvent) event loop.

Shuvgey use [Protocol::HTTP2](https://metacpan.org/pod/Protocol::HTTP2) for HTTP/2 support. Supported plain text HTTP/2
connections, HTTP/1.1 Upgrade, and secure TLS connections (with ALPN/NPN
protocol negotiation).

# STATUS

It's just prototype. But work started... 😉

# NAMING

There is a wellknown python non-blocking, single-threaded HTTP server Tornado.

Shuvgey is the collective name of evil forces in Komi-Zyryan and Komi-Perm
folklore. Materialized in the form of a strong wind vortex. See also wikipedia
article
[Шувгей](http://ru.wikipedia.org/wiki/%D0%A8%D1%83%D0%B2%D0%B3%D0%B5%D0%B9) (in
russian).

So Shuvgey is like Tornado, but more scary: written in Perl and support HTTP/2
protocol.

# LICENSE

Copyright (C) Vladimir Lettiev.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Vladimir Lettiev <thecrux@gmail.com>
