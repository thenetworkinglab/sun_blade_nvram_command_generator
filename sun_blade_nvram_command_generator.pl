#!/usr/bin/perl

#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program.  If not, see <http://www.gnu.org/licenses/>.

use warnings qw(all);

use Getopt::Long;
use Pod::Usage;
use POSIX;

=pod 

=head1 SYNOPSIS

    sun_blade_nvram_command_generator.pl --starting_address=starting_memory_address --mac=mac_address_in_colon-separated_notation

=head1 DESCRIPTION

Creates the commands needed to reprogram the NVRAM on a Sun Blade workstation.
In order to use this, you need 2 pieces of information:

1. --mac - The MAC/Ethernet address of the workstation, in colon-separated notation. 
The first 24 bits of this *should* be either 8:0:20 if it is an early Sun Blade, or
0:3:ba if your machine was manufactured after February 2001.  
The last 24 bits of this will be printed on an orange sticker on the 
NVRAM chip on the computer's motherboard. If someone has already replaced the NVRAM chip and
you don't have an orange sticker, you can make up an Ethernet address, e.g. 0:0:ba:c0:ff:ee
although any software that is tied to the original Ethernet address/host ID may no longer work.

2. --starting_address - the memory address of the eeprom device in your workstation. How you find
this address is with going to the OpenBoot prompt (the 'ok' prompt) and typing:

    show-devs

This will display a long list of devices. You are looking for something like:

    /pci@1f,0/ebus@c/eeprom@1,0

Then, change into that device 'directory':

    cd /pci@1f,0/ebus@c/eeprom@1,0

Then, print out its properties with:

    .properties

This will print out something like

    model               mk48t59
    address             fff58000
    reg                 00000001 00000000 00002000
    device_type         nvram
    name                eeprom

The value in the 'address' field above, i.e. in this case, 'fff58000' is the address you're looking for here.

Then, based on the above made up MAC address/NVRAM sticker and the memory address, you would run
this program using:

    sun_blade_nvram_command_generator.pl --starting_address=fff58000 --mac=00:03:ba:c0:ff:ee 

This program will then print to standard output the commands you should use to reprogram your NVRAM
chip.

=cut

# Deal with the command line arguments
GetOptions(
    'help'                  => \my $help,
    'starting_address=s'    => \my $starting_address,
    'mac=s'                 => \my $mac
) or pod2usage(q(-verbose) => 1);
pod2usage(q(-verbose) => 2) if $help;

# Some more variables we should declare
my $offset = 0x1fd8;
my @mac_array;
my $segment;
my $xor_val;
my $serial;
my $host_id;

# First, convert the entered MAC address into an array and convert all the values 
# from strings to hexadecimal:
@mac_array = split(':', $mac);

for ( my $i = 0; $i < 6; $i++ ) {
    $mac_array[$i] = hex(0x . $mac_array[$i]);
}

# Create the host ID:
$host_id = 830 . sprintf("%x", $mac_array[3]) . sprintf("%x", $mac_array[4]) . sprintf("%x", $mac_array[5]);

# Create the serial #:
$serial = hex(0x . substr($host_id, 1));

# Determine the memory segment address:
$segment = hex(0x . substr($starting_address, 0, 4));

# Now generate the reprogramming instructions:
print "\n";
print "**********************************************************\n";
print "Here are the commands you can use to reprogram your NVRAM.\n";
print "First we have to do some setup.\n";
print "Type the following in at the OpenBoot PROM's 'ok' prompt:\n";
print "**********************************************************\n";
print "\n";

print "$starting_address >physical\n";
print "showstack\n";
print "2000 memmap\n";
print "1fd8 +\n";
print "30 dump\n";
print "\n";

print "**********************************************************\n";
print "If this has all gone well, you should see something like:\n";
print "**********************************************************\n";
print "\n";

print "          0  1  2  3  4  5  6  7  \\/  9  a  b  c  d  e  f   01234567v9abcdef\n";
print sprintf("%x", $segment) . "1fd0 08 00 40 02 00 00 00 00  00 00 00 00 00 00 00 06  ..@.............\n";
print sprintf("%x", $segment) . "1fe0 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 04  ................\n";
print sprintf("%x", $segment) . "1ff0 10 00 00 00 00 00 00 00  00 48 16 20 03 29 12 47  .........H. .).G\n";
print sprintf("%x", $segment) . "2000 00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 ff  ................\n";
print "\n";

print "**********************************************************\n";
print "Now enter the following commands to reprogram the NVRAM:\n";
print "**********************************************************\n";
print "\n";

# format code:
print "01 " . sprintf("%x", $segment) . sprintf("%x", $offset) . " c!\n";

# machine type:
print "83 " . sprintf("%x", $segment) . sprintf("%x", $offset + 1) . " c!\n";

# MAC address:
print sprintf("%02x", $mac_array[0]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 2) . " c!\n";
print sprintf("%02x", $mac_array[1]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 3) . " c!\n";
print sprintf("%02x", $mac_array[2]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 4) . " c!\n";
print sprintf("%02x", $mac_array[3]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 5) . " c!\n";
print sprintf("%02x", $mac_array[4]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 6) . " c!\n";
print sprintf("%02x", $mac_array[5]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 7) . " c!\n";

# date/time of manufacture (just use zeroes):
print "00 " . sprintf("%x", $segment) . sprintf("%x", $offset + 8) . " c!\n";
print "00 " . sprintf("%x", $segment) . sprintf("%x", $offset + 9) . " c!\n";
print "00 " . sprintf("%x", $segment) . sprintf("%x", $offset + 10) . " c!\n";
print "00 " . sprintf("%x", $segment) . sprintf("%x", $offset + 11) . " c!\n";

# host ID:
print sprintf("%02x", $mac_array[3]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 12) . " c!\n";
print sprintf("%02x", $mac_array[4]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 13) . " c!\n";
print sprintf("%02x", $mac_array[5]) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 14) . " c!\n";

# XOR the values we've entered above to calculate the checksum:
$xor_val = 0x01 ^ 0x83;
$xor_val = $xor_val ^ $mac_array[0];
$xor_val = $xor_val ^ $mac_array[1];
$xor_val = $xor_val ^ $mac_array[2];
$xor_val = $xor_val ^ $mac_array[3];
$xor_val = $xor_val ^ $mac_array[4];
$xor_val = $xor_val ^ $mac_array[5];
$xor_val = $xor_val ^ $mac_array[3];
$xor_val = $xor_val ^ $mac_array[4];
$xor_val = $xor_val ^ $mac_array[5];

# The command to store the checksum
print sprintf("%x", $xor_val) . " " . sprintf("%x", $segment) . sprintf("%x", $offset + 15) . " c!\n";
print "\n";

print "**********************************************************\n";
print "Done! Now enter the following to reboot:\n";
print "**********************************************************\n";
print "\n";
print "reset-all\n";
print "\n";

print "**********************************************************\n";
print "When it boots you should see something that looks like\n";
print "the following, with the relevant values changed for your\n";
print "machine:\n";
print "**********************************************************\n";
print "\n";

print "Sun Blade 100 (UltraSPARC-IIe), Keyboard Present\n";
print "OpenBoot 4.0, 1024 MB memory installed, Serial #$serial\n";
print "Ethernet address " . sprintf("%x", $mac_array[0]) . ":" . sprintf("%x", $mac_array[1]) . ":" . sprintf("%x", $mac_array[2]) . ":" . sprintf("%x", $mac_array[3]) . ":" . sprintf("%x", $mac_array[4]) . ":" . sprintf("%x", $mac_array[5]) . ", Host ID: $host_id.\n";
print "\n";
