# find-geotagged

A small Perl script that searches directories for geotagged photos
(JPEG, HEIC, TIFF) within a given radius of coordinates, using EXIF GPS
data via [Image::ExifTool](https://exiftool.org/).

## Usage

```
Usage: $0 LAT LON RADIUS_KM DIR [DIR ...]
```

Coordinates can also be passed as a single `LAT/LON` argument:

```
Usage: $0 LAT/LON RADIUS_KM DIR [DIR ...]
```

## Example

```sh
# find photos within 10 km of Belgrade
./bin/find-geotagged.pl 44.7866 20.4489 10 ~/photo

# same thing, coordinates as LAT/LON
./bin/find-geotagged.pl 44.7866/20.4489 10 ~/photo
```

Output lists each matching file with its distance and coordinates:

```
/home/user/photo/belgrade.jpg	0.432 km - 44.786200, 20.449100
```

## Requirements

- Perl
- `Image::ExifTool`
- `File::Find`, `Math::Trig` (core modules)

## Tests

```sh
prove -l t/
```
