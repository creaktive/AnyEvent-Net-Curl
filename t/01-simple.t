use strict;
use warnings qw( all );

use AnyEvent::Net::Curl;
use Test::HTTP::AnyEvent::Server;

use Test::More tests => 21;

my $server = Test::HTTP::AnyEvent::Server->new;
isa_ok( $server, 'Test::HTTP::AnyEvent::Server' );

my $cv = AE::cv;

$cv->begin;
curl_request GET => $server->uri . 'echo/head',
    # verbose => 1,
    on_success => sub {
        my ( $easy, $hdr, $body ) = @_;

        isa_ok( $easy, 'Net::Curl::Easy' );
        like(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ),
            qr{ /echo/head $ }x,
            'GET /echo/head - CURLINFO_EFFECTIVE_URL',
        );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ),
            200,
            'GET /echo/head - CURLINFO_RESPONSE_CODE is 200',
        );
        like(
            $hdr,
            qr{^ HTTP/\d\.\d \s+ 200 \s+ OK }x,
            'GET /echo/head - header response is also 200 OK',
        );
        like(
            $body,
            qr{^ GET \s+ /echo/head \s+ HTTP/\d\.\d }x,
            'GET /echo/head - request was a GET',
        );

        $cv->end;
    };

$cv->begin;
my $post_body = 'quick brown fox jumps over a lazy dog';
curl_request POST => $server->uri . 'echo/body',
    # verbose => 1,
    body => $post_body,
    on_success => sub {
        my ( $easy, $hdr, $body ) = @_;

        isa_ok( $easy, 'Net::Curl::Easy' );
        like(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ),
            qr{ /echo/body $ }x,
            'POST /echo/body - CURLINFO_EFFECTIVE_URL',
        );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ),
            200,
            'POST /echo/body - CURLINFO_RESPONSE_CODE is 200',
        );
        like(
            $hdr,
            qr{^ HTTP/\d\.\d \s+ 200 \s+ OK }x,
            'POST /echo/body - header response is also 200 OK',
        );
        is(
            $body,
            $post_body,
            'POST /echo/body - request was a POST',
        );

        $cv->end;
    };

$cv->begin;
curl_request GET => $server->uri . 'hurrdurr',
    # verbose => 1,
    on_success => sub {
        my ( $easy, $hdr, $body ) = @_;

        isa_ok( $easy, 'Net::Curl::Easy' );
        like(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ),
            qr{ /hurrdurr $ }x,
            'GET /hurrdurr - CURLINFO_EFFECTIVE_URL',
        );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ),
            404,
            'GET /hurrdurr - CURLINFO_RESPONSE_CODE is 404',
        );
        like(
            $hdr,
            qr{^ HTTP/\d\.\d \s+ 404 \s+ Not \s+ Found }x,
            'GET /hurrdurr - GET /hurrdurr - header response is also 404 Not Found',
        );
        is(
            $body,
            'Not Found',
            'GET /hurrdurr - body is Not Found',
        );

        $cv->end;
    };

$cv->begin;
curl_request HEAD => $server->uri,
    # verbose => 1,
    on_success => sub {
        my ( $easy, $hdr, $body ) = @_;

        note 'It is expected for Test::HTTP::AnyEvent::Server to complain about bad request';

        isa_ok( $easy, 'Net::Curl::Easy' );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ),
            $server->uri,
            'HEAD / - CURLINFO_EFFECTIVE_URL',
        );
        is(
            $easy->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ),
            400,
            'HEAD / - CURLINFO_RESPONSE_CODE is 400',
        );
        like(
            $hdr,
            qr{^ HTTP/\d\.\d \s+ 400 \s+ Bad \s+ Request }x,
            'HEAD / - header response is also 400 Bad Request',
        );
        is(
            $body,
            '',
            'HEAD / - body is empty',
        );

        $cv->end;
    };

$cv->recv;
