package MetaCPAN::Web::Model::API::Release;
use Moose;
use namespace::autoclean;

extends 'MetaCPAN::Web::Model::API';
with 'MetaCPAN::Web::Role::RiverData';

use CPAN::DistnameInfo;
use Future ();

=head1 NAME

MetaCPAN::Web::Model::Release - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Moritz Onken, Matthew Phillips

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

sub coverage {
    my ( $self, $author, $release ) = @_;
    $self->request("/cover/$release")->then( sub {
        my $data = shift;
        if ( !$data->{release} ) {
            return Future->done( { code => 404 } );
        }
        return Future->done( { coverage => $data } );
    } );
}

sub get {
    my ( $self, $author, $release ) = @_;
    $self->request("/release/$author/$release");
}

sub latest_by_author {
    my ( $self, $pauseid ) = @_;
    $self->request("/release/latest_by_author/$pauseid")
        ->then( $self->add_river );
}

sub all_by_author {
    my ( $self, $pauseid, $page, $page_size ) = @_;
    $self->request( "/release/all_by_author/$pauseid",
        undef, { page => $page, page_size => $page_size } )
        ->then( $self->add_river );
}

sub recent {
    my ( $self, $page, $page_size, $type ) = @_;
    $self->request(
        '/release/recent',
        undef,
        {
            page      => $page,
            page_size => $page_size,
            type      => $type,
        }
    )->then( $self->add_river );
}

sub modules {
    my ( $self, $author, $release ) = @_;
    $self->request("/release/modules/$author/$release")->then( sub {
        my $data = shift;
        if ( my $modules = delete $data->{files} ) {
            $data->{modules} = $modules;
        }
        Future->done($data);
    } );
}

sub find {
    my ( $self, $distribution ) = @_;
    $self->request("/release/latest_by_distribution/$distribution");
}

# stolen from Module/requires
sub reverse_dependencies {
    my ( $self, $distribution, $page, $page_size, $sort ) = @_;
    $sort ||= 'date:desc';

    $self->request(
        "/reverse_dependencies/dist/$distribution",
        undef,
        {
            page      => $page,
            page_size => $page_size,
            sort      => $sort,
        }
    )->transform(
        done => sub {
            my ($data) = @_;

            # api should really be returning in this form already
            $data->{releases} ||= delete $data->{data};
            $data->{total}    ||= 0;
            $data->{took}     ||= 0;
            return $data;
        }
    )->then( $self->add_river );
}

sub interesting_files {
    my ( $self, $author, $release ) = @_;
    $self->request("/release/interesting_files/$author/$release");
}

sub versions {
    my ( $self, $dist ) = @_;
    $self->request("/release/versions/$dist")->then( sub {
        my ($data) = @_;
        my $releases = delete $data->{releases};
        for my $release (@$releases) {
            $release->{distname_version}
                = CPAN::DistnameInfo->new( $release->{download_url} )
                ->version;
        }
        $data->{versions} = $releases;
        Future->done($data);
    } );
}

sub topuploaders {
    my ( $self, $range ) = @_;
    my $param = $range ? { range => $range } : ();
    $self->request( '/release/top_uploaders', undef, $param );
}

__PACKAGE__->meta->make_immutable;

1;
