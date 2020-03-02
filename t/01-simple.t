use strict;
use warnings qw( all );

use AnyEvent::Net::Curl;
use Test::HTTP::AnyEvent::Server;

use Test::More tests => 36;
use Test::Exception;

my $server = Test::HTTP::AnyEvent::Server->new;
isa_ok( $server, 'Test::HTTP::AnyEvent::Server' );

my $cv = AE::cv;

throws_ok {
    curl_request GET => $server->uri;
} qr{^ last \s+ argument \s+ to \s+ curl_request \s+ must \s+ be \s+ a \s+ CODE \s+ reference }x,
    'missing callback';

throws_ok {
    curl_request PUT => $server->uri, sub { ... };
} qr{^ PUT \s+ method \s+ not \s+ implemented }x,
    'PUT method';

throws_ok {
    curl_request GET => $server->uri,
        wubbalubbadubdub => 123,
        sub { ... };
} qr{^ Unknown \s+ option \s+ CURLOPT_WUBBALUBBADUBDUB }x,
    'bad CURLOPT';

throws_ok {
    curl_request OOPS => $server->uri,
        sub { ... };
} qr{^ Unknown \s+ HTTP \s+ method: \s+ OOPS }x,
    'bad method';

$cv->begin;
curl_request GET => $server->uri . 'echo/head',
    # verbose => 1,
    sub {
        my ( $res ) = @_;

        isa_ok( $res, 'AnyEvent::Net::Curl::Result' );
        like(
            $res->url,
            qr{ /echo/head $ }x,
            'GET /echo/head - CURLINFO_EFFECTIVE_URL',
        );
        ok(
            $res->is_success,
            'GET /echo/head - is_success',
        );
        is(
            $res->status,
            200,
            'GET /echo/head - CURLINFO_RESPONSE_CODE is 200',
        );
        is(
            $res->content_length,
            -1,
            "GET /echo/head - Content-Length is unset",
        );
        is(
            $res->content_type,
            'text/plain',
            "GET /echo/head - Content-Type is text/plain",
        );
        like(
            $res->raw_headers,
            qr{^ HTTP/\d\.\d \s+ 200 \s+ OK }x,
            'GET /echo/head - header response is also 200 OK',
        );
        like(
            $res->raw_body,
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
    sub {
        my ( $res ) = @_;

        isa_ok( $res, 'AnyEvent::Net::Curl::Result' );
        like(
            $res->url,
            qr{ /echo/body $ }x,
            'POST /echo/body - CURLINFO_EFFECTIVE_URL',
        );
        ok(
            $res->is_success,
            'GET /echo/body - is_success',
        );
        is(
            $res->status,
            200,
            'POST /echo/body - CURLINFO_RESPONSE_CODE is 200',
        );
        like(
            $res->raw_headers,
            qr{^ HTTP/\d\.\d \s+ 200 \s+ OK }x,
            'POST /echo/body - header response is also 200 OK',
        );
        is(
            $res->raw_body,
            $post_body,
            'POST /echo/body - request was a POST',
        );

        $cv->end;
    };

$cv->begin;
curl_request GET => $server->uri . 'hurrdurr',
    # verbose => 1,
    sub {
        my ( $res ) = @_;

        isa_ok( $res, 'AnyEvent::Net::Curl::Result' );
        like(
            $res->url,
            qr{ /hurrdurr $ }x,
            'GET /hurrdurr - CURLINFO_EFFECTIVE_URL',
        );
        ok(
            $res->is_error,
            'GET /hurrdurr - is_error',
        );
        ok(
            $res->is_client_error,
            'GET /hurrdurr - is_client_error',
        );
        is(
            $res->status,
            404,
            'GET /hurrdurr - CURLINFO_RESPONSE_CODE is 404',
        );
        like(
            $res->raw_headers,
            qr{^ HTTP/\d\.\d \s+ 404 \s+ Not \s+ Found }x,
            'GET /hurrdurr - GET /hurrdurr - header response is also 404 Not Found',
        );
        is(
            $res->raw_body,
            'Not Found',
            'GET /hurrdurr - body is Not Found',
        );

        $cv->end;
    };

$cv->begin;
curl_request HEAD => $server->uri,
    # verbose => 1,
    sub {
        my ( $res ) = @_;

        note 'It is expected for Test::HTTP::AnyEvent::Server to complain about bad request';

        isa_ok( $res, 'AnyEvent::Net::Curl::Result' );
        is(
            $res->url,
            $server->uri,
            'HEAD / - CURLINFO_EFFECTIVE_URL',
        );
        ok(
            $res->is_error,
            'HEAD / - is_error',
        );
        ok(
            $res->is_client_error,
            'HEAD / - is_client_error',
        );
        is(
            $res->status,
            400,
            'HEAD / - CURLINFO_RESPONSE_CODE is 400',
        );
        like(
            $res->raw_headers,
            qr{^ HTTP/\d\.\d \s+ 400 \s+ Bad \s+ Request }x,
            'HEAD / - header response is also 400 Bad Request',
        );
        is(
            $res->raw_body,
            '',
            'HEAD / - body is empty',
        );

        $cv->end;
    };

$cv->begin;
curl_request DELETE => 'http://0.0.0.0/',
    # verbose => 1,
    sub {
        my ( $res ) = @_;

        isa_ok( $res, 'AnyEvent::Net::Curl::Result' );
        is(
            $res->status,
            undef,
            'DELETE http://0.0.0.0/ - status NOT set',
        );
        ok(
            $res->is_error,
            'DELETE http://0.0.0.0/ - is_error',
        );

        $cv->end;
    };

$cv->recv;
