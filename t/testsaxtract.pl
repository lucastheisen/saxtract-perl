#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use XML::Saxtract;

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

my $result = XML::Saxtract::parse_string( $xml, $spec );
print( "DONE\n", Dumper( $result ), "\n" );
