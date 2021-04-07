#!/usr/bin/env perl
use strict;
use warnings qw( all );
use feature qw( say state );

use lib qw( lib );

use AnyEvent::Net::Curl qw( curl_request );
use Carp ();
use EV ();

{
    my $active = 0;
    sub active_connections { $active }
    sub connections_cap ($) { $active >= shift }
    sub fetch_url ($) {
        my ( $url ) = @_;
        ++$active;
        curl_request GET => $url,
            # proxy           => 'socks5://127.0.0.1:9050',
            useragent       => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15',
            verbose         => 1,
            sub {
                my ( $res ) = @_;
                say $res->url;
                --$active;
                # say $res->raw_headers;
            };
    }
}

sub url_iterator {
    state $fh = do {
        open my $h, '<', 'urls.txt';
        $h;
    };
    return unless $fh;
    if ( my $url = <$fh> ) {
        chomp $url;
        return $url;
    } else {
        close $fh;
        undef $fh;
        return;
    }
}

sub main {
    my $cv = AE::cv;
    my $t = AE::timer 0, .01, sub {
        return if connections_cap 8;
        if ( my $url = url_iterator ) {
            fetch_url $url;
        } elsif ( ! active_connections ) {
            $cv->send;
        } else {
            # waiting for active_connections to drain
        }
    };
    $cv->recv;
    return 0;
}

exit main( @ARGV );
