#!/usr/bin/env perl
use strict;
use warnings qw( all );
use feature qw( say );

use lib qw( lib );

use AnyEvent::Net::Curl;
use EV;

sub main {
    my $cv = AE::cv;

    my @urls = qw(
        https://google.com/
        https://sysd.org/
        https://sysd.org/favicon.gif
        https://sysd.org/favicon.ico
        https://sysd.org/google785d2c90164ceee4.html
        https://sysd.org/robots.txt
    );

    for my $url ( @urls ) {
        $cv->begin;
        curl_request GET => $url,
            # proxy           => 'socks5://127.0.0.1:9050',
            useragent       => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15',
            # verbose         => 1,
            on_success => sub {
                my ( $easy, $hdr, $body ) = @_;
                say $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
                # say $hdr;
                $cv->end;
            },
            on_error => sub {
                my ( $easy, $result ) = @_;
                if ( $result == Net::Curl::Easy::CURLE_OPERATION_TIMEDOUT ) {
                    say "TIMEOUT\t", $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
                } else {
                    say "$result\t", $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
                }
                $cv->end;
            };
    }

    $cv->recv;
    return 0;
}

exit main( @ARGV );
