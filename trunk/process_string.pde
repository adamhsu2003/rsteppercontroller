


//steps per inch or mm
float _units[3] = {
  X_STEPS_PER_INCH,Y_STEPS_PER_INCH,Z_STEPS_PER_INCH};
float curve_section = CURVE_SECTION_INCHES;

//our feedrate variables.
float feedrate = 0.0;
long feedrate_micros = 0;
uint8_t stepping = DEFAULT_STEP;


void setXYZ(FloatPoint *fp) {
  fp->x = getValue('X') + ((abs_mode) ? 0 : xaxis->current_units); 
  fp->y = getValue('Y') + ((abs_mode) ? 0 : yaxis->current_units);
  fp->z = getValue('Z') + ((abs_mode) ? 0 : zaxis->current_units);
}


//Read the string and execute instructions
void process_string(uint8_t  *instruction) {
  uint8_t code;
  //command commands = NULL;
  FloatPoint fp;


  //the character / means delete block... used for comments and stuff.
  if (instruction[0] == '/') 	{
    Serial.println("ok");
    return;
  }

  enable_steppers();
  purge_commands(); //clear old commands
  parse_commands(instruction); //create linked list of arguments
  if (command_exists('G')) {
    code = getValue('G');

    switch(code) {
    case 0: //Rapid Motion
    case 1: //Coordinated Motion
      //Set Target
      setXYZ(&fp);
      set_target(&fp);
      //Set Speed
      if (code == 1 && command_exists('F') && ((feedrate = getValue('F')) > 0)) feedrate_micros = feedrate;
      else feedrate_micros = getMaxFeedrate();
      //Move.
      dda_move(feedrate_micros);
      break;
    case 2://Clockwise arc
    case 3://Counterclockwise arc
      FloatPoint cent;
      float angleA, angleB, angle, radius, length, aX, aY, bX, bY;

      //Seet fp Values
      setXYZ(&fp);
      // Centre coordinates are always relative
      cent.x = xaxis->current_units + getValue('I');
      cent.y = yaxis->current_units + getValue('J');

      aX = (xaxis->current_units - cent.x);
      aY = (yaxis->current_units - cent.y);
      bX = (fp.x - cent.x);
      bY = (fp.y - cent.y);

      if (code == 2) { // Clockwise
        angleA = atan2(bY, bX);
        angleB = atan2(aY, aX);
      } 
      else { // Counterclockwise
        angleA = atan2(aY, aX);
        angleB = atan2(bY, bX);
      }

      // Make sure angleB is always greater than angleA
      // and if not add 2PI so that it is (this also takes
      // care of the special case of angleA == angleB,
      // ie we want a complete circle)
      if (angleB <= angleA) angleB += 2 * M_PI;
      angle = angleB - angleA;

      radius = sqrt(aX * aX + aY * aY);
      length = radius * angle;
      int steps, s, step;
      steps = (int) ceil(length / curve_section);

      FloatPoint newPoint;
      for (s = 1; s <= steps; s++) {
        step = (code == 3) ? s : steps - s; // Work backwards for CW
        newPoint.x = cent.x + radius * cos(angleA + angle * ((float) step / steps));
        newPoint.y = cent.y + radius * sin(angleA + angle * ((float) step / steps));
        set_target(&newPoint);

        // Need to calculate rate for each section of curve
        feedrate_micros = (feedrate > 0) ? feedrate : getMaxFeedrate();

        // Make step
        dda_move(feedrate_micros);
      }

      break;
    case 4: //Dwell
      delay((int)getValue('P'));
      break;
    case 20: //Inches for Units
      _units[0] = X_STEPS_PER_INCH;
      _units[1] = Y_STEPS_PER_INCH;
      _units[2] = Z_STEPS_PER_INCH;
      curve_section = CURVE_SECTION_INCHES;
      calculate_deltas();
      break;
    case 21: //mm for Units
      _units[0] = X_STEPS_PER_MM;
      _units[1] = Y_STEPS_PER_MM;
      _units[2] = Z_STEPS_PER_MM; 
      curve_section = CURVE_SECTION_MM;
      calculate_deltas();
      break;
    case 28: //go home.
      set_target(&zeros);
      dda_move(getMaxFeedrate());
      break;
    case 30://go home via an intermediate point.
      //Set Target
      setXYZ(&fp);
      set_target(&fp);
      //go there.
      dda_move(getMaxFeedrate());
      //go home.
      set_target(&zeros);
      dda_move(getMaxFeedrate());
      break;
    case 90://Absolute Positioning
      abs_mode = true;
      break;
    case 91://Incremental Positioning
      abs_mode = false;
      break;
    case 92://Set as home
      set_position(&zeros);
      break;
    case 93://Inverse Time Feed Mode
      break;  //TODO: add this 
    case 94://Feed per Minute Mode
      break;  //TODO: add this
    default:
      Serial.print("huh? G");
      Serial.println(code,DEC);
    }
  }
  if (command_exists('M')) {
    code = getValue('M');
    switch(code) {
    case 0: //M0 turn off motor
      motor_off();
      break;
    case 1: //M1 turn on motor
      motor_on();
      break;
    case 10: //M10 S{1,2,4,8,16} -- set stepping mode
      if (command_exists('S')) {
        code = getValue('S');
        if (code == 1 || code == 2 || code == 4 || code == 8 || code == 16) {
          stepping = code;
          setStep(stepping);
          break;
        }
      }
    default:
      Serial.print("huh? M");
      Serial.println(code,DEC);
    }
  }
  Serial.println("ok");//tell our host we're done.
}




