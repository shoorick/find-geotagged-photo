#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);

my $script = abs_path(File::Spec->catfile('bin', 'find-geotagged.pl'));
die "Cannot locate $script" unless $script && -f $script;
do $script or die "Cannot load $script: $@";

sub pa {
    return main::parse_args(@_);
}

# --- parse_args unit tests ---

is_deeply(
    [ pa('44.7654/20.1234', '10', '/tmp') ],
    ['44.7654', '20.1234', '10', '/tmp'],
    'LAT/LON shorthand is split into two arguments',
);

is_deeply(
    [ pa('44.7654', '20.1234', '10', '/tmp') ],
    ['44.7654', '20.1234', '10', '/tmp'],
    'separate LAT and LON arguments are kept as is',
);

is_deeply(
    [ pa('-33.86/151.21', '5', '/tmp', '/var') ],
    ['-33.86', '151.21', '5', '/tmp', '/var'],
    'negative latitude in LAT/LON shorthand works',
);

is_deeply(
    [ pa('not/a/coord', '10', '/tmp') ],
    ['not/a/coord', '10', '/tmp'],
    'first arg that is not LAT/LON is left untouched',
);

# --- end-to-end test with a real geotagged JPEG ---

my $dir = tempdir(CLEANUP => 1);
my $jpg = File::Spec->catfile($dir, 'photo.jpg');

# smallest valid JPEG (1x1 px)
open my $fh, '>', $jpg or die $!;
binmode $fh;
print $fh pack('H*',
    'ffd8ffe000104a46494600010100000100010000'
    . 'ffdb004300' . ('08' x 64)
    . 'ffc00011080001000103012200021101031101'
    . 'ffc4001400010000000000000000000000000000000000000008'
    . 'ffc4001401010000000000000000000000000000000000000000'
    . 'ffda000c03010002110311003f00'
    . 'd2cf20ffd9'
);
close $fh;

system('exiftool', '-overwrite_original', '-q',
    '-GPSLatitude=44.7654', '-GPSLatitudeRef=N',
    '-GPSLongitude=20.1234', '-GPSLongitudeRef=E',
    $jpg) == 0 or die 'Failed to write GPS tags with exiftool';

sub run_script {
    my (@args) = @_;
    my $out = `perl "$script" @args 2>&1`;
    return $out;
}

my $out1 = run_script('44.7654', '20.1234', '1', $dir);
my $out2 = run_script('44.7654/20.1234', '1', $dir);
my $out3 = run_script('10.0/10.0', '1', $dir);

like($out1, qr/photo\.jpg/, 'separate LAT LON finds the photo');
like($out2, qr/photo\.jpg/, 'LAT/LON shorthand finds the photo');
unlike($out3, qr/photo\.jpg/, 'far-away coordinates do not match');

done_testing;
