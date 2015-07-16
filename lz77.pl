#!/usr/bin/perl
use autodie;

my $WINDOW_SIZE = 12;
my $PREVIEW_SIZE = 12;
my $CHUNK_SIZE = 1024;

sub max ($$) { $_[$_[0] < $_[1]] }
sub min ($$) { $_[$_[0] > $_[1]] }

sub find {
	my ($buffer, $start, $ptr, $length, $plen) = @_;
	for my $i (1..$plen+1) {
		return $i - 1 > $length ? (1, $i - 1) : (0, $length) if substr($buffer, $start, $i) ne substr($buffer, $ptr, $i);
	}
	return (1, $plen+$ptr-$start);
}

sub compress {
	my ($source, $target) = @_;
	open my $input, "<", $source or die "Can't open file $source\n";
	open my $output, ">", $target or die "Can't open file $target\n";

	my $buffer;
	binmode($input);
	while (read($input, $buffer, $CHUNK_SIZE)) {
		my $wlen = 0;
		my $len = length($buffer);
		my $ptr = 0;
		my $plen = min($len - $ptr + 1, $PREVIEW_SIZE);
		while ($ptr < $len) {
			my $start = 0;
			my $length = 0;
			my $update = 0;
			for my $i (reverse 1..$wlen) {
				($update, $length) = find($buffer, $ptr - $i, $ptr, $length, $plen);
				$start = $i if $update;
			}
			
			$ptr += $length;
			my $next = $ptr >= $len ? '' : ord(substr($buffer, $ptr, 1));
			$ptr++;
			$wlen = min($wlen+$length+1, $WINDOW_SIZE);
			$plen = min($len - $ptr, $PREVIEW_SIZE);
			print $output "$start,$length,$next\n";
		}
	}
	close $input;
	close $output;
}

sub decompress {
	my ($source, $target) = @_;
	open my $input, "<", $source or die "Can't open file $source\n";
	open my $output, ">", $target or die "Can't open file $target\n";

	my $buffer = '';
	binmode($output);
	while (<$input>) {
		chomp;
		my ($start, $length, $next) = split /,\s*/;
		
		while ($length) {
			my $len = min($start, $length);
			$buffer .= substr($buffer, -$start, $len);
			$length -= $len;
		}
		length($next) ? $buffer .= chr($next) : print $output $buffer;
		$buffer = '' unless length($next);
	}
	print $output $buffer;
	close $input;
	close $output;
}

my ($command, $source, $target) = @ARGV;
if ($command eq 'c' or $command eq '-c') {
	die "no input file!\n" unless defined $source;	
	$target = "$source~" unless defined $target;
	compress($source, $target);
} elsif ($command eq 'x' or $command eq '-x') {
	die "no input file!\n" unless defined $source;	
	$target = "$source~" unless defined $target;
	decompress($source, $target);
} elsif ($command eq 't' or $command eq '-t') {
	my $temp = "$target~";
	compress($source, $temp);
	decompress($temp, $target);
	unlink $temp;
} elsif ($command eq 'h' or $command eq '-h') {
	die "I know nothing...\n";
} else {
	die "nothing to do!\n";
}
