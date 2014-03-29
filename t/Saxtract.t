use strict;
use warnings;

use Test::More tests => 8;
use XML::Saxtract qw(saxtract_string saxtract_url);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root>value</root>",
        { '/root' => 'rootValue' }
    ),
    { rootValue => 'value' },
    'simple value'
);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root id='root' />",
        { '/root/@id' => 'rootId' }
    ),
    { rootId => 'root' },
    'simple attribute'
);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root id='root'>value</root>",
        {   '/root'     => 'rootValue',
            '/root/@id' => 'rootId'
        }
    ),
    {   rootValue => 'value',
        rootId    => 'root'
    },
    'simple value and attribute'
);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root xmlns='http://abc'>value</root>",
        {   'http://abc' => 'abc',
            '/root'      => 'rootValue',
            '/abc:root'  => 'abcRootValue'
        }
    ),
    { abcRootValue => 'value' },
    'simple namespaced value'
);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root xmlns='http://abc'>value</root>",
        {   'http://abc' => 'abc',
            '/root'      => 'rootValue',
            '/abc:root'  => sub {
                my ( $object, $value ) = @_;
                $object->{abcRootValue}  = $value;
                $object->{computedValue} = "computed_$value";
                }
        }
    ),
    {   abcRootValue  => 'value',
        computedValue => 'computed_value'
    },
    'subroutine value setter'
);

is_deeply(
    saxtract_string(
        "<?xml version='1.0' encoding='UTF-8'?><root xmlns:n='http://abc' n:id='root' />",
        {   'http://abc'    => 'abc',
            '/root/@id'     => 'rootId',
            '/root/@abc:id' => 'abcRootId'
        }
    ),
    { abcRootId => 'root' },
    'mismatching namespace prefixes'
);

my $complex_xml = <<XML;
<?xml version='1.0' encoding='UTF-8'?>
<root xmlns='http://abc' xmlns:d='http://def' d:id='1' name='root' d:other='abc'>
  <person id='1'>Lucas</person>
  <d:employee id='2'>Ali</d:employee>
  <person id='3'>Boo</person>
  <d:employee id='4'>Dude</d:employee>
</root>
XML
my $complex_spec = {
    'http://def'     => 'k',
    'http://abc'     => '',
    '/root/@k:id'    => 'id',
    '/root/@name'    => 'name',
    '/root/@k:other' => 'other',
    '/root/person'   => {
        name => 'people',
        type => 'map',
        key  => 'name',
        spec => {
            ''     => 'name',
            '/@id' => 'id'
        }
    },
    '/root/k:employee' => {
        name => 'firstEmployee',
        type => 'first',
        spec => {
            ''     => 'name',
            '/@id' => 'id'
        }
    }
};
my $complex_expected = {   
    id     => '1',
    name   => 'root',
    other  => 'abc',
    people => {
        Lucas => {
            name => 'Lucas',
            id   => 1
        },
        Boo => {
            name => 'Boo',
            id   => 3
        }
    },
    firstEmployee => {
        name => 'Ali',
        id   => 2
    }
};

is_deeply(
    saxtract_string( $complex_xml, $complex_spec ),
    $complex_expected,
    'complex with namespaces'
);

SKIP: {
    eval { require( "Test/HTTP/Server.pm" ); };
    skip( 'Test::HTTP::Server not installed', 1 ) if ( $@ );

    my $server = Test::HTTP::Server->new();
    sub Test::HTTP::Server::Request::complex {
        my $self = shift;
        return $complex_xml;
    }
    is_deeply(
        saxtract_url( $server->uri() . 'complex', $complex_spec ),
        $complex_expected,
        'url complex with namespaces'
    );
}
