/*

  MegaJolt tuner program.
  
  MegaJolt Lite Jr (serial) and new MegaJolt/E (USB).
  
  reads and writes files created by the official configurator. 
  writes files readable by the official configurator.
  
  this program edits advance bins, loads from file/saves to
  file (compatible with the official tuner program).
  
  now edits and flashes global data (number of cylinders, etc).
  
  does not edit bins or bin values, labels. those rarely change and a
  text editor is "good enough for me". does not edit MAP bins or
  mappings.
  
  arrow keys select a cell for editing. 
  

  AUTOMATIC UPLOAD:
  
  the direct cell-modification commands below can be enabled to
  upload to the Megajolt immediately, without the U)pload
  command. this is very useful for on-the-road tuning. auto-upload
  applies ONLY to the commands marked below. default is OFF.
  
  note that auto-upload does only upload, not burn to flash.
  
  
  EDITING SPARK MAP CELLS:

  ENTER key edits that cell; + and - increment and decrement, 
  respectively. BACKSPACE erases to zero (do that to enter a 
  new value). ENTER again to end editing. (AUTO-uPLOAD).

  + and - increment and decrement cell. (AUTO-UPLOAD)
  
  copy-row-up and copy-row-down commands. (AUTO-UPLOAD)
  
  increment-all-cells, decrement-all-cells. (AUTO-UPLOAD)
  
  load spark map from file. exact file format used
  by official tuner program.
  
 
 
  OTHER COMMANDS:
  
  auto-upload feature. toggles on and off.

  save to file. saved file compatible with official tuner.
  
  upload spark map. 
  
  burn current spark map to flash memory.
  
  
  GLOBAL SETTINGS:
  
  v3 now does global parameters:
  
  Cyls, PIP noise filter, cranking advance, wheel offset.
  
  G command uploads global parms to flash.
  
   
  
FIXME
-----

  22 mar 2019  can now edit global config. not very elegant, editing
               the value isn't very obvious, it updates the value
               in real time, but there's no highlight or
               cursor. meh.
               added ^ and v copy row up/down, deleted copy
               column left/right; useless. copy row strategically
               useful.
  21 mar 2019  verified works with MegaJolt/E on MacOS
               10.14.3 (Mojave). fixed bytes recv'd not working.
               added commands for changing global parms;
               editing isn't pretty (no cursor).
  17 mar 2019  = (below +) now increments. added more serial
               names for macos. mjlj load sensor died.
  07 jul 2018  + and - now incr/decr cell. added EDIT CELL
               to status display. simpler connect and MJ data
               update. edit-cell digit handling is primitive.
               added autoUpload. single-cell changes use updatecell,
               the rest upload the entire map. with this on
               the road spot changes are much simpler.
  04 jul 2018  bin labels were not displayed right (no
               BG color). still a problem with display; need
               to update after loading data (spacebar).
               fixed a few connect() bugs. connect() now
               makes one attempt at start; spacebar makes
               one attempt to connect per press if not connected.
               with this, files can be loaded, edited, saved
               without a serial port or MJ.
  24 apr 2018  working at least minimally useful. all commands
               work. changes made via this code visible in the
               Windows app etc. files produced are identical.
  23 apr 2018  successfully fetched runtime data from
               MJLJ, advance bins, file save.
               file load working, still missing edit non-bin
               data.
  20 apr 2018  worked out save_file.
  19 apr 2018  roughed out, working with the crappy emulator.
  18 apr 2018  new
  


    copyright Tom Jennings

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import processing.serial.*;                           // for talking arduino
import java.io.File;                                  // for finding files in folders


// adapter information.
//
Serial Arduino;
int bitRate= 38400;                                 // MJ v4
String devName = "unknown";                         // determined by tryConnect()
int ABUFFMAX = 300;                                 // room for largest blob of data from MJ
volatile byte[] aBuff = new byte [ABUFFMAX];        // the blob
volatile int aCount;                                // how much crap in blob
int commTimer;                                      // red/green link indicator
int bytes_sent, bytes_read;                         // MJ byte counts for status display

String progName=   "MegaJolt tuner v3";
String boilerplate = 
  "(L)oad file    (W)rite file          (U)pload config     (B)urn flash\n" +
  "arrow keys navigate                  (A)uto-upload cell-edits     \n" +
  "SPACEBAR re-loads all from MJ                                     \n" +
  "                                     \n" +
  "EDIT CELL(S): ENTER edit/done        GLOBAL SETTINGS (follow with G)\n" + 
  "(+) inc cell   (-)dec cell           (C)yls (4,6,8)      (P)IP NF (0...255)\n" +
  "(*)inc all     (_)dec all            (K)rank adv (0..59) (O)ffset wheel\n" +
  "(^)copy row UP (v) copy row DOWN     (G)lobal var flash                 ";

// these flags are interlocks to prevent loss of edited changes.
// 
boolean advBinModified = false;                     // in-memory data changed
boolean globalModified = false;                     // global datum(s) changed
boolean error = false;
boolean isConnected;                               // MJ detected on serial device

// colors

int BLACK =            0;  
int WHITE =          255;
int GRAYW =          240;
int GRAY1 =          190;                           // light gray
int GRAY2 =          128;                           // dark gray
int GRAY3 =           90;                           // darker gray

int BGCOLOR =      GRAY2;                           // generic grey background
int TEXTCOLOR =    BLACK;
int EDITCOLOR =    GRAY1;

// the backgronud color of advance cells reflects
// cell contents.

int LOWADVCOLOR =    240;                           // color for LOWADVANCE
int HIGHADVCOLOR =    70;                           // color for HIGHADVANCE

int sparkX, sparkY;
int sparkW, sparkH;

// fixed capabilities of the MJ.

int MAXRPMS=          10;
int MAXLOADS=         10;
int MAXADVANCE =      59;

int LOWADVANCE =       0;
int HIGHADVANCE =     50;

// -----------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------
//
// these are the datums that are downloaded from and uploaded to the
// MJ/MJLJ. they're loosely in the order given by the MJLJ API document,
// but that's just for human convenience.

// get version
byte versionMajor, versionMinor, versionBugfix;

// get state
byte advance;
byte rpmTickH, rpmTickL;                            // uS between PIPs (16 bits)
byte rpmLoadBin;                                    // adv bin cell (two nybbles)
byte load;                                          // KPa or TPS
byte contState;                                     // controller state bits
byte auxIn;                                         // aux input value
byte currAdvBin;                                    // current advance bin
byte currAdvCorr;                                   // current advance correction

// global configuration.
int cyls;                                           // global number of cylinders
byte pipNF;                                         // global PIP noise filter level
byte crankingAdvance;
byte offset;                                        // global wheel offset

// get ignition config.
byte[] rpmBinLabel = new byte [MAXRPMS];            // column "labels" (bin values)
byte[] loadBinLabel = new byte [MAXLOADS];          // row "labels" (bin values)
byte[][] advBin = new byte [MAXLOADS] [MAXRPMS];    // the spark map, loads is ROW, RPM is cols
byte userOutTypes;
byte userOutConfigs;
byte userOutThresh1;
byte userOutThresh2;
byte userOutThresh3;
byte userOutThresh4;
byte revLimit;
byte shiftLight;
byte[] advCorrBin = new byte [MAXLOADS];            // advance correction bins
byte[] advCorrVal = new byte [MAXLOADS];            // advance correction values
byte auxPHD1, auxPHD2;                              // unsigned short


byte correctionPeakHold;
byte userOutType0;
byte userOutMode0;
byte userOutValue0;
byte userOutType1;
byte userOutMode1;
byte userOutValue1;
byte userOutType2;
byte userOutMode2;
byte userOutValue2;
byte userOutType3;
byte userOutMode3;
byte userOutValue3;

// -----------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------
// -----------------------------------------------------------------------------------------


// data derived from MJ data, usually unpacking things.
int rpm;                                            // calculated from rpmTickH and L
int loadBin, rpmBin;                                // derived from rpmLoadBin


// window layout gunk.
// prog name, device, version, etc

int versionX =               15;
int versionY =               15;

int commX =                 178;
int commY =                   4;
int commH =                  12;
int commW =                  12;

// file read from/written to

int fileX =                  15;
int fileY =                  33;
int fileW =                 600;
int fileH =                  20;

// global info area. cyls, pip NF, offset on one row, hence W.

int globalX =                20;
int globalY =                55;
int globalCellW =           120;
int globalCellH =            20;

// runtime RPM, load, advance

int runtimeX =               20;
int runtimeY =               70;
int runtimeCellW =          120;
int runtimeCellH =           20;

// wtf, too many tiny little fudge factors, i hate writing
// graphical rectangle shit.

int spaceFudge= 4;

// spark advance matrix.

int originX =                50; 
int originY =               100;

// the size of each advance matrix cell space on the screen. cursors fit
// within this. box width is cellW * MAXRPMS, and box height
// is cellH * MAXLOADS.

int cellW =                     60;
int cellH =                     30;

// size of the inner rectangle used to surround or
// highlight a cell.

int selW =     cellW - spaceFudge * 2;
int selH =     cellH - spaceFudge * 2;

// advance correction

int advCorrX =               50;
int advCorrY =              450;
int advCorrH =               20;

int helpX =                  50;
int helpY =                 520;

// WINDOW dimensions. 
//
int MINWIDTH= 720;                                 // X
int MINHEIGHT= 700;                                // Y the smallest window
int MAXWIDTH= 1024;
int window_width = MINWIDTH;                       // these are calc'ed in drawBirds()
int window_height = MINHEIGHT;                            

int mjState;
boolean redraw;
int T0, T1, T2;                                    // software timers; see draw()
boolean windowResized = false;

// state machine etc for the command input stuff.

int cursorRow, cursorCol;
boolean editAtCursor = false;
String editMessage;                                // user-activity message
int keyState = 0;                                  // follows states command, arg, enter
int nnn = 0;                                       // decimal arg builds here
boolean autoUpload;                                // A command


void setup() {

// oh seriously, wtf is this nonsense.
// size (MINWIDTH, MINHEIGHT);
  size (800, 700); 
  background (0);
  noStroke();
  
  // fixed-width font needed for the terrible help command menu.

  textFont (createFont ("Courier", 14));
  background (BGCOLOR);  
  surface.setSize (window_width, window_height); 
  if (frame != null) {
    surface.setResizable (true);    // 3.0
  }

  // capture window-resize events. sets new window size and flag for
// draw() to redraw.
//
import java.awt.event.*;
  frame.addComponentListener (new ComponentAdapter() {
    public void componentResized (ComponentEvent e) {
      if (e.getSource() == frame) {
        println ("resized to: " + width + " x " + height);
        window_width= width; 
        window_height= height; 
        
        windowResized = true;
      }
    }
  })
;

  // draw the basic, if incomplete, window now 
  // just to indicate we're up etc. there's a 
  // delay before actual data appears.
  //
  draw_frame();
  draw_global();
  draw_version(); 
  draw_bin_labels();
  draw_adv_bins();
  draw_runtime();
  redraw= true;

  // this will find and connect the MJ, or not; the
  // isConnected flag will be set accordingly.
  
  connect();
  
  // ---------------------------------------------------------------------
  // wtf, resize. if done in the first iteration, nothing happens,
  // hence the 500 mS. and i can't make sense of when/why what
  // windowResized does. it never sets after a resize.
  // as a kludge workaround, spacebar sets windowResized.
  // after first iteration T0 becomes the tick timer.

  T0= 500;
}


// this does all of the drawing of the screen. "slow" datums
// (global ignition configuration, bin labels, etc) are updated
// on a timer separate from fast things (advance bin, edit bin,
// runtime cursor, etc).

void draw() {
  
  // nothing in here needs to be looked at more than
  // this often. this sets a nice tick rate and avoids
  // CPU hogging.
  
  if (millis() < T0) return;
  T0= millis() + 25;
  

  if (windowResized) {
    windowResized= false;
  }
  // ---------------------------------------------------------------------


  // this state machine fetches junk from the MJ. once at
  // startup, and any time the spacebar is hit, it fetches
  // everything. otherwise, ignition state (GETSTATE) is
  // fetched "often".
  
  switch (mjState) {
    
    // always draw the basics, to indicate success 
    // of finding/connecting to the serial device.
    
    case 0:
      advBinModified= false;
      globalModified= false;
      redraw= true;
      mjState= 1;
      break;

    // nothing else can happen until we get VERSION.
    
    case 1:
      if (isConnected == true) { 
        if (MJ_VERSION() == true) {
          mjState= 2;
          redraw= true;
          draw_status ("read MJ version");

        } else {
          draw_error ("can't read VERSION!");
        }
      }
      break;
      
    // get global configuration stuff. number of
    // cylinders, etc.
    
    case 2:
      println ("MJ: fetch global config");
      if (MJ_GETGLOBALCONFIG() == true) {
        draw_status ("read MJ global config");
        mjState= 3;
        redraw= true;
      }
      break;
      
    // get ignition configuration, mainly bin labels.
    
    case 3:
      println ("MJ: fetch ignition config");
      if (MJ_GETIGNITIONCONFIG() == true) {
        draw_status ("read MJ ignition config");
        mjState= 4;
        redraw= true;
      }
      break;
      
    // once everything is fetched this
    // state persists, updatimg the realtime
    // display, cursors, editing, etc.
    
    case 4:
        if (MJ_GETSTATE() == true) {
          redraw= true;

        } else {
          draw_error ("get-state failed");
        }
        break;
  }

  // re-draw the basics when flagged.
  
  if (redraw) {
      redraw= false;
      draw_frame();
      draw_global();
      draw_version();        // no version info yet, but draws devName
      draw_bin_labels();
  }
  
  // re-draw dynamic stuff (data, cursors) always.
  
  draw_adv_bins();
  draw_runtime();

  if (error) {
    println ("EXIT");
    Arduino.stop();          // disconnect serial
    stop();
    exit();
  } 
}


void draw_frame () {
int i, j;
int x, y;

  fill (TEXTCOLOR);
  text (boilerplate, helpX, helpY);

  for (i= 0; i < MAXRPMS; i++) {
    x= originX + i * cellW;
    for (j= 0; j < MAXLOADS; j++) {
      y= originY + j * cellH + cellH / 2;
      fill (WHITE);
      rect (x, y - cellH / 2, cellW, cellH);
    }
  }
}

void draw_error (String e) {
    
  fill (BGCOLOR);
  rect (fileX, fileY - fileH / 2, fileW, fileH);

  fill (255, 0, 0);
  text (e, fileX, fileY);
}

void draw_status (String e) {
    
  fill (BGCOLOR);
  rect (fileX, fileY - fileH / 2, fileW, fileH);

  fill (0, 255, 0);
  text (e, fileX, fileY);
}


void draw_version () {

  fill (BGCOLOR);
  rect (versionX, 0, MINWIDTH, globalCellH);

  fill (TEXTCOLOR);
  text (String.format ("%s    %s     MJ v%d.%d.%d     %4d sent %4d recv", 
    progName, devName, 
    versionMajor, versionMinor, versionBugfix, 
    bytes_sent, bytes_read), 
    
    versionX, versionY);
}


void draw_global () {
int i;

  // (data from GETGLOBALCONFIG)
    
  fill (BGCOLOR);
  i= 0;
  rect (globalX + i++ * globalCellW, globalY - globalCellH / 2, globalCellW, globalCellH);
  rect (globalX + i++ * globalCellW, globalY - globalCellH / 2, globalCellW, globalCellH);
  rect (globalX + i++ * globalCellW, globalY - globalCellH / 2, globalCellW, globalCellH);
  rect (globalX + i++ * globalCellW, globalY - globalCellH / 2, globalCellW, globalCellH);

  fill (BLACK);
  i= 0;
  text (String.format ("%4d cyls", cyls),         globalX + i++ * globalCellW,     globalY);
  text (String.format ("%4d pip NF", (int)(pipNF & 0xff)),      globalX + i++ * globalCellW,     globalY);
  text (String.format ("%4d crank adv", crankingAdvance),globalX + i++ * globalCellW,    globalY);
  text (String.format ("%4d off", offset),        globalX + i++ * globalCellW,     globalY);

  if (globalModified) {
    text ("MODIFIED",                             globalX + i++ * globalCellW,     globalY);
  }
  
  if (autoUpload == true) {
    text ("auto-upload",                          globalX + i++ * globalCellW,     globalY);
  }
}

void draw_runtime () {
int i;

  // (data from GETIGNITIONSTATE)
  
  fill (BGCOLOR);
  i= 0;
  rect (runtimeX + i++ * runtimeCellW,   runtimeY - runtimeCellH / 2 - spaceFudge, runtimeCellW, runtimeCellH);
  rect (runtimeX + i++ * runtimeCellW,   runtimeY - runtimeCellH / 2 - spaceFudge, runtimeCellW, runtimeCellH);
  rect (runtimeX + i++ * runtimeCellW,   runtimeY - runtimeCellH / 2 - spaceFudge, runtimeCellW, runtimeCellH);
  rect (runtimeX + i++ * runtimeCellW,   runtimeY - runtimeCellH / 2 - spaceFudge, runtimeCellW * 2, runtimeCellH);

  fill (BLACK);
  i= 0; 
  text (String.format ("%4d RPM", rpm),          runtimeX + i++ * runtimeCellW,   runtimeY);
  text (String.format ("%4d load", load),        runtimeX + i++ * runtimeCellW,   runtimeY);
  text (String.format ("%4d adv", advance),      runtimeX + i++ * runtimeCellW,   runtimeY);

  fill (BLACK);
  if (advBinModified) {
    text ("MODIFIED",                            runtimeX + i++ * runtimeCellW,   runtimeY);
  }
  if (editAtCursor) {
    text ("EDIT CELL",                           runtimeX + i++ * runtimeCellW,   runtimeY);
  }
}

void draw_bin_labels () {
int i;
int x, y;

  // draw the bin labels, RPM and load.
  
  y= originY - 5;
  for (i= 0; i < MAXRPMS; i++) {
    x= originX + i * cellW;

    fill (BGCOLOR);
    rect (x, y - cellH / 2, cellW, cellH);

    fill (TEXTCOLOR);
    text (String.format (" %4d", rpmBinLabel [i] * 100),  x, y);
  }
  
  x= originX - cellW / 2;
  for (i= 0; i < MAXLOADS; i++) {
    y= originY + i * cellH + cellH / 2 + spaceFudge;

    fill (BGCOLOR);
    rect (x, y - cellH / 2, cellW, cellH);

    fill (TEXTCOLOR);
    text (String.format ("%3d", loadBinLabel [i]),  x, y);
  }

  // draw the advance correction bins and values.
  // bins, on background
  
  y= advCorrY;
  for (i= 0; i < MAXRPMS; i++) {
    x= advCorrX + i * cellW;

    fill (BGCOLOR);
    rect (x, y - cellH / 2, cellW, cellH);

    fill (TEXTCOLOR);
    text (String.format ("%4d", advCorrBin [i]),  x, y);
  }
  
  // values, on white.
  
  y= advCorrY + advCorrH;
  for (i= 0; i < MAXRPMS; i++) {
    x= advCorrX + i * cellW;

    fill (WHITE);
    rect (x, y - cellH / 2, cellW, cellH);

    fill (TEXTCOLOR);
    text (String.format ("%4d", advCorrVal [i]),  x, y + spaceFudge);
  }
}



void draw_adv_bins () {
int row, col;
int x, y;

  // draw the advance matrix, including the cursors.
    
  for (row= 0; row < MAXLOADS; row++) {
    y= originY + row * cellH + cellH / 2;
    for (col= 0; col < MAXRPMS; col++) {
      x= originX + col * cellW;

      // set the cell background color
    
      cell_background (row, col,  x, y);

      // draw the (white, or green, or red) rectangle to erase,
      // then draw the number on it.
 
      fill (BLACK);
      text (String.format ("%4d", advBin [row][col]), x, y + spaceFudge);
    }
  }
  cell_cursor();
}

// for the cell about to be drawn, determine the background color
// and draw the cursor if required. the cursor-selected cell
// always has a black outline. the fill color is, in decreasing
// priority:
//
// cell being edited: bg=white
// cell selected by MJ runtime data: green
// red (high advance)..yellow (low advance)
//
// the cell is considered to be a central rectangle with the
// visible background color, and a border that is black for the
// cursor. this is done by filling the entire cell with the 
// border color then the "background" color in a smaller rectangle
// centered within it.

void cell_background (int row, int col,  int x, int y) {

  // clear out the entire cell, this creates the
  // thin cell border
  
  fill (GRAYW);
  rect (x, y - cellH / 2, cellW, cellH);

  // if editing highlight red
  
  if ((row == cursorRow) && (col == cursorCol) && editAtCursor) {
    fill (255, 0, 0);

  // the cell selected by runtime rpm/load bin
  // is highlighted in green otherwise white.
  
  } else if ((row == loadBin) && (col == rpmBin)) {
    fill (0, 255, 0);
    
  } else {
    fill (map (advBin [row] [col], LOWADVANCE, HIGHADVANCE,     LOWADVCOLOR, HIGHADVCOLOR));       
  }
  rect (x + 2, y - cellH / 2 + 2, selW + 5, selH + 5);
}


// draw the edit/select cursor and re-draw cell contents.
// the cursor gets a black full-cell background with a
// background rect that's normal cell background, or
// EDITCOLOR if editing.

void cell_cursor () {
int x, y;

  y= originY + cursorRow * cellH + cellH / 2;
  x= originX + cursorCol * cellW;

  // full cell black creates the border
  fill (BLACK);
  rect (x, y - cellH / 2, cellW, cellH);
  if (editAtCursor) {
    fill (EDITCOLOR);

  } else {
    fill (WHITE);
  }
  rect (x + 2, y - cellH / 2 + 2, selW + 4, selH + 4);
  fill (BLACK);
  text (String.format ("%4d", advBin [cursorRow][cursorCol]), x, y + spaceFudge);

}


// necessary overhead: release all the resources we consumed during setup().
//
void stop() {

  super.stop();
}
