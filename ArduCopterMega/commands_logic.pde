/// -*- tab-width: 4; Mode: C++; c-basic-offset: 4; indent-tabs-mode: nil -*-

/********************************************************************************/
// Command Event Handlers
/********************************************************************************/
void handle_process_must()
{
	// reset navigation integrators
	// -------------------------
	reset_I();

	switch(next_command.id){

		case MAV_CMD_NAV_TAKEOFF:
			do_takeoff();
			break;

		case MAV_CMD_NAV_WAYPOINT:	// Navigate to Waypoint
			do_nav_wp();
			break;

		case MAV_CMD_NAV_LAND:	// LAND to Waypoint
			do_land();
			break;

		case MAV_CMD_NAV_LOITER_UNLIM:	// Loiter indefinitely
			do_loiter_unlimited();
			break;

		case MAV_CMD_NAV_LOITER_TURNS:	// Loiter N Times
			//do_loiter_turns();
			break;

		case MAV_CMD_NAV_LOITER_TIME:
			do_loiter_time();
			break;

		case MAV_CMD_NAV_RETURN_TO_LAUNCH:
			do_RTL();
			break;
		default:
			break;
	}
}

void handle_process_may()
{
	switch(next_command.id){

		case MAV_CMD_CONDITION_DELAY:
			do_wait_delay();
			break;

		case MAV_CMD_CONDITION_DISTANCE:
			do_within_distance();
			break;

		case MAV_CMD_CONDITION_CHANGE_ALT:
			do_change_alt();
			break;

		case MAV_CMD_CONDITION_YAW:
			do_yaw();
			break;

		default:
			break;
	}
}

void handle_process_now()
{
	switch(next_command.id){

		case MAV_CMD_DO_JUMP:
			do_jump();
			break;

		case MAV_CMD_DO_CHANGE_SPEED:
			//do_change_speed();
			break;

		case MAV_CMD_DO_SET_HOME:
			do_set_home();
			break;

		case MAV_CMD_DO_SET_SERVO:
			do_set_servo();
			break;

		case MAV_CMD_DO_SET_RELAY:
			do_set_relay();
			break;

		case MAV_CMD_DO_REPEAT_SERVO:
			do_repeat_servo();
			break;

		case MAV_CMD_DO_REPEAT_RELAY:
			do_repeat_relay();
			break;

        case MAV_CMD_NAV_ORIENTATION_TARGET:
            do_target_yaw();
	}
}

void handle_no_commands()
{
	if (command_must_ID)
		return;

	switch (control_mode){

		default:
			set_mode(RTL);
			break;
	}
}

/********************************************************************************/
// Verify command Handlers
/********************************************************************************/

bool verify_must()
{
	switch(command_must_ID) {

		case MAV_CMD_NAV_TAKEOFF:
			return verify_takeoff();
			break;

		case MAV_CMD_NAV_LAND:
			return verify_land();
			break;

		case MAV_CMD_NAV_WAYPOINT:
			return verify_nav_wp();
			break;

		case MAV_CMD_NAV_LOITER_UNLIM:
			return false;
			break;

		case MAV_CMD_NAV_LOITER_TURNS:
			return true;
			break;

		case MAV_CMD_NAV_LOITER_TIME:
			return verify_loiter_time();
			break;

		case MAV_CMD_NAV_RETURN_TO_LAUNCH:
			return verify_RTL();
			break;

		default:
			//gcs.send_text_P(SEVERITY_HIGH,PSTR("<verify_must: default> No current Must commands"));
			return false;
			break;
	}
}

bool verify_may()
{
	switch(command_may_ID) {

		case MAV_CMD_CONDITION_DELAY:
			return verify_wait_delay();
			break;

		case MAV_CMD_CONDITION_DISTANCE:
			return verify_within_distance();
			break;

		case MAV_CMD_CONDITION_CHANGE_ALT:
			return verify_change_alt();
			break;

		case MAV_CMD_CONDITION_YAW:
			return verify_yaw();
			break;

		default:
			//gcs.send_text_P(SEVERITY_HIGH,PSTR("<verify_must: default> No current May commands"));
			return false;
			break;
	}
}

/********************************************************************************/
//  Nav (Must) commands
/********************************************************************************/

void do_RTL(void)
{
	control_mode 	= LOITER;
	Location temp 	= home;
	temp.alt 		= read_alt_to_hold();

	//so we know where we are navigating from
	next_WP = current_loc;

	// Loads WP from Memory
	// --------------------
	set_next_WP(&temp);

	// output control mode to the ground station
	gcs.send_message(MSG_HEARTBEAT);

	if (g.log_bitmask & MASK_LOG_MODE)
		Log_Write_Mode(control_mode);
}

void do_takeoff()
{
	Location temp 		= current_loc;
	temp.alt			= next_command.alt;
	takeoff_complete 	= false;			// set flag to use g_gps ground course during TO.  IMU will be doing yaw drift correction

	set_next_WP(&temp);
}

void do_nav_wp()
{
	set_next_WP(&next_command);
}

void do_land()
{
	land_complete 		= false;			// set flag to use g_gps ground course during TO.  IMU will be doing yaw drift correction
	velocity_land		= 1000;

	Location temp 		= current_loc;
	//temp.alt 			= home.alt;
	temp.alt 			= -1000;

	set_next_WP(&temp);
}

void do_loiter_unlimited()
{
	set_next_WP(&next_command);
}

void do_loiter_turns()
{
	set_next_WP(&next_command);
	loiter_total = next_command.p1 * 360;
}

void do_loiter_time()
{
	set_next_WP(&next_command);
	loiter_time = millis();
	loiter_time_max = next_command.p1; // units are (seconds * 10)
}

/********************************************************************************/
//  Verify Nav (Must) commands
/********************************************************************************/

bool verify_takeoff()
{
	if (current_loc.alt > next_WP.alt){
		takeoff_complete = true;
		return true;
	}else{
		return false;
	}
}

bool verify_land()
{
	velocity_land  = ((old_alt - current_loc.alt) *.2) + (velocity_land * .8);
	old_alt = current_loc.alt;

   	if(g.sonar_enabled){
		// decide which sensor we're usings
		if(sonar_alt < 20){
    		land_complete = true;
	    	return true;
	    }
    } else {
		//land_complete = true;
		//return true;
    }

	//update_crosstrack();
	return false;
}

bool verify_nav_wp()
{
	update_crosstrack();
	if ((wp_distance > 0) && (wp_distance <= g.waypoint_radius)) {
		//SendDebug("MSG <verify_must: MAV_CMD_NAV_WAYPOINT> REACHED_WAYPOINT #");
		//SendDebugln(command_must_index,DEC);
		char message[30];
		sprintf(message,"Reached Waypoint #%i",command_must_index);
		gcs.send_text(SEVERITY_LOW,message);
		return true;
	}

	// Have we passed the WP?
	if(loiter_sum > 90){
		gcs.send_text_P(SEVERITY_MEDIUM,PSTR("Missed WP"));
		return true;
	}
	return false;
}

bool verify_loiter_unlim()
{
	return false;
}

bool verify_loiter_time()
{
	if ((millis() - loiter_time) > (long)loiter_time_max * 10000l) {		// scale loiter_time_max from (sec*10) to milliseconds
		gcs.send_text_P(SEVERITY_LOW,PSTR("verify_must: LOITER time complete"));
		return true;
	}
	return false;
}

bool verify_RTL()
{
	if (wp_distance <= g.waypoint_radius) {
		gcs.send_text_P(SEVERITY_LOW,PSTR("Reached home"));
		return true;
	}else{
		return false;
	}
}

/********************************************************************************/
//  Condition (May) commands
/********************************************************************************/

void do_wait_delay()
{
	condition_start = millis();
	condition_value  = next_command.lat * 1000;	// convert to milliseconds
}

void do_change_alt()
{
	Location temp 	= next_WP;
	condition_start = current_loc.alt;
	condition_value = next_command.alt + home.alt;
	temp.alt 		= condition_value;
	set_next_WP(&temp);
}

void do_within_distance()
{
	condition_value  = next_command.lat;
}

void do_yaw()
{
    yaw_tracking = TRACK_NONE;

	// target angle in degrees
	command_yaw_start		= nav_yaw; // current position
	command_yaw_start_time 	= millis();

	command_yaw_dir		    = next_command.p1;      // 1 = clockwise,    0 = counterclockwise
	command_yaw_relative    = next_command.lng;     // 1 = Relative,     0 = Absolute

	command_yaw_speed   	= next_command.lat * 100;


	// if unspecified go 10° a second
	if(command_yaw_speed == 0)
		command_yaw_speed = 6000;

	// if unspecified go counterclockwise
	if(command_yaw_dir == 0)
		command_yaw_dir = -1;

	if (command_yaw_relative){
		// relative
		//command_yaw_dir     = (command_yaw_end > 0) ? 1 : -1;
		//command_yaw_end     += nav_yaw;
		//command_yaw_end     = wrap_360(command_yaw_end);
		command_yaw_delta   = next_command.alt * 100;
	}else{
		// absolute
		command_yaw_end 	= next_command.alt * 100;

        // calculate the delta travel in deg * 100
        if(command_yaw_dir == 1){
            if(command_yaw_start >= command_yaw_end){
                command_yaw_delta = 36000 - (command_yaw_start - command_yaw_end);
            }else{
                command_yaw_delta = command_yaw_end - command_yaw_start;
            }
        }else{
            if(command_yaw_start > command_yaw_end){
                command_yaw_delta = command_yaw_start - command_yaw_end;
            }else{
                command_yaw_delta = 36000 + (command_yaw_start - command_yaw_end);
            }
        }
    	command_yaw_delta = wrap_360(command_yaw_delta);
	}


	// rate to turn deg per second - default is ten
	command_yaw_time 	= command_yaw_delta / command_yaw_speed;
	command_yaw_time    *= 1000;


    //
	//9000 turn in 10 seconds
	//command_yaw_time = 9000/ 10 = 900° per second
}


/********************************************************************************/
// Verify Condition (May) commands
/********************************************************************************/

bool verify_wait_delay()
{
	if ((millis() - condition_start) > condition_value){
		condition_value 	= 0;
		return true;
	}
	return false;
}

bool verify_change_alt()
{
	if (condition_start < next_WP.alt){
		// we are going higer
		if(current_loc.alt > next_WP.alt){
			condition_value = 0;
			return true;
		}
	}else{
		// we are going lower
		if(current_loc.alt < next_WP.alt){
			condition_value = 0;
			return true;
		}
	}
	return false;
}

bool verify_within_distance()
{
	if (wp_distance < condition_value){
		condition_value = 0;
		return true;
	}
	return false;
}

bool verify_yaw()
{
	if((millis() - command_yaw_start_time) > command_yaw_time){
		// time out
		nav_yaw = command_yaw_end;
		return true;

	}else{
		// else we need to be at a certain place
		// power is a ratio of the time : .5 = half done
		float power = (float)(millis() - command_yaw_start_time) / (float)command_yaw_time;

		nav_yaw 	= command_yaw_start + ((float)command_yaw_delta * power * command_yaw_dir);
		nav_yaw     = wrap_360(nav_yaw);
		return false;
	}
}

/********************************************************************************/
//  Do (Now) commands
/********************************************************************************/

void do_target_yaw()
{
    yaw_tracking = next_command.p1;

    if(yaw_tracking & TRACK_TARGET_WP){
        target_WP = next_command;
    }

}

void do_loiter_at_location()
{
	next_WP = current_loc;
}

void do_jump()
{
	struct Location temp;
	if(next_command.lat > 0) {

		command_must_index 	= 0;
		command_may_index 	= 0;
		temp 				= get_wp_with_index(g.waypoint_index);
		temp.lat 			= next_command.lat - 1;					// Decrement repeat counter

		set_wp_with_index(temp, g.waypoint_index);
		g.waypoint_index.set_and_save(next_command.p1 - 1);
	}
}

void do_set_home()
{
	if(next_command.p1 == 1) {
		init_home();
	} else {
		home.id 	= MAV_CMD_NAV_WAYPOINT;
		home.lng 	= next_command.lng;				// Lon * 10**7
		home.lat 	= next_command.lat;				// Lat * 10**7
		home.alt 	= max(next_command.alt, 0);
		home_is_set = true;
	}
}

void do_set_servo()
{
	APM_RC.OutputCh(next_command.p1 - 1, next_command.alt);
}

void do_set_relay()
{
	if (next_command.p1 == 1) {
		relay_on();
	} else if (next_command.p1 == 0) {
		relay_off();
	}else{
		relay_toggle();
	}
}

void do_repeat_servo()
{
	event_id = next_command.p1 - 1;

	if(next_command.p1 >= CH_5 + 1 && next_command.p1 <= CH_8 + 1) {

		event_timer 	= 0;
		event_delay 	= next_command.lng * 500.0;	// /2 (half cycle time) * 1000 (convert to milliseconds)
		event_repeat 	= next_command.lat * 2;
		event_value 	= next_command.alt;

		switch(next_command.p1) {
			case CH_5:
				event_undo_value = g.rc_5.radio_trim;
				break;
			case CH_6:
				event_undo_value = g.rc_6.radio_trim;
				break;
			case CH_7:
				event_undo_value = g.rc_7.radio_trim;
				break;
			case CH_8:
				event_undo_value = g.rc_8.radio_trim;
				break;
		}
		update_events();
	}
}

void do_repeat_relay()
{
	event_id 		= RELAY_TOGGLE;
	event_timer 	= 0;
	event_delay 	= next_command.lat * 500.0;	// /2 (half cycle time) * 1000 (convert to milliseconds)
	event_repeat	= next_command.alt * 2;
	update_events();
}
