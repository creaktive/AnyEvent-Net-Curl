package AnyEvent::Net::Curl::Result;

use strict;
use warnings qw( all );

use HTTP::Parser::XS ();
use HTTP::Status ();
use HTTP::XSHeaders ();
use Net::Curl::Easy ();

sub new {
    my ( $class, $args ) = @_;
    return bless {
        _easy   => $args->{easy},
        _result => $args->{result}  // -1,
        _header => $args->{header}  // '',
        _body   => $args->{body}    // '',
    } => $class;
}

sub status {
    my ( $self ) = @_;
    $self->{_status} //=
        $self->is_curl_error
            ? '' # empty status means hard error
            : 0 + $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_RESPONSE_CODE );
}

sub url {
    my ( $self ) = @_;
    $self->{_url} //=
        $self->{_easy}->getinfo( Net::Curl::Easy::CURLINFO_EFFECTIVE_URL );
}

sub is_curl_error       { shift->{_result} != Net::Curl::Easy::CURLE_OK }
sub is_timeout          { shift->{_result} == Net::Curl::Easy::CURLE_OPERATION_TIMEDOUT }

sub is_info             { HTTP::Status::is_info         ( $_[0]->status ) }
sub is_success          { HTTP::Status::is_success      ( $_[0]->status ) }
sub is_redirect         { HTTP::Status::is_redirect     ( $_[0]->status ) }
sub is_error            { HTTP::Status::is_error        ( $_[0]->status ) || ! $_[0]->status }
sub is_client_error     { HTTP::Status::is_client_error ( $_[0]->status ) }
sub is_server_error     { HTTP::Status::is_server_error ( $_[0]->status ) }

sub raw_headers         { shift->{_header} }
sub raw_body            { shift->{_body} }
sub body                { shift->{_body} }

sub headers {
    my ( $self ) = @_;
    $self->{_headers_object} //=
        HTTP::XSHeaders->new( @{
            $self->{_headers_array} //=
                HTTP::Parser::XS::parse_http_response(
                    # libcurl concatenates headers of redirections!
                    $self->{_header} =~ s{^ .* (?: \015\012? | \012\015) {2} (?!$)}{}rsx,
                    HTTP::Parser::XS::HEADERS_AS_ARRAYREF,
                )
        } );
}

sub authorization       { shift->headers->authorization }
sub authorization_basic { shift->headers->authorization_basic }
sub content_encoding    { shift->headers->content_encoding }
sub content_is_html     { shift->headers->content_is_html }
sub content_is_xhtml    { shift->headers->content_is_xhtml }
sub content_is_xml      { shift->headers->content_is_xml }
sub content_language    { shift->headers->content_language }
sub content_length      { shift->headers->content_length }
sub content_type        { shift->headers->content_type }
sub content_type_charset{ shift->headers->content_charset }
sub date                { shift->headers->date }
sub expires             { shift->headers->expires }
sub from                { shift->headers->from }
sub header_field_names  { shift->headers->header_field_names }
sub if_modified_since   { shift->headers->if_modified_since }
sub if_unmodified_since { shift->headers->if_unmodified_since }
sub last_modified       { shift->headers->last_modified }
sub referer             { shift->headers->referer }
sub referrer            { shift->headers->referrer }
sub server              { shift->headers->server }
sub www_authenticate    { shift->headers->www_authenticate }

1;
