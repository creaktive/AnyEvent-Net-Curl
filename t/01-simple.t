use strict;
use warnings qw( all );

use AnyEvent::Net::Curl;
use Test::HTTP::AnyEvent::Server;

use Test::More tests => 6;

my $server = Test::HTTP::AnyEvent::Server->new;
isa_ok( $server, 'Test::HTTP::AnyEvent::Server' );

my $cv = AE::cv;
curl_request GET => $server->uri . 'echo/head',
    # verbose => 1,
    on_success => sub {
        my ( $easy, $hdr, $body ) = @_;

        isa_ok( $easy, 'Net::Curl::Easy' );
        like(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ),
            qr{ /echo/head $ }x,
            'CURLINFO_EFFECTIVE_URL',
        );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ),
            200,
            'CURLINFO_RESPONSE_CODE is 200',
        );
        like(
            $hdr,
            qr{^ HTTP/\d\.\d \s+ 200 \s+ OK }x,
            'header response is also 200 OK',
        );
        like(
            $body,
            qr{^ GET \s+ /echo/head \s+ HTTP/\d\.\d }x,
            'request was a GET',
        );

        $cv->send;
    };
$cv->recv;
