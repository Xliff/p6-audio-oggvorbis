#!/usr/bin/perl6
unit class OggVorbis;

use v6.c;

use NativeCall;
use Audio::OggVorbis::Ogg;
use Autio::OggVorbis::Vorbis;
use Autio::OggVorbis::VorbisEnc;

# Used by both encode() and decode()
has  		$!input_data;
has 		$!output_data;
has	uint64	$!input_offset;
has uint64	$!bytes_io;
has 		$!ogg_buffer;

constant BLOCK_SIZE = 4096;

method readInputBlock {
	my $block;

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

method writeOutputBlock($block) {
	# cw: -XXX-
	#     Getting there. But need to handle 
	#	  MULTIPLE channels.

	# Proper Interleave!
	# <psch> m:  my $lol = [(1, 2, 3), (4, 5, 6), (7, 8, 9)]; say [Z](|$lol).flat

	given $output_data {
		when IO::Handle {
			$!output_data.write($block);
		}

		when Buf {
			# cw: Could use ~=, but don't want new object.
			$!output_data.push($block);
		}

		when Nil {
			# Need to create $!output_data as Buf
			$!output_data = Buf[int16].new($block);
		}
	}

}

multi method !actual_decode($id, $od) {
	$!input_data = $id;
	$!output_data = $od;
	$!input_offset = 0;

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
		readInputBlock();

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
			readInputBlock();

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
		my @outblocks;
		push @outblocks, Buf[int16].new(0 xx BLOCK_SIZE)
			for ^$vi.channels;

		# Start central decode.
		if (vorbis_synthesis_init($vd, $vi) == 0) {
			vorbis_block_init($vd, $vb);

			# Straight decode loop until end of stream 
			while ($eos != 0) {
		        while ($eos != 0) {
					$result = ogg_sync_pageout($oy, $og);

					# check if more data needed.
					last if $result == 0;

					die "Corrupt or missing data in bitstream" 
						if $result < 0;
						
					ogg_stream_pagein($os, $og);
		            loop {
						$result = ogg_stream_packetout($os, $op);
		              
		              	# check if more data needed.
		              	last if $result == 0;

						# check for unexpected error.
		              	die "Corrupt or missing data in bitstream."
							if $result < 0;

		                # We have a packet.  Decode it.
		                my Pointer $pcm;
		                my $samples;

		                if (vorbis_synthesis($vb, $op) == 0) {
							vorbis_synthesis_blockin($vd, $vb);
		                }

		                $pcm .= new;
		                $samples = vorbis_synthesis_pcmout($vd, $pcm);
		                while ($samples > 0) {
		            		my ($j, $clipflag, $bout);
							$clipflag = 0;
							$bout = $samples < $convsize ?? $samples !! $convsize;

							my @channels := nativecast(CArray[CArray[num32]], $pcm);
							loop ($i = 0; $i < $vi.channels; $i++) {
								loop (my $j = 0; $j < $bout; $j++) {
									my ($val) = @channels[$i][$j] * 32767.5;

									if ($val > 32767) {
										$val = 32767;
										$clipflag = 1;
									} elsif ($val < -32768) {
								        $val = -32768;
								        $clipflag = 1;
								  	}

								  	@outblocks[$i][$j] = $val;
								}
							}
		                  
		                  	# cw: -YYY- May want to *not* emit this unless the 
		                  	#     user specifically asks for it.
							warn sprintf("Clipping in frame %ld", $vd.sequence)
								if $clipflag == 1;                  
		                  
		                  	# cw: -XXX- 
		                  	# Emit @outblocks either to disk or store to memory
		                  	#fwrite(convbuffer, 2 * vi.channels, bout, stdout);
		                  	#
		                  	# Keep channels separate, interleve or both? 
		                  	# Probably should be an option, which means
		                  	# the write routine will need to be more complex.
		                  	writeOutputBlock();
		                  
		                  	vorbis_synthesis_read($vd, $bout);
	                  	}            
            		}

				    $eos = 1 if ogg_page_eos($og) != 0;
				}

				if ($eos == 0) {
					readInputBlock();
					$eos = 1 if $bytes == 0;
		      	}
			}

	      	# cw: This is worth keeping in mind -- 
		  	# 
			# * ogg_page and ogg_packet structs always point to storage in
		    # * libvorbis.  They're never freed or manipulated directly
			vorbis_block_clear($vb);
			vorbis_dsp_clear($vd);
		}

		ogg_stream_clear($os);
		vorbis_comment_clear($vc);
		vorbis_info_clear($vi);			# must be called last

	}
	ogg_sync_clear($oy);

	# cw: At the very least, let's return a hash. 
	my %return_val = {
		channels		=> $vi.channels,
		bitrate			=> $vi.bitrate,
		comments 		=> @uc,
		vendor			=> $vc.vendor,
	}

	if $!input_data ~~ Blob {
		# cw: -XXX- Add binary data to return value.
	} else {
		# cw: -XXX- Add output file size. 
	}
}

# cw: Decode file on disk.
multi method decode(IO::Handle $fr, IO:Hanlde $fw) {
	.actual_decode($fr, $fw);
}

# cw: Decode file on disk.
multi method decode(Str $fn) {
	# check for existence or throw exception
	die "File $fn not found" unless $fn.IO.e;

	# Not a WAV because there won't be a header.
	my $fno = $fn ~~ s/ '.' .+ $/.raw/;

	my $fhi = $fn.IO.open :r, :bin;
	my $fho = open($fno, :w, :bin);
	die "Can't open output file!" unless $fho;

	.decode: $fhi, $fho;
}

# cw: Decode data in memory. Returns Blob.
multi method decode(Blob $b) {
	.actual_decode($b, Nil);
}


# cw: Do we -really- need instance variables of this class, or can these be static routines?
# cw: ALSO...current interface to decode() is incomplete. We need to handle options.
#     and said options should have reasonable defaults!
