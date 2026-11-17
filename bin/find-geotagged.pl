#!/usr/bin/env perl

use strict;
use warnings;
use File::Find;
use Image::ExifTool;
use Math::Trig qw(deg2rad great_circle_distance);

if (@ARGV < 4) {
    die "Usage: $0 LAT LON RADIUS_KM DIR [DIR ...]\n";
}

my ($lat0, $lon0, $radius_km, @dirs) = @ARGV;
my $RADIUS = 6371; # km

my $exifTool = Image::ExifTool->new;

find(
    {
        wanted => sub {
            return unless -f $_;
            return unless /\.(jpe?g|heic|tiff?)$/i;

            my $info = $exifTool->ImageInfo($_, { PrintConv => 0 }, 'GPSLatitude', 'GPSLongitude');
            return unless defined $info->{GPSLatitude} && defined $info->{GPSLongitude};

            my $lat = $info->{GPSLatitude};
            my $lon = $info->{GPSLongitude};

            # to radians
            my $lat_r  = deg2rad($lat);
            my $lon_r  = deg2rad($lon);
            my $lat0_r = deg2rad($lat0);
            my $lon0_r = deg2rad($lon0);

            # great_circle_distance ожидает (долгота, широта)
            my $dist_km = great_circle_distance($lon_r, $lat_r, $lon0_r, $lat0_r, $RADIUS);

            if ($dist_km <= $radius_km) {
                printf "%s\t%.3f km - %f, %f\n", $File::Find::name, $dist_km, $lat, $lon;
            }
        },
        no_chdir => 1,
    },
    @dirs
);
