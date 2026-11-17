#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use lib File::Spec->catdir('..', 'lib');
use File::Find::Geotagged;

my $data_dir = tempdir(CLEANUP => 1);
local $ENV{XDG_DATA_HOME} = $data_dir;

is(
    File::Find::Geotagged::db_file(),
    File::Spec->catfile($data_dir, 'find-geotagged', 'geotagged.db'),
    'db_file respects XDG_DATA_HOME',
);

my $cache = File::Find::Geotagged->connect;
ok(-f File::Spec->catfile($data_dir, 'find-geotagged', 'geotagged.db'),
    'connect creates the database file');

$cache->store_coords('/tmp/a.jpg', 44.7654, 20.1234);
$cache->store_coords('/tmp/b.jpg', 10.0,    10.0);

my @rows = $cache->find_in_bbox(44.7, 20.0, 50);
is(scalar @rows, 1, 'find_in_bbox returns only rows inside the bbox');
is($rows[0]{filename}, '/tmp/a.jpg', 'correct filename returned');
like($rows[0]{modified_at}, qr/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/,
    'modified_at is set to the write time');

# dedupe: storing the same filename again must not create a second row
$cache->store_coords('/tmp/a.jpg', 44.8, 20.2);
@rows = $cache->find_in_bbox(44.0, 20.0, 500);
my @a = grep { $_->{filename} eq '/tmp/a.jpg' } @rows;
is(scalar @a, 1, 're-storing a filename does not duplicate the row');
is($a[0]{latitude}, 44.8, 'coordinates are updated on re-store');

# distance_km sanity checks
cmp_ok(
    File::Find::Geotagged::distance_km(44.7654, 20.1234, 44.7654, 20.1234),
    '==', 0, 'distance to itself is zero',
);
cmp_ok(
    File::Find::Geotagged::distance_km(0, 0, 0, 1),
    '>', 100, 'one degree of longitude near equator is >100 km',
);
cmp_ok(
    File::Find::Geotagged::distance_km(0, 0, 1, 0),
    '>', 100, 'one degree of latitude is >100 km',
);

done_testing;
