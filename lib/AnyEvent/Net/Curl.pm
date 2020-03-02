package AnyEvent::Net::Curl;

use strict;
use warnings qw( all );
use feature qw( state );

use AE ();
use Carp ();
use Net::Curl::Easy ();
use Net::Curl::Multi ();
use Net::Curl::Share ();

use AnyEvent::Net::Curl::Result ();

use base Exporter::;
our @EXPORT = qw( curl_request );

=head1 NAME

AnyEvent::Net::Curl - thin wrapper around Net::Curl

=head1 SYNOPSIS

    use AnyEvent::Net::Curl;
    my $cv = AE::cv;
    $cv->begin;
    curl_request GET => 'https://google.com',
        verbose => 1,
        sub {
            my ( $res ) = @_;
            print $res->raw_headers;
            $cv->end;
        };
    $cv->recv;

=head1 DESCRIPTION

Minimalistic glue between L<AnyEvent> and L<Net::Curl>.

=head1 METHODS

=head2 curl_request $http_verb, $url, %options, on_success => sub { ... }

WIP

=cut

sub curl_request ( $$@ ) {
    my $cb = pop;
    Carp::croak "last argument to curl_request must be a CODE reference!\n"
        if 'CODE' ne ref $cb;

    my ( $method, $url, %args ) = @_;

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

    no strict 'refs';
    state $curlopt = {
        map { lc s/^ CURLOPT_//rx => &{ "Net::Curl::Easy::$_" } }
        grep { /^ CURLOPT_/x && defined &{ "Net::Curl::Easy::$_" } }
        keys %Net::Curl::Easy::
    };
    use strict 'refs';

    # silently ignored for everything except POST
    my $content = delete $args{body} // '';

    my $easy = Net::Curl::Easy->new;
    my $body = '';
    my $header = '';

    # request type
    $method = uc $method;
    if ( $method eq 'GET' ) {
        $easy->setopt( Net::Curl::Easy::CURLOPT_HTTPGET     => 1 );
    } elsif ( $method eq 'POST' ) {
        $easy->setopt( Net::Curl::Easy::CURLOPT_POST        => 1 );
        $easy->setopt( Net::Curl::Easy::CURLOPT_POSTFIELDS  => $content );
        $easy->setopt( Net::Curl::Easy::CURLOPT_POSTFIELDSIZE => length $content );
    } elsif ( $method eq 'HEAD' ) {
        $easy->setopt( Net::Curl::Easy::CURLOPT_NOBODY      => 1 );
    } elsif ( $method eq 'DELETE' ) {
        $easy->setopt( Net::Curl::Easy::CURLOPT_CUSTOMREQUEST => $method );
    } elsif ( $method eq 'PUT' ) {
        Carp::croak "$method method not implemented (yet)\n";
    } else {
        Carp::croak "Unknown HTTP method: $method\n";
    }

    my %opts = (
        # ol' reliable
        autoreferer     => 1,
        encoding        => '',
        followlocation  => 1,
        maxredirs       => 7,

        # timeouts
        connecttimeout  => 10,
        low_speed_limit => 30, # abort if slower than 30 bytes/sec
        low_speed_time  => 60, # during 60 seconds

        # references
        share           => $share,
        url             => $url,
        writedata       => \$body,
        writeheader     => \$header,

        # custom
        %args,
    );

    for my $opt ( keys %opts ) {
        my $opt_code = $curlopt->{ lc $opt };
        Carp::croak "Unknown option CURLOPT_\U$opt\n" unless $opt_code;
        $easy->setopt( $opt_code => $opts{ $opt } );
    }

    my ( $socket_action, $callback ) = _socket_action_wrapper( $multi );
    $callback->{ $easy } = sub {
        my ( $result ) = @_;
        $cb->( AnyEvent::Net::Curl::Result->new( {
            easy    => $easy,
            result  => $result,
            header  => $header,
            body    => $body,
        } ) );
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
            Carp::croak "I don't know what to do with message $msg.\n"
                if $msg != Net::Curl::Multi::CURLMSG_DONE;
            $multi->remove_handle( $easy );
            $callback->{ $easy }->( $result );
            delete $callback->{ $easy };
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

1;

=pod

=head1 AUTHOR

Stanislaw Pusep <stas@sysd.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2020 by Stanislaw Pusep.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
