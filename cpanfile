requires 'perl', '5.008005';
requires 'AnyEvent';
requires 'Plack';
requires 'Net::SSLeay', '> 1.45';
requires 'Protocol::HTTP2', '0.06';
requires 'URI::Escape';

on 'test' => sub {
    requires 'Test::More', '0.98';
};
