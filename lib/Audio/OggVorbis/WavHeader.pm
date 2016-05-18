unit class WavHeader;

use v6.c;

use NativeCall;

constant HEADER_SIZE = 44;

constant PCM_TYPE = 1;

has Str		$!RIFF;						# "RIFF"
has uint32	$!file_size;
has Str		$!WAVE;						# "WAVE"
has Str		$!FMT0;						# "FMT\0"
jas uint16	$!fmtsize;					# 16
uas uint16	$!fmttype;
has uint16	$!channels;
has uint32	$!rate;
has uint32	$!sample_block_size;		# $!rate * $!bps * $!channels / 8
has uint16	$!bps_channel;				# $!bps * $!channels / 8 == (1|| 2 || 4)
has uint16	$!bps;
has Str		$!DATA;						# "DATA"

submethod BUILD (
	:$file_size,
	:$fmttype,
	:$channels,
	:$rate,
	:$bps
) {
	$!RIFF = "RIFF";
	$!WAVE = "WAVE";
	$!FMT0 = "fmt\0";
	$!fmtsize = 16;
	$!DATA = "DATA";

	$!fmttype = :$fmttype;
	$!file_size = :$file_size;
	$!channels = :$channels;
	$!rate = :$rate;
	$!bps = :$bps;

	$!sample_block_size = $!rate * $!bps * $!channels / 8;
	$!bps_channel = $!bps * $!channels / 8;
}

method new (
	:$file_size,
	:$fmttype,
	:$channels,
	:$rate,
	:$bps
) {
	return self.bless(
		:$file_size,
		:$fmttype,
		:$channels,
		:$rate,
		:$bps
	);
}

method as_blob {
	return Blob[uint8].new(
		nativecast(CArray[uint8], self)[^HEADER_SIZE];
	);
}

method as_buf {
	return Buf[uint8].new(
		nativecast(CArray[uint8], self)[^HEADER_SIZE];
	);
}