
char LF = '\n';

// keystrokes perform editing and value-changing functions
//
//
void keyPressed() {

  if (key == ESC) key= 0;
    
  if (key == CODED) {
    if (editAtCursor == true) return;

    switch (keyCode) {
      case RIGHT: cursorCol++; if (cursorCol >= MAXLOADS) cursorCol= MAXLOADS - 1; break;    
      case LEFT:  cursorCol--; if (cursorCol < 0) cursorCol= 0; break;
      case DOWN:  cursorRow++; if (cursorRow >= MAXRPMS) cursorRow= MAXRPMS - 1; break;    
      case UP:    cursorRow--; if (cursorRow < 0) cursorRow= 0; break;
      default: break;
    }
    return;
  }

  // when a keyboard command selects an edit/enter number command,
  // that case statement sets a funny state number, 1000 and above,
  // to redirect keystrokes to it. upon completion (usually CR)
  // keyState is set to 0.
  //
  // non-edit command keys are always < 1000.
 
  if (keyState < 1000) {
    keyState= key;
  }
  
  switch (keyState) {  

    case 'w': case 'W': save_file(); break;
    case 'l': case 'L': load_file(); break;
    case 'a': case 'A': autoUpload= !autoUpload; break;
    
    case 'u': case 'U': 
      MJ_UPDATEIGNITION(); 
      advBinModified= false;
      break;

    case 'b': case 'B': MJ_WRITEFLASH(); break;   

    // modify global configuration data.
    case 'c': case 'C': 
      nnn= cyls;                // number to edit
      draw_error ("edit global CYLS");
      println ("EDIT CYLS"); 
      keyState= 2000; 
      break;

    case 'p': case 'P': 
      nnn= pipNF; 
      draw_error ("edit global PIP NF");
      println ("EDIT PIPNF"); 
      keyState= 2001; 
      break;

    case 'k': case 'K': 
      nnn= crankingAdvance;
      draw_error ("edit global CRANK ADV");
      println ("EDIT CRANK ADV"); 
      keyState= 2002; 
      break;

    case 'o': case 'O': 
      nnn= offset; 
      draw_error ("edit global OFFSET");
      println ("EDIT CYLS"); 
      keyState= 2003; 
      break;

    case 'g': case 'G': 
      MJ_UPDATEGLOBALCONFIG(); 
      globalModified= false;
      break;

    
    case ' ':
      editAtCursor= false;
      keyState= 0;
      if (isConnected == false) {
        isConnected= connect();
      }
      
      // this causes the startup state machine to re-fetch
      // everything. any edits not saved are lost.

      mjState= 0;
      break;
      

    // incr/decr current cell

    case '-': 
      if (advBin [cursorRow][cursorCol] > 0) { 
        --advBin [cursorRow][cursorCol]; 
        advBinModified= true; 
      } 
      if (advBinModified && autoUpload) {
        MJ_UPDATECELL (cursorRow, cursorCol, advBin [cursorRow] [cursorCol]);
      }
      break;    

  case '+': 
  case '=':
    if (advBin [cursorRow][cursorCol] < MAXADVANCE - 1) { 
      ++advBin [cursorRow][cursorCol]; 
      advBinModified= true; 
    }
    if (advBinModified && autoUpload) {
      draw_status ("auto upload");
      MJ_UPDATECELL (cursorRow, cursorCol, advBin [cursorRow] [cursorCol]);
    }
    break;

    // decrement all cells
    
    case '_':
      for (int i= 0; i < MAXRPMS; i++) {
        for (int j= 0; j < MAXLOADS; j++) {
            if (advBin [i][j] > 0) --advBin [i][j];            
        }
      }
      if (autoUpload) {
        draw_status ("auto upload");
        MJ_UPDATEIGNITION();
        advBinModified= false;
        
      } else {
        advBinModified= true;
      }
      break;

    // increment all cells
    
    case '*':
      for (int i= 0; i < MAXRPMS; i++) {
        for (int j= 0; j < MAXLOADS; j++) {
            if(advBin [i][j] < MAXADVANCE - 1) ++advBin [i][j];
        }
      }
      if (autoUpload) {
        draw_status ("auto upload");
        MJ_UPDATEIGNITION();
        advBinModified= false;
        
      } else {
        advBinModified= true;
      }
      break;
        
    // duplicate cursor row, up.

    case '^':
      if (cursorRow > 0) {
        println ("cursorRow=" + cursorRow + " cursorCol=" + cursorCol);
        for (int i= 0; i < MAXRPMS; i++) {
          advBin [cursorRow - 1] [i]= advBin [cursorRow] [i];
        }
        advBinModified= true;
      }
      if (advBinModified && autoUpload) {
        draw_status ("auto upload");
        MJ_UPDATEIGNITION();
        advBinModified= false;
        
      } else {
        advBinModified= true;
      }
      break;

    // duplicate cursor row, down.
    
    case 'v':
      if (cursorRow < MAXLOADS - 2) {
        for (int i= 0; i < MAXRPMS; i++) {
          advBin [cursorRow + 1] [i]= advBin [cursorRow] [i];
        }
        advBinModified= true;
      }
      if (advBinModified && autoUpload) {
        draw_status ("auto upload");
        MJ_UPDATEIGNITION();
        advBinModified= false;
        
      } else {
        advBinModified= true;
      }
      break;

    case  '\n': 
      keyState= 1000;                     // edit cell mode
      editAtCursor= true;
      nnn= advBin [cursorRow] [cursorCol]; // number to edit
      println ("EDIT CELL"); 
      break;
    
    
    // manual edit of one cell value.

    case 1000: 
      if (editNum (key, 0, 59, "advance") == true) {
        keyState= 0; 
        editAtCursor= false;
      }
      advBin [cursorRow] [cursorCol]= (byte)nnn;    // value in table so it displays
      if (advBinModified && autoUpload) {
        draw_status ("auto upload");
        MJ_UPDATECELL (cursorRow, cursorCol, advBin [cursorRow] [cursorCol]);
        advBinModified= false;
        
      } else {
        advBinModified= true;
      }
      println ("keystate ", keyState);
      break;


    // manual edit of global datums.

    case 2000: 
      if (editNum (key, 4, 8, "cyls (4,6,8)", globalX, globalY) == true) {
        keyState= 0; 
        editAtCursor= false;
      }
      cyls= (byte)nnn;   
      globalModified= true;
      break;

    case 2001: 
      if (editNum (key, 0, 255, "PIPNF", globalX, globalY) == true) {
        keyState= 0; 
        editAtCursor= false;
      }
      pipNF= (byte)nnn;
      globalModified= true;
      break;

    case 2002: 
      if (editNum (key, 0, 59, "crank adv", globalX, globalY) == true) {
        keyState= 0; 
        editAtCursor= false;
      }
      crankingAdvance= (byte)nnn;   
      globalModified= true;
      break;

    case 2003: 
      if (editNum (key, -5, 5, "offset", globalX, globalY) == true) {
        keyState= 0; 
        editAtCursor= false;
      }
      offset= (byte)nnn;   
      globalModified= true;
      break;


    default: 
      println ("unused ", keyState);
      keyState= 0; 
      break;    
   }
   
   // not all keys need this, but low load and reliable.
   
   redraw= true;
}
// edit a number within the advance matrix.
//
boolean editNum (char key, int lowLimit, int highLimit, String prompt) {
int x, y;

  x= originX + cursorRow * cellW;
  y= originY + cursorCol * cellH + cellH / 2;
  return editNum (key, lowLimit, highLimit, prompt, x, y);
}


// put up the editor and input a number. this works in the global var
// inputVal (which can be preset with a default value). the last-entered
// key is returned (to detect abort vs. enter, etc).
//
boolean editNum (char key, int lowLimit, int highLimit, String prompt, int x, int y) {

  fill (BGCOLOR);
  rect (x, y - cellH / 2, cellW, cellH);

  fill (TEXTCOLOR);

  switch (key) {  
    case '\n': 
      println ("d ", advBin [cursorRow] [cursorCol]);
      if ((nnn <= highLimit) && (nnn >= lowLimit)) {
        fill (BGCOLOR);
        rect (x, y - cellH / 2, cellW, cellH);
        return true;
      }
      break;

    case BACKSPACE:          nnn /= 10; break;    // decimal backspace
    case DELETE:             nnn= 0; break;
    case ' ':                nnn= 0; break;
    case '+': case '=':    ++nnn; break;
    case '-':              --nnn; break;

// the FIRST digit typed clears the value to zero before
// continuing.

    case '0': case '1': case '2': case '3': case '4': 
    case '5': case '6': case '7': case '8': case '9':
      nnn *= 10; 
      nnn += (int)(key - '0'); 
      println ("editNum: " + nnn);
      break;
  }
  if (nnn < lowLimit) nnn= lowLimit;
  if (nnn > highLimit) nnn= highLimit;
  return false;
}
