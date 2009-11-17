


void bzero(uint8_t *ptr, uint8_t len) {
  for (uint8_t i=0; i<len; i++) ptr[i] = 0;
}

void init_steppers(){
  //turn them off to start.
  disable_steppers();

  // setup data
  xaxis = &xaxis_data;
  yaxis = &yaxis_data;
  zaxis = &zaxis_data;

  axis_array[0] = xaxis;
  axis_array[1] = yaxis;
  axis_array[2] = zaxis;

  bzero((uint8_t*)&xaxis_data, sizeof(struct axis_t)); 
  bzero((uint8_t*)&yaxis_data, sizeof(struct axis_t)); 
  bzero((uint8_t*)&zaxis_data, sizeof(struct axis_t)); 

  // configure pins
  xaxis->step_pin = STEP_X;
  yaxis->step_pin = STEP_Y;
  zaxis->step_pin = STEP_Z;

  xaxis->min_pin  = MIN_X;
  yaxis->min_pin  = MIN_Y;
  zaxis->min_pin  = MIN_Z;

  xaxis->max_pin  = MAX_X;
  yaxis->max_pin  = MAX_Y;
  zaxis->max_pin  = MAX_Z;

  xaxis->direct_step_pin = _STEP_X;
  yaxis->direct_step_pin = _STEP_Y;
  zaxis->direct_step_pin = _STEP_Z;

  //figure our stuff.
  calculate_deltas();
}


axis nextEvent(void) {
  if (xaxis->nextEvent < yaxis->nextEvent) {
    return (xaxis->nextEvent <= zaxis->nextEvent) ? xaxis : zaxis;
  } 
  else {
    return (yaxis->nextEvent <= zaxis->nextEvent) ? yaxis : zaxis;
  }
}

void dda_move(float feedrate) {
  uint32_t starttime,duration;
  float distance;
  axis a;
  uint8_t i;

  // do not exceed maximum feedrate
  //if (feedrate > getMaxFeedrate()) feedrate = getMaxFeedrate();
feedrate = getMaxFeedrate(); //XXX
  
  //uint8_t sreg = intDisable();

  // distance / feedrate * 60000000.0 = move duration in microseconds
  distance = sqrt(xaxis->delta_units*xaxis->delta_units + 
    yaxis->delta_units*yaxis->delta_units + 
    zaxis->delta_units*zaxis->delta_units);
  duration = ((distance * 60000000.0) / feedrate); //in uS

  // setup axis
  for (i=0;i<3;i++) {
    a = axis_array[i];
    if (axis_array[i]->delta_steps) {
      a->timePerStep = duration / axis_array[i]->delta_steps;
      a->nextEvent = (a->timePerStep>>1); //1st event happens halfway though cycle.
    } else {
      a->nextEvent = 0xFFFFFFFF;
    }
  }

  starttime = micros();
  // start move
  while (xaxis->delta_steps || yaxis->delta_steps || zaxis->delta_steps) {
    a = nextEvent();
    while (micros() < (starttime + a->nextEvent) ); //wait till next action is required
    if (can_move(a)) {
      _STEP_PORT |= a->direct_step_pin;
      //need to wait 1uS
      __asm__("nop\n\t""nop\n\t""nop\n\t""nop\n\t""nop\n\t""nop\n\t");
      __asm__("nop\n\t""nop\n\t""nop\n\t""nop\n\t""nop\n\t""nop\n\t""nop\n\t");
      _STEP_PORT &= ~a->direct_step_pin;
    }
    if (--a->delta_steps) {
      a->nextEvent += a->timePerStep;
    } else {
      a->nextEvent = 0xFFFFFFFF; 
    }
  }

  //we are at the target
  xaxis->current_units = xaxis->target_units;
  yaxis->current_units = yaxis->target_units;
  zaxis->current_units = zaxis->target_units;
  calculate_deltas();

  //Serial.println("DDA_move finished");
  //intRestore(sreg);
}

void set_target(FloatPoint *fp){
  xaxis->target_units = fp->x;
  yaxis->target_units = fp->y;
  zaxis->target_units = fp->z;
  calculate_deltas();
}

void set_position(FloatPoint *fp){
  xaxis->current_units = fp->x;
  yaxis->current_units = fp->y;
  zaxis->current_units = fp->z;
  calculate_deltas();
}


long to_steps(float steps_per_unit, float units){
  return steps_per_unit * units * stepping;
}

void calculate_deltas() {
  //figure our deltas. 
  axis a;
  int i;

  for (i=0; i<3; i++) {
    a = axis_array[i];
    a->delta_units = a->target_units - a->current_units;
    a->delta_steps = to_steps(_units[i], abs(a->delta_units)); //XXX make x_units a vector
    a->direction = (a->delta_units < 0) ? BACKWARD : FORWARD;

    switch(i) {
    case 0: 
        digitalWrite(DIR_X, (a->direction==FORWARD) ? LOW : HIGH); 
      break;
    case 1: 
      digitalWrite(DIR_Y, (a->direction==FORWARD) ? LOW : HIGH); 
      break;
    case 2: 
      digitalWrite(DIR_Z, (a->direction==FORWARD) ? LOW : HIGH); 
      break;
    }
  }
}

long getMaxFeedrate() {
  if (_units[0] == X_STEPS_PER_MM) {
    return (zaxis->delta_steps) ? (FAST_Z_FEEDRATE*25.4) : (FAST_XY_FEEDRATE*25.4); //mm per second
  } else {
    return (zaxis->delta_steps) ? FAST_Z_FEEDRATE : FAST_XY_FEEDRATE; //inches per minute
  }
}



