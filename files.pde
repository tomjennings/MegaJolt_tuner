/*

 file functions, invoked by key stroke, etc.
 
 
 save_file();
 
 load_file();
 
 */


void load_file () {

  selectInput ("config file to load", "do_load_file");
}

void do_load_file (File selection) {
int i;
String fn;

  if (selection == null) {
    println ("load_file CANCELLED");
    return;
  }
  fn= selection.getAbsolutePath();
  println ("loading from", fn);

  String I[]= loadStrings (fn);
  println ("loaded " + I.length + " lines");

  // for each line in the loaded config, split into keyword/payload
  // pairs and load 'em into memory.

  for (i= 0; i < I.length; i++) {
    if (I [i].equals ("") == false) {  // skip blank lines
//      println (i + ": " + I[i]);
      load_config_line (I [i]);
    }
  }

  // draw filename etc on the screen
  
  fill (BGCOLOR);
  rect (fileX, fileY - fileH + spaceFudge, fileW, fileH);
  fill (BLACK);
  text (String.format ("read: %s", fn), fileX, fileY);
  
  // we just overwrote all cells (probably) so edits
  // thrown away.
  
  advBinModified= false;
  redraw= true;
}

// break a config line into keyword and payload

void load_config_line (String I) {
String[] m;
String[] A = new String [2];
int D[] = new int [MAXLOADS];
int i, d;

  try {
    A= split (I, '=');
    
  } catch (Exception e) {              // garbage line
    return;
  }

//  println ("KEYWORD", A[0], " ARGS", A[1]);
  
  // datums of the form
  // KEYWORD=1,2,3,4,5...
  
  m= match (A [0], "mapBins");
  if (m != null) {
    D = int (split (A [1], ','));
    for (i= 0; i < MAXLOADS; i++) {
      loadBinLabel [i]= (byte)D [i];
    }
    return;
  }

  m= match (A [0], "rpmBins");
  if (m != null) {
    D = int (split (A [1], ','));
    for (i= 0; i < MAXLOADS; i++) {
      rpmBinLabel [i]= (byte)D [i];
    }
    return;
  }

  m= match (A [0], "correctionBins");
  if (m != null) {
    D = int (split (A [1], ','));
    for (i= 0; i < MAXLOADS; i++) {
      advCorrBin [i]= (byte)D [i];
    }
    return;
  }

  m= match (A [0], "correctionValues");
  if (m != null) {
    D = int (split (A [1], ','));
    for (i= 0; i < MAXLOADS; i++) {
      advCorrVal [i]= (byte)D [i];
    }
    return;
  }

  // advanceN data goes in advBin[N] [0..9]
  
  m= match (A [0], "advance([0-9]+)");
  if (m != null) {
    int row= Integer.parseInt (m[1]);      // row is N
    D = int (split (A [1], ','));          // 1,2,3,4,5...
    for (i= 0; i < MAXLOADS; i++) {
      advBin [row] [i]= (byte)D [i];       // fill adv bins
    }
    return;
  }
  
  
  // single argument
  
  m= match (A [0], "correctionPeakHold");
  if (m != null) {
    d = int (A [1]);
    correctionPeakHold= (byte)d;
    return;
  }


  m= match (A [0], "userOutType0");
  if (m != null) {
    d = int (A [1]);
    userOutType0= (byte)d;
    return;
  }

  m= match (A [0], "userOutMode0");
  if (m != null) {
    d = int (A [1]);
    userOutMode0= (byte)d;
    return;
  }

  m= match (A [0], "userOutValue0");
  if (m != null) {
    d = int (A [1]);
    userOutValue0= (byte)d;
    return;
  }


  m= match (A [0], "userOutType1");
  if (m != null) {
    d = int (A [1]);
    userOutType1= (byte)d;
    return;
  }

  m= match (A [0], "userOutMode1");
  if (m != null) {
    d = int (A [1]);
    userOutMode1= (byte)d;
    return;
  }

  m= match (A [0], "userOutValue1");
  if (m != null) {
    d = int (A [1]);
    userOutValue1= (byte)d;
    return;
  }
  
  

  m= match (A [0], "userOutType2");
  if (m != null) {
    d = int (A [1]);
    userOutType2= (byte)d;
    return;
  }

  m= match (A [0], "userOutMode2");
  if (m != null) {
    d = int (A [1]);
    userOutMode2= (byte)d;
    return;
  }

  m= match (A [0], "userOutValue2");
  if (m != null) {
    d = int (A [1]);
    userOutValue2= (byte)d;
    return;
  }
  
  
  

  m= match (A [0], "userOutType3");
  if (m != null) {
    d = int (A [1]);
    userOutType3= (byte)d;
    return;
  }

  m= match (A [0], "userOutMode3");
  if (m != null) {
    d = int (A [1]);
    userOutMode3= (byte)d;
    return;
  }

  m= match (A [0], "userOutValue3");
  if (m != null) {
    d = int (A [1]);
    userOutValue3= (byte)d;
    return;
  }



  m= match (A [0], "shiftLight");
  if (m != null) {
    d = int (A [1]);
    shiftLight= (byte)d;
    return;
  }

  m= match (A [0], "revLimit");
  if (m != null) {
    d = int (A [1]);
    revLimit= (byte)d;
    return;
  }

  println ("load_file: unknown keyword:", A[0]);
}



// save file (as). 
void save_file () {

  selectOutput ("file to save config to", "do_save_file");
}


// writing data to the save file is done in this callback.

void do_save_file (File selection) {
String[] O = { };            // output array, written to file
String fn;

  if (selection == null) {
    println ("save_file CANCELLED");
    return;
  }
  fn= selection.getAbsolutePath();

  println ("saving to", fn);

  O= save_array (O, "mapBins", loadBinLabel, MAXLOADS);
  O= save_array (O, "rpmBins", rpmBinLabel, MAXRPMS);
  O= save_array (O, "advance0", advBin [0], MAXLOADS);
  O= save_array (O, "advance1", advBin [1], MAXLOADS);
  O= save_array (O, "advance2", advBin [2], MAXLOADS);
  O= save_array (O, "advance3", advBin [3], MAXLOADS);
  O= save_array (O, "advance4", advBin [4], MAXLOADS);
  O= save_array (O, "advance5", advBin [5], MAXLOADS);
  O= save_array (O, "advance6", advBin [6], MAXLOADS);
  O= save_array (O, "advance7", advBin [7], MAXLOADS);
  O= save_array (O, "advance8", advBin [8], MAXLOADS);
  O= save_array (O, "advance9", advBin [9], MAXLOADS);
  O= save_array (O, "correctionBins", advCorrBin, MAXRPMS);
  O= save_array (O, "correctionValues", advCorrVal, MAXRPMS);

  O= save_datum (O, "userOutType0", userOutType0);
  O= save_datum (O, "userOutMode0", userOutMode0);
  O= save_datum (O, "userOutValue0", userOutValue0);

  O= save_datum (O, "userOutType1", userOutType1);
  O= save_datum (O, "userOutMode1", userOutMode1);
  O= save_datum (O, "userOutValue1", userOutValue1);

  O= save_datum (O, "userOutType2", userOutType2);
  O= save_datum (O, "userOutMode2", userOutMode2);
  O= save_datum (O, "userOutValue2", userOutValue2);

  O= save_datum (O, "userOutType3", userOutType3);
  O= save_datum (O, "userOutMode3", userOutMode3);
  O= save_datum (O, "userOutValue3", userOutValue3);

  O= save_datum (O, "shiftLight", shiftLight);
  O= save_datum (O, "revLimit", revLimit);

  saveStrings (fn, O);

  // draw filename etc on the screen
  
  fill (BGCOLOR);
  rect (fileX, fileY - fileH + spaceFudge, fileW, fileH);
  fill (BLACK);
  text (String.format ("wrote: %s", fn), fileX, fileY);
}

// save one datum formatted as text "name=a,b,c,d..."
// appending it to the given output array.

String[] save_datum (String[] O, String name, int item) {
  String[] L = new String[2];     // line builder (keyword=arg)

  L [0]= name;                                  // revLimit
  L [1]= nf (item);                             // 123
  String l= join (L, "=");                      // is now revLimit=123
  return append (O, l);                         // add to write list
}

// save an array of bytes formatted as text "name=a,b,c,d..."
// appending it to the given output array.

String[] save_array (String[] O, String name, byte[] arr, int num) {
  String[] a = {};            // built list of args as text
  String[] L = new String[2];     // line builder (keyword=arg)

  for (int i= 0; i < num; i++) {                // array of bin values as text
    a= append (a, nf (arr [i]));
  }
  String args= join (a, ",");                   // join those into a string

  L [0]= name;                                  // rpmBins
  L [1]= args;                                  // 1,2,3,4,5...
  String l= join (L, "=");                      // is now rpmBins=1,2,3,4,5...
  return append (O, l);                             // add to write list
}
