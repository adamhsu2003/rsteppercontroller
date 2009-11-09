


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
  
  //figure our stuff.
  calculate_deltas();
}




//a motion is composed of a number of steps that take place
//over a length of time.  a slice of time is the total time
//divided by the number of steps.  We step when the the 
//timeIntoSlice >= .5*timePerStep.  we don't take 
//extra steps by keeping track of when we step.  only
//when the timeIntoSlice becomes a smaller number 
void dda_move(float feedrate) {
  long starttime,time,duration;
  uint32_t desiredStepCount;
  float distance;
  axis a;
  uint8_t i;
  

Serial.println("dda_move()");

  // distance / feedrate * 60000000.0 = move duration in microseconds
  distance = sqrt(xaxis->delta_units*xaxis->delta_units + 
    yaxis->delta_units*yaxis->delta_units + 
    zaxis->delta_units*zaxis->delta_units);
  duration = ((distance * 60000000.0) / feedrate);	

  // setup axis
  for (i=0;i<3;i++) {
    a = axis_array[i];
    if (!axis_array[i]->delta_steps) continue; //skip if no steps required
    a->timePerStep = duration / axis_array[i]->delta_steps;
    a->stepCount = 0;
Serial.println(a->timePerStep, DEC);
  }
  
  starttime = micros();
  // start move
  while (xaxis->delta_steps || yaxis->delta_steps || zaxis->delta_steps) {
    time = micros() - starttime + 10 /*trigger if w/in 10uS of desired time*/;
    for (i=0; i<3; i++) {
      a = axis_array[i];
      if (!a->delta_steps) continue; //skip if no steps required
      //where should we be (integer math)
      desiredStepCount = 1 + ((2*time) / a->timePerStep);
      desiredStepCount >>= 1;
      if (desiredStepCount > a->stepCount) {
        if (can_move(a)) {
          a->stepCount++;
          digitalWrite(a->step_pin, HIGH);
          digitalWrite(a->step_pin, LOW);
        }
        a->delta_steps--;
      }
    }
  }


  //we are at the target
  xaxis->current_units = xaxis->target_units;
  yaxis->current_units = yaxis->target_units;
  zaxis->current_units = zaxis->target_units;
  calculate_deltas();
  
  Serial.println("DDA_move finished");
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
  return steps_per_unit * units;
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
      digitalWrite(DIR_X, (a->direction==FORWARD) ? HIGH : LOW); 
      break;
    case 1: 
      digitalWrite(DIR_Y, (a->direction==FORWARD) ? HIGH : LOW); 
      break;
    case 2: 
      digitalWrite(DIR_Z, (a->direction==FORWARD) ? HIGH : LOW); 
      break;
    }
  }
}

long getMaxFeedrate(){
  return (zaxis->delta_steps) ? FAST_Z_FEEDRATE : FAST_XY_FEEDRATE;
}


