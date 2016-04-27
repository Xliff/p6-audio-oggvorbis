#!/usr/bin/perl6

use v6.c;
use Test;
use lib 'lib';

use NativeCall;
use Audio::OggVorbis::Ogg;
use Audio::OggVorbis::Vorbis;
use Audio::OggVorbis::VorbisEnc;

sub writeToFile(IO::Handle $f, $d, $len) {
	my @a := nativecast(CArray[uint8], $d); 
	$f.write(Blob.new(@a[^$len]));
}

# cw: Implements a variation of the following:
#     https://svn.xiph.org/trunk/vorbis/examples/encoder_example.c

my $os = ogg_stream_state.new();
my $og = ogg_page.new();
my $op = ogg_packet.new();
my $vi = vorbis_info.new();
my $vc = vorbis_comment.new();
my $vd = vorbis_dsp_state.new();
my $vb = vorbis_block.new();

my $eos = 0;

my ($ret, $i, $foundrate);

my $fh = open "resources/SoundMeni.wav", :bin;

# cw: An ammusing comment from the source, that applies here:
# 		"we cheat on the WAV header; we just bypass 44 bytes (simplest WAV
#  		header is 44 bytes) and assume that the data is 44.1khz, stereo, 16 bit
#		little endian pcm samples. This is just an example, after all."

# cw: When the encode() routine goes into Audio::OggVorbis, no assumptions
#     will be made. It will just be *cheating a little more* to read the 
#     header.

# Skip header.
$fh.read(44);

vorbis_info_init($vi);
$ret = vorbis_encode_init_vbr($vi, 2, 44100, 0.1);

if ($ret != 0) {
	flunk "encoder failed to initialize with error code $ret";
	die "Aborting.";
}

ok $ret == 0, 'encoder initialized';

# Set up output file.
my $fhw = open("SoundMenu-test.ogg", :w, :bin);
unless ($fhw) {
	flunk "error opening output file.";
	die "Aborting";
}

# Add a comment
vorbis_comment_init($vc);
vorbis_comment_add_tag($vc, "TEST", "Encoding via Audio::OggVorbis");

vorbis_analysis_init($vd, $vc);
vorbis_block_init($vd, $vb);

ogg_stream_init($os, rand);

my ogg_packet $header      .= new;
my ogg_packet $header_comm .= new;
my ogg_packet $header_code .= new;

# cw: Sanity check
ok [&&] (
	$header      ~~ ogg_packet, 
	$header_comm ~~ ogg_packet, 
	$header_code ~~ ogg_packet
), 'headers initialized';

vorbis_analysis_headerout($vd, $vc, $header, $header_comm, $header_code);

# cw: Will be streamlined when implemented in Audio::OggVorbis
ogg_stream_packetin($os, $header);
ogg_stream_packetin($os, $header_comm);
ogg_stream_packetin($os, $header_code);

# Write headers and insure the data begins on a new page.
repeat {
	$ret = ogg_stream_flush($os, $og);
	last if $ret != 0;

	writeToFile($fhw, $og.header, $og.header_len);
	writeToFile($fhw, $og.body, $og.body_len);

	# cw: Wow. This was missing from the original code.
	$eos = 1 if ogg_page_eos($og);
} while ($eos == 0);

### MOAR HERE


# Properly clear structures after use.
ogg_stream_clear($os);

# cw: This is the only testable routine!
$ret = vorbis_block_clear($vb);
ok $ret == 0, 'vorbis_block cleared';

vorbis_dsp_clear($vd);
vorbis_comment_clear($vc);
# Must be called LAST.
vorbis_info_clear($vi);

# Remember: ogg_page and ogg_packet structs always point to storage in
#           libvorbis.  They're never freed or manipulated directly!

done-testing;