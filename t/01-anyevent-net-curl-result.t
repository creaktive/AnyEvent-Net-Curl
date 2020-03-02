use strict;
use warnings qw( all );

use Test::More tests => 33;
use Test::Exception;

use_ok( 'AnyEvent::Net::Curl::Result' );

my $result = AnyEvent::Net::Curl::Result->new;

isa_ok(
    $result,
    'AnyEvent::Net::Curl::Result',
);

ok(
    ! defined $result->{_header},
    'empty object',
);

my %status = (
    is_info         => 100,
    is_success      => 200,
    is_redirect     => 300,
    is_client_error => 400,
    is_server_error => 500,
);

for my $status ( sort { $status{ $a } <=> $status{ $b } } keys %status ) {
    $result->{_status} = $status{ $status };
    ok( $result->$status, $status );
};

$result = AnyEvent::Net::Curl::Result->new( {
    header  => do { local $/; <DATA> },
} );

isa_ok(
    $result,
    'AnyEvent::Net::Curl::Result',
);

throws_ok
    { $result->url }
    qr/ "getinfo" \s+ on \s+ an \s+ undefined \s+ value /x,
    'easy not initialized';

ok(
    $result->is_curl_error,
    'not CURLE_OK',
);

ok(
    ! exists $result->{_headers_object},
    'lazy _headers_object',
);

ok(
    ! exists $result->{_headers_array},
    'lazy _headers_array',
);

my @header_field_names = $result->header_field_names;
is_deeply(
    \@header_field_names,
    [qw[
        Cache-Control
        Date
        Transfer-Encoding
        Server
        Content-Encoding
        Content-Type
        Expires
        Alt-Svc
        P3P
        Set-Cookie
        X-Frame-Options
        X-Xss-Protection
    ]],
    'header_field_names',
);

ok(
    exists $result->{_headers_object},
    'cached _headers_object',
);

ok(
    exists $result->{_headers_array},
    'cached _headers_array',
);

is(
    $result->headers->header( 'transfer-encoding' ),
    'chunked',
    'transfer-encoding',
);

my %tests = (
    content_is_html         => 1,
    content_is_xhtml        => '',
    content_is_xml          => 0,
    content_type            => 'text/html',
    content_type_charset    => 'ISO-8859-1',
    date                    => 1583170662,
    content_encoding        => 'gzip',
    server                  => 'gws',

    content_language        => undef,
    content_length          => undef,
    expires                 => undef,
    from                    => undef,
    last_modified           => undef,
    referer                 => undef,
    referrer                => undef,
    www_authenticate        => undef,
);

for my $header_name ( sort keys %tests ) {
    is(
        $result->$header_name,
        $tests{ $header_name },
        $header_name,
    );
}

__DATA__
HTTP/1.1 301 Moved Permanently
Location: https://www.google.com/
Content-Type: text/html; charset=UTF-8
Date: Mon, 02 Mar 2020 17:37:42 GMT
Expires: Wed, 01 Apr 2020 17:37:42 GMT
Cache-Control: public, max-age=2592000
Server: gws
Content-Length: 220
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Alt-Svc: quic=":443"; ma=2592000; v="46,43",h3-Q050=":443"; ma=2592000,h3-Q049=":443"; ma=2592000,h3-Q048=":443"; ma=2592000,h3-Q046=":443"; ma=2592000,h3-Q043=":443"; ma=2592000

HTTP/1.1 200 OK
Date: Mon, 02 Mar 2020 17:37:42 GMT
Expires: -1
Cache-Control: private, max-age=0
Content-Type: text/html; charset=ISO-8859-1
P3P: CP="This is not a P3P policy! See g.co/p3phelp for more info."
Content-Encoding: gzip
Server: gws
X-XSS-Protection: 0
X-Frame-Options: SAMEORIGIN
Set-Cookie: 1P_JAR=2020-03-02-17; expires=Wed, 01-Apr-2020 17:37:42 GMT; path=/; domain=.google.com; Secure
Set-Cookie: NID=199=OvHErm0qlgGLrsqRBgP7tn-ewFm4BY6FzQnmi5klDbbOMI-vsgKQpSStTKq6FuUxu59m4ikJrJ5oe4aBwJ_9wFTK-F4G2gdDk10cF87V-J5ccPfl6WtbN-h-ODw3-QjO1HvLy71orDZ6mO4GzDYnucdeXN8bXHxWa5Nis9qygpo; expires=Tue, 01-Sep-2020 17:37:42 GMT; path=/; domain=.google.com; HttpOnly
Alt-Svc: quic=":443"; ma=2592000; v="46,43",h3-Q050=":443"; ma=2592000,h3-Q049=":443"; ma=2592000,h3-Q048=":443"; ma=2592000,h3-Q046=":443"; ma=2592000,h3-Q043=":443"; ma=2592000
Transfer-Encoding: chunked

