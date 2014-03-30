#!/usr/local/bin/perl

package XML::Saxtract;

# ABSTRACT: Streaming parse XML data into a result hash based upon a specification hash
# PODNAME: XML::Saxtract

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(saxtract_string saxtract_url);

use LWP::UserAgent;
use XML::Sax;

sub saxtract_string {
    my $xml_string = shift;
    my $spec       = shift;

    my $handler = XML::Saxtract::ContentHandler->new($spec);
    my $parser = XML::SAX::ParserFactory->parser( Handler => $handler );
    $parser->parse_string($xml_string);

    return $handler->get_result();
}

sub saxtract_url {
    my $uri  = shift;
    my $spec = shift;
    my $die_on_failure = shift;

    my $response = LWP::UserAgent->new()->get( $uri );
    if ( ! $response->is_success() ) {
        if ( $die_on_failure ) {
            die( $response );
        }
        else {
            return;
        }
    }
    return saxtract_string( $response->content(), $spec );
}

package XML::Saxtract::ContentHandler;

use parent qw(Class::Accessor);
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_ro_accessors(qw(result));

use Data::Dumper;

sub new {
    my ( $class, @args ) = @_;
    my $self = bless( {}, $class );

    return $self->_init(@args);
}

sub _add_value {
    my $object = shift;
    my $spec   = shift;
    my $value  = shift;

    my $type = ref($spec);
    if ( !$type ) {
        $object->{$spec} = $value;
    }
    elsif ( $type eq 'SCALAR' ) {
        $object->{$$spec} = $value;
    }
    elsif ( $type eq 'CODE' ) {
        &$spec( $object, $value );
    }
    else {
        my $name = $spec->{name};
        if ( $spec->{type} eq 'array' ) {
            if ( !defined( $object->{$name} ) ) {
                $object->{$name} = [];
            }
            push( @{ $object->{$name} }, $value );
        }
        elsif ( $spec->{type} eq 'map' ) {
            if ( !defined( $object->{$name} ) ) {
                $object->{$name} = {};
            }
            $object->{$name}{ $value->{ $spec->{key} } } = $value;
        }
        elsif ( $spec->{type} eq 'first' ) {
            if ( !defined( $object->{$name} ) ) {
                $object->{$name} = $value;
            }
        }
        else {
            # type 'last' or default
            $object->{$name} = $value;
        }
    }
}

sub characters {
    my ( $self, $characters ) = @_;
    return if ( $self->{skip} > 0 );

    if ( defined($characters) ) {
        push( @{ $self->{buffer} }, $characters->{Data} );
    }
}

sub end_element {
    my ( $self, $element ) = @_;

    if ( $self->{skip} > 0 ) {
        $self->{skip}--;
        return;
    }

    my $stack_element = pop( @{ $self->{element_stack} } );
    my $name          = $stack_element->{name};
    my $attrs         = $stack_element->{attrs};
    my $spec          = $stack_element->{spec};
    my $path          = $stack_element->{spec_path};
    my $result        = $stack_element->{result};

    if ( defined( $spec->{$path} ) && scalar( @{ $self->{buffer} } ) ) {
        my $buffer_data = join( '', @{ $self->{buffer} } );
        $buffer_data =~ s/^\s*//;
        $buffer_data =~ s/\s*$//;
        _add_value( $result, $spec->{$path}, $buffer_data );
    }

    foreach my $attr ( values(%$attrs) ) {
        my $ns_uri    = $attr->{NamespaceURI};
        my $attr_path = join( '',
            $path, '/@', ( $ns_uri && $spec->{$ns_uri} ? "$spec->{$ns_uri}:" : '' ),
            $attr->{LocalName} );

        if ( $spec->{$attr_path} ) {
            _add_value( $result, $spec->{$attr_path}, $attr->{Value} );
        }
    }

    if ( !$path && scalar( @{ $self->{element_stack} } ) ) {
        my $parent_element = $self->{element_stack}[-1];
        my $path_in_parent = "$parent_element->{spec_path}/$name";
        _add_value( $parent_element->{result}, $parent_element->{spec}{$path_in_parent},
            $result );
    }

    $self->{buffer} = [];
}

sub _init {
    my ( $self, $spec ) = @_;

    $self->{result}        = {};
    $self->{element_stack} = [
        {   spec      => $spec,
            spec_path => '',
            result    => $self->{result}
        }
    ];
    $self->{buffer} = [];
    $self->{skip}   = 0;

    return $self;
}

sub start_element {
    my ( $self, $element ) = @_;

    if ( $self->{skip} ) {
        $self->{skip}++;
        return;
    }

    my $stack_top = $self->{element_stack}[-1];
    my $spec      = $stack_top->{spec};
    my $result    = $stack_top->{result};
    my $uri       = $element->{NamespaceURI};

    my $qname;
    if ($uri) {
        my $spec_prefix = $spec->{$uri};
        if ( !defined($spec_prefix) ) {

            # uri is not in spec, so nothing could possibly match
            $self->{skip} = 1;
            return;
        }
        elsif ( $spec_prefix eq '' ) {
            $qname = $element->{LocalName};
        }
        else {
            $qname = "$spec_prefix:$element->{LocalName}";
        }
    }
    else {
        $qname = $element->{LocalName};
    }

    my $spec_path = "$stack_top->{spec_path}/$qname";
    if (   defined( $spec->{$spec_path} )
        && ref( $spec->{$spec_path} ) eq 'HASH'
        && defined( $spec->{$spec_path}{spec} ) )
    {
        $spec      = $spec->{$spec_path}{spec};
        $spec_path = '';
        $result    = {};
    }

    push(
        @{ $self->{element_stack} },
        {   name      => $qname,
            attrs     => $element->{Attributes},
            spec      => $spec,
            spec_path => $spec_path,
            result    => $result
        }
    );
}

1;

__END__
=head1 SYNOPSIS

    use XML::Saxtract qw(saxtract_string saxtract_uri);

    my $xml = "<root id='1' />";
    my $spec = { '/root/@id' => rootId };

    my $result = saxtract_string( $xml, $spec );
    my $rootId = $result->{rootId};

    my $complex_xml = <<'XML';
    <root xmlns='http://abc' xmlns:d='http://def' d:id='1' name='root' d:other='abc'>
      <person id='1'>Lucas</person>
      <d:employee id='2'>Ali</d:employee>
      <person id='3'>Boo</person>
      <d:employee id='4'>Dude</d:employee>
    </root>
    XML

    # get a map of all the employees
    my $complex_spec = {
        'http://def' => 'k',
        '/root/k:employee' => {
            name => 'employees',
            type => 'map',
            key => 'name',
            spec => {
                '' => sub {
                    my ($object, $value) = @_;
                    $object->{name} => $value;
                    $object->{email} => lc($value) . '@example.com';
                },
                '/@id' => 'id'
            }
        }
    };
    my $result = saxtract_string( $complex_xml, $complex_spec );
    foreach my $employee ( keys( %{$result->{employees}} ) ) {
        print( "$employee->{id}: $employee->{name} <$employee->{email}>\n" );
    }
    # Prints:
    # 2: Ali <ali@example.com>
    # 4: Dude <dude@example.com>

=head1 DESCRIPTION

This module provides methods for SAX based (streaming) parsing of XML data into
a result hash based upon a specification hash.

=head SEE ALSO
https://github.com/lucastheisen/saxtract-perl
https://github.com/lucastheisen/saxtract

