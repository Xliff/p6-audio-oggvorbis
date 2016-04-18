#!/usr/bin/perl6

use v6;
use NativeCall;

sub pointerArrayTest(Pointer is rw)
	is native('./03-read-vorbis.so')
	returns int32
	{ * };

my Pointer $appp .= new;

say "Calling C routine...";
my $ret = pointerArrayTest($appp);
die 'Borkage in C Lib!' unless $ret == 0;
say "Routine returned with code {$ret}...";

my @ap := nativecast(CArray[CArray[num32]], $appp);

my @chan_a := nativecast(CArray[num32], @ap[4]);

for (450..499) -> $s {
	say "chan_a[$s]: {sprintf "%.0f", @chan_a[$s]}";
}