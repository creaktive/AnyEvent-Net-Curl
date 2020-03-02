package AnyEvent::Net::Curl::Result;

use strict;
use warnings qw( all );

use Net::Curl::Easy ();

sub new {
    my ( $class, $args ) = @_;
    return bless {
        _easy   => $args->{easy},
        _result => $args->{result}  // -1,
        _header => $args->{header}  // '',
        _body   => $args->{body}    // '',
    }, $class;
}

sub is_success  { shift->{_result} == Net::Curl::Easy::CURLE_OK }
sub is_timeout  { shift->{_result} == Net::Curl::Easy::CURLE_OPERATION_TIMEDOUT }

sub raw_headers { shift->{_header} }
sub raw_body    { shift->{_body} }

sub curl_result { shift->{_result} }

sub status      { shift->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE ) }
sub url         { shift->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL ) }

1;
