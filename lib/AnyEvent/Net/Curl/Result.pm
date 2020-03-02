package AnyEvent::Net::Curl::Result;

use strict;
use warnings qw( all );

use HTTP::Status ();
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

sub status {
    my ( $self ) = @_;
    $self->{_status} //=
        ( $self->{_result} == Net::Curl::Easy::CURLE_OK )
            ? 0 + $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE )
            : ();
}

sub url {
    my ( $self ) = @_;
    $self->{_url} //=
        $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
}

sub content_length {
    my ( $self ) = @_;
    $self->{_content_length} //=
        $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_CONTENT_LENGTH_DOWNLOAD );
}

sub content_type {
    my ( $self ) = @_;
    $self->{_content_type} //=
        $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_CONTENT_TYPE );
}

sub is_info     { HTTP::Status::is_info             ( $_[0]->status ) }
sub is_success  { HTTP::Status::is_success          ( $_[0]->status ) }
sub is_redirect { HTTP::Status::is_redirect         ( $_[0]->status ) }
sub is_error    { HTTP::Status::is_error            ( $_[0]->status ) || ! $_[0]->status }
sub is_client_error { HTTP::Status::is_client_error ( $_[0]->status ) }
sub is_server_error { HTTP::Status::is_server_error ( $_[0]->status ) }

sub is_timeout  { shift->{_result} == Net::Curl::Easy::CURLE_OPERATION_TIMEDOUT }

sub raw_headers { shift->{_header} }
sub raw_body    { shift->{_body} }

1;
