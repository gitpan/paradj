#!/usr/local/bin/perl

# Julius C. Duque

use diagnostics;
use strict;
use warnings;
use Getopt::Long;
use TeX::Hyphen;

my ($width, $hyphenate, $left, $centered, $right, $both);
my ($indent, $newline);
GetOptions("width=i" => \$width, "help" => \$hyphenate,
  "left" => \$left, "centered" => \$centered,
  "right" => \$right, "both" => \$both,
  "indent:i" => \$indent, "newline" => \$newline);

my $hyp = new TeX::Hyphen;

syntax() if (!$width);
$indent = 0 if (!$indent);

local $/ = "";

while (<>) {
  my @linein = split;
  printpar(@linein);
  print "\n" if ($newline);
}

sub printpar
{
  my (@par) = @_;
  my $firstline = 0;

  while (@par) {
    $firstline++;
    my ($buffer, $word);
    my ($charcount, $wordlen) = (0, 0);
    my $linewidth = $width;

    if ($firstline == 1) {
      $linewidth -= $indent;
      print " " x $indent;
    }

    while (($charcount < $linewidth) and (@par)) {
      $word = shift @par;
      $buffer .= $word;
      $wordlen = length($word);
      $charcount += $wordlen;
      $buffer .= " ";
      $charcount++;
    }

    chop $buffer;
    $charcount--;

    if ($charcount == $wordlen) {
      $linewidth = $wordlen;
      my ($pos, $pre_word_len) = (0, 0);
      if ($hyphenate) {
        if ($word =~ /^([^a-zA-Z]*)([a-zA-Z-']+)([^a-zA-Z]*)$/) {
          my $pre_word = $1;
          $pre_word_len = length($pre_word);
          my $stripped_word = $2;
          $pos = hyphenate_word($stripped_word, $width);
          $pos = 0 if ($wordlen <= $width);
        }

        if ($pos) {
          $charcount = $pre_word_len + $pos;
          my $post_word = substr $word, $charcount;
          unshift(@par, $post_word);
          $buffer = substr $word, 0, $charcount;
          $buffer .= "-";
          $charcount++;
        }
      }
    }

    my $lineout = $buffer;

    if ($charcount > $linewidth) {
      my ($pos, $pre_word_len) = (0, 0);
      if ($hyphenate) {
        if ($word =~ /^([^a-zA-Z]*)([a-zA-Z-']+)([^a-zA-Z]*)$/) {
          my $pre_word = $1;
          $pre_word_len = length($pre_word);
          my $stripped_word = $2;
          my $unfilled = $linewidth - $charcount + $wordlen
            - $pre_word_len + 1;

          $pos = hyphenate_word($stripped_word, $unfilled);
        }
      }

      $charcount -= $wordlen;

      if ($pos == 0) {
        $charcount--;
        unshift(@par, $word);
      } else {
        my $post_word = substr $word, ($pre_word_len + $pos);
        unshift(@par, $post_word);
        $charcount = $charcount + $pre_word_len + $pos;
      }

      $lineout = substr $buffer, 0, $charcount;

      if ($pos) {
        $lineout .= "-";
        $charcount++;
      }
    }

    my $spaces_to_fill = $linewidth - $charcount;

    if ($centered) {
      my $leftfill = int($spaces_to_fill/2);
      print " " x $leftfill;
    } elsif ($right) {
      print " " x $spaces_to_fill;
    } elsif ($both) {
      my $tempbuf = $lineout;
      my $replacements_made = 0;

      if (@par) {
        my $reps = 1;

        while (length($tempbuf) < $linewidth) {
          last if ($tempbuf !~ /\s/);
          if ($tempbuf =~ /(\S+ {$reps})(\S+)/) {
            $tempbuf =~ s/(\S+ {$reps})(\S+)/$1 $2/;
            $replacements_made++;
            $tempbuf = reverse $tempbuf;
          } else {
            $reps++;
          }
        }
      }

      if ($replacements_made % 2 == 0) {
        $lineout = $tempbuf;
      } else {
        $lineout = reverse $tempbuf;
      }
    }

    print "$lineout\n";
  }
}

sub hyphenate_word
{
  my ($tword, $unfilled) = @_;
  my @hyphen_places = $hyp->hyphenate($tword);

  if (@hyphen_places) {
    @hyphen_places = reverse @hyphen_places;

    foreach my $places (@hyphen_places) {
      return $places if ($places < $unfilled - 1);
    }
  }

  return 0;
}

sub syntax
{
  print "Usage:\n";
  print "  $0 --width=n [options] file1 [file2 file3 ...]\n";
  print "  cat file1 [file2 file3 ...] | $0 --width=n [options]\n\n";
  print "Options:\n";
  print "--width=n (or -w=n or -w n)   Line width is n chars ";
  print "long\n";
  print "--left (or -l)                Left-justified";
  print " (default)\n";
  print "--right (or -r)               Right-justified\n";
  print "--centered (or -c)            Centered\n";
  print "--both (or -b)                Both left- and\n";
  print "                                right-justified\n";
  print "--indent=n (or -i=n or -i n)  Leave n spaces for ";
  print "initial\n";
  print "                                indention (defaults ";
  print "to 0)\n";
  print "--newline (or -n)             Output an empty line \n";
  print "                                between ";
  print "paragraphs\n";
  print "--hyphenate (or -h)           Hyphenate word that ";
  print "doesn't\n";
  print "                                fit on a line\n";
  exit 0;
}

