package AnyEvent::Net::Curl::Result;

use strict;
use warnings qw( all );

use Net::Curl::Easy ();

sub new {
    my ( $class, $args ) = @_;
    return bless {
        _easy   => $args->{easy},
        _result => $args->{result},
        _header => $args->{header},
        _body   => $args->{body},
    }, $class;
}

sub is_success {
    return ( $_[0]->{_result} // -1 ) == Net::Curl::Easy::CURLE_OK;
}

sub is_timeout {
    return ( $_[0]->{_result} // -1 ) == Net::Curl::Easy::CURLE_OPERATION_TIMEDOUT;
}

sub raw_headers {
    return $_[0]->{_header};
}

sub raw_body {
    return $_[0]->{_body};
}

sub curl_result {
    return $_[0]->{_result};
}

sub code {
    return $_[0]->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE );
}

sub url {
    return $_[0]->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
}

1;
