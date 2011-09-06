package WebService::Deltacloud;

use warnings;
use strict;

BEGIN {

    use version 0.77; our( $VERSION ) = version->declare( "v0.0.1" );

    use Exporter ();

    use Carp;
    use Data::Dumper;
    use Readonly;

    use HTTP::Request;
    use LWP::UserAgent;
    use Params::Validate qw( :all );
    use URI;
    use URI::QueryParam;
    use URI::Split qw( uri_split uri_join );
    use XML::Simple qw( :strict );

    our( @ISA, @EXPORT, @EXPORT_OK );
    @ISA = qw( Exporter );
    @EXPORT = qw();
    @EXPORT_OK = qw( hardware_profiles realms images instances );
};

=head1 NAME

WebService::Deltacloud - The great new WebService::Deltacloud!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

Readonly my $APIDEFAULT => 'http://localhost:3001';
our( $APIBASE ) = $APIDEFAULT;

# credentials
our( $APIUSER, $APIPASS );

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use WebService::Deltacloud;

    my $foo = WebService::Deltacloud->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=cut

my( $ua ) = LWP::UserAgent->new;

### PRIVATE

sub _build_uri {

    my( %params ) = validate( @_, 
        {
            base_uri => {
                isa         => 'URI',
                required    => 1,
            },
            target => {
                type        => SCALAR,
                required    => 1,
            },
            params => {
                type    => HASHREF,
            },
        },
    );

    # parse params
    my( $scheme, $auth, $path, $query, $frag ) = uri_split( $params{base_uri} );

    # add the target
    $path .= $params{target};

    # add query params if any are available
    my( $result ) = URI->new( uri_join( $scheme, $auth, $path, $query, $frag ) );
    foreach my $query_param ( keys( %{$params{params}} ) ) {
        $result->query_param( $query_param => $params{params}->{$query_param} );
    }

    return( $result );
}

sub _api_request {

    my( %params ) = validate( @_, 
        {
            method  => {
                type    => SCALAR,
                regex   => qr/^(?:GET|HEAD|POST|PUT)$/,
            },
            ua      => {
                isa     => 'LWP::UserAgent',
                default => $ua,
            },
            uri     => {
                isa         => 'URI',
                required    => 1,
            },
            username => {
                type        => SCALAR,
                optional    => 1,
                depends     => [ qw( password ) ],
            },
            password => {
                type        => SCALAR,
                optional    => 1,
                depends     => [ qw( username ) ],
            },
        },
    );

    my( $request ) = HTTP::Request->new( $params{method} => $params{uri} );

    # add credentials if provided
    if ( defined( $params{username} ) && defined( $params{password} ) ) {

        $request->authorization_basic( $params{username}, $params{password} );
    }

    # set encoding if necessary
    if ( $params{method} eq 'POST' ) {
    
        $request->content_type( 'application/x-www-form-encoded' );
    }

    print Data::Dumper->Dump( [$request], [qw(*request)] );

    my( $response ) = $params{ua}->request( $request ); 

    return( $response );
}

sub _parse_content {

    my( %params ) = validate( @_, 
        {
            response  => {
                isa         => 'HTTP::Response',
                required    => 1,
            },
            keys => {
                type    => HASHREF,
                default => {},
            },
            values => {
                type    => HASHREF,
                default => {},
            },
            group => {
                type    => HASHREF,
                default => {},
            },
        },
    );

    my( $xml ) = XML::Simple->new(
        ForceArray  => [ keys( %{$params{keys}} ) ],
        KeyAttr     => $params{keys},
        ValueAttr   => $params{values},
        GroupTags   => $params{group},
        SuppressEmpty   => 1,
    );

    my( $result );

    if ( $params{response}->is_success ) {

        my( $raw ) = $params{response}->decoded_content;
        $result = $xml->XMLin( $raw );
    }
    else {
        $result->{error} = {
            status  => $params{response}->status_line,
            text    => $params{response}->as_string,
            html    => $params{response}->error_as_HTML,
        };
    }

    return( $result );
}

sub _process_api {

    my( %params ) = validate( @_, 
        {
            base => {
                type    => SCALAR,
                default => $APIBASE,
            },
            target => {
                type        => SCALAR,
                regex       => qr/^\//,
                optional    => 1,
            },
            params => {
                type    => HASHREF,
                default => {},
            },
            method => {
                type    => SCALAR,
                regex   => qr/^(?:GET|HEAD|POST|PUT)$/,
                default => 'GET',
            },
            keys => {
                type    => HASHREF,
                default => {},
            },
            values => {
                type    => HASHREF,
                default => {},
            },
            username => {
                type        => SCALAR,
                optional    => 1,
                depends     => [ qw( password ) ],
            },
            password => {
                type        => SCALAR,
                optional    => 1,
                depends     => [ qw( username ) ],
            },
        },
    );

    # instantiate the URI object
    my( $base_uri ) = URI->new( $params{base} );

    my( $uri ) = _build_uri(
        base_uri    => $base_uri,
        target      => $params{target},
        params      => $params{params},
    );

    my( $response ) = _api_request(
        method  => $params{method},
        uri     => $uri,
    );

    # do we need to authenticate?
    if ( ( $response->is_error ) && ( $response->code == 401 ) ) {
     
        if ( defined( $params{username} ) && defined( $params{password} ) ) {

            $response = _api_request(
                method  => $params{method},
                uri     => $uri,
                username    => $params{username},
                password    => $params{password},
            );
        }
    }

    my( $parsed ) = _parse_content(
        response    => $response,
        keys        => $params{keys},
        values      => $params{values},
    );

    return( $parsed );
}

### PUBLIC

sub hardware_profiles {

    my( %params ) = validate( @_, 
        {
            base => {
                type    => SCALAR,
                default => $APIBASE,
            },
            id => {
                type        => SCALAR,
                optional    => 1,
            },
        },
    );

    my( $keys ) = {
        hardware_profile    => 'id',
        property            => 'name',
        enum                => 'value',
    };

    my( $values ) = {
        hardware_profile    => 'name',
    };

    my( $target ) = '/hardware_profiles';
    my( $queryparams ) = {};

    if ( defined( $params{id} ) ) {

        $target .= join( '', '/', $params{id} );
        $queryparams->{id} = $params{id};
    }

    my( $result ) = _process_api(
        base    => $params{base},
        target  => $target,
        params  => $queryparams,
        method  => 'GET',
        keys    => $keys,
        values  => $values,
    );

    if ( defined( $result->{error} ) ) {

        # that's no good
        carp( $result->{error}->{status} );
        return( $result );
    }
    else {

        # that's good
        return( $result );
    }
}

sub realms {

    my( %params ) = validate( @_, 
        {
            base => {
                type    => SCALAR,
                default => $APIBASE,
            },
            id => {
                type        => SCALAR,
                optional    => 1,
            },
        },
    );

    my( $keys ) = {
        realm       => 'id',
    };

    my( $values ) = {
        realm => 'name',
        realm => 'state',
    };

    my( $target ) = '/realms';
    my( $queryparams ) = {};

    if ( defined( $params{id} ) ) {

        $target .= join( '', '/', $params{id} );
        $queryparams->{id} = $params{id};
    }

    my( $result ) = _process_api(
        base    => $params{base},
        target  => $target,
        params  => $queryparams,
        method  => 'GET',
        keys    => $keys,
        values  => $values,
        username    => $APIUSER,
        password    => $APIPASS,
    );

    if ( defined( $result->{error} ) ) {

        # that's no good
        croak( $result->{error}->{status} );
    }
    else {

        # that's good
        return( $result );
    }
}

sub images {

    my( %params ) = validate( @_, 
        {
            base => {
                type    => SCALAR,
                default => $APIBASE,
            },
            id => {
                type        => SCALAR,
                optional    => 1,
            },
        },
    );

    my( $keys ) = {
        image       => 'id',
    };

    my( $values ) = {
        image => 'name',
        image => 'owner',
        image => 'description',
        image => 'architecture',
    };

    my( $target ) = '/images';
    my( $queryparams ) = {};

    if ( defined( $params{id} ) ) {

        $target .= join( '', '/', $params{id} );
        $queryparams->{id} = $params{id};
    }

    my( $result ) = _process_api(
        base        => $params{base},
        target      => $target,
        params      => $queryparams,
        method      => 'GET',
        keys        => $keys,
        values      => $values,
        username    => $APIUSER,
        password    => $APIPASS,
    );

    if ( defined( $result->{error} ) ) {

        # that's no good
        croak( $result->{error}->{status} );
    }
    else {

        # that's good
        return( $result );
    }
}

sub instances {

    my( %params ) = validate( @_, 
        {
            base => {
                type    => SCALAR,
                default => $APIBASE,
            },
            id => {
                type        => SCALAR,
                optional    => 1,
            },
            image => {
                type        => SCALAR,
                optional    => 1,
            },
            realm => {
                type        => SCALAR,
                optional    => 1,
                depends     => 'image',
            },
            profile => {
                type        => SCALAR,
                optional    => 1,
                depends     => 'image',
            },
            name => {
                type        => SCALAR,
                optional    => 1,
                depends     => 'image',
            },
            key => {
                type        => SCALAR,
                optional    => 1,
                depends     => 'image',
            },
            loadbalancer => {
                type        => SCALAR,
                optional    => 1,
                depends     => 'image',
            },
        },
    );

    my( $keys ) = {
        instance            => 'id',
        link                => 'rel',
        image               => 'href',
        hardware_profile    => 'href',
        realm               => 'href',
        public_addresses    => 'address',
        private_addresses   => 'address',
    };

    my( $values ) = {
        instance => 'name',
        instance => 'owner',
        instance => 'description',
        instance => 'architecture',
        instance => 'state',
    };

    my( $group ) = {
    };

    my( $target ) = '/instances';
    my( $method ) = 'GET';
    my( $queryparams ) = {};

    if ( defined( $params{id} ) ) {

        $target .= join( '', '/', $params{id} );
        $queryparams->{id} = $params{id};
    }
    elsif ( defined( $params{image} ) ) {

        # we're creating a new instance
        $queryparams->{image_id} = $params{image};
        defined( $params{realm} ) && ( $queryparams->{realm_id} = $params{realm} );
        defined( $params{profile} ) && ( $queryparams->{hwp_id} = $params{profile} );
        defined( $params{name} ) && ( $queryparams->{name} = $params{name} );
        defined( $params{key} ) && ( $queryparams->{keyname} = $params{key} );
        defined( $params{loadbalancer} ) && ( $queryparams->{load_balancer_id} = $params{loadbalancer} );

        $method = 'POST';
    }

    my( $result ) = _process_api(
        base    => $params{base},
        target  => $target,
        params  => $queryparams,
        method  => $method,
        keys    => $keys,
        values  => $values,
        username    => $APIUSER,
        password    => $APIPASS,
    );

    if ( defined( $result->{error} ) ) {

        # that's no good
        croak( $result->{error}->{status} );
    }
    else {

        # that's good
        return( $result );
    }
}

=head1 AUTHOR

Steve Huff, C<< <shuff at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-webservice-deltacloud at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WebService-Deltacloud>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WebService::Deltacloud


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WebService-Deltacloud>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WebService-Deltacloud>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WebService-Deltacloud>

=item * Search CPAN

L<http://search.cpan.org/dist/WebService-Deltacloud/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Steve Huff.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WebService::Deltacloud
