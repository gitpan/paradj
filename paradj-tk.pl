#!/usr/local/bin/perl

# Perl/Tk version of pretty
# Julius C. Duque

use diagnostics;
use strict;
use warnings;
use Tk;
use Tk::Balloon;
use TeX::Hyphen;

my $INDENT_DEF = 0;
my $LWIDTH_DEF = 70;
my $VERSION = "1.3.0";
my $TITLE = "Paragraph Adjuster $VERSION";
my $AUTHOR = "Julius C. Duque";
my $indent = $INDENT_DEF;
my $newline = 1;
my $hyphenate = 1;
my $width = $LWIDTH_DEF;
my ($BOTH, $LEFT, $RIGHT, $CENTERED) = (1, 2, 3, 4);
my $format_choice = $BOTH;   # both left- and right-justified
my ($infile, $outfile) = ();

my $hyp = new TeX::Hyphen;

local $/ = "";    # paragraph mode

my $mw = new MainWindow();
drawButtons();
Tk::MainLoop();

sub processfile
{
  my $retval = 0;

  open INFILE, $infile;
  if (open OUTFILE, "> $outfile") {
    while (<INFILE>) {
      my @linein = split;
      $retval = printpar(@linein);
      last if ($retval);
      print OUTFILE "\n" if ($newline);
    }

    close INFILE;
    close OUTFILE;
  }

  printMessage("info", "OK", "File was successfully saved.")
    if (!$retval);
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
      print OUTFILE " " x $indent;
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

    if ($format_choice == $CENTERED) {
      my $leftfill = int($spaces_to_fill/2);
      print OUTFILE " " x $leftfill;
    } elsif ($format_choice == $RIGHT) {
      print OUTFILE " " x $spaces_to_fill;
    } elsif ($format_choice == $BOTH) {
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

    print OUTFILE "$lineout\n";
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

sub drawButtons
{
  $mw->title($TITLE);

  # Status bar widget
  my $status = $mw->Label(-width => 70, -relief => "sunken",
    -anchor => "w")->pack(-side => "bottom", -padx => 1, -pady => 1,
    -fill => "x");

  # Create balloon widget
  my $b = $mw->Balloon(-statusbar => $status);

  # Create menu bar frame
  my $menubar = $mw->Frame(-borderwidth => 4, -relief => "ridge")->
    pack(-side => "top", -fill => "x"); 

  # Create Open File button
  my $openfilebutton = $menubar->
    Button(-text => "Open File", -relief => "raised", -width => 10,
      -command => [\&fileDialog, $mw, "open"])->pack(-side => "left");

  $b->attach($openfilebutton, -msg => "Open a file to be reformatted");

  # Create Save File button
  my $savefilebutton = $menubar->
    Button(-text => "Save To File", -relief => "raised", -width => 10,
      -command => sub {
          if (defined $infile and $infile ne "") {
            fileDialog($mw, "save");
          } else {
              printMessage("warning", "OK",
                "You must open a file to reformat first.");
          }
        })->pack(-side => "left");

  $b->attach($savefilebutton,
    -msg => "Proceed with reformatting and save result to a file");

  # Create About button
  my $aboutbutton = $menubar->Button(-text => "About",
    -relief => "raised", -width => 10,
    -command => [\&printMessage, "info", "OK",
      "A Perl/Tk script created by $AUTHOR"])->pack(-side => "left");

  $b->attach($aboutbutton,
    -msg => "$TITLE created by $AUTHOR");

  # Create Quit button
  my $quitbutton = $menubar->Button(-text => "Dismiss",
    -relief => "raised", -width => 10, -command => sub { exit })->
    pack(-side => "right");

  $b->attach($quitbutton, -msg => "Quit this Perl/Tk script");

  my $both = $mw->Radiobutton(-variable => \$format_choice,
    -value => $BOTH, -text => "Both left- and right-justified")->
    pack(-side => "top", -anchor => "w");

  $b->attach($both, -msg => "Each line is left- and right-justified");

  my $left = $mw->Radiobutton(-variable => \$format_choice,
    -value => $LEFT, -text => "Left-justified")->pack(-side => "top",
    -anchor => "w");

  $b->attach($left, -msg => "Each line is left-justified, ragged-right");

  my $right = $mw->Radiobutton(-variable => \$format_choice,
    -value => $RIGHT, -text => "Right-justified")->pack(-side => "top",
    -anchor => "w");

  $b->attach($right, -msg => "Each line is right-justified, ragged-left");

  my $centered = $mw->Radiobutton(-variable => \$format_choice,
    -value => $CENTERED, -text => "Centered")->pack(-side => "top",
    -anchor => "w");

  $b->attach($centered, -msg =>
    "Each line is equidistant from the left and right margins");

  $both->select;   # Set default to $both

  my $chknewline = $mw->Checkbutton(-variable => \$newline,
    -text => "Insert empty lines between paragraphs")->
    pack(-side => "top", -anchor => "w");

  $b->attach($chknewline,
    -msg => "Insert a blank line between two consecutive paragraphs");

  $chknewline->select;   # Set default to $newline

  my $chkhyphen = $mw->Checkbutton(-variable => \$hyphenate,
    -text => "Hyphenate")->
    pack(-side => "top", -anchor => "w");

  $b->attach($chkhyphen,
    -msg => "Hyphenate word that does not fit on a line");

  $chknewline->select;   # Set default to $hyphenate

  my $f = $mw->Frame->pack(-side => "left");

  my $l = $f->Label(-text => "Indention: ", -justify => "left");

  $b->attach($l,
    -msg => "Number of spaces at the start of every paragraph");

  Tk::grid($l, -row => 0, -column => 0);

  my $tindent = $f->Entry(-width => 2, -textvariable => \$indent,
    -justify => "right");

  $b->attach($tindent,
    -msg => "Number of spaces at the start of every paragraph");

  Tk::grid($tindent, -row => 0, -column => 1);

  $l = $f->Label(-text => "characters (default: $INDENT_DEF) ",
    -justify => "left");

  $b->attach($l,
    -msg => "Number of spaces at the beginning of each paragraph");

  Tk::grid($l, -row => 0, -column => 2);

  $l = $f->Label(-text => "Line width: ", -justify => "left");
  Tk::grid($l, -row => 1, -column => 0);
  $b->attach($l, -msg => "Maximum length of every line");

  my $tlwidth = $f->Entry(-width => 2, -textvariable => \$width,
    -justify => "right");

  $b->attach($tlwidth, -msg => "Maximum length of every line");
  Tk::grid($tlwidth, -row => 1, -column => 1);

  $l = $f->Label(-text => "characters (default: $LWIDTH_DEF)",
    -justify => "left");

  $b->attach($l, -msg => "Maximum length of every line");
  Tk::grid($l, -row => 1, -column => 2);
}

sub printMessage
{
  my ($icon, $type, $outputmsg) = @_;
  my $msg = $mw->messageBox(-icon => $icon, -type => $type,
  -title => $TITLE, -message => $outputmsg);
}

sub fileDialog {
  my ($w, $operation) = @_;
  my @types = (["Text files", [qw/.txt .doc/]],
    ["Text files", "", "TEXT"],
    ["All files", "*"]
  );

  if ($operation eq "open") {
    $infile = $w->getOpenFile(-filetypes => \@types);
  }

  if ($operation eq "save") {
      $outfile = $w->getSaveFile(-filetypes => \@types,
        -initialfile => "Untitled",
        -defaultextension => ".txt");

    processfile() if (defined $outfile and $outfile ne "");
  }
}

