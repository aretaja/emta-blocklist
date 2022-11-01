#!/usr/bin/perl
#
# emta-blocklist.pl fetches pdf from EMTA website, parses it and generates
# text file of blocked domains.
# Copyright 2016-2022 by Marko Punnar <marko[AT]aretaja.org>
# Version: 2.0.1
#
# Retrives pdf file from EMTA homepage, extracts blocked domain names and
# writes them to text file.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# Changelog:
# 1.0 initial release
# 1.1 fix URL; use pdftotext instead of CAM::PDF
# 1.2 fix URL; use full path to pdftotext
# 1.3 fix duplikates in EMTA list;
# 1.4 pdf url changed;
# 1.5 pdf url changed;
# 1.6 use https and pdftotext from package poppler-utils;
# 1.7 EMTA homepage changed;
# 1.8 EMTA homepage changed;
# 2.0.0 Change versioning;
# 2.0.1 Adopt changes in EMTA homepage;

use strict;
use warnings;
use HTTP::Tiny;
use File::Fetch;
use Data::Dumper;

#$File::Fetch::DEBUG = 1;
$File::Fetch::BLACKLIST = ['lwp']; # Throws error when using lwp

# checking webpage for downloadable package
my $fileloc  = '/var/tmp';          # file download location
my $file_out = 'emta_block.txt';
my $websess  = HTTP::Tiny->new();
my $res      = $websess->get(
'https://www.emta.ee/ariklient/registreerimine-ettevotlus/hasartmangukorraldajale/blokeeritud-hasartmangu'
);

unless ($res->{success})
{
    print STDERR 'No data from EMTA web('
      . $res->{status} . ', '
      . $res->{reason} . ')';
    exit 1;
}

# download pdf
my $pdf_location;
if ($res->{content} =~
m%<a .*?href=\"(.*?)\".*Blokeeritud ebaseadusliku kaughasartmängu serverite domeeninimed%
  )
{
    my $base_url      = $1;
    my @parts = split('/', $base_url);
    my $filename = "mta_must_nimekiri_${parts[-1]}.pdf";
    $pdf_location = $fileloc . '/' . $filename;
    my $url = "${base_url}/download/${filename}";
    print "Found url: $base_url, filename: $filename\n";

    unless (-f $pdf_location)
    {
        #Create the file
        open my $fc, ">", $pdf_location;
        close $fc;

        my $ff      = File::Fetch->new(uri => $url);
        my $where   = $ff->fetch(to => $fileloc) || die($ff->error);
    }
    else
    {
        print "File $filename allready exists. Not downloading\n";
    }
}
else
{
    print STDERR "Can't find url pointing to blocked domains file";
    exit 1;
}

# get data from pdf
my @lines = qx(/usr/bin/pdftotext -layout $pdf_location -);
my $domains;

foreach (@lines)
{
    if ($_ =~ m/^\s*\d+\s+([\w\d\-\.]+)\s*$/)
    {
        my $domain = lc($1);
        $domains->{$domain} = 1;
    }
}

# write domains to file
if ($domains)
{
    my $out = join("\n", sort(keys(%$domains)));
    open my $fh_out, '>', $fileloc . '/' . $file_out or die $!;
    print $fh_out $out;
    close $fh_out;
}
else
{
    print STDERR "Can't extract text from pdf\n";
    exit 1;
}
exit 0;
