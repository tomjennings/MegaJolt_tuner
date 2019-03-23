/*

  serial communication gunk.

  connect() tries each system serial interface, sends a VERSION 
  command to test it and upon correct response declares success. 
  the tuner program will not proceed until this returns true.
  
  the MJ_*() functions issue the appropriate command, fetch
  and primitively check the returned data, and update the
  display window.
 
  
*/


// get MJLJ version. returns true if success.

boolean MJ_VERSION () {
  
  if (isConnected == false) return false;

  if (MJ_command ('V', 3) == true) {
    versionMajor= aBuff [0];
    versionMinor= aBuff [1];
    versionBugfix= aBuff [2];
   return true;
  }
  return false;
}

// get MJ global configuration

boolean MJ_GETGLOBALCONFIG () {
 
  if (isConnected == false) return false;

  if (MJ_command ('g', 64) == true) {
    cyls= aBuff [0];
    pipNF= aBuff [1];
    crankingAdvance= aBuff [2];
    offset= aBuff [3];
    return true;
  }
  return false;
}

    
// get MJ current state.

boolean MJ_GETSTATE () {
int a, i;

  if (isConnected == false) return false;

  if (MJ_command ('S', 9) == true) {
    i= 0;
    advance= aBuff [i++];

    // rpm delivered as number of uS between ignition pulses.
    
    rpmTickH= aBuff [i++];
    rpmTickL= aBuff [i++];
    a= (rpmTickH << 8) | rpmTickL;
    if (a > 0) {
      rpm= 60 * (1000000 / (a * (cyls / 2)));

//    } else {
//      rpm= 0;
    }
    // bin selection is packed nybbles
    
    rpmLoadBin= aBuff [i++];
    rpmBin=  rpmLoadBin >> 4;
    loadBin= rpmLoadBin & 0x0f;

    load= aBuff [i++];

    contState= aBuff [i++];
    auxIn= aBuff [i++];
    currAdvBin= aBuff [i++];
    currAdvCorr= aBuff [i++]; 
    return true;
  }
  return false;
}


// MJ get ignition configuration. this gets the
// spark map and bin info.

boolean MJ_GETIGNITIONCONFIG () {
int a, i, j;

  if (isConnected == false) return false;

  if (MJ_command ('C', 150)) {
    a= 0;
    
    // 10 RPM bin values, then 10 LOAD bin values.
    
    for (i= 0; i < 10; i++) {
      rpmBinLabel [i]= aBuff [a++];
    }
    for (i= 0; i < 10; i++) {
      loadBinLabel [i]= aBuff [a++];
    }
    
    // 100 spark advance bin contents, 10 x 10 map
    
    for (i= 0; i < MAXLOADS; i++) {
      for (j= 0; j < MAXRPMS; j++) {
        advBin [i] [j]= aBuff [a++];
      }
    }

   // user output stuff

   userOutTypes= aBuff[a++];
   userOutConfigs= aBuff[a++];
   userOutThresh1= aBuff[a++];
   userOutThresh2= aBuff[a++];
   userOutThresh3= aBuff[a++];
   userOutThresh4= aBuff[a++];
   revLimit= aBuff[a++];
   shiftLight= aBuff[a++];

   // advance correction bins and values
   
   for (i= 0; i < MAXRPMS; i++) {
     advCorrBin [i]= aBuff [a++];
   }
   for (i= 0; i < MAXRPMS; i++) {
     advCorrVal [i]= aBuff [a++];
   }

   auxPHD1= aBuff [a++];
   auxPHD2= aBuff [a++];
   return true;
  }
  return false;
}

// update one cell in the advance map. no response.

void MJ_UPDATECELL (int row, int col, int adv) {
byte a;

  if (isConnected == false) return;

  mj_write ('u');
  a= (byte)(col << 4);
  a |= (byte)row;
  mj_write (a);
  mj_write ((byte)adv);
}

// upload the big blob of data to the MJ.

void  MJ_UPDATEIGNITION () {
int i, j;

  if (isConnected == false) return;

    mj_write ('U');
    
    // 10 RPM bin values, then 10 LOAD bin values.
    
    for (i= 0; i < 10; i++) {
      mj_write (rpmBinLabel [i]);
    }
    for (i= 0; i < 10; i++) {
      mj_write (loadBinLabel [i]);
    }
    
    // 100 spark advance bin contents, 10 x 10 map
    
    for (i= 0; i < MAXLOADS; i++) {
      for (j= 0; j < MAXRPMS; j++) {
        mj_write (advBin [i] [j]);
      }
    }

   // user output stuff

   mj_write (userOutTypes);
   mj_write (userOutConfigs);
   mj_write (userOutThresh1);
   mj_write (userOutThresh2);
   mj_write (userOutThresh3);
   mj_write (userOutThresh4);
   mj_write (revLimit);
   mj_write (shiftLight);

   // advance correction bins and values
   
   for (i= 0; i < MAXRPMS; i++) {
     mj_write (advCorrBin [i]);
   }
   for (i= 0; i < MAXRPMS; i++) {
     mj_write (advCorrVal [i]);
   }

   mj_write (auxPHD1);
   mj_write (auxPHD2);
}


// tell the MJ to write RAM config to flash. no response.

void MJ_WRITEFLASH() {
  
  if (isConnected == false) return;

  mj_write ('W');
  delay (500);                          // just guessing
}


// write global configuration. this command is different. from the API doc:
//       "Note: a 150ms delay is required every 32 bytes, 
//        starting with the beginning of the Global
//        Configuration data section (byte 2)"
//
// this command writes a block of 64 bytes, with a delay
// after each 32 count.

void MJ_UPDATEGLOBALCONFIG () {
int i;

  if (isConnected == false) return;

  mj_write ('G');

  mj_write (cyls);                      // 1
  mj_write (pipNF);                     // 2
  mj_write (crankingAdvance);           // 3
  mj_write (offset);                    // 4

  // padd out the rest of the block with 0's, i guess.
  
  for (i= 0; i < 32 - 4; i++) {         // pad out
    mj_write (0);
  }
  delay (200);

  for (i= 0; i < 32; i++) {
    mj_write (0);
  }
  delay (200);
}


// execute MJ command; clear the receive buffer, send command letter, 
// fetch response bytes until we reach the given count or timeout.

boolean MJ_command (char c, int count) { 

  if (isConnected == false) return false;

  aCount= 0;                           // flush the buffer
  mj_write (c);                        // send command

  // there's some unaccountable sluggishness in
  // serialEvent or something that delays response.
  // the count+timeout loop below should deal with
  // any per-response-byte delay or inter-byte delay.
  // even making delay 1000 mS doesn't cure it.

  delay (count);
  
  int T= millis() + 100;
  while ((millis() < T) && (aCount < count)) {
    // wait timeout or count
  }
  bytes_read += aCount;                // for display

  if (aCount >= count) {               // success
    println (millis(), "MJ_command", c + ": ok, got", aCount);
    fill (0, 255, 0);                  // green
    
  } else {
    println (millis(), "MJ_command", c + ": expected", count, "got", aCount);
    fill (255, 0, 0);                  // red
  }
  rect (commX, commY, commW, commH);
  return aCount >= count;
}


// write bytes to the Arduino/MJ, and count them.

void mj_write (char d) {
  
  ++bytes_sent;
  Arduino.write (d);
}

void mj_write (byte d) {
  
  ++bytes_sent;
  Arduino.write (d);
}

void mj_write (int d) {
  
  ++bytes_sent;
  Arduino.write (d & 0xff);
}



// locate and connect to the Arduino base adapter. this takes two
// steps: for each serial device (OS dependent), connect, look for the
// #baseToFlock ID string. returns status, and isConnected set.
//
boolean connect () {
int i, j;

  String[] devs= Serial.list();               // get the list of all serial devices
  
  // for each usable device in the list, try to open it, and if success,
  // send an MJ "version" command to it to make sure it's a MegaJolt.
  
  for  (i= 0; i < devs.length; i++) {         // try each one in secession
    devName= devs[i];                         // candidate name
    if (serial_device_ok (devName) == true) {
      draw_version();                         // put on the screen
      println ("connect probing " + devName);
      draw_error ("probing " + devName);

      // see if we can open the port. ugh, the Serial object is sluggish.
      // these disgusting delay()'s are REQUIRED. though it doesn't throw
      // an exception, it's either not ready to write to, or it writes
      // and early reads are lost. delays fix it.
      
      try {
        Arduino = new Serial (this, devName, bitRate);
        draw_error ("device " + devName + " checking if MegaJolt");
        println (devName + ": connected at ", bitRate);

        // LET THE STUPID SERIAL OBJECT BECOME ONE WITH REALITY.      
        delay (1000);
        
        // this is required, else the MJ_* commands won't work.
        
        isConnected= true;
        
        // now see if it's an MJ at the end of the link. 
        for (j= 3; j-- > 0; ) {
          if (MJ_VERSION() == true) {
            draw_error ("successful connect to MegaJolt");
            println ("connectMJ on the line");
            return isConnected;
          }
        }
        isConnected= false;

        draw_error (devName + " is not a MegaJolt");
        println ("connect " + devName + " not a MegaJolt");
        Arduino.stop();
        delay (1000);

      } catch (Exception e) {
        draw_error ("cannot connect to " + devName);
        println ("connect " + devName + ": port in use " + e);
      }
    }  // end if serial_device_ok...
  }    // end of for... devs list
  
  // nothing in the list was usable.
  
  draw_error ("no usable serial devices");
  println ("connect: no usable serial devices\n");
  return isConnected;
}

// return true if this device name is OK to use. system dependent.

boolean serial_device_ok (String devName) {
  
  if (devName.startsWith ("/dev/ttyUSB") ||                // (debian linux)
    devName.startsWith ("/dev/ttyACM") ||                  // (debian arduino, testing)
    devName.startsWith ("/dev/tty.usbmodem") ||            // (macintosh)
    devName.startsWith ("/dev/cu.usbserial") ||            // (macintosh)
//    devName.startsWith ("/dev/cu.KeySerial") ||            // (macintosh)
    devName.startsWith ("/dev/cu.USA19H") ||            // (macintosh)
    devName.startsWith ("/dev/tty.usbserial") ||           // (macintosh)
    devName.startsWith ("COM")) {                          // (windows)

    return true;
      
  } else {
    return false;
  }
}

// serialEvent is invoked when the port has data for us. 
// pull out the data and append it to the global
// buffer. the buffer must be drained elsewhere.

void serialEvent (Serial p) {
byte[] buff = new byte [100];
int a;
int s;

  a= p.readBytes (buff);
  for (s= 0; s < a; s++) {
    aBuff [aCount]= buff [s++];
    if (aCount < ABUFFMAX) ++aCount;
  }
}
