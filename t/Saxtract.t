use strict;
use warnings;
use Test::More tests => 3;
use XML::Saxtract;

BEGIN { use_ok('XML::Saxtract') }

is_deeply( 
    XML::Saxtract::parse_string( 
        "<?xml version='1.0' encoding='UTF-8'?><root>value</root>",
        { '/root' => 'rootValue' }
    ),
    { rootValue => 'value' } );

my $xml = <<XML;
<?xml version='1.0' encoding='UTF-8'?>
<root xmlns='http://abc' xmlns:d='http://def' d:id='1' name='root' d:other='abc'>
  <person id='1'>Lucas</person>
  <d:employee id='2'>Ali</d:employee>
  <person id='3'>Boo</person>
  <d:employee id='4'>Dude</d:employee>
</root>
XML
my $spec = {
    'http://def' => 'k',
    'http://abc' => '',
    '/root/@k:id' => 'id',
    '/root/@name' => 'name',
    '/root/@k:other' => 'other',
    '/root/person' => {
        name => 'people',
        type => 'map',
        key => 'name',
        spec => {
            '' => 'name',
            '/@id' => 'id'
        }
    },
    '/root/k:employee' => {
        name => 'firstEmployee',
        type => 'first',
        spec => {
            '' => 'name',
            '/@id' => 'id'
        }
    }
};

is_deeply( XML::Saxtract::parse_string( $xml, $spec ),
    {
        id => '1',
        name => 'root',
        other => 'abc',
        people => {
            Lucas => {
                name => 'Lucas',
                id => 1
            },
            Boo => {
                name => 'Boo',
                id => 3
            }
        },
        firstEmployee => {
            name => 'Ali',
            id => 2
        }
    } );
