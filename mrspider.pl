#!/usr/bin/env perl
use strict;
use warnings qw( all );
use feature qw( say state );

use AE ();
use Carp ();
use EV ();
use Net::Curl::Easy ();
use Net::Curl::Multi ();
use Net::Curl::Share ();

sub easy_gen ( $&& ) {
    my ( $url, $cb_success, $cb_error ) = @_;

    state $share = do {
        my $s = Net::Curl::Share->new({ stamp => time });
        $s->setopt( Net::Curl::Share::CURLSHOPT_SHARE   => Net::Curl::Share::CURL_LOCK_DATA_COOKIE );
        $s->setopt( Net::Curl::Share::CURLSHOPT_SHARE   => Net::Curl::Share::CURL_LOCK_DATA_DNS );
        $s->setopt( Net::Curl::Share::CURLSHOPT_SHARE   => Net::Curl::Share::CURL_LOCK_DATA_SSL_SESSION );
        $s;
    };

    state $multi = do {
        my $m = Net::Curl::Multi->new;
        $m->setopt( Net::Curl::Multi::CURLMOPT_SOCKETFUNCTION   => \&_cb_socket);
        $m->setopt( Net::Curl::Multi::CURLMOPT_TIMERFUNCTION    => \&_cb_timer);
        $m;
    };

    my $easy = Net::Curl::Easy->new;
    my $body = '';
    my $header = '';

    $easy->setopt( Net::Curl::Easy::CURLOPT_CONNECTTIMEOUT  => 10 );
    $easy->setopt( Net::Curl::Easy::CURLOPT_ENCODING        => '' );
    $easy->setopt( Net::Curl::Easy::CURLOPT_FOLLOWLOCATION  => 1 );
    $easy->setopt( Net::Curl::Easy::CURLOPT_LOW_SPEED_LIMIT => 30 ); # abort if slower than 30 bytes/sec
    $easy->setopt( Net::Curl::Easy::CURLOPT_LOW_SPEED_TIME  => 60 ); # during 60 seconds
    $easy->setopt( Net::Curl::Easy::CURLOPT_SHARE           => $share );
    $easy->setopt( Net::Curl::Easy::CURLOPT_URL             => $url );
    $easy->setopt( Net::Curl::Easy::CURLOPT_USERAGENT       => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15' );
    # $easy->setopt( Net::Curl::Easy::CURLOPT_VERBOSE         => 1 );
    $easy->setopt( Net::Curl::Easy::CURLOPT_WRITEDATA       => \$body );
    $easy->setopt( Net::Curl::Easy::CURLOPT_WRITEHEADER     => \$header );

    my ( $socket_action, $callback ) = _socket_action_wrapper( $multi );
    $callback->{ $easy } = sub {
        my ( $result ) = @_;
        if ( $result == Net::Curl::Easy::CURLE_OK ) {
            $cb_success->( $easy, $header, $body );
        } else {
            $cb_error->( $easy, $result );
        }
    };

    $multi->add_handle( $easy );
    AE::postpone { $socket_action->() };

    return $easy;
}

sub _socket_action_wrapper {
    my ( $multi ) = @_;

    state $callback = {};

    $multi->{_active} //= -1;
    my $socket_action = sub {
        my $active = $multi->socket_action( @_ );
        return if $multi->{_active} == $active;
        $multi->{_active} = $active;

        while ( my ( $msg, $easy, $result ) = $multi->info_read ) {
            if ( $msg == Net::Curl::Multi::CURLMSG_DONE ) {
                $multi->remove_handle( $easy );
                $callback->{ $easy }->( $result );
                delete $callback->{ $easy };
            } else {
                Carp::croak "I don't know what to do with message $msg.\n";
            }
        }
    };

    return ( $socket_action, $callback );
}

# socket callback: will be called by curl any time events on some
# socket must be updated
sub _cb_socket {
    my ( $multi, undef, $socketfn, $action ) = @_;

    # Right now $socketfn belongs to that $easy, but it can be
    # shared with another easy handle if server supports persistent
    # connections.
    # This is why we register socket events inside multi object
    # and not $easy.

    # AnyEvent does not support registering a socket for both
    # reading and writing. This is rarely used so there is no
    # harm in separating the events.

    my $keep = 0;
    state $pool = {};

    my ( $socket_action ) = _socket_action_wrapper( $multi );

    # register read event
    if ( $action & Net::Curl::Multi::CURL_POLL_IN ) {
        $pool->{ "r$socketfn" } = AE::io $socketfn, 0, sub {
            $socket_action->( $socketfn, Net::Curl::Multi::CURL_CSELECT_IN );
        };
        ++$keep;
    }

    # register write event
    if ( $action & Net::Curl::Multi::CURL_POLL_OUT ) {
        $pool->{ "w$socketfn" } = AE::io $socketfn, 1, sub {
            $socket_action->( $socketfn, Net::Curl::Multi::CURL_CSELECT_OUT );
        };
        ++$keep;
    }

    # deregister old io events
    unless ($keep) {
        delete $pool->{ "r$socketfn" };
        delete $pool->{ "w$socketfn" };
    }

    return 1;
}

# timer callback: It triggers timeout update. Timeout value tells
# us how soon socket_action must be called if there were no actions
# on sockets. This will allow curl to trigger timeout events.
sub _cb_timer {
    my ( $multi, $timeout_ms ) = @_;

    # deregister old timer
    delete $multi->{_timer};

    my ( $socket_action ) = _socket_action_wrapper( $multi );
    my $cb_timeout = sub {
        $socket_action->( Net::Curl::Multi::CURL_SOCKET_TIMEOUT )
    };

    if ( $timeout_ms < 0 ) {
        # Negative timeout means there is no timeout at all.
        # Normally happens if there are no handles anymore.
        #
        # However, curl_multi_timeout(3) says:
        #
        # Note: if libcurl returns a -1 timeout here, it just means
        # that libcurl currently has no stored timeout value. You
        # must not wait too long (more than a few seconds perhaps)
        # before you call curl_multi_perform() again.

        $multi->{_timer} = AE::timer 10, 10, $cb_timeout;
    } else {
        # This will trigger timeouts if there are any.
        $multi->{_timer} = AE::timer $timeout_ms / 1000, 0, $cb_timeout;
    }

    return 1;
}

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
        easy_gen
            $url,
            sub {
                my ( $easy, $hdr, $body ) = @_;
                say $easy->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
                # say $hdr;
                $cv->end;
            },
            sub {
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
