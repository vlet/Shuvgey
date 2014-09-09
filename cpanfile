requires 'perl', '5.008005';
requires 'AnyEvent';
requires 'Plack';
requires 'Net::SSLeay', '1.56';
requires 'Protocol::HTTP2', '0.11';
requires 'URI::Escape';
requires 'Sys::Hostname';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
