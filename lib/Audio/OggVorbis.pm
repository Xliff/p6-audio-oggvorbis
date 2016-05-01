#!/usr/bin/perl6
unit class OggVorbis;

use v6.c;

use NativeCall;
use Audio::OggVorbis::Ogg;
use Autio::OggVorbis::Vorbis;
use Autio::OggVorbis::VorbisEnc;

# Used by both encode() and decode()
has  		$!input_data;
has	uint64	$!input_offset;
has uint64	$!bytes_io;
has 		$!ogg_buffer;

constant BLOCK_SIZE = 4096;

method getNextInputBlock($id) {
	my $block;
	my $bytes;

	# cw: I'm sure there's a slightly better way to do this.
	given $id {
		when IO::Handle {
			$block = $fh.read(BLOCK_SIZE);
			$bytes_io = $block.elems;
		}

		when Blob {
			my $block_end = $input_offset + BLOCK_SIZE;
			$block_end = $block_end > $id.elems ?? 
				$id.elems !! $block_end;

			$block = Blob.new($id[$!input_offset .. $block_end]);
			$bytes_io = $block_end - $!input_offset;
			$!input_offset += bytes_io;
		}

		default {
			# cw: Raise exception here. 
			die "Invalid input data type.";
		}
	}
	ogg_sync_wrote($oy, $bytes_io);

	# Write data into $!ogg_buffer.
	$!ogg_bufer[$_] = $block[$_] for ^$bytes_io;
}

multi method !actual_decode($id) {
	$!input_data = $id;

	# cw:
	# In the case of large files, we really 
	# don't want to load the whole file into memory.
	# How to do that AND handle the cases where the input 
	# data already resides in a Buf/Blob?
	my ($data, $result, $eos);

	my $oy = ogg_sync_state.new();
	my $os = ogg_stream_state.new();
	my $og = ogg_page.new();
	my $op = ogg_packet.new();
	my $vi = vorbis_info.new();
	my $vc = vorbis_comment.new();
	my $vd = vorbis_dsp_state.new();
	my $vb = vorbis_block.new();

	# cw: Loop in case of chained bitstreams.
	$eos = 0;
	loop {
		$buffer = ogg_sync_buffer($oy, BLOCK_SIZE);
		getNextInputBlock();

		if (ogg_sync_pageout($oy, $og) != 1) {
			last if $!bytes_io < BLOCK_SIZE;
			
			die "Not an Ogg bitstream.";
		}

		ogg_stream_init($os, ogg_page_serialno($og));
		vorbis_info_init($vi);
		vorbis_comment_init($vc);

		die "Error reading first page of Ogg bitstream data"
			if ogg_stream_pagein($os, $og) < 0;

		die "Error reading initial header packet."
			if ogg_stream_packetout($os, $op) != 1;

		die "Ogg bitstream does not contain Vorbis data"
			if vorbis_synthesis_headerin($vi, $vc, $op) < 0;

		my $i = 0;
		while ($i < 2) {
			while ($i < 2) {
				$result = ogg_sync_pageout($oy, $og);
				last if $result == 0;

				if ($result == 1) {
					ogg_stream_pagein($os, $og);

					while ($i < 2) {
						$result = ogg_stream_packetout($os, $op);
						last if $result == 0;
						die "Read corrupted secondary header from ogg packet"
							if $result < 0;

						die "Received corrupt secondary header from vorbis packet";

						$i++;
					}
				}
			}

			$!ogg_buffer = ogg_sync_buffer($oy, 4096);
			getNextInputBlock();

			die "Unexpected end of file while reading vorbis headers.";
				if $!bytes_io == 0 && $i < 2;
		}

		# cx: -YYY- Need to figure out what the eventual output is 
		#     supposed to look like and include vorbis_info and 
		#     vorbis_comment data.
		#
		#     Output should *not* need any knowledge of C structures.
		my @uc := nativecast(CArray[Str], $vc.user_comments);
		#loop (my $ci = 0; @uc[$ci].defined; $ci++) {
		#	diag "Comment: {@uc[$ci]}";
		#}

		$convsize = (4096 / $vi.channels).floor;

		# Start central decode.
		if (vorbis_synthesis_init($vd, $vi) == 0) {
			#...
		}
	}

	# cw: At the very least, let's return a hash. 
}

# cw: Decode file on disk.
multi method decode(IO::Handle $fh) {
	$!input_data = $fh;
	$!input_offset = 0;

	.actual_decode($fhandle)
}

# cw: Decode file on disk.
multi method decode(Str $fn) {
	# check for existence or throw exception
	die "File $fn not found" unless $fn.IO.e;

	my $fh = open($fn, :r, :bin);
	.decode: $fn;
}

# cw: Decode data in memory. Returns Blob.
multi method decode(Blob $b) {
	.actual_decode($b);
}

